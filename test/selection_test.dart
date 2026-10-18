import 'dart:typed_data';

import 'package:disassembler/disassembler.dart';
import 'package:disassembler/exarmo_native.dart' as exarmo;
import 'package:disassembler/zydis_native.dart' as zydis;
import 'package:test/test.dart';

/// `mov rax, rcx`, `call +5`, `call rax`, `add rsp, 8`, `ret`, `nop`.
const List<int> _x64Code = [
  0x48, 0x89, 0xC8, 0xE8, 0x05, 0x00, 0x00, 0x00, //
  0xFF, 0xD0, 0x48, 0x83, 0xC4, 0x08, 0xC3, 0x90,
];

/// `bl +8`, `blr x8`, `bl -4`, `ret`, `add x1, x1, #8`, `ldr w0, [x0]`,
/// `nop`, `b +4`, `b.ne +8`, as little endian words.
const List<int> _arm64Words = [
  0x94000002, 0xD63F0100, 0x97FFFFFF, 0xD65F03C0, 0x91002021, //
  0xB9400000, 0xD503201F, 0x14000001, 0x54000041,
];

Uint8List _bytesOf(List<int> words) {
  final Uint8List bytes = Uint8List(words.length * 4);
  final ByteData data = ByteData.sublistView(bytes);
  for (int i = 0; i < words.length; i++) {
    data.setUint32(i * 4, words[i], Endian.little);
  }
  return bytes;
}

/// 32-bit words of a 64-bit linear congruential generator, so every test
/// run sees the same spread over the A64 encoding space.
List<int> _randomWords(int count, int seed) {
  int state = seed;
  final List<int> words = [];
  for (int i = 0; i < count; i++) {
    state = state * 6364136223846793005 + 1442695040888963407;
    words.add((state >>> 32) & 0xffffffff);
  }
  return words;
}

final class _Decoder {
  final Disassembler engine;
  final DisassemblerBuffer buffer;
  final DisassemblerReader reader;
  final DecodedBatch batch = DecodedBatch(capacity: 16384);

  _Decoder._(this.engine, this.buffer, this.reader);

  factory _Decoder(
    DisassemblerArch architecture,
    DisassemblerBackend backend,
    Uint8List code,
  ) {
    final Disassembler engine = Disassembler(architecture, backend: backend);
    final DisassemblerBuffer buffer = DisassemblerBuffer(code);
    final _Decoder decoder = _Decoder._(engine, buffer, engine.reader(buffer));
    addTearDown(decoder.close);
    return decoder;
  }

  int decode({
    DecodeSelection? select,
    Set<ControlFlow> stopAfter = const {},
    bool stopAfterInvalid = false,
  }) => reader.decode(
    batch,
    select: select,
    stopAfter: stopAfter,
    stopAfterInvalid: stopAfterInvalid,
  );

  /// Address, id, operand count and written registers of each record, the
  /// fields a selection changes.
  List<String> records() => [
    for (int i = 0; i < batch.length; i++)
      '${batch.address(i)} ${batch.id(i)} ${batch.size(i)} '
          '${batch.operandCount(i)} ${batch.registersWritten(i)} '
          '${batch.brief(i)}',
  ];

  void close() {
    batch.close();
    reader.close();
    buffer.close();
    engine.close();
  }
}

