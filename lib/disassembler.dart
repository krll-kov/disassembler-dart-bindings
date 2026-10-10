import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'capstone.dart' as capstone;
import 'exarmo.dart' as exarmo;
import 'zydis.dart' as zydis;
import 'src/third_party/capstone.g.dart' as cs;
import 'src/third_party/disassembler.g.dart' as native;
import 'src/third_party/zydis.g.dart' as zy;

export 'backend.dart';

part 'src/capstone_common.dart';
part 'src/zydis_common.dart';
part 'src/exarmo_common.dart';

enum DisassemblerArch { x86, x64, arm, thumb, arm64 }

enum OperandKind { register, immediate, memory, other }

enum ControlFlow { none, call, jump, return_, interrupt }

enum OperandShift { none, lsl, lsr, asr, ror, msl }

enum OperandExtend { none, uxtb, uxth, uxtw, uxtx, sxtb, sxth, sxtw, sxtx }

abstract final class OperandAccess {
  static const int read = 1;
  static const int write = 2;
}

final class Memory {
  final int base;
  final int index;
  final int segment;
  final int scale;
  final int displacement;
  final bool absolute;

  const Memory({
    this.base = 0,
    this.index = 0,
    this.segment = 0,
    this.scale = 1,
    this.displacement = 0,
    this.absolute = false,
  });
}

final class Operand {
  final OperandKind kind;
  final int register;
  final int immediate;
  final int size;
  final int? access;
  final Memory? memory;
  final OperandShift shift;
  final int shiftValue;
  final OperandExtend extend;
  final bool zeroing;
  final int broadcast;
  final int vectorElementBits;
  final int vectorLanes;

  const Operand({
    required this.kind,
    this.register = 0,
    this.immediate = 0,
    this.size = 0,
    this.access,
    this.memory,
    this.shift = OperandShift.none,
    this.shiftValue = 0,
    this.extend = OperandExtend.none,
    this.zeroing = false,
    this.broadcast = 0,
    this.vectorElementBits = 0,
    this.vectorLanes = 0,
  });
}

final class RegisterAccess {
  final List<int> read;
  final List<int> written;

  RegisterAccess({required Iterable<int> read, required Iterable<int> written})
    : read = List.unmodifiable(read),
      written = List.unmodifiable(written);
}

sealed class InstructionDetails {
  const InstructionDetails();
}

final class InvalidInstructionDetails extends InstructionDetails {
  final int nativeStatus;

  const InvalidInstructionDetails(this.nativeStatus);
}

final class CapstoneInstructionDetails extends InstructionDetails {
  final capstone.Instruction instruction;

  const CapstoneInstructionDetails(this.instruction);
}

final class ZydisInstructionDetails extends InstructionDetails {
  final zydis.ZydisInstruction instruction;

  const ZydisInstructionDetails(this.instruction);
}

final class ExarmoInstructionDetails extends InstructionDetails {
  final exarmo.ExarmoInstruction instruction;

  const ExarmoInstructionDetails(this.instruction);
}

final class Instruction {
  final DisassemblerBackend backend;
  final DisassemblerArch architecture;
  final int address;
  final int size;
  final int id;
  final bool valid;
  final String mnemonic;
  final String canonicalMnemonic;
  final Uint8List bytes;
  final List<Operand> operands;
  final RegisterAccess? registerAccess;
  final ControlFlow controlFlow;
  final bool conditional;
  final String? condition;
  final bool writeback;
  final bool postIndex;
  final int immediateSize;
  final bool? writesFlags;
  final bool vectorEncoding;
  final InstructionDetails details;

