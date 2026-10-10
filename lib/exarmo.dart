// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'backend.dart';
import 'src/third_party/exarmo.g.dart' as native;
import 'src/third_party/exarmo.models.g.dart';

export 'src/third_party/exarmo.models.g.dart';

enum ExarmoMode { aarch64, arm, thumb }

sealed class ExarmoDetails {
  const ExarmoDetails();
}

final class ExarmoAarch64Details extends ExarmoDetails {
  final ExarmoAarch64FlagEffect flags;
  final ExarmoAarch64Branch branch;
  final List<ExarmoAarch64Operand> operands;
  final List<ExarmoAarch64Token> tokens;
  final List<ExarmoAarch64Intrinsic> intrinsics;

  ExarmoAarch64Details({
    required this.flags,
    required this.branch,
    required Iterable<ExarmoAarch64Operand> operands,
    required Iterable<ExarmoAarch64Token> tokens,
    required Iterable<ExarmoAarch64Intrinsic> intrinsics,
  }) : operands = List.unmodifiable(operands),
       tokens = List.unmodifiable(tokens),
       intrinsics = List.unmodifiable(intrinsics);
}

final class ExarmoAarch32Details extends ExarmoDetails {
  final ExarmoAarch32FlagEffect flags;
  final ExarmoAarch32Branch branch;
  final List<ExarmoAarch32Operand> operands;
  final List<ExarmoAarch32Token> tokens;
  final ExarmoAarch32ItState itStateBefore;
  final ExarmoAarch32ItState itStateAfter;
  final ExarmoAarch32Sysreg? systemRegister;

  ExarmoAarch32Details({
    required this.flags,
    required this.branch,
    required Iterable<ExarmoAarch32Operand> operands,
    required Iterable<ExarmoAarch32Token> tokens,
    required this.itStateBefore,
    required this.itStateAfter,
    required this.systemRegister,
  }) : operands = List.unmodifiable(operands),
       tokens = List.unmodifiable(tokens);
}

final class ExarmoInstruction {
  final int address;
  final Uint8List _bytes;
  final int encoding;
  final String encodingName;
  final int mnemonic;
  final String mnemonicName;
  final String text;
  final bool unpredictable;
  final ExarmoDetails details;

  ExarmoInstruction({
    required this.address,
    required List<int> bytes,
    required this.encoding,
    required this.encodingName,
    required this.mnemonic,
    required this.mnemonicName,
    required this.text,
    required this.unpredictable,
    required this.details,
  }) : _bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  Uint8List get bytes => _bytes;
  int get size => _bytes.length;
}

final class Exarmo {
  static final Finalizer<Arena> _finalizer = Finalizer<Arena>(
    (Arena arena) => arena.releaseAll(),
  );
  final ExarmoMode mode;
  final Arena _arena = Arena();
  late final Pointer<native.exarmo_aarch64_instruction> _aarch64;
  late final Pointer<native.exarmo_aarch32_instruction> _aarch32;
  late final Pointer<native.exarmo_aarch32_it_state> _it;
  late final Pointer<Char> _text;
  late final Pointer<native.exarmo_aarch64_token> _tokens64;
  late final Pointer<native.exarmo_aarch32_token> _tokens32;
  late final Pointer<native.exarmo_aarch64_operand> _operands64;
  late final Pointer<native.exarmo_aarch32_operand> _operands32;
  late final Pointer<native.exarmo_aarch32_sysreg> _systemRegister;
  bool _closed = false;
  bool _busy = false;
  int _lastStatus = 0;

