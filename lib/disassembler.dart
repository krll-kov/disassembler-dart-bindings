import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'capstone.dart' as capstone;
import 'exarmo.dart' as exarmo;
import 'zydis.dart' as zydis;
import 'src/third_party/capstone.g.dart' as cs;
import 'src/third_party/zydis.g.dart' as zy;
import 'src/third_party/exarmo.g.dart' as ex;

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

abstract class InstructionView {
  DisassemblerBackend get backend;
  DisassemblerArch get architecture;
  int get address;
  int get size;
  int get id;
  bool get valid;
  String get mnemonic;
  String get canonicalMnemonic;
  Uint8List get bytes;
  List<Operand> get operands;
  RegisterAccess? get registerAccess;
  ControlFlow get controlFlow;
  bool get conditional;
  String? get condition;
  bool get writeback;
  bool get postIndex;
  int get immediateSize;
  bool? get writesFlags => null;
  bool get vectorEncoding => false;
  InstructionDetails get details;

  List<int>? get registersRead => registerAccess?.read;
  List<int>? get registersWritten => registerAccess?.written;

  Instruction copy() => Instruction(
    backend: backend,
    architecture: architecture,
    address: address,
    size: size,
    id: id,
    valid: valid,
    mnemonic: mnemonic,
    canonicalMnemonic: canonicalMnemonic,
    bytes: bytes,
    operands: operands,
    registerAccess: registerAccess,
    controlFlow: controlFlow,
    conditional: conditional,
    condition: condition,
    writeback: writeback,
    postIndex: postIndex,
    immediateSize: immediateSize,
    writesFlags: writesFlags,
    vectorEncoding: vectorEncoding,
    details: details,
  );
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

  void close() {
    if (_activeReaders != 0)
      throw StateError('Cannot close buffer during decoding');
    if (isClosed) return;
    malloc.free(_pointer);
    _pointer = nullptr;
  }
}

abstract class _Decoder {
  void visit(
    Pointer<Uint8> input,
    int length,
    int address,
    bool Function(InstructionView) onInstruction,
  );
  String registerName(int register);
  int registerId(String name);
  void close();

  _DecoderInput reader(DisassemblerBuffer buffer) =>
      _PointerDecoderInput(this, buffer);
}

abstract interface class _DecoderInput {
  void visit(
    int start,
    int end,
    int address,
    bool Function(InstructionView) onInstruction,
  );
  void close();
}

final class _PointerDecoderInput implements _DecoderInput {
  final _Decoder _decoder;
  final DisassemblerBuffer _buffer;

  _PointerDecoderInput(this._decoder, this._buffer);

  @override
  void visit(
    int start,
    int end,
    int address,
    bool Function(InstructionView) onInstruction,
  ) => _decoder.visit(
    _buffer.pointer + start,
    end - start,
    address,
    onInstruction,
  );

  @override
  void close() {}
}

final class Disassembler {
  final DisassemblerArch architecture;
  final DisassemblerBackend backend;
  final _Decoder _decoder;
  bool _closed = false;
  bool _active = false;

  factory Disassembler(
    DisassemblerArch architecture, {
    required DisassemblerBackend backend,
  }) {
    requireBackend(backend);
    final _Decoder decoder = switch (backend) {
      DisassemblerBackend.capstone => _CapstoneDecoder(architecture),
      DisassemblerBackend.zydis => _ZydisDecoder(architecture),
      DisassemblerBackend.exarmo => _ExarmoDecoder(architecture),
    };
    return Disassembler._(architecture, backend, decoder);
  }

  Disassembler._(this.architecture, this.backend, this._decoder);

  bool get isClosed => _closed;

  DisassemblerReader reader(DisassemblerBuffer buffer) {
    _ensureOpen();
    if (buffer.isClosed) throw StateError('Disassembler buffer is closed');
    return DisassemblerReader._(this, buffer);
  }

  List<Instruction> decode(Uint8List bytes, {int address = 0}) {
    _ensureOpen();
    final DisassemblerBuffer buffer = DisassemblerBuffer(bytes);
    try {
      final DisassemblerReader input = reader(buffer);
      try {
        final List<Instruction> result = [];
        input.visit((instruction) {
          result.add(instruction.copy());
          return true;
        }, address: address);
        return List.unmodifiable(result);
      } finally {
        input.close();
      }
    } finally {
      buffer.close();
    }
  }

  String registerName(int register) {
    _ensureOpen();
    return _decoder.registerName(register);
  }

  int registerId(String name) {
    _ensureOpen();
    return _decoder.registerId(name);
  }

  void close() {
    if (_active) throw StateError('Cannot close disassembler during decoding');
    if (_closed) return;
    _decoder.close();
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Disassembler is closed');
  }
}

final class DisassemblerReader {
  final Disassembler _engine;
  final DisassemblerBuffer _buffer;
  final _DecoderInput _input;
  bool _closed = false;
  bool _active = false;

  DisassemblerReader._(this._engine, this._buffer)
    : _input = _engine._decoder.reader(_buffer);

  void visit(
    bool Function(InstructionView instruction) onInstruction, {
    int start = 0,
    int? end,
    int address = 0,
  }) {
    _engine._ensureOpen();
    if (_closed) throw StateError('Disassembler reader is closed');
    if (_engine._active) throw StateError('Disassembler decoding is active');
    final int stop = RangeError.checkValidRange(start, end, _buffer.length);
    _buffer.pointer;
    _active = true;
    _engine._active = true;
    _buffer._activeReaders++;
    try {
      _input.visit(start, stop, address, onInstruction);
    } finally {
      _buffer._activeReaders--;
      _engine._active = false;
      _active = false;
    }
  }

  void close() {
    if (_active) throw StateError('Cannot close reader during decoding');
    if (_closed) return;
    _input.close();
    _closed = true;
  }
}
