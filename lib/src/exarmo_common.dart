part of '../disassembler.dart';

final class _ExarmoDecoder extends _Decoder {
  final DisassemblerArch architecture;
  final exarmo.Exarmo _decoder;

  _ExarmoDecoder(this.architecture)
    : _decoder = exarmo.Exarmo(switch (architecture) {
        .arm64 => .aarch64,
        .arm => .arm,
        .thumb => .thumb,
        _ => throw UnsupportedError('Exarmo does not decode $architecture'),
      });

  @override
  void visit(
    Pointer<Uint8> input,
    int length,
    int address,
    bool Function(InstructionView) onInstruction,
  ) {
    int offset = 0;
    bool follow = true;
    while (offset < length && follow) {
      _decoder.visitPointer(input + offset, length - offset, (
        exarmo.ExarmoInstructionView view,
      ) {
        offset += view.size;
        follow = onInstruction(_ExarmoInstructionView(this, view));
        return follow;
      }, address: address + offset);
      if (!follow || offset == length) return;
      final int unit = architecture == .thumb ? 2 : 4;
      final int remaining = length - offset;
      final int size = remaining < unit ? remaining : unit;
      final _ExarmoInvalidInstructionView invalid =
          _ExarmoInvalidInstructionView(
            architecture,
            input + offset,
            address + offset,
            size,
            _decoder.lastStatus,
          );
      try {
        follow = onInstruction(invalid);
      } finally {
        invalid._active = false;
      }
      offset += size;
    }
  }

  @override
  String registerName(int register) => _decoder.registerName(register);

  @override
  int registerId(String name) => _decoder.registerId(name);

  @override
  void close() => _decoder.close();
}

final class _ExarmoInvalidInstructionView extends InstructionView {
  final DisassemblerArch _architecture;
  final Pointer<Uint8> _input;
  final int _address;
  final int _size;
  final int _status;
  bool _active = true;

  _ExarmoInvalidInstructionView(
    this._architecture,
    this._input,
    this._address,
    this._size,
    this._status,
  );

  T _checked<T>(T value) {
    if (!_active) throw StateError('Exarmo instruction view expired');
    return value;
  }

  @override
  DisassemblerBackend get backend => _checked(.exarmo);

  @override
  DisassemblerArch get architecture => _checked(_architecture);

  @override
  int get address => _checked(_address);

  @override
  int get size => _checked(_size);

  @override
  int get id => _checked(0);

  @override
  bool get valid => _checked(false);

  @override
  String get mnemonic => _checked('');

  @override
  String get canonicalMnemonic => _checked('');

  @override
  Uint8List get bytes {
    _checked(0);
    return Uint8List.fromList(_input.asTypedList(_size)).asUnmodifiableView();
  }

  @override
  List<Operand> get operands => _checked(const []);

  @override
  RegisterAccess? get registerAccess => _checked(null);

  @override
  ControlFlow get controlFlow => _checked(.none);

  @override
  bool get conditional => _checked(false);

  @override
  String? get condition => _checked(null);

  @override
  bool get writeback => _checked(false);

  @override
  bool get postIndex => _checked(false);

  @override
  int get immediateSize => _checked(0);

  @override
  bool? get writesFlags => _checked(null);

  @override
  bool get vectorEncoding => _checked(false);

  @override
  InvalidInstructionDetails get details =>
      _checked(InvalidInstructionDetails(_status));
}

final class _ExarmoInstructionView extends InstructionView {
  final _ExarmoDecoder _decoder;
  final exarmo.ExarmoInstructionView _view;
  List<Operand>? _operands;
  ex.exarmo_aarch64_branch? _branch64;
  ex.exarmo_aarch32_branch? _branch32;

  _ExarmoInstructionView(this._decoder, this._view);

  bool get _is64 => _view.mode == .aarch64;

  ex.exarmo_aarch64_branch get _aarch64Branch {
    final Pointer<ex.exarmo_aarch64_instruction> instruction = _view.aarch64;
    return _branch64 ??= ex.exarmo_aarch64_instruction_branch(
      instruction,
      address,
    );
  }

  ex.exarmo_aarch32_branch get _aarch32Branch {
    final Pointer<ex.exarmo_aarch32_instruction> instruction = _view.aarch32;
    return _branch32 ??= ex.exarmo_aarch32_instruction_branch(
      instruction,
      address,
    );
  }