  Exarmo(this.mode) {
    try {
      requireBackend(DisassemblerBackend.exarmo);
      requireExarmoDecoder(mode == .aarch64 ? 'arm64' : 'arm');
      final bool validAbi = mode == .aarch64
          ? native.exarmo_aarch64_instruction_size() ==
                sizeOf<native.exarmo_aarch64_instruction>()
          : native.exarmo_aarch32_instruction_size() ==
                sizeOf<native.exarmo_aarch32_instruction>();
      if (!validAbi)
        throw StateError('Exarmo instruction ABI differs from bindings');
      _aarch64 = _arena<native.exarmo_aarch64_instruction>();
      _aarch32 = _arena<native.exarmo_aarch32_instruction>();
      _it = _arena<native.exarmo_aarch32_it_state>();
      _text = _arena<Char>(
        native.EXARMO_AARCH32_MAX_TEXT > native.EXARMO_AARCH64_MAX_TEXT
            ? native.EXARMO_AARCH32_MAX_TEXT + 1
            : native.EXARMO_AARCH64_MAX_TEXT + 1,
      );
      _tokens64 = _arena<native.exarmo_aarch64_token>(
        native.EXARMO_AARCH64_MAX_TOKENS,
      );
      _tokens32 = _arena<native.exarmo_aarch32_token>(
        native.EXARMO_AARCH32_MAX_TOKENS,
      );
      _operands64 = _arena<native.exarmo_aarch64_operand>(
        native.EXARMO_AARCH64_MAX_OPERANDS,
      );
      _operands32 = _arena<native.exarmo_aarch32_operand>(
        native.EXARMO_AARCH32_MAX_OPERANDS,
      );
      _systemRegister = _arena<native.exarmo_aarch32_sysreg>();
      _finalizer.attach(this, _arena, detach: this);
    } catch (_) {
      _arena.releaseAll();
      rethrow;
    }
  }

  bool get isClosed => _closed;

  int registerNumber(int registerClass, int number) {
    if (number < 0 || number > 255) return 0;
    if (mode == .aarch64) {
      if (registerClass ==
              native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W_SP &&
          number != 31) {
        registerClass = native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W;
      } else if (registerClass ==
              native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X_SP &&
          number != 31) {
        registerClass = native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X;
      }
    }
    final int value =
        (mode == .aarch64 ? 0x20000 : 0x10000) | (registerClass << 8) | number;
    return registerName(value).isEmpty ? 0 : value;
  }

  String registerName(int register) {
    final int scope = mode == .aarch64 ? 0x20000 : 0x10000;
    if (register >> 16 != scope >> 16) return '';
    final int registerClass = (register >> 8) & 255;
    final int number = register & 255;
    if (mode != .aarch64) {
      if (registerClass ==
          native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_CORE) {
        return switch (number) {
          >= 0 && <= 12 => 'r$number',
          13 => 'sp',
          14 => 'lr',
          15 => 'pc',
          _ => '',
        };
      }
      return switch (registerClass) {
        native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_S when number < 32 =>
          's$number',
        native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_D when number < 32 =>
          'd$number',
        native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_Q when number < 16 =>
          'q$number',
        _ => '',
      };
    }
    if (number > 31) return '';
    return switch (registerClass) {
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W =>
        number == 31 ? 'wzr' : 'w$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W_SP =>
        number == 31 ? 'wsp' : 'w$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X =>
        number == 31 ? 'xzr' : 'x$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X_SP =>
        number == 31 ? 'sp' : 'x$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_B => 'b$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_H => 'h$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_S => 's$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_D => 'd$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_Q => 'q$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_V => 'v$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_Z => 'z$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_P when number < 16 =>
        'p$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_PN when number < 16 =>
        'pn$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_ZA_TILE
          when number < 16 =>
        'za$number',
      native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_ZT0 when number == 0 =>
        'zt0',
      _ => '',
    };
  }

