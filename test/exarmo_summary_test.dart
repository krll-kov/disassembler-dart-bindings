import 'dart:typed_data';

import 'package:disassembler/disassembler.dart';
import 'package:disassembler/exarmo.dart';
import 'package:test/test.dart';

/// `bl`, `blr x8`, `ret`, `add x1, x1, #8`, `adds w0, w0, #1`, `ldr w0, [x0]`,
/// `nop`, `b +4`, `b.ne +8`, `cbz x0, +8`, `svc #0`, `brk #0`.
const List<int> _words = [
  0x94000002, 0xD63F0100, 0xD65F03C0, 0x91002021, 0x31000400, 0xB9400000, //
  0xD503201F, 0x14000001, 0x54000041, 0xB4000040, 0xD4000001, 0xD4200000,
];

Uint8List _bytesOf(List<int> words) {
  final Uint8List bytes = Uint8List(words.length * 4);
  final ByteData data = ByteData.sublistView(bytes);
  for (int i = 0; i < words.length; i++) {
    data.setUint32(i * 4, words[i], Endian.little);
  }
  return bytes;
}

List<int> _randomWords(int count, int seed) {
  int state = seed;
  return [
    for (int i = 0; i < count; i++)
      ((state = state * 6364136223846793005 + 1442695040888963407) >>> 32) &
          0xffffffff,
  ];
}

ControlFlow _flowOf(int kind) => switch (kind) {
  1 || 2 => ControlFlow.jump,
  3 || 4 => ControlFlow.call,
  5 || 6 => ControlFlow.return_,
  7 || 8 || 9 => ControlFlow.interrupt,
  _ => ControlFlow.none,
};

void main() {
  test('The batch summary of every word matches the single-field calls', () {
    final Uint8List code = _bytesOf([..._words, ..._randomWords(4096, 11)]);
    final Disassembler engine = Disassembler(
      DisassemblerArch.arm64,
      backend: DisassemblerBackend.exarmo,
    );
    addTearDown(engine.close);
    final Exarmo single = Exarmo(ExarmoMode.aarch64);
    addTearDown(single.close);
    final DisassemblerBuffer buffer = DisassemblerBuffer(code);
    addTearDown(buffer.close);
    final DisassemblerReader reader = engine.reader(buffer);
    addTearDown(reader.close);
    final DecodedBatch batch = DecodedBatch(capacity: 8192);
    addTearDown(batch.close);

    const int address = 0x10000;
    final int count = reader.decode(batch, address: address);
    expect(count, code.length ~/ 4);
    int decoded = 0;
    for (int i = 0; i < count; i++) {
      if (batch.status(i) != 0) continue;
      decoded++;
      final ExarmoInstruction one = single
          .decode(batch.bytes(i), address: batch.address(i))
          .single;
      final ExarmoAarch64Details details = one.details as ExarmoAarch64Details;
      final String word = batch.address(i).toRadixString(16);
      expect(batch.size(i), one.size, reason: word);
      expect(batch.id(i), one.encoding, reason: word);
      expect(batch.valid(i), !one.unpredictable, reason: word);
      if (batch.valid(i)) {
        expect(batch.canonicalMnemonic(i), one.mnemonicName, reason: word);
      }
      expect(batch.controlFlow(i), _flowOf(details.branch.kind), reason: word);
      expect(batch.conditional(i), details.branch.conditional, reason: word);
      expect(batch.writesFlags(i), details.flags.writes != 0, reason: word);
    }
    expect(decoded, greaterThan(_words.length + 1000));
  });
}