void main() {
  group('Zydis selection', () {
    test('by flow decodes operands and registers of calls only', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.x64,
        DisassemblerBackend.zydis,
        Uint8List.fromList(_x64Code),
      );
      final int count = d.decode();
      final List<String> full = d.records();
      expect(count, 6);
      expect(d.decode(select: DecodeSelection(flows: {ControlFlow.call})), 6);
      for (int i = 0; i < count; i++) {
        final bool call = d.batch.controlFlow(i) == ControlFlow.call;
        expect(d.batch.brief(i), !call, reason: 'instruction $i');
        if (call) {
          expect(d.records()[i], full[i]);
          continue;
        }
        expect(d.batch.operandCount(i), 0);
        expect(d.batch.hasRegisterAccess(i), isFalse);
        expect(d.batch.registersWritten(i), isNull);
        expect(d.batch.writesFlags(i), isNull);
      }
      expect(d.batch.address(5), 15);
      expect(d.batch.id(5), zydis.ZydisMnemonic.ZYDIS_MNEMONIC_NOP);
    });

    test('by id decodes the operands of that mnemonic', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.x64,
        DisassemblerBackend.zydis,
        Uint8List.fromList(_x64Code),
      );
      d.decode(
        select: DecodeSelection(ids: {zydis.ZydisMnemonic.ZYDIS_MNEMONIC_MOV}),
      );
      expect(d.batch.brief(0), isFalse);
      expect(d.batch.operandCount(0), 2);
      expect(d.batch.registersWritten(0), [d.engine.registerId('rax')]);
      for (int i = 1; i < d.batch.length; i++) {
        expect(d.batch.brief(i), isTrue);
      }
    });

    test('skipping keeps the selected and the stopping instruction', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.x64,
        DisassemblerBackend.zydis,
        Uint8List.fromList(_x64Code),
      );
      final DecodeSelection calls = DecodeSelection(
        flows: {ControlFlow.call},
        skipOthers: true,
      );
      expect(d.decode(select: calls, stopAfter: {ControlFlow.return_}), 3);
      expect([for (int i = 0; i < 3; i++) d.batch.address(i)], [3, 8, 14]);
      expect(d.batch.brief(1), isFalse);
      expect(d.batch.operandCount(1), 1);
      expect(d.batch.brief(2), isTrue);
      expect(d.batch.controlFlow(2), ControlFlow.return_);
      expect(d.batch.stopped, isTrue);
      expect(d.batch.consumed, 15);
      expect(d.decode(select: calls), 2);
      expect(d.batch.consumed, 16);
      expect(d.batch.stopped, isFalse);
    });

    test('skipped invalid bytes are written only on a stop', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.x64,
        DisassemblerBackend.zydis,
        Uint8List.fromList([0x06, 0x06, 0xC3]),
      );
      final DecodeSelection returns = DecodeSelection(
        flows: {ControlFlow.return_},
        skipOthers: true,
      );
      expect(d.decode(select: returns), 1);
      expect(d.batch.address(0), 2);
      expect(d.batch.consumed, 3);
      expect(d.decode(select: returns, stopAfterInvalid: true), 1);
      expect(d.batch.valid(0), isFalse);
      expect(d.batch.consumed, 1);
      expect(d.batch.stopped, isTrue);
    });

    test('a later decode without a selection is full again', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.x64,
        DisassemblerBackend.zydis,
        Uint8List.fromList(_x64Code),
      );
      d.decode(select: DecodeSelection(flows: {ControlFlow.call}));
      expect(d.batch.brief(0), isTrue);
      d.decode();
      for (int i = 0; i < d.batch.length; i++) {
        expect(d.batch.brief(i), isFalse);
        expect(d.batch.hasRegisterAccess(i), isTrue);
      }
    });
  });

  group('exarmo ARM64 selection', () {
    test('skipping by flow keeps calls and the stopping return', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.arm64,
        DisassemblerBackend.exarmo,
        _bytesOf(_arm64Words),
      );
      final DecodeSelection calls = DecodeSelection(
        flows: {ControlFlow.call},
        skipOthers: true,
      );
      expect(d.decode(select: calls, stopAfter: {ControlFlow.return_}), 4);
      expect([for (int i = 0; i < 4; i++) d.batch.address(i)], [0, 4, 8, 12]);
      expect(d.batch.operandCount(0), 1);
      expect(d.batch.operandImmediate(0, 0), 8);
      expect(d.batch.registersWritten(1), [d.engine.registerId('x30')]);
      expect(d.batch.brief(3), isTrue);
      expect(d.batch.stopped, isTrue);
      expect(d.batch.consumed, 16);
      expect(d.decode(select: calls), 3);
      expect(d.batch.consumed, _arm64Words.length * 4);
    });

    test('by id leaves the other instructions brief', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.arm64,
        DisassemblerBackend.exarmo,
        _bytesOf(_arm64Words),
      );
      final DecodeSelection adds = DecodeSelection(
        ids: {exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENC_Add64AddsubImm},
      );
      expect(d.decode(select: adds), _arm64Words.length);
      for (int i = 0; i < d.batch.length; i++) {
        expect(d.batch.brief(i), i != 4, reason: 'instruction $i');
      }
      expect(d.batch.controlFlow(1), ControlFlow.call);
      expect(d.batch.controlFlow(3), ControlFlow.return_);
      expect(d.batch.operandCount(4), 3);
      expect(d.batch.registersWritten(4), [d.engine.registerId('x1')]);
      expect(d.batch.conditional(8), isTrue);
    });

    for (final (String name, DecodeSelection selection) in [
      (
        'calls and 64-bit add immediates',
        DecodeSelection(
          flows: {ControlFlow.call},
          ids: {
            exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENC_Add64AddsubImm,
            exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENC_Ldr32LdstPos,
          },
          skipOthers: true,
        ),
      ),
      (
        'jumps and returns',
        DecodeSelection(
          flows: {ControlFlow.jump, ControlFlow.return_},
          skipOthers: true,
        ),
      ),
      (
        'every encoding with a pattern',
        DecodeSelection(
          ids: {
            for (
              int id = 0;
              id < exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENCODING_COUNT;
              id++
            )
              if (DecodeSelection.arm64Pattern(id) != null) id,
          },
          skipOthers: true,
        ),
      ),
    ]) {
      test('skipping $name over random words matches the brief decode', () {
        final _Decoder d = _Decoder(
          DisassemblerArch.arm64,
          DisassemblerBackend.exarmo,
          _bytesOf([..._arm64Words, ..._randomWords(8192, 0x5eed)]),
        );
        final DecodeSelection brief = DecodeSelection(
          flows: selection.flows,
          ids: selection.ids,
        );
        d.decode(select: brief);
        final List<String> expected = [
          for (int i = 0; i < d.batch.length; i++)
            if (!d.batch.brief(i) && d.batch.status(i) == 0) d.records()[i],
        ];
        expect(expected.length, greaterThan(_arm64Words.length ~/ 2));
        expect(expected.length, lessThan(d.batch.length));
        final int count = d.decode(select: selection);
        expect(d.records(), expected);
        expect(count, expected.length);
        expect(d.batch.consumed, d.buffer.length);
      });
    }

    test('encoding patterns admit their fixture words', () {
      const int bl =
          exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENC_BlOnlyBranchImm;
      expect(DecodeSelection.arm64Pattern(bl), (
        mask: 0xfc000000,
        value: 0x94000000,
      ));
      final ({int mask, int value}) add = DecodeSelection.arm64Pattern(
        exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENC_Add64AddsubImm,
      )!;
      expect(0x91002021 & add.mask, add.value);
      expect(0x91402021 & add.mask, add.value);
      expect(0xD1002021 & add.mask, isNot(add.value));
      expect(DecodeSelection.arm64Pattern(-1), isNull);
      expect(
        DecodeSelection.arm64Pattern(
          exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENCODING_COUNT,
        ),
        isNull,
      );
      int withPattern = 0;
      for (
        int id = 0;
        id < exarmo.exarmo_aarch64_encoding.EXARMO_AARCH64_ENCODING_COUNT;
        id++
      ) {
        if (DecodeSelection.arm64Pattern(id) != null) withPattern++;
      }
      expect(withPattern, 4665);
    });

    test('skipping a range without a selected instruction writes nothing', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.arm64,
        DisassemblerBackend.exarmo,
        _bytesOf([0x91002021, 0xB9400000, 0xD503201F, 0x14000001]),
      );
      final DecodeSelection calls = DecodeSelection(
        flows: {ControlFlow.call},
        skipOthers: true,
      );
      expect(d.decode(select: calls), 0);
      expect(d.batch.consumed, 16);
      expect(d.batch.stopped, isFalse);
      int batches = 0;
      d.reader.visit(d.batch, (DecodedBatch batch) {
        batches++;
        return true;
      }, select: calls);
      expect(batches, 0);
      final DecodedBatch tiny = DecodedBatch(capacity: 1);
      addTearDown(tiny.close);
      expect(d.reader.decode(tiny, end: 0, select: calls), 0);
      expect(tiny.consumed, 0);
    });

    test('a stop on invalid words decodes every word', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.arm64,
        DisassemblerBackend.exarmo,
        _bytesOf([0x94000002, 0xFFFFFFFF, 0x94000002]),
      );
      final DecodeSelection calls = DecodeSelection(
        flows: {ControlFlow.call},
        skipOthers: true,
      );
      expect(d.decode(select: calls), 2);
      expect(d.batch.consumed, 12);
      expect(d.decode(select: calls, stopAfterInvalid: true), 2);
      expect(d.batch.valid(1), isFalse);
      expect(d.batch.stopped, isTrue);
      expect(d.batch.consumed, 8);
    });

    test('visit passes the selection to every batch', () {
      final _Decoder d = _Decoder(
        DisassemblerArch.arm64,
        DisassemblerBackend.exarmo,
        _bytesOf(_randomWords(4096, 7)),
      );
      final DecodedBatch small = DecodedBatch(capacity: 64);
      addTearDown(small.close);
      int batches = 0;
      int brief = 0;
      d.reader.visit(small, (DecodedBatch batch) {
        batches++;
        for (int i = 0; i < batch.length; i++) {
          if (batch.brief(i)) brief++;
        }
        return true;
      }, select: DecodeSelection(flows: {ControlFlow.call}));
      expect(batches, greaterThan(1));
      expect(brief, greaterThan(1000));
    });
  });

  test('Capstone and 32-bit ARM reject a selection', () {
    for (final (DisassemblerArch arch, DisassemblerBackend backend) in [
      (DisassemblerArch.x64, DisassemblerBackend.capstone),
      (DisassemblerArch.arm, DisassemblerBackend.exarmo),
    ]) {
      final _Decoder d = _Decoder(arch, backend, Uint8List.fromList(_x64Code));
      expect(
        () => d.decode(select: DecodeSelection(flows: {ControlFlow.call})),
        throwsUnsupportedError,
      );
      expect(d.decode(), greaterThan(0));
    }
  });

  test('An empty or out of range selection is rejected', () {
    expect(() => DecodeSelection(), throwsArgumentError);
    expect(() => DecodeSelection(ids: {-1}), throwsRangeError);
    expect(() => DecodeSelection(ids: {8192}), throwsRangeError);
  });
}