  int registerId(String name) {
    final String value = name.toLowerCase();
    if (mode != .aarch64) {
      if (value == 'sp') return registerNumber(0, 13);
      if (value == 'lr') return registerNumber(0, 14);
      if (value == 'pc') return registerNumber(0, 15);
      final int number =
          int.tryParse(value.length > 1 ? value.substring(1) : '') ?? -1;
      final int registerClass = switch (value.isEmpty ? '' : value[0]) {
        'r' => native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_CORE,
        's' => native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_S,
        'd' => native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_D,
        'q' => native.exarmo_aarch32_reg_class.EXARMO_AARCH32_REG_Q,
        _ => -1,
      };
      return registerClass < 0 ? 0 : registerNumber(registerClass, number);
    }
    if (value == 'sp')
      return registerNumber(
        native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X_SP,
        31,
      );
    if (value == 'wsp')
      return registerNumber(
        native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W_SP,
        31,
      );
    if (value == 'xzr')
      return registerNumber(
        native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X,
        31,
      );
    if (value == 'wzr')
      return registerNumber(
        native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W,
        31,
      );
    if (value == 'zt0')
      return registerNumber(
        native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_ZT0,
        0,
      );
    const Map<String, int> prefixes = {
      'w': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_W,
      'x': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_X,
      'b': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_B,
      'h': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_H,
      's': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_S,
      'd': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_D,
      'q': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_Q,
      'v': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_V,
      'z': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_Z,
      'p': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_P,
      'pn': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_PN,
      'za': native.exarmo_aarch64_reg_class.EXARMO_AARCH64_REG_ZA_TILE,
    };
    final int prefixSize = value.startsWith('pn') || value.startsWith('za')
        ? 2
        : 1;
    if (value.length <= prefixSize) return 0;
    final int? registerClass = prefixes[value.substring(0, prefixSize)];
    final int number = int.tryParse(value.substring(prefixSize)) ?? -1;
    return registerClass == null ? 0 : registerNumber(registerClass, number);
  }

  int get lastStatus => _lastStatus;

  List<ExarmoInstruction> decode(
    Uint8List bytes, {
    int address = 0,
    int count = 0,
    ExarmoAarch32ItState? itState,
  }) {
    final List<ExarmoInstruction> result = [];
    visit(
      bytes,
      (ExarmoInstruction instruction) {
        result.add(instruction);
        return true;
      },
      address: address,
      count: count,
      itState: itState,
    );
    return List.unmodifiable(result);
  }

  int visit(
    Uint8List bytes,
    bool Function(ExarmoInstruction) visitor, {
    int address = 0,
    int count = 0,
    ExarmoAarch32ItState? itState,
  }) {
    if (_closed) throw StateError('Exarmo is closed');
    if (_busy) throw StateError('Exarmo decode is already active');
    if (count < 0) throw RangeError.value(count, 'count');
    if (bytes.isEmpty) {
      _lastStatus = 0;
      return 0;
    }
    final Pointer<Uint8> input = calloc<Uint8>(bytes.length);
    try {
      input.asTypedList(bytes.length).setAll(0, bytes);
      return visitPointer(
        input,
        bytes.length,
        (ExarmoInstructionView instruction) => visitor(instruction.copy()),
        address: address,
        count: count,
        itState: itState,
      );
    } finally {
      calloc.free(input);
    }
  }