  @override
  DisassemblerBackend get backend {
    _view.mode;
    return .exarmo;
  }

  @override
  DisassemblerArch get architecture {
    _view.mode;
    return _decoder.architecture;
  }

  @override
  int get address {
    _view.mode;
    return _view.address;
  }

  @override
  int get size => _view.size;

  @override
  int get id => _view.encoding;

  @override
  bool get valid => _is64
      ? !ex.exarmo_aarch64_instruction_unpredictable(_view.aarch64)
      : !ex.exarmo_aarch32_instruction_unpredictable(_view.aarch32);

  @override
  String get mnemonic => _view.mnemonicName;

  @override
  String get canonicalMnemonic => _view.canonicalMnemonic;

  @override
  Uint8List get bytes => _view.bytes;

  @override
  List<Operand> get operands {
    final bool is64 = _is64;
    return _operands ??= List.unmodifiable([
      for (int i = 0; i < _view.operandCount; i++)
        if (is64)
          _operand64(_view.operands64[i])
        else
          _operand32(_view.operands32[i]),
    ]);
  }

  @override
  RegisterAccess? get registerAccess {
    _view.mode;
    return null;
  }

  @override
  bool get writesFlags => _is64
      ? ex.exarmo_aarch64_instruction_flags(_view.aarch64).writes != 0
      : ex.exarmo_aarch32_instruction_flags(_view.aarch32).writes != 0;

  @override
  ControlFlow get controlFlow {
    final int kind = _is64 ? _aarch64Branch.kind : _aarch32Branch.kind;
    if (_is64) {
      return switch (kind) {
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_DIRECT ||
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_INDIRECT => .jump,
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_DIRECT_CALL ||
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_INDIRECT_CALL =>
          .call,
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_RETURN ||
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_EXCEPTION_RETURN =>
          .return_,
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_SYSTEM_CALL ||
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_EXCEPTION ||
        ex.exarmo_aarch64_branch_kind.EXARMO_AARCH64_BRANCH_HALT => .interrupt,
        _ => .none,
      };
    }
    return switch (kind) {
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_DIRECT ||
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_INDIRECT => .jump,
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_DIRECT_CALL ||
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_INDIRECT_CALL =>
        .call,
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_RETURN ||
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_EXCEPTION_RETURN =>
        .return_,
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_SYSTEM_CALL ||
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_EXCEPTION ||
      ex.exarmo_aarch32_branch_kind.EXARMO_AARCH32_BRANCH_HALT => .interrupt,
      _ => .none,
    };
  }

  @override
  bool get conditional => _is64
      ? _aarch64Branch.conditional
      : _aarch32Branch.conditional || condition != null;

  @override
  String? get condition {
    int? value;
    for (int i = 0; i < _view.operandCount; i++) {
      if (_is64) {
        final ex.exarmo_aarch64_operand operand = _view.operands64[i];
        if (operand.kind ==
            ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_COND) {
          value = operand.unnamed.cond;
          break;
        }
      } else {
        final ex.exarmo_aarch32_operand operand = _view.operands32[i];
        if (operand.kind ==
            ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_COND) {
          value = operand.unnamed.cond;
          break;
        }
      }
    }
    const List<String> values = [
      'eq',
      'ne',
      'hs',
      'lo',
      'mi',
      'pl',
      'vs',
      'vc',
      'hi',
      'ls',
      'ge',
      'lt',
      'gt',
      'le',
    ];
    return value != null && value < values.length ? values[value] : null;
  }

  @override
  bool get writeback => _writeback(false);

  @override
  bool get postIndex => _writeback(true);

