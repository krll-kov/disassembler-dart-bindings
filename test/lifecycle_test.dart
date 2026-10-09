import 'dart:typed_data';

import 'package:disassembler/capstone.dart';
import 'package:disassembler/constants.dart';
import 'package:test/test.dart';

void main() {
  final Uint8List bytes = Uint8List.fromList([0x90, 0xc3]);

  test('Buffered ranges preserve copied input and instruction addresses', () {
    final Uint8List source = Uint8List.fromList([0x90, 0x48, 0x89, 0xd8, 0xc3]);
    final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    final CapstoneBuffer buffer = CapstoneBuffer(source);
    final CapstoneReader reader = decoder.reader(buffer);
    try {
      source.fillRange(0, source.length, 0);
      final List<Instruction> found = [];
      reader.visit(
        (instruction) {
          found.add(instruction.copy());
          return true;
        },
        start: 1,
        end: 4,
        address: 0x2000,
      );
      expect(found.single.mnemonic, 'mov');
      expect(found.single.address, 0x2000);
      expect(found.single.bytes, [0x48, 0x89, 0xd8]);
      expect(
        found.single.registerAccess!.written,
        contains(x86_reg.X86_REG_RAX),
      );
      reader.visit((instruction) {
        expect(instruction.id, x86_insn.X86_INS_RET);
        return false;
      }, start: 4);
      expect(found.single.mnemonic, 'mov');
      expect(
        () => reader.visit((_) => true, start: 4, end: 2),
        throwsRangeError,
      );
    } finally {
      reader.close();
      buffer.close();
      decoder.close();
    }
  });

  test(
    'Expired views reject access after early stop and callback exception',
    () {
      final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
      final CapstoneBuffer buffer = CapstoneBuffer(bytes);
      final CapstoneReader reader = decoder.reader(buffer);
      late NativeInstructionView saved;
      try {
        reader.visit((instruction) {
          saved = instruction;
          expect(buffer.close, throwsStateError);
          expect(reader.close, throwsStateError);
          expect(decoder.close, throwsStateError);
          return false;
        });
        expect(() => saved.id, throwsStateError);
        expect(() => saved.copy(), throwsStateError);
        expect(
          () => reader.visit((instruction) {
            saved = instruction;
            throw const FormatException('stop');
          }),
          throwsFormatException,
        );
        expect(() => saved.registersWritten, throwsStateError);
        int count = 0;
        reader.visit((_) {
          count++;
          return true;
        });
        expect(count, 2);
      } finally {
        reader.close();
        buffer.close();
        decoder.close();
      }
    },
  );

  test('Shared buffers permit nested readers with independent decoders', () {
    final Capstone first = Capstone(Architecture.x86, mode: Mode.mode64);
    final Capstone second = Capstone(Architecture.x86, mode: Mode.mode64);
    final CapstoneBuffer buffer = CapstoneBuffer(bytes);
    final CapstoneReader outer = first.reader(buffer);
    final CapstoneReader inner = second.reader(buffer);
    try {
      outer.visit((instruction) {
        inner.visit((nested) {
          expect(nested.id, x86_insn.X86_INS_RET);
          return false;
        }, start: 1);
        expect(instruction.id, x86_insn.X86_INS_NOP);
        expect(() => first.decode(bytes), throwsStateError);
        return false;
      });
      buffer.close();
      expect(() => outer.visit((_) => true), throwsStateError);
      outer.close();
      expect(() => outer.visit((_) => true), throwsStateError);
    } finally {
      inner.close();
      outer.close();
      buffer.close();
      second.close();
      first.close();
    }
  });

  test('Buffered ARM64 decoding preserves trailing incomplete bytes', () {
    final Capstone decoder = Capstone(Architecture.aarch64);
    final CapstoneBuffer buffer = CapstoneBuffer(Uint8List.fromList([0, 1, 2]));
    final CapstoneReader reader = decoder.reader(buffer);
    try {
      final List<Instruction> found = [];
      reader.visit((instruction) {
        found.add(instruction.copy());
        return true;
      }, address: 0x1000);
      expect(found.single.id, 0);
      expect(found.single.address, 0x1000);
      expect(found.single.bytes, [0, 1, 2]);
      expect(found.single.registerAccess, isNull);
    } finally {
      reader.close();
      buffer.close();
      decoder.close();
    }
  });

  test('Early stop permits subsequent decoding', () {
    final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    try {
      int count = 0;
      decoder.visit(bytes, (Instruction instruction) {
        count++;
        return false;
      });
      expect(count, 1);
      expect(decoder.decode(bytes).length, 2);
    } finally {
      decoder.close();
    }
  });

  test('Callback exception permits subsequent decoding', () {
    final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    try {
      expect(
        () => decoder.visit(bytes, (_) => throw const FormatException('stop')),
        throwsFormatException,
      );
      expect(decoder.decode(bytes).length, 2);
    } finally {
      decoder.close();
    }
  });

  test('Reentrant close cannot invalidate active native memory', () {
    final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    try {
      decoder.visit(bytes, (Instruction instruction) {
        expect(decoder.close, throwsStateError);
        expect(() => decoder.decode(bytes), throwsStateError);
        return true;
      });
      expect(decoder.decode(bytes).length, 2);
    } finally {
      decoder.close();
    }
  });

  test('Closed decoder rejects native operations', () {
    final Capstone decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    decoder.close();
    decoder.close();
    expect(() => decoder.decode(bytes), throwsStateError);
    expect(() => decoder.registerName(0), throwsStateError);
    expect(() => decoder.instructionName(0), throwsStateError);
    expect(() => decoder.groupName(0), throwsStateError);
  });

  test('Disabled details avoid unallocated native detail memory', () {
    final Capstone decoder = Capstone(
      Architecture.x86,
      mode: Mode.mode64,
      details: false,
    );
    try {
      final Instruction instruction = decoder.decode(bytes).last;
      expect(instruction.mnemonic, 'ret');
      expect(instruction.details, isNull);
      expect(instruction.registerAccess, isNull);
      expect(instruction.groups, isEmpty);
    } finally {
      decoder.close();
    }
  });

  test('ATT syntax preserves operand direction and register identity', () {
    final Capstone decoder = Capstone(
      Architecture.x86,
      mode: Mode.mode64,
      syntax: Syntax.att,
    );
    try {
      final Instruction instruction = decoder
          .decode(Uint8List.fromList([0x48, 0x89, 0xd8]))
          .single;
      expect(instruction.operandsText, '%rbx, %rax');
      expect(decoder.registerName(x86_reg.X86_REG_RAX), 'rax');
      expect(decoder.instructionName(x86_insn.X86_INS_MOV), 'mov');
      expect(decoder.groupName(cs_group_type.CS_GRP_RET), 'ret');
    } finally {
      decoder.close();
    }
  });

  test('Alias detail selection preserves real instruction operands', () {
    final Uint8List mov = Uint8List.fromList([0xe0, 0x03, 0x01, 0xaa]);
    final Capstone real = Capstone(Architecture.aarch64);
    final Capstone alias = Capstone(Architecture.aarch64, aliasDetails: true);
    try {
      final Instruction realInstruction = real.decode(mov).single;
      final Instruction aliasInstruction = alias.decode(mov).single;
      expect(realInstruction.isAlias, isTrue);
      expect(aliasInstruction.isAlias, isTrue);
      expect(realInstruction.usesAliasDetails, isFalse);
      expect(aliasInstruction.usesAliasDetails, isTrue);
      expect((realInstruction.details as Aarch64Details).op_count, 3);
      expect((aliasInstruction.details as Aarch64Details).op_count, 2);
    } finally {
      real.close();
      alias.close();
    }
  });

  test('Instruction byte storage survives mutation of constructor input', () {
    final Uint8List input = Uint8List.fromList([0x90]);
    final Instruction instruction = Instruction(
      address: 0,
      size: 1,
      id: x86_insn.X86_INS_NOP,
      aliasId: 0,
      isAlias: false,
      usesAliasDetails: false,
      illegal: false,
      mnemonic: 'nop',
      operandsText: '',
      bytes: input,
      implicitRegistersRead: [],
      implicitRegistersWritten: [],
      groups: [],
      writeback: false,
      registerAccess: null,
      details: null,
    );
    input[0] = 0xcc;
    expect(instruction.bytes, [0x90]);
    expect(() => instruction.bytes[0] = 0xcc, throwsUnsupportedError);
  });
}