  int visitPointer(
    Pointer<Uint8> input,
    int length,
    bool Function(ExarmoInstructionView) visitor, {
    int address = 0,
    int count = 0,
    ExarmoAarch32ItState? itState,
  }) {
    if (_closed) throw StateError('Exarmo is closed');
    if (_busy) throw StateError('Exarmo decode is already active');
    if (length < 0) throw RangeError.value(length, 'length');
    if (count < 0) throw RangeError.value(count, 'count');
    if (length > 0 && input == nullptr)
      throw ArgumentError.value(input, 'input');
    _lastStatus = 0;
    if (length == 0) return 0;
    _busy = true;
    try {
      _it.ref.kind =
          itState?.kind ??
          native.exarmo_aarch32_it_kind.EXARMO_AARCH32_IT_OUTSIDE;
      _it.ref.cond = itState?.cond ?? 0;
      _it.ref.mask = itState?.mask ?? 0;
      int offset = 0;
      int decoded = 0;
      while (offset < length && (count == 0 || decoded < count)) {
        final ExarmoAarch32ItState before = ExarmoAarch32ItState.copy(_it.ref);
        _lastStatus = switch (mode) {
          .aarch64 => native.exarmo_aarch64_decode_bytes(
            input + offset,
            length - offset,
            _aarch64,
          ),
          .arm => native.exarmo_aarch32_decode_a32_bytes(
            input + offset,
            length - offset,
            _aarch32,
          ),
          .thumb => native.exarmo_aarch32_decode_t32_bytes(
            input + offset,
            length - offset,
            _it.ref,
            _aarch32,
          ),
        };
        if (_lastStatus != 0) break;
        final ExarmoInstructionView instruction = ExarmoInstructionView._(
          this,
          input + offset,
          length - offset,
          address + offset,
          before,
        );
        try {
          final int size = instruction.size;
          if (size < 1 || size > length - offset)
            throw StateError('Exarmo instruction size exceeds input');
          decoded++;
          offset += size;
          final bool follow = visitor(instruction);
          if (mode == .thumb)
            _it.ref = native.exarmo_aarch32_it_state_after(_it.ref, _aarch32);
          if (!follow) break;
        } finally {
          instruction._valid = false;
        }
      }
      return decoded;
    } finally {
      _busy = false;
    }
  }

  ExarmoInstruction _instruction64(Uint8List bytes, int offset, int address) {
    final int size = native.exarmo_aarch64_instruction_length(_aarch64);
    final int encoding = native.exarmo_aarch64_instruction_encoding(_aarch64);
    final int mnemonic = native.exarmo_aarch64_instruction_mnemonic(_aarch64);
    final native.exarmo_aarch64_text_size textSize = native
        .exarmo_aarch64_instruction_tokens(
          _aarch64,
          address,
          _text,
          native.EXARMO_AARCH64_MAX_TEXT + 1,
          _tokens64,
          native.EXARMO_AARCH64_MAX_TOKENS,
        );
    final int operandCount = native.exarmo_aarch64_instruction_operands(
      _aarch64,
      _operands64,
      native.EXARMO_AARCH64_MAX_OPERANDS,
    );
    if (size < 1 ||
        offset + size > bytes.length ||
        textSize.length > native.EXARMO_AARCH64_MAX_TEXT ||
        textSize.tokens > native.EXARMO_AARCH64_MAX_TOKENS ||
        operandCount > native.EXARMO_AARCH64_MAX_OPERANDS)
      throw StateError('Exarmo AArch64 output exceeds header capacities');
    return ExarmoInstruction(
      address: address,
      bytes: bytes.sublist(offset, offset + size),
      encoding: encoding,
      encodingName: _string64(native.exarmo_aarch64_encoding_name(encoding)),
      mnemonic: mnemonic,
      mnemonicName: _string64(native.exarmo_aarch64_mnemonic_name(mnemonic)),
      text: utf8.decode(_text.cast<Uint8>().asTypedList(textSize.length)),
      unpredictable: native.exarmo_aarch64_instruction_unpredictable(_aarch64),
      details: ExarmoAarch64Details(
        flags: ExarmoAarch64FlagEffect.copy(
          native.exarmo_aarch64_instruction_flags(_aarch64),
        ),
        branch: ExarmoAarch64Branch.copy(
          native.exarmo_aarch64_instruction_branch(_aarch64, address),
        ),
        operands: [
          for (int i = 0; i < operandCount; i++)
            ExarmoAarch64Operand.copy(_operands64[i]),
        ],
        tokens: [
          for (int i = 0; i < textSize.tokens; i++)
            ExarmoAarch64Token.copy(_tokens64[i]),
        ],
        intrinsics: _intrinsics64(),
      ),
    );
  }

