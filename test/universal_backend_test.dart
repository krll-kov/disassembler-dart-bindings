@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:disassembler/capstone.dart';
import 'package:test/test.dart';

const _modes = <String, int>{
  'CS_MODE_LITTLE_ENDIAN': Mode.littleEndian,
  'CS_MODE_ARM': Mode.arm,
  'CS_MODE_BPF_CLASSIC': Mode.bpfClassic,
  'CS_MODE_BIG_ENDIAN': Mode.bigEndian,
  'CS_MODE_HPPA_20': Mode.hppa20,
  'CS_MODE_LOONGARCH32': Mode.loongarch32,
  'CS_MODE_M680X_6301': Mode.m680x6301,
  'CS_MODE_M68K_060': Mode.m68k060,
  'CS_MODE_MIPS32R5': Mode.mips32r5,
  'CS_MODE_MOS65XX_6502': Mode.mos65xx6502,
  'CS_MODE_RISCV32': Mode.riscv32,
  'CS_MODE_RISCV_A': Mode.riscvA,
  'CS_MODE_RISCV_D': Mode.riscvFd,
  'CS_MODE_SH4A': Mode.sh4a,
  'CS_MODE_SHFPU': Mode.shfpu,
  'CS_MODE_SYSTEMZ_ARCH14': Mode.systemzArch14,
  'CS_MODE_TRICORE_162': Mode.tricore162,
  'CS_MODE_16': Mode.mode16,
};

String _normalize(String value) => value
    .toLowerCase()
    .replaceAllMapped(
      RegExp(r'0x[0-9a-f]+'),
      (match) => int.parse(match.group(0)!.substring(2), radix: 16).toString(),
    )
    .replaceAll(RegExp(r'\s+'), '');

void main() {
  final fixtures = (jsonDecode(
    File('test/_data/universal_upstream_oracles.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();

  test('All 23 architecture decoders are available', () {
    expect(Architecture.values, hasLength(23));
    expect(
      Capstone.supportedArchitectures,
      unorderedEquals(Architecture.values),
    );
    expect(fixtures, hasLength(23));
  });

  for (final fixture in fixtures) {
    final input = fixture['input'] as Map<String, dynamic>;
    final architectureText = (input['arch'] as String)
        .replaceFirst('CS_ARCH_', '')
        .toLowerCase();
    final architecture = Architecture.values.singleWhere(
      (value) => value.name == architectureText,
    );
    final options = (input['options'] as List).cast<String>();
    var mode = 0;
    for (final option in options.where(
      (value) => value.startsWith('CS_MODE_'),
    )) {
      final value = _modes[option];
      if (value == null) throw StateError('Missing mode $option');
      mode |= value;
    }
    final syntax = options.contains('CS_OPT_SYNTAX_MOTOROLA')
        ? Syntax.motorola
        : options.contains('CS_OPT_SYNTAX_REAL')
        ? Syntax.real
        : null;
    final expected = ((fixture['expected'] as Map)['insns'] as List)
        .cast<Map<String, dynamic>>();

    test('${architecture.name} instructions match upstream byte fixtures', () {
      final decoder = Capstone(
        architecture,
        mode: mode,
        syntax: syntax,
        skipData: false,
      );
      addTearDown(decoder.close);
      final bytes = Uint8List.fromList((input['bytes'] as List).cast<int>());
      final decoded = decoder.decode(
        bytes,
        address: (input['address'] as int?) ?? 0,
      );
      expect(decoded, hasLength(expected.length));
      var position = (input['address'] as int?) ?? 0;
      var offset = 0;
      for (var index = 0; index < expected.length; index++) {
        final instruction = decoded[index];
        expect(instruction.id, greaterThan(0));
        expect(instruction.address, position);
        expect(
          instruction.bytes,
          orderedEquals(bytes.sublist(offset, offset + instruction.size)),
        );
        expect(
          _normalize('${instruction.mnemonic} ${instruction.operandsText}'),
          _normalize(expected[index]['asm_text'] as String),
          reason: '${architecture.name} instruction $index',
        );
        expect(instruction.details, isNotNull);
        expect(
          instruction.details.runtimeType.toString().toLowerCase(),
          '${architecture.name}details',
        );
        expect(instruction.size, greaterThan(0));
        position += instruction.size;
        offset += instruction.size;
      }
      expect(offset, lessThanOrEqualTo(bytes.length));
    });
  }
}
