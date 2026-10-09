import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'src/third_party/zydis.g.dart' as native;
import 'src/third_party/zydis.models.g.dart' as model;

export 'src/third_party/zydis.constants.g.dart';
export 'src/third_party/zydis.models.g.dart';

enum ZydisInvalidPolicy { throwException, stop, skipByte }

final class ZydisException implements Exception {
  final int status;
  final int address;

  const ZydisException(this.status, this.address);

  @override
  String toString() =>
      'Zydis status 0x${status.toRadixString(16)} '
      'at 0x${address.toRadixString(16)}';
}

final class ZydisInstruction {
  final int address;
  final int status;
  final Uint8List bytes;
  final model.ZydisDecodedInstruction? details;
  final List<model.ZydisDecodedOperand> operands;

  ZydisInstruction({
    required this.address,
    required this.status,
    required Uint8List bytes,
    required this.details,
    required List<model.ZydisDecodedOperand> operands,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
       operands = List.unmodifiable(operands);

  bool get valid => details != null;
  int get size => bytes.length;
  String get mnemonic => details == null
      ? ''
      : _nativeString(native.ZydisMnemonicGetString(details!.mnemonic));

  List<model.ZydisDecodedOperand> get visibleOperands =>
      List.unmodifiable(operands.take(details?.operand_count_visible ?? 0));

  Map<int, int> get registerActions {
    final Map<int, int> result = {};
    void add(int register, int actions) {
      if (register != native.ZydisRegister.ZYDIS_REGISTER_NONE) {
        result.update(
          register,
          (value) => value | actions,
          ifAbsent: () => actions,
        );
      }
    }

    for (final operand in operands) {
      if (operand.type == native.ZydisOperandType.ZYDIS_OPERAND_TYPE_REGISTER) {
        add(operand.unnamed.reg.value, operand.actions);
      } else if (operand.type ==
          native.ZydisOperandType.ZYDIS_OPERAND_TYPE_MEMORY) {
        add(
          operand.unnamed.mem.segment,
          native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ,
        );
        add(
          operand.unnamed.mem.base,
          native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ,
        );
        add(
          operand.unnamed.mem.index,
          native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ,
        );
      }
    }
    return Map.unmodifiable(result);
  }

  List<int> get registersRead => List.unmodifiable([
    for (final entry in registerActions.entries)
      if (entry.value &
              native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_READ !=
          0)
        entry.key,
  ]);

  List<int> get registersWritten => List.unmodifiable([
    for (final entry in registerActions.entries)
      if (entry.value &
              native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_WRITE !=
          0)
        entry.key,
  ]);
}

final class ZydisInstructionView {
  final Zydis _decoder;
  final int _epoch;
  final int address;
  final int status;
  final int size;
  final Pointer<Uint8> _bytes;

  ZydisInstructionView._(
    this._decoder,
    this._epoch,
    this.address,
    this.status,
    this.size,
    this._bytes,
  );

  bool get valid => status & 0x80000000 == 0;

  Uint8List get bytes {
    _check();
    return _bytes.asTypedList(size).asUnmodifiableView();
  }

  int get operandCount => valid ? details.operand_count : 0;

  native.ZydisDecodedInstruction get details {
    _check();
    if (!valid) throw StateError('Invalid instruction has no details');
    return _decoder._instruction.ref;
  }

  native.ZydisDecodedOperand operand(int index) {
    _check();
    RangeError.checkValidIndex(index, this, 'index', details.operand_count);
    return (_decoder._operands + index).ref;
  }

  ZydisInstruction copy() {
    _check();
    return ZydisInstruction(
      address: address,
      status: status,
      bytes: _bytes.asTypedList(size),
      details: valid ? model.ZydisDecodedInstruction.copy(details) : null,
      operands: [
        if (valid)
          for (int index = 0; index < details.operand_count; index++)
            model.ZydisDecodedOperand.copy(operand(index)),
      ],
    );
  }

  Map<int, int> get registerActions {
    _check();
    final Map<int, int> result = {};
    void add(int register, int actions) {
      if (register != native.ZydisRegister.ZYDIS_REGISTER_NONE) {
        result.update(
          register,
          (value) => value | actions,
          ifAbsent: () => actions,
        );
      }
    }

    if (valid) {
      for (int index = 0; index < details.operand_count; index++) {
        final value = operand(index);
        if (value.type == native.ZydisOperandType.ZYDIS_OPERAND_TYPE_REGISTER) {
          add(value.unnamed.reg.value, value.actions);
        } else if (value.type ==
            native.ZydisOperandType.ZYDIS_OPERAND_TYPE_MEMORY) {
          final memory = value.unnamed.mem;
          add(
            memory.segment,
            native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ,
          );
          add(memory.base, native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ);
          add(
            memory.index,
            native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_READ,
          );
        }
      }
    }
    return Map.unmodifiable(result);
  }

  List<int> get registersRead => List.unmodifiable([
    for (final entry in registerActions.entries)
      if (entry.value &
              native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_READ !=
          0)
        entry.key,
  ]);

  List<int> get registersWritten => List.unmodifiable([
    for (final entry in registerActions.entries)
      if (entry.value &
              native.ZydisOperandAction.ZYDIS_OPERAND_ACTION_MASK_WRITE !=
          0)
        entry.key,
  ]);

  void _check() {
    if (_decoder._closed || _decoder._epoch != _epoch || !_decoder._active) {
      throw StateError('Instruction view has expired');
    }
  }
}

final class Zydis {
  final Pointer<native.ZydisDecoder> _decoder = calloc();
  final Pointer<native.ZydisDecodedInstruction> _instruction = calloc();
  final Pointer<native.ZydisDecodedOperand> _operands = calloc(
    native.ZYDIS_MAX_OPERAND_COUNT,
  );
  final Pointer<Uint8> _input = calloc(native.ZYDIS_MAX_INSTRUCTION_LENGTH);
  bool _closed = false;
  bool _active = false;
  int _epoch = 0;
  Map<String, int>? _registerIds;

  factory Zydis({
    int machineMode = native.ZydisMachineMode.ZYDIS_MACHINE_MODE_LONG_64,
    int stackWidth = native.ZydisStackWidth.ZYDIS_STACK_WIDTH_64,
  }) {
    requireBackend(DisassemblerBackend.zydis);
    requireZydisFeature('decoder');
    return Zydis._(machineMode, stackWidth);
  }

  Zydis._(int machineMode, int stackWidth) {
    try {
      final int status = native.ZydisDecoderInit(
        _decoder,
        machineMode,
        stackWidth,
      );
      if (status & 0x80000000 != 0) throw ZydisException(status, 0);
    } catch (_) {
      close();
      rethrow;
    }
  }

  void enableMode(int mode, bool enabled) {
    _checkIdle();
    final int status = native.ZydisDecoderEnableMode(
      _decoder,
      mode,
      enabled ? 1 : 0,
    );
    if (status & 0x80000000 != 0) throw ZydisException(status, 0);
  }

  List<ZydisInstruction> decode(
    Uint8List bytes, {
    int address = 0,
    ZydisInvalidPolicy invalid = ZydisInvalidPolicy.throwException,
  }) {
    final List<ZydisInstruction> result = [];
    visit(
      bytes,
      (view) {
        result.add(view.copy());
        return true;
      },
      address: address,
      invalid: invalid,
    );
    return List.unmodifiable(result);
  }

  void visit(
    Uint8List bytes,
    bool Function(ZydisInstructionView) callback, {
    int address = 0,
    ZydisInvalidPolicy invalid = ZydisInvalidPolicy.throwException,
  }) {
    _checkIdle();
    final Uint8List buffer = _input.asTypedList(
      native.ZYDIS_MAX_INSTRUCTION_LENGTH,
    );
    _visit(
      bytes.length,
      (offset, length) {
        buffer.setRange(0, length, bytes, offset);
        return _input;
      },
      callback,
      address,
      invalid,
    );
  }

  void visitPointer(
    Pointer<Uint8> bytes,
    int length,
    bool Function(ZydisInstructionView) callback, {
    int address = 0,
    ZydisInvalidPolicy invalid = ZydisInvalidPolicy.throwException,
  }) {
    RangeError.checkNotNegative(length, 'length');
    if (length > 0 && bytes == nullptr) throw ArgumentError.notNull('bytes');
    _visit(length, (offset, _) => bytes + offset, callback, address, invalid);
  }

  void _visit(
    int length,
    Pointer<Uint8> Function(int, int) input,
    bool Function(ZydisInstructionView) callback,
    int address,
    ZydisInvalidPolicy invalid,
  ) {
    _checkIdle();
    _active = true;
    try {
      for (int offset = 0; offset < length;) {
        final int available = (length - offset).clamp(
          0,
          native.ZYDIS_MAX_INSTRUCTION_LENGTH,
        );
        final Pointer<Uint8> pointer = input(offset, available);
        final int status = native.ZydisDecoderDecodeFull(
          _decoder,
          pointer.cast(),
          available,
          _instruction,
          _operands,
        );
        final bool valid = status & 0x80000000 == 0;
        if (!valid) {
          if (invalid == ZydisInvalidPolicy.stop) break;
          if (invalid == ZydisInvalidPolicy.throwException) {
            throw ZydisException(status, address + offset);
          }
        }
        final int size = valid ? _instruction.ref.length : 1;
        final view = ZydisInstructionView._(
          this,
          ++_epoch,
          address + offset,
          status,
          size,
          pointer,
        );
        final bool proceed = callback(view);
        _epoch++;
        if (!proceed) break;
        offset += size;
      }
    } finally {
      _epoch++;
      _active = false;
    }
  }

  String registerName(int register) {
    _checkOpen();
    return _nativeString(native.ZydisRegisterGetString(register));
  }

  int registerId(String name) {
    _checkOpen();
    final Map<String, int> names = _registerIds ??= Map.unmodifiable({
      for (
        int register = 1;
        register <= native.ZydisRegister.ZYDIS_REGISTER_MAX_VALUE;
        register++
      )
        registerName(register): register,
    });
    return names[name.toLowerCase()] ??
        native.ZydisRegister.ZYDIS_REGISTER_NONE;
  }

  void _checkOpen() {
    if (_closed) throw StateError('Zydis decoder is closed');
  }

  void _checkIdle() {
    _checkOpen();
    if (_active) throw StateError('Zydis decoder is already decoding');
  }

  void close() {
    if (_closed) return;
    if (_active) throw StateError('Cannot close Zydis during decoding');
    _closed = true;
    calloc.free(_input);
    calloc.free(_operands);
    calloc.free(_instruction);
    calloc.free(_decoder);
  }
}

String _nativeString(Pointer<Char> value) =>
    value == nullptr ? '' : value.cast<Utf8>().toDartString();
