part of '../disassembler.dart';

final class _ZydisDecoder extends _Decoder {
  final DisassemblerArch architecture;
  final zydis.Zydis engine;

  factory _ZydisDecoder(DisassemblerArch architecture) {
    if (architecture != DisassemblerArch.x86 &&
        architecture != DisassemblerArch.x64) {
      throw UnsupportedError('Zydis does not support $architecture');
    }
    return _ZydisDecoder._(
      architecture,
      zydis.Zydis(
        machineMode: architecture == DisassemblerArch.x64
            ? zy.ZydisMachineMode.ZYDIS_MACHINE_MODE_LONG_64
            : zy.ZydisMachineMode.ZYDIS_MACHINE_MODE_LEGACY_32,
        stackWidth: architecture == DisassemblerArch.x64
            ? zy.ZydisStackWidth.ZYDIS_STACK_WIDTH_64
            : zy.ZydisStackWidth.ZYDIS_STACK_WIDTH_32,
      ),
    );
  }

  _ZydisDecoder._(this.architecture, this.engine);

  @override
  void visit(
    Pointer<Uint8> input,
    int length,
    int address,
    bool Function(InstructionView) onInstruction,
  ) {
    engine.visitPointer(
      input,
      length,
      (instruction) => onInstruction(_ZydisInstructionView(this, instruction)),
      address: address,
      invalid: zydis.ZydisInvalidPolicy.skipByte,
    );
  }

  @override
  String registerName(int register) =>
      register == 0 ? '' : engine.registerName(register);

  @override
  int registerId(String name) => engine.registerId(name);

  @override
  void close() => engine.close();
}

final class _ZydisInstructionView extends InstructionView {
  final _ZydisDecoder _decoder;
  final zydis.ZydisInstructionView _view;
  List<Operand>? _operands;
  RegisterAccess? _registers;

  _ZydisInstructionView(this._decoder, this._view);

  void _check() => _view.bytes;

  @override
  DisassemblerBackend get backend {
    _check();
    return DisassemblerBackend.zydis;
  }

  @override
  DisassemblerArch get architecture {
    _check();
    return _decoder.architecture;
  }

  @override
  int get address {
    _check();
    return _view.address;
  }

  @override
  int get size {
    _check();
    return _view.size;
  }

  @override
  int get id => valid ? _view.details.mnemonic : 0;

  @override
  bool get valid {
    _check();
    return _view.valid;
  }

  @override
  String get mnemonic =>
      valid ? zy.ZydisMnemonicGetString(id).cast<Utf8>().toDartString() : '';

  @override
  String get canonicalMnemonic => _x86CanonicalMnemonic(mnemonic);

  @override
  Uint8List get bytes => _view.bytes;

  @override
  List<Operand> get operands {
    _check();
    if (!valid) return const [];
    return _operands ??= List.unmodifiable([
      for (int i = 0; i < _view.details.operand_count_visible; i++)
        _operand(_view.operand(i)),
    ]);
  }

