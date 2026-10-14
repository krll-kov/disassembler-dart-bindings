import 'dart:typed_data';

import 'package:disassembler/disassembler.dart';
import 'package:test/test.dart';

void main() {
  for (final DisassemblerBackend backend in DisassemblerBackend.values) {
    final DisassemblerArch architecture = backend == DisassemblerBackend.exarmo
        ? DisassemblerArch.arm64
        : DisassemblerArch.x64;
    final Uint8List bytes = Uint8List.fromList(
      architecture == DisassemblerArch.arm64
          ? [0x20, 0x00, 0x80, 0xd2, 0xc0, 0x03, 0x5f, 0xd6]
          : [0xb8, 1, 0, 0, 0, 0xc3],
    );

    test('$backend rejects absent register identities', () {
      final Disassembler decoder = Disassembler(architecture, backend: backend);
      addTearDown(decoder.close);
      expect(decoder.registerName(0), isEmpty);
    });

    test('$backend preserves typed details after decoding', () {
      final Disassembler decoder = Disassembler(architecture, backend: backend);
      final List<Instruction> instructions = decoder.decode(
        bytes,
        address: 0x1000,
      );
      decoder.close();
      expect(instructions.length, 2);
      expect(instructions.first.address, 0x1000);
      expect(instructions.first.valid, isTrue);
      expect(instructions.first.operands.first.kind, OperandKind.register);
      expect(instructions.last.controlFlow, ControlFlow.return_);
      expect(instructions.first.details, switch (backend) {
        DisassemblerBackend.capstone => isA<CapstoneInstructionDetails>(),
        DisassemblerBackend.zydis => isA<ZydisInstructionDetails>(),
        DisassemblerBackend.exarmo => isA<ExarmoInstructionDetails>(),
      });
      expect(() => instructions.first.bytes[0] = 0, throwsUnsupportedError);
      expect(() => instructions.first.operands.clear(), throwsUnsupportedError);
    });

    test('$backend rejects expired views and active resource closure', () {
      final Disassembler decoder = Disassembler(architecture, backend: backend);
      final DisassemblerBuffer buffer = DisassemblerBuffer(bytes);
      final DisassemblerReader reader = decoder.reader(buffer);
      final DecodedBatch batch = DecodedBatch();
      addTearDown(() {
        batch.close();
        reader.close();
        buffer.close();
        decoder.close();
      });
      reader.visit(batch, (decoded) {
        expect(() => buffer.close(), throwsStateError);
        expect(() => reader.close(), throwsStateError);
        expect(() => decoder.close(), throwsStateError);
        return false;
      });
      int count = 0;
      reader.visit(batch, (decoded) {
        count += decoded.length;
        return true;
      });
      expect(count, 2);
      batch.close();
      expect(() => batch.operand(0, 0), throwsRangeError);
      expect(() => batch.instruction(0), throwsRangeError);
      reader.close();
      expect(() => reader.visit(batch, (_) => true), throwsStateError);
      decoder.close();
      expect(() => decoder.decode(bytes), throwsStateError);
      expect(() => decoder.reader(buffer), throwsStateError);
    });

    test('$backend translates relative branch targets', () {
      final Disassembler decoder = Disassembler(architecture, backend: backend);
      addTearDown(decoder.close);
      final List<Instruction> instructions = decoder.decode(
        Uint8List.fromList(
          architecture == DisassemblerArch.arm64 ? [2, 0, 0, 0x14] : [0xeb, 6],
        ),
        address: 0x1000,
      );
      expect(instructions.single.controlFlow, ControlFlow.jump);
      expect(instructions.single.operands.single.immediate, 0x1008);
    });
  }

  for (final DisassemblerBackend backend in [
    DisassemblerBackend.capstone,
    DisassemblerBackend.exarmo,
  ]) {
    test('$backend preserves ARM64 post-index address and update', () {
      final Disassembler decoder = Disassembler(
        DisassemblerArch.arm64,
        backend: backend,
      );
      addTearDown(decoder.close);
      final Instruction instruction = decoder
          .decode(Uint8List.fromList([0xfe, 0x07, 0x41, 0xf8]))
          .single;
      final Memory memory = instruction.operands
          .firstWhere((operand) => operand.kind == OperandKind.memory)
          .memory!;
      final Operand last = instruction.operands.last;
      final int update = last.kind == OperandKind.immediate
          ? last.immediate
          : memory.displacement;
      expect(instruction.canonicalMnemonic, 'ldr');
      expect(instruction.writeback, isTrue);
      expect(instruction.postIndex, isTrue);
      expect(decoder.registerName(memory.base), 'sp');
      expect(instruction.postIndex ? 0 : memory.displacement, 0);
      expect(update, 16);
    });
  }

  test('Unsupported backend architectures fail without fallback', () {
    expect(
      () => Disassembler(
        DisassemblerArch.arm64,
        backend: DisassemblerBackend.zydis,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => Disassembler(
        DisassemblerArch.x64,
        backend: DisassemblerBackend.exarmo,
      ),
      throwsUnsupportedError,
    );
  });

  test('Exarmo does not invent unavailable register access metadata', () {
    final Disassembler decoder = Disassembler(
      DisassemblerArch.arm64,
      backend: DisassemblerBackend.exarmo,
    );
    addTearDown(decoder.close);
    final Instruction instruction = decoder
        .decode(Uint8List.fromList([0x20, 0, 0x80, 0xd2]))
        .single;
    expect(instruction.registerAccess, isNull);
    expect(instruction.registersRead, isNull);
    expect(instruction.registersWritten, isNull);
    expect(instruction.operands.first.access, isNull);
  });

  test('Buffer decodes bytes changed after it was created', () {
    final decoder = Disassembler(
      DisassemblerArch.x64,
      backend: DisassemblerBackend.zydis,
    );
    final Uint8List bytes = Uint8List.fromList([0x48, 0x01, 0xd8]);
    final buffer = DisassemblerBuffer(bytes);
    final reader = decoder.reader(buffer);
    final batch = DecodedBatch();
    bytes[1] = 0x29;

    reader.decode(batch);

    expect(batch.mnemonic(0), 'sub');
    batch.close();
    reader.close();
    buffer.close();
    decoder.close();
  });

  test('Zydis rejects retained common fields after callback and closure', () {
    final decoder = Disassembler(
      DisassemblerArch.x64,
      backend: DisassemblerBackend.zydis,
    );
    final buffer = DisassemblerBuffer(Uint8List.fromList([0x48, 0x01, 0xd8]));
    final reader = decoder.reader(buffer);
    final batch = DecodedBatch();
    expect(decoder.registerName(1), isNotEmpty);
    reader.visit(batch, (decoded) {
      expect(decoded.mnemonic(0), 'add');
      expect(decoded.canonicalMnemonic(0), 'add');
      expect(decoded.writesFlags(0), isTrue);
      expect(decoded.hasRegisterAccess(0), isTrue);
      expect(decoded.bytes(0), [0x48, 0x01, 0xd8]);
      return true;
    });
    final Instruction kept = batch.instruction(0);
    batch.close();
    expect(() => batch.mnemonic(0), throwsRangeError);
    expect(() => batch.canonicalMnemonic(0), throwsRangeError);
    expect(() => batch.writesFlags(0), throwsRangeError);
    expect(() => batch.registersWritten(0), throwsRangeError);
    expect(() => batch.bytes(0), throwsRangeError);
    reader.close();
    buffer.close();
    decoder.close();
    expect(() => decoder.registerName(1), throwsStateError);
    expect(kept.mnemonic, 'add');
    expect(kept.writesFlags, isTrue);
    expect(kept.bytes, [0x48, 0x01, 0xd8]);
  });

  for (final DisassemblerBackend backend in [
    DisassemblerBackend.capstone,
    DisassemblerBackend.zydis,
  ]) {
    test('$backend preserves partial registers and implicit writes', () {
      final Disassembler decoder = Disassembler(
        DisassemblerArch.x64,
        backend: backend,
      );
      addTearDown(decoder.close);
      final List<Instruction> instructions = decoder.decode(
        Uint8List.fromList([0xb4, 0x41, 0x50]),
      );
      final Operand destination = instructions.first.operands.first;
      expect(decoder.registerName(destination.register), 'ah');
      expect(destination.size, 1);
      expect(destination.access! & OperandAccess.write, OperandAccess.write);
      expect(decoder.registerId('ah'), destination.register);
      expect(
        instructions.last.registersWritten!.map(decoder.registerName),
        contains('rsp'),
      );
    });

    test('$backend invalid bytes preserve progress and original bytes', () {
      final Disassembler decoder = Disassembler(
        DisassemblerArch.x64,
        backend: backend,
      );
      addTearDown(decoder.close);
      final List<Instruction> instructions = decoder.decode(
        Uint8List.fromList([0x0f]),
        address: 0x3000,
      );
      expect(instructions.single.valid, isFalse);
      expect(instructions.single.address, 0x3000);
      expect(instructions.single.size, 1);
      expect(instructions.single.bytes, [0x0f]);
      expect(instructions.single.registerAccess, isNull);
    });
  }
}