  List<ExarmoAarch64Intrinsic> _intrinsics64() {
    final int count = native.exarmo_aarch64_instruction_intrinsics(
      _aarch64,
      nullptr,
      0,
    );
    if (count == 0) return const [];
    final Pointer<native.exarmo_aarch64_intrinsic> values =
        calloc<native.exarmo_aarch64_intrinsic>(count);
    try {
      final int written = native.exarmo_aarch64_instruction_intrinsics(
        _aarch64,
        values,
        count,
      );
      if (written > count) throw StateError('Exarmo intrinsic count changed');
      return [
        for (int i = 0; i < written; i++)
          ExarmoAarch64Intrinsic.copy(values[i]),
      ];
    } finally {
      calloc.free(values);
    }
  }

  ExarmoInstruction _instruction32(Uint8List bytes, int offset, int address) {
    final int size = native.exarmo_aarch32_instruction_length(_aarch32);
    final int encoding = native.exarmo_aarch32_instruction_encoding(_aarch32);
    final int mnemonic = native.exarmo_aarch32_instruction_mnemonic(_aarch32);
    final ExarmoAarch32ItState before = ExarmoAarch32ItState.copy(_it.ref);
    final native.exarmo_aarch32_text_size textSize = native
        .exarmo_aarch32_instruction_tokens(
          _aarch32,
          address,
          _text,
          native.EXARMO_AARCH32_MAX_TEXT + 1,
          _tokens32,
          native.EXARMO_AARCH32_MAX_TOKENS,
        );
    final int operandCount = native.exarmo_aarch32_instruction_operands(
      _aarch32,
      _operands32,
      native.EXARMO_AARCH32_MAX_OPERANDS,
    );
    if (size < 1 ||
        offset + size > bytes.length ||
        textSize.length > native.EXARMO_AARCH32_MAX_TEXT ||
        textSize.tokens > native.EXARMO_AARCH32_MAX_TOKENS ||
        operandCount > native.EXARMO_AARCH32_MAX_OPERANDS)
      throw StateError('Exarmo AArch32 output exceeds header capacities');
    final bool hasSystemRegister = native.exarmo_aarch32_instruction_sysreg(
      _aarch32,
      _systemRegister,
    );
    final ExarmoAarch32ItState after = mode == .thumb
        ? ExarmoAarch32ItState.copy(
            native.exarmo_aarch32_it_state_after(_it.ref, _aarch32),
          )
        : before;
    return ExarmoInstruction(
      address: address,
      bytes: bytes.sublist(offset, offset + size),
      encoding: encoding,
      encodingName: _string32(native.exarmo_aarch32_encoding_name(encoding)),
      mnemonic: mnemonic,
      mnemonicName: _string32(native.exarmo_aarch32_mnemonic_name(mnemonic)),
      text: utf8.decode(_text.cast<Uint8>().asTypedList(textSize.length)),
      unpredictable: native.exarmo_aarch32_instruction_unpredictable(_aarch32),
      details: ExarmoAarch32Details(
        flags: ExarmoAarch32FlagEffect.copy(
          native.exarmo_aarch32_instruction_flags(_aarch32),
        ),
        branch: ExarmoAarch32Branch.copy(
          native.exarmo_aarch32_instruction_branch(_aarch32, address),
        ),
        operands: [
          for (int i = 0; i < operandCount; i++)
            ExarmoAarch32Operand.copy(_operands32[i]),
        ],
        tokens: [
          for (int i = 0; i < textSize.tokens; i++)
            ExarmoAarch32Token.copy(_tokens32[i]),
        ],
        itStateBefore: before,
        itStateAfter: after,
        systemRegister: hasSystemRegister
            ? ExarmoAarch32Sysreg.copy(_systemRegister.ref)
            : null,
      ),
    );
  }

  String _string64(native.exarmo_aarch64_str value) =>
      utf8.decode(value.data.cast<Uint8>().asTypedList(value.length));

  String _string32(native.exarmo_aarch32_str value) =>
      utf8.decode(value.data.cast<Uint8>().asTypedList(value.length));

  String mnemonicName(int mnemonic) => mode == .aarch64
      ? _string64(native.exarmo_aarch64_mnemonic_name(mnemonic))
      : _string32(native.exarmo_aarch32_mnemonic_name(mnemonic));