  Operand _operand(zy.ZydisDecodedOperand operand) {
    final OperandKind kind = switch (operand.type) {
      zy.ZydisOperandType.ZYDIS_OPERAND_TYPE_REGISTER => OperandKind.register,
      zy.ZydisOperandType.ZYDIS_OPERAND_TYPE_IMMEDIATE => OperandKind.immediate,
      zy.ZydisOperandType.ZYDIS_OPERAND_TYPE_MEMORY => OperandKind.memory,
      _ => OperandKind.other,
    };
    int access = 0;
    if (operand.actions &
            zy.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_READ !=
        0)
      access |= OperandAccess.read;
    if (operand.actions &
            zy.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_WRITE !=
        0)
      access |= OperandAccess.write;
    final zy.ZydisDecodedOperandImm immediate = operand.unnamed.imm;
    int value = 0;
    if (kind == OperandKind.immediate) {
      value = immediate.is_signed != 0 ? immediate.value.s : immediate.value.u;
      if (immediate.is_relative != 0) {
        value += address + size;
        if (architecture == DisassemblerArch.x86) value &= 0xffffffff;
      }
    }
    final zy.ZydisDecodedOperandMem memory = operand.unnamed.mem;
    final zy.ZydisDecodedInstructionAvx avx = _view.details.avx;
    return Operand(
      kind: kind,
      register: kind == OperandKind.register ? operand.unnamed.reg.value : 0,
      immediate: value,
      size: (operand.size + 7) ~/ 8,
      access: access,
      zeroing:
          access & OperandAccess.write != 0 &&
          (avx.mask.mode == zy.ZydisMaskMode.ZYDIS_MASK_MODE_ZEROING ||
              avx.mask.mode ==
                  zy.ZydisMaskMode.ZYDIS_MASK_MODE_CONTROL_ZEROING),
      broadcast: kind == OperandKind.memory
          ? _zydisBroadcast(avx.broadcast.mode)
          : 0,
      vectorElementBits: operand.element_size,
      vectorLanes: operand.element_count,
      memory: kind == OperandKind.memory
          ? Memory(
              base: memory.base,
              index: memory.index,
              segment: memory.segment,
              scale: memory.scale,
              displacement: memory.disp.has_displacement != 0
                  ? memory.disp.value
                  : 0,
            )
          : null,
    );
  }

  @override
  RegisterAccess? get registerAccess {
    _check();
    if (!valid) return null;
    return _registers ??= RegisterAccess(
      read: _view.registersRead,
      written: _view.registersWritten,
    );
  }

  @override
  ControlFlow get controlFlow {
    if (!valid) return ControlFlow.none;
    return switch (_view.details.meta$1.category) {
      zy.ZydisInstructionCategory.ZYDIS_CATEGORY_CALL => ControlFlow.call,
      zy.ZydisInstructionCategory.ZYDIS_CATEGORY_RET => ControlFlow.return_,
      zy.ZydisInstructionCategory.ZYDIS_CATEGORY_COND_BR ||
      zy.ZydisInstructionCategory.ZYDIS_CATEGORY_UNCOND_BR => ControlFlow.jump,
      zy.ZydisInstructionCategory.ZYDIS_CATEGORY_INTERRUPT =>
        ControlFlow.interrupt,
      _ => ControlFlow.none,
    };
  }

  @override
  bool get conditional =>
      valid &&
      _view.details.meta$1.category ==
          zy.ZydisInstructionCategory.ZYDIS_CATEGORY_COND_BR;

  @override
  String? get condition => conditional ? canonicalMnemonic : null;

  @override
  bool get writeback {
    _check();
    return false;
  }

  @override
  bool get postIndex {
    _check();
    return false;
  }

  @override
  int get immediateSize => valid ? _view.details.raw.imm[0].size ~/ 8 : 0;

  @override
  InstructionDetails get details => ZydisInstructionDetails(_view.copy());

  @override
  bool? get writesFlags => valid
      ? registersWritten!.any(
          (id) => const {
            'flags',
            'eflags',
            'rflags',
          }.contains(_decoder.registerName(id)),
        )
      : null;

  @override
  bool get vectorEncoding =>
      valid &&
      const {
        zy.ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_VEX,
        zy.ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_EVEX,
        zy.ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_XOP,
        zy.ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_MVEX,
      }.contains(_view.details.encoding);
}

String _x86CanonicalMnemonic(String mnemonic) => switch (mnemonic) {
  'jz' => 'je',
  'jnz' => 'jne',
  'jc' || 'jnae' => 'jb',
  'jnc' || 'jnb' => 'jae',
  'jna' => 'jbe',
  'jnbe' => 'ja',
  'jpe' => 'jp',
  'jpo' => 'jnp',
  'jnge' => 'jl',
  'jnl' => 'jge',
  'jng' => 'jle',
  'jnle' => 'jg',
  'sal' => 'shl',
  _ => mnemonic,
};

int _zydisBroadcast(int mode) => switch (mode) {
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_2 => 2,
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_4 => 4,
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_8 => 8,
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_16 => 16,
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_32 => 32,
  zy.ZydisBroadcastMode.ZYDIS_BROADCAST_MODE_1_TO_64 => 64,
  _ => 0,
};
