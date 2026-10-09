part of '../disassembler.dart';

final class _CapstoneDecoder extends _Decoder {
  final DisassemblerArch architecture;
  final capstone.Capstone engine;
  Map<String, int>? _registerIds;

  _CapstoneDecoder(this.architecture)
    : engine = capstone.Capstone(
        switch (architecture) {
          DisassemblerArch.x86 ||
          DisassemblerArch.x64 => capstone.Architecture.x86,
          DisassemblerArch.arm ||
          DisassemblerArch.thumb => capstone.Architecture.arm,
          DisassemblerArch.arm64 => capstone.Architecture.aarch64,
        },
        mode: switch (architecture) {
          DisassemblerArch.x86 => capstone.Mode.mode32,
          DisassemblerArch.x64 => capstone.Mode.mode64,
          DisassemblerArch.thumb => capstone.Mode.thumb,
          _ => 0,
        },
      );

  @override
  void visit(
    Pointer<Uint8> input,
    int length,
    int address,
    bool Function(InstructionView) onInstruction,
  ) {
    final capstone.CapstoneBuffer buffer = capstone.CapstoneBuffer.borrowed(
      input,
      length,
    );
    final capstone.CapstoneReader reader = engine.reader(buffer);
    try {
      reader.visit(
        (instruction) => onInstruction(
          _CapstoneInstructionView(
            this,
            instruction,
            input + instruction.address - address,
          ),
        ),
        address: address,
      );
    } finally {
      reader.close();
      buffer.close();
    }
  }

  @override
  String registerName(int register) => engine.registerName(register);

  @override
  int registerId(String name) {
    final int end = switch (architecture) {
      DisassemblerArch.x86 || DisassemblerArch.x64 => cs.x86_reg.X86_REG_ENDING,
      DisassemblerArch.arm ||
      DisassemblerArch.thumb => cs.arm_reg.ARM_REG_ENDING,
      DisassemblerArch.arm64 => cs.aarch64_reg.AARCH64_REG_ENDING,
    };
    _registerIds ??= {
      for (int id = 1; id < end; id++)
        if (engine.registerName(id).isNotEmpty) engine.registerName(id): id,
    };
    return _registerIds![name.toLowerCase()] ?? 0;
  }

  @override
  void close() => engine.close();

  @override
  _DecoderInput reader(DisassemblerBuffer buffer) =>
      _CapstoneInput(this, buffer);
}

final class _CapstoneInput implements _DecoderInput {
  final _CapstoneDecoder _decoder;
  final capstone.CapstoneBuffer _buffer;
  final capstone.CapstoneReader _reader;
  final Pointer<Uint8> _pointer;

  factory _CapstoneInput(_CapstoneDecoder decoder, DisassemblerBuffer buffer) {
    final capstone.CapstoneBuffer borrowed = capstone.CapstoneBuffer.borrowed(
      buffer.pointer,
      buffer.length,
    );
    try {
      return _CapstoneInput._(
        decoder,
        borrowed,
        decoder.engine.reader(borrowed),
        buffer.pointer,
      );
    } catch (_) {
      borrowed.close();
      rethrow;
    }
  }

  _CapstoneInput._(this._decoder, this._buffer, this._reader, this._pointer);

  @override
  void visit(
    int start,
    int end,
    int address,
    bool Function(InstructionView) onInstruction,
  ) => _reader.visit(
    (instruction) => onInstruction(
      _CapstoneInstructionView(
        _decoder,
        instruction,
        _pointer + start + instruction.address - address,
      ),
    ),
    start: start,
    end: end,
    address: address,
  );

  @override
  void close() {
    _reader.close();
    _buffer.close();
  }
}

final class _CapstoneInstructionView extends InstructionView {
  final _CapstoneDecoder _decoder;
  final capstone.NativeInstructionView _view;
  final Pointer<Uint8> _bytes;
  List<Operand>? _operands;
  RegisterAccess? _registers;
  bool _accessRead = false;