  void close() {
    if (_closed) return;
    if (_busy) throw StateError('Exarmo decode is already active');
    _closed = true;
    _finalizer.detach(this);
    _arena.releaseAll();
  }
}

final class ExarmoInstructionView {
  final Exarmo _decoder;
  final Pointer<Uint8> _input;
  final int _length;
  final int address;
  final ExarmoAarch32ItState itStateBefore;
  bool _valid = true;
  int? _operandCount;

  ExarmoInstructionView._(
    this._decoder,
    this._input,
    this._length,
    this.address,
    this.itStateBefore,
  );

  void _check() {
    if (!_valid) throw StateError('Exarmo instruction view expired');
  }

  ExarmoMode get mode {
    _check();
    return _decoder.mode;
  }

  Pointer<native.exarmo_aarch64_instruction> get aarch64 {
    if (mode != .aarch64) throw StateError('Exarmo instruction is AArch32');
    return _decoder._aarch64;
  }

  Pointer<native.exarmo_aarch32_instruction> get aarch32 {
    if (mode == .aarch64) throw StateError('Exarmo instruction is AArch64');
    return _decoder._aarch32;
  }

  int get size => mode == .aarch64
      ? native.exarmo_aarch64_instruction_length(aarch64)
      : native.exarmo_aarch32_instruction_length(aarch32);

  Uint8List get bytes {
    _check();
    return Uint8List.fromList(_input.asTypedList(size)).asUnmodifiableView();
  }

  String registerName(int register) {
    _check();
    return _decoder.registerName(register);
  }

  int registerId(String name) {
    _check();
    return _decoder.registerId(name);
  }

  int get encoding => mode == .aarch64
      ? native.exarmo_aarch64_instruction_encoding(aarch64)
      : native.exarmo_aarch32_instruction_encoding(aarch32);

  int get mnemonic => mode == .aarch64
      ? native.exarmo_aarch64_instruction_mnemonic(aarch64)
      : native.exarmo_aarch32_instruction_mnemonic(aarch32);

  String get mnemonicName => mode == .aarch64
      ? _decoder._string64(native.exarmo_aarch64_mnemonic_name(mnemonic))
      : _decoder._string32(native.exarmo_aarch32_mnemonic_name(mnemonic));

  String get canonicalMnemonic => mode == .aarch64
      ? _decoder._string64(
          native.exarmo_aarch64_mnemonic_name(
            native.exarmo_aarch64_encoding_mnemonic(encoding),
          ),
        )
      : _decoder._string32(
          native.exarmo_aarch32_mnemonic_name(
            native.exarmo_aarch32_encoding_mnemonic(encoding),
          ),
        );

  int get operandCount {
    _check();
    return _operandCount ??= mode == .aarch64
        ? native.exarmo_aarch64_instruction_operands(
            aarch64,
            _decoder._operands64,
            native.EXARMO_AARCH64_MAX_OPERANDS,
          )
        : native.exarmo_aarch32_instruction_operands(
            aarch32,
            _decoder._operands32,
            native.EXARMO_AARCH32_MAX_OPERANDS,
          );
  }

  Pointer<native.exarmo_aarch64_operand> get operands64 {
    aarch64;
    if (operandCount > native.EXARMO_AARCH64_MAX_OPERANDS)
      throw StateError('Exarmo operand count exceeds header capacity');
    return _decoder._operands64;
  }

  Pointer<native.exarmo_aarch32_operand> get operands32 {
    aarch32;
    if (operandCount > native.EXARMO_AARCH32_MAX_OPERANDS)
      throw StateError('Exarmo operand count exceeds header capacity');
    return _decoder._operands32;
  }

  ExarmoInstruction copy() {
    _check();
    final Uint8List bytes = _input.asTypedList(_length);
    return mode == .aarch64
        ? _decoder._instruction64(bytes, 0, address)
        : _decoder._instruction32(bytes, 0, address);
  }
}
