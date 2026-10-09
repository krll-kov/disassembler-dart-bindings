// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'src/generated/models.g.dart';
import 'src/third_party/capstone.g.dart' as native;

export 'src/generated/models.g.dart';

final class RegisterAccess {
  final List<int> read;
  final List<int> written;

  RegisterAccess(List<int> read, List<int> written)
    : read = List<int>.unmodifiable(read),
      written = List<int>.unmodifiable(written);
}

final class Instruction {
  final int address;
  final int size;
  final int id;
  final int aliasId;
  final bool isAlias;
  final bool usesAliasDetails;
  final bool illegal;
  final String mnemonic;
  final String operandsText;
  final Uint8List bytes;
  final List<int> implicitRegistersRead;
  final List<int> implicitRegistersWritten;
  final List<int> groups;
  final bool writeback;
  final RegisterAccess? registerAccess;
  final ArchitectureDetails? details;

  Instruction({
    required this.address,
    required this.size,
    required this.id,
    required this.aliasId,
    required this.isAlias,
    required this.usesAliasDetails,
    required this.illegal,
    required this.mnemonic,
    required this.operandsText,
    required Uint8List bytes,
    required List<int> implicitRegistersRead,
    required List<int> implicitRegistersWritten,
    required List<int> groups,
    required this.writeback,
    required this.registerAccess,
    required this.details,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
       implicitRegistersRead = List<int>.unmodifiable(implicitRegistersRead),
       implicitRegistersWritten = List<int>.unmodifiable(
         implicitRegistersWritten,
       ),
       groups = List<int>.unmodifiable(groups);
}

final class CapstoneException implements Exception {
  final int code;
  final String message;

  CapstoneException(this.code)
    : message = native.cs_strerror(code).cast<Utf8>().toDartString();

  @override
  String toString() => 'CapstoneException($code): $message';
}

final class Capstone {
  final Architecture architecture;
  final int mode;
  final bool _skipData;
  final bool _detailsEnabled;
  final Map<int, String> _registerNames = {};
  int _handle = 0;
  bool _active = false;

  Capstone(
    this.architecture, {
    this.mode = 0,
    bool details = true,
    bool aliasDetails = false,
    bool skipData = true,
    Syntax? syntax,
  }) : _skipData = skipData,
       _detailsEnabled = details {
    requireBackend(DisassemblerBackend.capstone);
    final int version = native.cs_version(nullptr, nullptr);
    if (version != (native.CS_API_MAJOR << 8 | native.CS_API_MINOR)) {
      throw StateError('Capstone library and bindings versions differ');
    }
    using<void>((Arena arena) {
      final Pointer<UintPtr> handle = arena<UintPtr>();
      _check(native.cs_open(architecture.value, mode, handle));
      _handle = handle.value;
      try {
        _check(
          native.cs_option(
            _handle,
            native.cs_opt_type.CS_OPT_DETAIL,
            details
                ? native.cs_opt_value.CS_OPT_ON |
                      (aliasDetails
                          ? native.cs_opt_value.CS_OPT_DETAIL_ALIAS
                          : native.cs_opt_value.CS_OPT_DETAIL_REAL)
                : native.cs_opt_value.CS_OPT_OFF,
          ),
        );
        _check(
          native.cs_option(
            _handle,
            native.cs_opt_type.CS_OPT_SKIPDATA,
            skipData
                ? native.cs_opt_value.CS_OPT_ON
                : native.cs_opt_value.CS_OPT_OFF,
          ),
        );
        if (syntax != null) {
          _check(
            native.cs_option(
              _handle,
              native.cs_opt_type.CS_OPT_SYNTAX,
              syntax.value,
            ),
          );
        }
      } catch (_) {
        native.cs_close(handle);
        _handle = 0;
        rethrow;
      }
    });
  }

  static bool supports(Architecture architecture) =>
      native.cs_support(architecture.value);

  static List<Architecture> get supportedArchitectures => [
    for (final Architecture architecture in Architecture.values)
      if (supports(architecture)) architecture,
  ];

  List<Instruction> decode(Uint8List bytes, {int address = 0}) {
    final List<Instruction> instructions = [];
    visit(bytes, (Instruction instruction) {
      instructions.add(instruction);
      return true;
    }, address: address);
    return instructions;
  }

  CapstoneReader reader(CapstoneBuffer buffer) {
    _ensureOpen();
    return CapstoneReader._(this, buffer);
  }

  // Native allocations cannot be released when a sync* iterator is abandoned
  void visit(
    Uint8List bytes,
    bool Function(Instruction instruction) onInstruction, {
    int address = 0,
  }) {
    _ensureOpen();
    if (_active) throw StateError('Capstone decoding is already active');
    if (bytes.isEmpty) return;
    final CapstoneBuffer buffer = CapstoneBuffer(bytes);
    try {
      final CapstoneReader input = reader(buffer);
      try {
        input.visit(
          (instruction) => onInstruction(instruction.copy()),
          address: address,
        );
      } finally {
        input.close();
      }
    } finally {
      buffer.close();
    }
  }

  Instruction _copyInstruction(NativeInstructionView instruction) {
    final native.cs_insn? value = instruction.value;
    // ARM64 skip-data stops before incomplete 4-byte instructions
    if (value == null) {
      return Instruction(
        address: instruction.address,
        size: instruction.size,
        id: 0,
        aliasId: 0,
        isAlias: false,
        usesAliasDetails: false,
        illegal: false,
        mnemonic: '.byte',
        operandsText: '',
        bytes: instruction._reader._cursor.value.asTypedList(instruction.size),
        implicitRegistersRead: const [],
        implicitRegistersWritten: const [],
        groups: const [],
        writeback: false,
        registerAccess: null,
        details: null,
      );
    }
    final native.cs_detail? detail = instruction.details;
    final List<int>? read = instruction.registersRead;
    final List<int>? written = instruction.registersWritten;
    return Instruction(
      address: value.address,
      size: value.size,
      id: value.id,
      aliasId: value.alias_id,
      isAlias: value.is_alias,
      usesAliasDetails: value.usesAliasDetails,
      illegal: value.illegal,
      mnemonic: _text(value.mnemonic, 32),
      operandsText: _text(value.op_str, 160),
      bytes: Uint8List.fromList([
        for (int i = 0; i < value.size; i++) value.bytes[i],
      ]),
      implicitRegistersRead: [
        if (detail != null)
          for (int i = 0; i < detail.regs_read_count; i++) detail.regs_read[i],
      ],
      implicitRegistersWritten: [
        if (detail != null)
          for (int i = 0; i < detail.regs_write_count; i++)
            detail.regs_write[i],
      ],
      groups: [
        if (detail != null)
          for (int i = 0; i < detail.groups_count; i++) detail.groups[i],
      ],
      writeback: detail?.writeback ?? false,
      registerAccess: read == null || written == null
          ? null
          : RegisterAccess(read, written),
      details: detail == null
          ? null
          : copyArchitectureDetails(detail, architecture.value),
    );
  }

  String registerName(int register) {
    _ensureOpen();
    return _registerNames.putIfAbsent(register, () {
      final Pointer<Char> name = native.cs_reg_name(_handle, register);
      return name == nullptr ? '' : name.cast<Utf8>().toDartString();
    });
  }

  String instructionName(int instruction) {
    _ensureOpen();
    final Pointer<Char> name = native.cs_insn_name(_handle, instruction);
    return name == nullptr ? '' : name.cast<Utf8>().toDartString();
  }

  String groupName(int group) {
    _ensureOpen();
    final Pointer<Char> name = native.cs_group_name(_handle, group);
    return name == nullptr ? '' : name.cast<Utf8>().toDartString();
  }

  void close() {
    if (_active) throw StateError('Cannot close Capstone during decoding');
    if (_handle == 0) return;
    using<void>((Arena arena) {
      final Pointer<UintPtr> handle = arena<UintPtr>();
      handle.value = _handle;
      _check(native.cs_close(handle));
      _handle = 0;
    });
  }

  void _ensureOpen() {
    if (_handle == 0) throw StateError('Capstone is closed');
  }

  static void _check(int error) {
    if (error != native.cs_err.CS_ERR_OK) throw CapstoneException(error);
  }

  static String _text(Array<Char> text, int length) => String.fromCharCodes([
    for (int i = 0; i < length && text[i] != 0; i++) text[i],
  ]);
}

final class CapstoneBuffer {
  final int length;
  final bool _owned;
  Pointer<Uint8> _data = nullptr;
  int _activeReaders = 0;

  CapstoneBuffer(Uint8List bytes) : length = bytes.length, _owned = true {
    _data = malloc<Uint8>(length == 0 ? 1 : length);
    _data.asTypedList(length).setAll(0, bytes);
  }

  CapstoneBuffer.borrowed(Pointer<Uint8> bytes, this.length) : _owned = false {
    if (length < 0) throw RangeError.range(length, 0, null, 'length');
    if (bytes == nullptr) throw ArgumentError.value(bytes, 'bytes');
    _data = bytes;
  }

  void close() {
    if (_activeReaders != 0) {
      throw StateError('Cannot close buffer during decoding');
    }
    if (_data == nullptr) return;
    if (_owned) malloc.free(_data);
    _data = nullptr;
  }
}

final class CapstoneReader {
  final Capstone _engine;
  final CapstoneBuffer _buffer;
  final Arena _arena = Arena();
  late final Pointer<Pointer<Uint8>> _cursor;
  late final Pointer<Size> _remaining;
  late final Pointer<Uint64> _position;
  late final Pointer<Uint16> _read;
  late final Pointer<Uint16> _written;
  late final Pointer<Uint8> _readCount;
  late final Pointer<Uint8> _writtenCount;
  Pointer<native.cs_insn> _instruction = nullptr;
  bool _active = false;
  int _revision = 0;
  int? _accessStatus;

  CapstoneReader._(this._engine, this._buffer) {
    if (_buffer._data == nullptr) throw StateError('Capstone buffer is closed');
    try {
      _cursor = _arena<Pointer<Uint8>>();
      _remaining = _arena<Size>();
      _position = _arena<Uint64>();
      _read = _arena<Uint16>(64);
      _written = _arena<Uint16>(64);
      _readCount = _arena<Uint8>();
      _writtenCount = _arena<Uint8>();
      _instruction = native.cs_malloc(_engine._handle);
      if (_instruction == nullptr) {
        throw CapstoneException(native.cs_err.CS_ERR_MEM);
      }
    } catch (_) {
      _arena.releaseAll();
      rethrow;
    }
  }

  /// Instruction views expire when visit callback returns
  void visit(
    bool Function(NativeInstructionView instruction) onInstruction, {
    int start = 0,
    int? end,
    int address = 0,
  }) {
    _engine._ensureOpen();
    if (_instruction == nullptr) throw StateError('Capstone reader is closed');
    if (_buffer._data == nullptr) throw StateError('Capstone buffer is closed');
    if (_engine._active)
      throw StateError('Capstone decoding is already active');
    final int stop = RangeError.checkValidRange(start, end, _buffer.length);
    _cursor.value = _buffer._data + start;
    _remaining.value = stop - start;
    _position.value = address;
    _active = true;
    _engine._active = true;
    _buffer._activeReaders++;
    try {
      while (_remaining.value > 0) {
        final bool decoded = native.cs_disasm_iter(
          _engine._handle,
          _cursor,
          _remaining,
          _position,
          _instruction,
        );
        if (!decoded) {
          Capstone._check(native.cs_errno(_engine._handle));
          if (!_engine._skipData) break;
        }
        _accessStatus = null;
        final NativeInstructionView view = NativeInstructionView._(
          this,
          ++_revision,
          decoded ? null : _position.value,
          decoded ? null : _remaining.value,
        );
        final bool more = onInstruction(view);
        _revision++;
        if (!more || !decoded) break;
      }
    } finally {
      _revision++;
      _active = false;
      _engine._active = false;
      _buffer._activeReaders--;
    }
  }

  bool _registerAccess() {
    if (_accessStatus != null) return _accessStatus == native.cs_err.CS_ERR_OK;
    _readCount.value = 0;
    _writtenCount.value = 0;
    final int status = native.cs_regs_access(
      _engine._handle,
      _instruction,
      _read,
      _readCount,
      _written,
      _writtenCount,
    );
    if (status != native.cs_err.CS_ERR_ARCH) Capstone._check(status);
    _accessStatus = status;
    return status == native.cs_err.CS_ERR_OK;
  }

  void close() {
    if (_active) throw StateError('Cannot close reader during decoding');
    if (_instruction == nullptr) return;
    native.cs_free(_instruction, 1);
    _instruction = nullptr;
    _arena.releaseAll();
  }
}

/// Native fields and register lists expire when visit callback returns
final class NativeInstructionView {
  final CapstoneReader _reader;
  final int _revision;
  final int? _trailingAddress;
  final int? _trailingSize;

  NativeInstructionView._(
    this._reader,
    this._revision,
    this._trailingAddress,
    this._trailingSize,
  );

  native.cs_insn? get value {
    _ensureCurrent();
    return _trailingAddress == null ? _reader._instruction.ref : null;
  }

  int get address => value?.address ?? _trailingAddress!;
  int get size => value?.size ?? _trailingSize!;
  int get id => value?.id ?? 0;

  native.cs_detail? get details {
    final native.cs_insn? instruction = value;
    if (!_reader._engine._detailsEnabled ||
        instruction == null ||
        instruction.id == 0 ||
        instruction.detail == nullptr)
      return null;
    return instruction.detail.ref;
  }

  List<int>? get registersRead {
    if (details == null || !_reader._registerAccess()) return null;
    return _reader._read.asTypedList(_reader._readCount.value);
  }

  List<int>? get registersWritten {
    if (details == null || !_reader._registerAccess()) return null;
    return _reader._written.asTypedList(_reader._writtenCount.value);
  }

  Instruction copy() => _reader._engine._copyInstruction(this);

  void _ensureCurrent() {
    if (!_reader._active || _revision != _reader._revision) {
      throw StateError('Instruction view expired');
    }
  }
}
