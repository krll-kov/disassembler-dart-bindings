@TestOn('vm')
library;

import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:disassembler/disassembler.dart';
import 'package:test/test.dart';

@Native<Uint32 Function(Bool)>(
  symbol: 'disassembler_exarmo_probe',
  assetId: 'package:disassembler/disassembler.dart',
)
external int _probe(bool fail);

void main() {
  test('exarmo panic returns the fallback and the process keeps decoding', () {
    expect(_probe(true), 1);
    expect(_probe(true), 1);
    expect(_probe(false), 2);
    final Disassembler decoder = Disassembler(
      DisassemblerArch.arm64,
      backend: DisassemblerBackend.exarmo,
    );
    addTearDown(decoder.close);
    final List<String> mnemonics = [
      for (final Instruction instruction in decoder.decode(
        Uint8List.fromList([0x20, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6]),
        address: 0x1000,
      ))
        instruction.mnemonic,
    ];
    expect(mnemonics, ['mov', 'ret']);
  });

  test(
    'exarmo panic on several threads returns the fallback on each',
    () async {
      final List<int> results = await Future.wait([
        for (int i = 0; i < 4; i++)
          Isolate.run(() {
            int recovered = 0;
            for (int k = 0; k < 1000; k++) recovered += _probe(k.isEven);
            return recovered;
          }),
      ]);
      expect(results, everyElement(500 * 1 + 500 * 2));
    },
  );
}