  _CapstoneInstructionView(this._decoder, this._view, this._bytes);

  cs.cs_insn? get _instruction => _view.value;

  @override
  DisassemblerBackend get backend {
    _instruction;
    return DisassemblerBackend.capstone;
  }

  @override
  DisassemblerArch get architecture {
    _instruction;
    return _decoder.architecture;
  }

  @override
  int get address => _view.address;
  @override
  int get size => _view.size;
  @override
  int get id => _view.id;
  @override
  bool get valid => id != 0;

  @override
  String get mnemonic {
    final cs.cs_insn? instruction = _instruction;
    if (instruction == null) return '';
    final List<int> text = [];
    for (int i = 0; i < 32 && instruction.mnemonic[i] != 0; i++) {
      text.add(instruction.mnemonic[i]);
    }
    return String.fromCharCodes(text).toLowerCase();
  }

  @override
  String get canonicalMnemonic =>
      valid ? _decoder.engine.instructionName(id).toLowerCase() : '';

  @override
  Uint8List get bytes {
    _instruction;
    return _bytes.asTypedList(size).asUnmodifiableView();
  }

  @override
  List<Operand> get operands {
    final cs.cs_detail? detail = _view.details;
    if (detail == null) return const [];
    return _operands ??= List.unmodifiable(switch (architecture) {
      DisassemblerArch.x86 || DisassemblerArch.x64 => [
        for (int i = 0; i < detail.unnamed.x86.op_count; i++)
          _x86Operand(detail.unnamed.x86.operands[i]),
      ],
      DisassemblerArch.arm64 => [
        for (int i = 0; i < detail.unnamed.aarch64.op_count; i++)
          _aarch64Operand(detail.unnamed.aarch64.operands[i]),
      ],
      DisassemblerArch.arm || DisassemblerArch.thumb => [
        for (int i = 0; i < detail.unnamed.arm.op_count; i++)
          _armOperand(detail.unnamed.arm.operands[i]),
      ],
    });
  }

  Operand _x86Operand(cs.cs_x86_op operand) {
    final OperandKind kind = switch (operand.type) {
      cs.x86_op_type.X86_OP_REG => OperandKind.register,
      cs.x86_op_type.X86_OP_IMM => OperandKind.immediate,
      cs.x86_op_type.X86_OP_MEM => OperandKind.memory,
      _ => OperandKind.other,
    };
    final cs.x86_op_mem memory = operand.unnamed.mem;
    return Operand(
      kind: kind,
      register: kind == OperandKind.register ? operand.unnamed.reg : 0,
      immediate: kind == OperandKind.immediate ? operand.unnamed.imm : 0,
      size: operand.size,
      access: operand.access,
      zeroing: operand.avx_zero_opmask,
      broadcast: operand.avx_bcast > 0 ? 1 << operand.avx_bcast : 0,
      memory: kind == OperandKind.memory
          ? Memory(
              base: memory.base,
              index: memory.index,
              segment: memory.segment,
              scale: memory.scale,
              displacement: memory.disp,
            )
          : null,
    );
  }

  Operand _aarch64Operand(cs.cs_aarch64_op operand) {
    final OperandKind kind = switch (operand.type) {
      cs.aarch64_op_type.AARCH64_OP_REG ||
      cs.aarch64_op_type.AARCH64_OP_MEM_REG => OperandKind.register,
      cs.aarch64_op_type.AARCH64_OP_IMM ||
      cs.aarch64_op_type.AARCH64_OP_MEM_IMM => OperandKind.immediate,
      cs.aarch64_op_type.AARCH64_OP_MEM => OperandKind.memory,
      _ => OperandKind.other,
    };
    final cs.aarch64_op_mem memory = operand.unnamed.mem;
    final int register = kind == OperandKind.register ? operand.unnamed.reg : 0;
    return Operand(
      kind: kind,
      register: register,
      immediate: kind == OperandKind.immediate ? operand.unnamed.imm : 0,
      size: _registerSize(_decoder.registerName(register)),
      access: operand.access,
      shift: _aarch64Shift(operand.shift.type),
      shiftValue: operand.shift.value,
      extend: _aarch64Extend(operand.ext),
      memory: kind == OperandKind.memory
          ? Memory(
              base: memory.base,
              index: memory.index,
              displacement: memory.disp,
              absolute: memory.base == 0 && memory.index == 0,
            )
          : null,
    );
  }