  Instruction({
    required this.backend,
    required this.architecture,
    required this.address,
    required this.size,
    required this.id,
    required this.valid,
    required this.mnemonic,
    required this.canonicalMnemonic,
    required Uint8List bytes,
    required Iterable<Operand> operands,
    required this.registerAccess,
    required this.controlFlow,
    required this.conditional,
    required this.condition,
    required this.writeback,
    required this.postIndex,
    required this.immediateSize,
    this.writesFlags,
    this.vectorEncoding = false,
    required this.details,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
       operands = List.unmodifiable(operands);

  List<int>? get registersRead => registerAccess?.read;
  List<int>? get registersWritten => registerAccess?.written;
}

final class DisassemblerBuffer {
  final int length;
  Pointer<Uint8> _pointer = nullptr;
  Uint8List? _view;
  int _activeReaders = 0;

  DisassemblerBuffer(Uint8List bytes) : length = bytes.length {
    _pointer = malloc<Uint8>(length == 0 ? 1 : length);
    _pointer.asTypedList(length).setAll(0, bytes);
  }

  bool get isClosed => _pointer == nullptr;

  Pointer<Uint8> get pointer {
    if (isClosed) throw StateError('Disassembler buffer is closed');
    return _pointer;
  }

  Uint8List get _bytes => _view ??= pointer.asTypedList(length);

  void close() {
    if (_activeReaders != 0)
      throw StateError('Cannot close buffer during decoding');
    if (isClosed) return;
    malloc.free(_pointer);
    _pointer = nullptr;
    _view = null;
  }
}

abstract class _Backend {
  String mnemonic(int key);
  String canonicalMnemonic(int key);
  String registerName(int register);
  int registerId(String name);
  InstructionDetails details(DecodedBatch batch, int index);
  void close();
}

const List<String> _armConditions = [
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

final class Disassembler {
  final DisassemblerArch architecture;
  final DisassemblerBackend backend;
  final _Backend _backend;
  final Pointer<Void> _context;
  bool _closed = false;
  bool _active = false;

  factory Disassembler(
    DisassemblerArch architecture, {
    required DisassemblerBackend backend,
  }) {
    requireBackend(backend);
    final _Backend engine = switch (backend) {
      DisassemblerBackend.capstone => _CapstoneBackend(architecture),
      DisassemblerBackend.zydis => _ZydisBackend(architecture),
      DisassemblerBackend.exarmo => _ExarmoBackend(architecture),
    };
    final Pointer<Void> context = native.disassembler_open(
      backend.index,
      architecture.index,
    );
    if (context == nullptr) {
      engine.close();
      throw UnsupportedError('${backend.name} cannot decode $architecture');
    }
    if (engine is _CapstoneBackend) engine._context = context;
    return Disassembler._(architecture, backend, engine, context);
  }

  Disassembler._(this.architecture, this.backend, this._backend, this._context);

  bool get isClosed => _closed;

  DisassemblerReader reader(DisassemblerBuffer buffer) {
    _ensureOpen();
    if (buffer.isClosed) throw StateError('Disassembler buffer is closed');
    return DisassemblerReader._(this, buffer);
  }

  List<Instruction> decode(Uint8List bytes, {int address = 0}) {
    _ensureOpen();
    final DisassemblerBuffer buffer = DisassemblerBuffer(bytes);
    final DecodedBatch batch = DecodedBatch();
    try {
      final DisassemblerReader input = reader(buffer);
      try {
        final List<Instruction> result = [];
        input.visit(batch, (DecodedBatch decoded) {
          for (int i = 0; i < decoded.length; i++) {
            result.add(decoded.instruction(i));
          }
          return true;
        }, address: address);
        return List.unmodifiable(result);
      } finally {
        input.close();
      }
    } finally {
      batch.close();
      buffer.close();
    }
  }

  String registerName(int register) {
    _ensureOpen();
    return _backend.registerName(register);
  }

  int registerId(String name) {
    _ensureOpen();
    return _backend.registerId(name);
  }

  void close() {
    if (_active) throw StateError('Cannot close disassembler during decoding');
    if (_closed) return;
    native.disassembler_close(_context);
    _backend.close();
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Disassembler is closed');
  }
}

final class DisassemblerReader {
  final Disassembler _engine;
  final DisassemblerBuffer _buffer;
  bool _closed = false;
  bool _active = false;

  DisassemblerReader._(this._engine, this._buffer);

  /// Thumb IT state is kept only with [resume], so an IT block split between
  /// calls without it decodes as code outside IT
  int decode(
    DecodedBatch batch, {
    int start = 0,
    int? end,
    int address = 0,
    int limit = 0,
    Set<ControlFlow> stopAfter = const {},
    bool stopAfterInvalid = false,
    bool resume = false,
  }) {
    _engine._ensureOpen();
    if (_closed) throw StateError('Disassembler reader is closed');
    if (batch._closed) throw StateError('Decoded batch is closed');
    final int stop = RangeError.checkValidRange(start, end, _buffer.length);
    final Pointer<Uint8> pointer = _buffer.pointer;
    int flags = stopAfterInvalid ? native.DISASSEMBLER_STOP_INVALID : 0;
    for (final ControlFlow flow in stopAfter) {
      flags |= switch (flow) {
        ControlFlow.jump => native.DISASSEMBLER_STOP_JUMP,
        ControlFlow.call => native.DISASSEMBLER_STOP_CALL,
        ControlFlow.return_ => native.DISASSEMBLER_STOP_RETURN,
        ControlFlow.interrupt => native.DISASSEMBLER_STOP_INTERRUPT,
        ControlFlow.none => 0,
      };
    }
    final int status = native.disassembler_decode(
      _engine._context,
      pointer + start,
      stop - start,
      address,
      limit,
      flags,
      resume ? 1 : 0,
      batch._native,
    );
    if (status != native.DISASSEMBLER_STATUS_OK &&
        !(status == native.DISASSEMBLER_STATUS_CAPACITY && stop == start)) {
      throw StateError('Decoding failed with status $status');
    }
    batch._attach(_engine, _buffer, start, address, flags);
    return batch.length;
  }

  void visit(
    DecodedBatch batch,
    bool Function(DecodedBatch batch) onBatch, {
    int start = 0,
    int? end,
    int address = 0,
    Set<ControlFlow> stopAfter = const {},
    bool stopAfterInvalid = false,
  }) {
    _engine._ensureOpen();
    if (_closed) throw StateError('Disassembler reader is closed');
    if (_engine._active) throw StateError('Disassembler decoding is active');
    final int stop = RangeError.checkValidRange(start, end, _buffer.length);
    _active = true;
    _engine._active = true;
    _buffer._activeReaders++;
    try {
      int offset = start;
      bool resume = false;
      while (offset < stop) {
        decode(
          batch,
          start: offset,
          end: stop,
          address: address + offset - start,
          stopAfter: stopAfter,
          stopAfterInvalid: stopAfterInvalid,
          resume: resume,
        );
        resume = true;
        if (batch.length == 0) break;
        final bool more = onBatch(batch);
        offset += batch.consumed;
        if (!more || batch.stopped) break;
      }
    } finally {
      _buffer._activeReaders--;
      _engine._active = false;
      _active = false;
    }
  }

  void close() {
    if (_active) throw StateError('Cannot close reader during decoding');
    _closed = true;
  }
}

/// Next decode overwrites these rows, so keep [instruction] copies instead
final class DecodedBatch {
  final int capacity;
  final Pointer<native.disassembler_batch> _native;
  late final Int64List _instructions;
  late final Int64List _operands;
  late final Uint32List _registers;
  Disassembler? _engine;
  DisassemblerBuffer? _buffer;
  int _start = 0;
  int _address = 0;
  int _stop = 0;
  int _count = 0;
  bool _closed = false;

  static final Finalizer<Pointer<native.disassembler_batch>> _finalizer =
      Finalizer(_free);

  DecodedBatch({this.capacity = 4096})
    : _native = calloc<native.disassembler_batch>() {
    if (capacity < 1) {
      calloc.free(_native);
      throw RangeError.value(capacity, 'capacity');
    }
    final int operands = capacity * 8 < 64 ? 64 : capacity * 8;
    final int registers = capacity * 16 < 256 ? 256 : capacity * 16;
    final native.disassembler_batch value = _native.ref;
    value.instructions = calloc<Int64>(
      capacity * native.DISASSEMBLER_INSTRUCTION_STRIDE,
    );
    value.operands = calloc<Int64>(
      operands * native.DISASSEMBLER_OPERAND_STRIDE,
    );
    value.registers = calloc<Uint32>(registers);
    value.instruction_capacity = capacity;
    value.operand_capacity = operands;
    value.register_capacity = registers;
    _instructions = value.instructions.asTypedList(
      capacity * native.DISASSEMBLER_INSTRUCTION_STRIDE,
    );
    _operands = value.operands.asTypedList(
      operands * native.DISASSEMBLER_OPERAND_STRIDE,
    );
    _registers = value.registers.asTypedList(registers);
    _finalizer.attach(this, _native, detach: this);
  }

  static void _free(Pointer<native.disassembler_batch> batch) {
    calloc.free(batch.ref.instructions);
    calloc.free(batch.ref.operands);
    calloc.free(batch.ref.registers);
    calloc.free(batch);
  }

  void _attach(
    Disassembler engine,
    DisassemblerBuffer buffer,
    int start,
    int address,
    int stop,
  ) {
    _engine = engine;
    _buffer = buffer;
    _start = start;
    _address = address;
    _stop = stop;
    _count = _native.ref.count;
  }

  int get length => _count;

  int get consumed => _native.ref.consumed;

  bool get stopped {
    if (length == 0 || _stop == 0) return false;
    final int last = length - 1;
    if (!valid(last)) return _stop & native.DISASSEMBLER_STOP_INVALID != 0;
    return switch (controlFlow(last)) {
      ControlFlow.jump => _stop & native.DISASSEMBLER_STOP_JUMP != 0,
      ControlFlow.call => _stop & native.DISASSEMBLER_STOP_CALL != 0,
      ControlFlow.return_ => _stop & native.DISASSEMBLER_STOP_RETURN != 0,
      ControlFlow.interrupt => _stop & native.DISASSEMBLER_STOP_INTERRUPT != 0,
      ControlFlow.none => false,
    };
  }

  @pragma('vm:prefer-inline')
  int _word(int index, int field) {
    if (index < 0 || index >= _count)
      throw IndexError.withLength(
        index,
        _count,
        indexable: this,
        name: 'index',
      );
    return _instructions[index * native.DISASSEMBLER_INSTRUCTION_STRIDE +
        field];
  }

  int address(int index) => _word(index, 0);

  int size(int index) => _word(index, 1) & 0xffffffff;

  int offset(int index) => _start + address(index) - _address;

  int operandCount(int index) => (_word(index, 1) >> 32) & 0xff;

  int immediateSize(int index) => (_word(index, 1) >> 40) & 0xff;

  bool valid(int index) => _word(index, 2) & 1 != 0;

  ControlFlow controlFlow(int index) =>
      ControlFlow.values[(_word(index, 2) >> 1) & 7];

  bool conditional(int index) => _word(index, 2) & (1 << 4) != 0;

  bool writeback(int index) => _word(index, 2) & (1 << 5) != 0;

  bool postIndex(int index) => _word(index, 2) & (1 << 6) != 0;

  bool vectorEncoding(int index) => _word(index, 2) & (1 << 7) != 0;

  bool? writesFlags(int index) {
    final int flags = _word(index, 2);
    return flags & (1 << 8) == 0 ? null : flags & (1 << 9) != 0;
  }

  bool hasRegisterAccess(int index) => _word(index, 2) & (1 << 10) != 0;

  int id(int index) => _word(index, 3);

  String mnemonic(int index) {
    final int key = _word(index, 4);
    if (key < 0 ||
        _engine!.backend != DisassemblerBackend.capstone && !valid(index)) {
      return '';
    }
    return _engine!._backend.mnemonic(key);
  }

  String canonicalMnemonic(int index) {
    if (!valid(index)) return '';
    return _engine!._backend.canonicalMnemonic(_word(index, 5) & 0xffffffff);
  }

  String? condition(int index) {
    final int code = (_word(index, 1) >> 48) & 0x1f;
    if (code == 0) return null;
    if (code == 31) return canonicalMnemonic(index);
    return _armConditions[code - 1];
  }

  int status(int index) => (_word(index, 7) >> 32) & 0xffffffff;

  int _itState(int index) => (_word(index, 5) >> 32) & 0xffffff;

  Uint8List bytes(int index) {
    final DisassemblerBuffer buffer = _buffer!;
    final int start = offset(index);
    return Uint8List.sublistView(
      buffer._bytes,
      start,
      start + size(index),
    ).asUnmodifiableView();
  }

  List<int>? registersRead(int index) {
    if (!hasRegisterAccess(index)) return null;
    final int start = (_word(index, 6) >> 32) & 0xffffffff;
    final int count = _word(index, 7) & 0xffff;
    return Uint32List.sublistView(_registers, start, start + count);
  }

  List<int>? registersWritten(int index) {
    if (!hasRegisterAccess(index)) return null;
    final int start =
        ((_word(index, 6) >> 32) & 0xffffffff) + (_word(index, 7) & 0xffff);
    final int count = (_word(index, 7) >> 16) & 0xffff;
    return Uint32List.sublistView(_registers, start, start + count);
  }

  @pragma('vm:prefer-inline')
  int _operand(int index, int operand, int field) {
    final int count = operandCount(index);
    if (operand < 0 || operand >= count)
      throw IndexError.withLength(operand, count, name: 'operand');
    final int base = (_word(index, 6) & 0xffffffff) + operand;
    return _operands[base * native.DISASSEMBLER_OPERAND_STRIDE + field];
  }

  OperandKind operandKind(int index, int operand) =>
      OperandKind.values[_operand(index, operand, 0) & 7];

  int? operandAccess(int index, int operand) {
    final int value = _operand(index, operand, 0);
    return value & (1 << 3) == 0 ? null : (value >> 4) & 3;
  }

  int operandSize(int index, int operand) =>
      (_operand(index, operand, 0) >> 8) & 0xff;

  OperandShift operandShift(int index, int operand) =>
      OperandShift.values[(_operand(index, operand, 0) >> 16) & 0xf];

  OperandExtend operandExtend(int index, int operand) =>
      OperandExtend.values[(_operand(index, operand, 0) >> 20) & 0xf];

  bool operandZeroing(int index, int operand) =>
      _operand(index, operand, 0) & (1 << 24) != 0;

  int operandBroadcast(int index, int operand) =>
      (_operand(index, operand, 0) >> 32) & 0xff;

  int operandVectorElementBits(int index, int operand) =>
      (_operand(index, operand, 0) >> 40) & 0xff;

  int operandVectorLanes(int index, int operand) =>
      (_operand(index, operand, 0) >> 48) & 0xff;

  int operandRegister(int index, int operand) => _operand(index, operand, 1);

  int operandImmediate(int index, int operand) => _operand(index, operand, 2);

  int operandShiftValue(int index, int operand) => _operand(index, operand, 7);

  int memoryBase(int index, int operand) => _operand(index, operand, 3);

  int memoryIndex(int index, int operand) => _operand(index, operand, 4);

  int memorySegment(int index, int operand) => _operand(index, operand, 5);

  int memoryScale(int index, int operand) => _operand(index, operand, 0) >> 56;

  int memoryDisplacement(int index, int operand) => _operand(index, operand, 6);

  bool memoryAbsolute(int index, int operand) =>
      _operand(index, operand, 0) & (1 << 25) != 0;

  Operand operand(int index, int operand) {
    final OperandKind kind = operandKind(index, operand);
    return Operand(
      kind: kind,
      register: operandRegister(index, operand),
      immediate: operandImmediate(index, operand),
      size: operandSize(index, operand),
      access: operandAccess(index, operand),
      memory: kind == OperandKind.memory
          ? Memory(
              base: memoryBase(index, operand),
              index: memoryIndex(index, operand),
              segment: memorySegment(index, operand),
              scale: memoryScale(index, operand),
              displacement: memoryDisplacement(index, operand),
              absolute: memoryAbsolute(index, operand),
            )
          : null,
      shift: operandShift(index, operand),
      shiftValue: operandShiftValue(index, operand),
      extend: operandExtend(index, operand),
      zeroing: operandZeroing(index, operand),
      broadcast: operandBroadcast(index, operand),
      vectorElementBits: operandVectorElementBits(index, operand),
      vectorLanes: operandVectorLanes(index, operand),
    );
  }

  Instruction instruction(int index) {
    final Disassembler engine = _engine!;
    final List<int>? read = registersRead(index);
    final List<int>? written = registersWritten(index);
    return Instruction(
      backend: engine.backend,
      architecture: engine.architecture,
      address: address(index),
      size: size(index),
      id: id(index),
      valid: valid(index),
      mnemonic: mnemonic(index),
      canonicalMnemonic: canonicalMnemonic(index),
      bytes: bytes(index),
      operands: [
        for (int i = 0; i < operandCount(index); i++) operand(index, i),
      ],
      registerAccess: read == null || written == null
          ? null
          : RegisterAccess(read: read, written: written),
      controlFlow: controlFlow(index),
      conditional: conditional(index),
      condition: condition(index),
      writeback: writeback(index),
      postIndex: postIndex(index),
      immediateSize: immediateSize(index),
      writesFlags: writesFlags(index),
      vectorEncoding: vectorEncoding(index),
      details: engine._backend.details(this, index),
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _count = 0;
    _finalizer.detach(this);
    _free(_native);
  }
}