  bool _writeback(bool postOnly) {
    for (int i = 0; i < _view.operandCount; i++) {
      if (_is64) {
        final ex.exarmo_aarch64_operand operand = _view.operands64[i];
        if (operand.kind ==
            ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_MEM) {
          final int value = operand.unnamed.mem.writeback;
          if (postOnly
              ? value ==
                    ex.exarmo_aarch64_writeback.EXARMO_AARCH64_WRITEBACK_POST
              : value !=
                    ex.exarmo_aarch64_writeback.EXARMO_AARCH64_WRITEBACK_NONE) {
            return true;
          }
        }
      } else {
        final ex.exarmo_aarch32_operand operand = _view.operands32[i];
        if (operand.kind ==
            ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_MEM) {
          final int value = operand.unnamed.mem.writeback;
          if (postOnly
              ? value ==
                    ex.exarmo_aarch32_writeback.EXARMO_AARCH32_WRITEBACK_POST
              : value !=
                    ex.exarmo_aarch32_writeback.EXARMO_AARCH32_WRITEBACK_NONE) {
            return true;
          }
        } else if (!postOnly &&
            operand.kind ==
                ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_REG &&
            operand.unnamed.reg.writeback) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  int get immediateSize {
    _view.mode;
    return 0;
  }

  @override
  InstructionDetails get details => ExarmoInstructionDetails(_view.copy());

  int _register64(ex.exarmo_aarch64_reg register) =>
      _decoder._decoder.registerNumber(register.class_, register.num);

  int _register32(ex.exarmo_aarch32_reg register) =>
      _decoder._decoder.registerNumber(register.class_, register.num);

  int _width64(int registerClass) => switch (registerClass) {
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W ||
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W_SP ||
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_S => 4,
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X ||
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X_SP ||
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_D => 8,
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_B => 1,
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_H => 2,
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_Q ||
    ex.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_V => 16,
    _ => 0,
  };

  int _width32(int registerClass) => switch (registerClass) {
    ex.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_CORE ||
    ex.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_S => 4,
    ex.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_D => 8,
    ex.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_Q => 16,
    _ => 0,
  };

  OperandShift _shift64(bool present, int kind, int amount) {
    if (!present) return .none;
    if (amount > 0 && _extend64(present, kind) != .none) return .lsl;
    return switch (kind) {
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_LSL => .lsl,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_LSR => .lsr,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_ASR => .asr,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_ROR => .ror,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_MSL => .msl,
      _ => .none,
    };
  }

  OperandExtend _extend64(bool present, int kind) {
    if (!present) return .none;
    return switch (kind) {
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_UXTB => .uxtb,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_UXTH => .uxth,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_UXTW => .uxtw,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_UXTX => .uxtx,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_SXTB => .sxtb,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_SXTH => .sxth,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_SXTW => .sxtw,
      ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_SXTX => .sxtx,
      _ => .none,
    };
  }

  OperandShift _shift32(bool present, int kind) {
    if (!present) return .none;
    return switch (kind) {
      ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_LSL => .lsl,
      ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_LSR => .lsr,
      ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_ASR => .asr,
      ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_ROR => .ror,
      _ => .none,
    };
  }

  int _shiftAmount(bool present, int amount) =>
      present && amount != -1 ? amount : 0;

  Operand _operand64(ex.exarmo_aarch64_operand operand) {
    switch (operand.kind) {
      case ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_REG:
        final ex.exarmo_aarch64_reg_operand value = operand.unnamed.reg;
        if (value.modifier.present &&
            value.modifier.kind ==
                ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_MUL) {
          return const Operand(kind: .other);
        }
        return Operand(
          kind: .register,
          register: _register64(value.reg),
          size: _width64(value.reg.class_),
          shift: _shift64(
            value.modifier.present,
            value.modifier.kind,
            value.modifier.amount,
          ),
          shiftValue: _shiftAmount(
            value.modifier.present,
            value.modifier.amount,
          ),
          extend: _extend64(value.modifier.present, value.modifier.kind),
          zeroing: value.predication == 0x7a,
          vectorElementBits: value.arrangement.element,
          vectorLanes: value.arrangement.lanes,
        );
      case ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_IMM:
        final ex.exarmo_aarch64_modifier modifier =
            operand.unnamed.imm.modifier;
        if (modifier.present &&
            modifier.kind ==
                ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_MUL) {
          return const Operand(kind: .other);
        }
        return Operand(
          kind: .immediate,
          immediate: operand.unnamed.imm.value,
          shift: _shift64(modifier.present, modifier.kind, modifier.amount),
          shiftValue: _shiftAmount(modifier.present, modifier.amount),
          extend: _extend64(modifier.present, modifier.kind),
        );
      case ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_LABEL:
        final ex.exarmo_aarch64_label label = operand.unnamed.label;
        return Operand(
          kind: .immediate,
          immediate:
              ((address + label.pc_ahead) & ~(label.pc_align - 1)) +
              label.offset,
        );
      case ex.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_MEM:
        final ex.exarmo_aarch64_mem memory = operand.unnamed.mem;
        final ex.exarmo_aarch64_offset offset = memory.offset;
        if (offset.mul_vl ||
            offset.modifier.present &&
                offset.modifier.kind ==
                    ex.exarmo_aarch64_modifier_kind.EXARMO_AARCH64_MOD_MUL) {
          return const Operand(kind: .other);
        }
        final bool hasIndex =
            offset.kind ==
                ex.exarmo_aarch64_offset_kind.EXARMO_AARCH64_OFFSET_REG ||
            offset.kind ==
                ex.exarmo_aarch64_offset_kind.EXARMO_AARCH64_OFFSET_VECTOR;
        return Operand(
          kind: .memory,
          memory: Memory(
            base: _register64(memory.base),
            index: hasIndex ? _register64(offset.reg) : 0,
            displacement:
                offset.kind ==
                    ex.exarmo_aarch64_offset_kind.EXARMO_AARCH64_OFFSET_IMM
                ? offset.imm
                : 0,
          ),
          shift: _shift64(
            offset.modifier.present,
            offset.modifier.kind,
            offset.modifier.amount,
          ),
          shiftValue: _shiftAmount(
            offset.modifier.present,
            offset.modifier.amount,
          ),
          extend: _extend64(offset.modifier.present, offset.modifier.kind),
          vectorElementBits: offset.arrangement.element,
          vectorLanes: offset.arrangement.lanes,
        );
      default:
        return const Operand(kind: .other);
    }
  }

  Operand _operand32(ex.exarmo_aarch32_operand operand) {
    switch (operand.kind) {
      case ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_REG:
        final ex.exarmo_aarch32_reg_operand value = operand.unnamed.reg;
        if (value.modifier.has_by ||
            value.modifier.present &&
                value.modifier.kind ==
                    ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_RRX) {
          return const Operand(kind: .other);
        }
        return Operand(
          kind: .register,
          register: _register32(value.reg),
          size: _width32(value.reg.class_),
          shift: _shift32(value.modifier.present, value.modifier.kind),
          shiftValue: _shiftAmount(
            value.modifier.present,
            value.modifier.amount,
          ),
        );
      case ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_IMM:
        final ex.exarmo_aarch32_modifier modifier =
            operand.unnamed.imm.modifier;
        return Operand(
          kind: .immediate,
          immediate: operand.unnamed.imm.value,
          shift: _shift32(modifier.present, modifier.kind),
          shiftValue: _shiftAmount(modifier.present, modifier.amount),
        );
      case ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_LABEL:
        final ex.exarmo_aarch32_label label = operand.unnamed.label;
        return Operand(
          kind: .immediate,
          immediate:
              (((address + label.pc_ahead) & ~(label.pc_align - 1)) +
                  label.offset) &
              0xffffffff,
        );
      case ex.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_MEM:
        final ex.exarmo_aarch32_mem memory = operand.unnamed.mem;
        final ex.exarmo_aarch32_offset offset = memory.offset;
        if (offset.modifier.has_by ||
            offset.modifier.present &&
                offset.modifier.kind ==
                    ex.exarmo_aarch32_modifier_kind.EXARMO_AARCH32_MOD_RRX) {
          return const Operand(kind: .other);
        }
        return Operand(
          kind: .memory,
          memory: Memory(
            base: _register32(memory.base),
            index:
                offset.kind ==
                    ex.exarmo_aarch32_offset_kind.EXARMO_AARCH32_OFFSET_REG
                ? _register32(offset.reg)
                : 0,
            scale: offset.subtract ? -1 : 1,
            displacement:
                offset.kind ==
                    ex.exarmo_aarch32_offset_kind.EXARMO_AARCH32_OFFSET_IMM
                ? offset.imm
                : 0,
          ),
          shift: _shift32(offset.modifier.present, offset.modifier.kind),
          shiftValue: _shiftAmount(
            offset.modifier.present,
            offset.modifier.amount,
          ),
        );
      default:
        return const Operand(kind: .other);
    }
  }
}