  Operand _armOperand(cs.cs_arm_op operand) {
    final OperandKind kind = switch (operand.type) {
      cs.arm_op_type.ARM_OP_REG => OperandKind.register,
      cs.arm_op_type.ARM_OP_IMM => OperandKind.immediate,
      cs.arm_op_type.ARM_OP_MEM => OperandKind.memory,
      _ => OperandKind.other,
    };
    final cs.arm_op_mem memory = operand.unnamed.mem;
    return Operand(
      kind: kind,
      register: kind == OperandKind.register ? operand.unnamed.reg : 0,
      immediate: kind == OperandKind.immediate ? operand.unnamed.imm : 0,
      size: kind == OperandKind.register
          ? switch (_decoder.registerName(operand.unnamed.reg)) {
              'sp' => 4,
              final name => _registerSize(name),
            }
          : 0,
      access: operand.access,
      shift: switch (operand.shift.type) {
        cs.arm_shifter.ARM_SFT_LSL => OperandShift.lsl,
        cs.arm_shifter.ARM_SFT_LSR => OperandShift.lsr,
        cs.arm_shifter.ARM_SFT_ASR => OperandShift.asr,
        cs.arm_shifter.ARM_SFT_ROR => OperandShift.ror,
        _ => OperandShift.none,
      },
      shiftValue: operand.shift.value,
      memory: kind == OperandKind.memory
          ? Memory(
              base: memory.base,
              index: memory.index,
              scale: memory.scale,
              displacement: memory.disp,
            )
          : null,
    );
  }

  @override
  RegisterAccess? get registerAccess {
    _instruction;
    if (!_accessRead) {
      _accessRead = true;
      final List<int>? read = _view.registersRead;
      final List<int>? written = _view.registersWritten;
      if (read != null && written != null) {
        _registers = RegisterAccess(read: read, written: written);
      }
    }
    return _registers;
  }

  @override
  ControlFlow get controlFlow {
    final cs.cs_detail? detail = _view.details;
    if (detail == null) return ControlFlow.none;
    for (int i = 0; i < detail.groups_count; i++) {
      switch (detail.groups[i]) {
        case cs.cs_group_type.CS_GRP_CALL:
          return ControlFlow.call;
        case cs.cs_group_type.CS_GRP_RET || cs.cs_group_type.CS_GRP_IRET:
          return ControlFlow.return_;
        case cs.cs_group_type.CS_GRP_JUMP:
          return ControlFlow.jump;
        case cs.cs_group_type.CS_GRP_INT:
          return ControlFlow.interrupt;
      }
    }
    return ControlFlow.none;
  }

  @override
  String? get condition {
    final cs.cs_detail? detail = _view.details;
    if (detail == null) return null;
    if (architecture == DisassemblerArch.arm64)
      return _armCondition(detail.unnamed.aarch64.cc);
    if (architecture == DisassemblerArch.arm ||
        architecture == DisassemblerArch.thumb)
      return _armCondition(detail.unnamed.arm.cc);
    if (controlFlow != ControlFlow.jump || canonicalMnemonic == 'jmp')
      return null;
    return canonicalMnemonic;
  }

  @override
  bool get conditional =>
      condition != null ||
      const {'cbz', 'cbnz', 'tbz', 'tbnz'}.contains(canonicalMnemonic);

  @override
  bool get writeback => _view.details?.writeback ?? false;

  @override
  bool get postIndex {
    final cs.cs_detail? detail = _view.details;
    if (detail == null) return false;
    return switch (architecture) {
      DisassemblerArch.arm64 => detail.unnamed.aarch64.post_index,
      DisassemblerArch.arm ||
      DisassemblerArch.thumb => detail.unnamed.arm.post_index,
      _ => false,
    };
  }

  @override
  int get immediateSize {
    final cs.cs_detail? detail = _view.details;
    if (detail == null) return 0;
    return switch (architecture) {
      DisassemblerArch.x86 ||
      DisassemblerArch.x64 => detail.unnamed.x86.encoding.imm_size,
      _ => 0,
    };
  }

  @override
  InstructionDetails get details => CapstoneInstructionDetails(_view.copy());

  @override
  bool? get writesFlags => registerAccess == null
      ? null
      : registersWritten!.any(
          (id) => const {
            'eflags',
            'rflags',
            'nzcv',
            'cpsr',
          }.contains(_decoder.registerName(id)),
        );

  @override
  bool get vectorEncoding {
    final cs.cs_detail? detail = _view.details;
    if (detail == null ||
        architecture == DisassemblerArch.arm64 ||
        architecture == DisassemblerArch.arm ||
        architecture == DisassemblerArch.thumb)
      return false;
    return [for (int i = 0; i < detail.groups_count; i++) detail.groups[i]].any(
      (group) => const {
        cs.x86_insn_group.X86_GRP_AVX,
        cs.x86_insn_group.X86_GRP_AVX2,
        cs.x86_insn_group.X86_GRP_AVX512,
      }.contains(group),
    );
  }
}

int _registerSize(String name) {
  if (name == 'sp' || name == 'xzr' || name.startsWith('x')) return 8;
  if (name == 'wsp' || name == 'wzr' || name.startsWith('w')) return 4;
  if (name.startsWith('q') || name.startsWith('v')) return 16;
  if (name.startsWith('d')) return 8;
  if (name.startsWith('s')) return 4;
  if (name.startsWith('h')) return 2;
  if (name.startsWith('b')) return 1;
  if (name.startsWith('r') || name == 'lr' || name == 'pc') return 4;
  return 0;
}

OperandShift _aarch64Shift(int value) => switch (value) {
  cs.aarch64_shifter.AARCH64_SFT_LSL => OperandShift.lsl,
  cs.aarch64_shifter.AARCH64_SFT_LSR => OperandShift.lsr,
  cs.aarch64_shifter.AARCH64_SFT_ASR => OperandShift.asr,
  cs.aarch64_shifter.AARCH64_SFT_ROR => OperandShift.ror,
  cs.aarch64_shifter.AARCH64_SFT_MSL => OperandShift.msl,
  _ => OperandShift.none,
};

OperandExtend _aarch64Extend(int value) => switch (value) {
  cs.aarch64_extender.AARCH64_EXT_UXTB => OperandExtend.uxtb,
  cs.aarch64_extender.AARCH64_EXT_UXTH => OperandExtend.uxth,
  cs.aarch64_extender.AARCH64_EXT_UXTW => OperandExtend.uxtw,
  cs.aarch64_extender.AARCH64_EXT_UXTX => OperandExtend.uxtx,
  cs.aarch64_extender.AARCH64_EXT_SXTB => OperandExtend.sxtb,
  cs.aarch64_extender.AARCH64_EXT_SXTH => OperandExtend.sxth,
  cs.aarch64_extender.AARCH64_EXT_SXTW => OperandExtend.sxtw,
  cs.aarch64_extender.AARCH64_EXT_SXTX => OperandExtend.sxtx,
  _ => OperandExtend.none,
};

String? _armCondition(int value) => switch (value) {
  0 => 'eq',
  1 => 'ne',
  2 => 'hs',
  3 => 'lo',
  4 => 'mi',
  5 => 'pl',
  6 => 'vs',
  7 => 'vc',
  8 => 'hi',
  9 => 'ls',
  10 => 'ge',
  11 => 'lt',
  12 => 'gt',
  13 => 'le',
  _ => null,
};
