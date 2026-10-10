// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:ffi';
import 'dart:typed_data';

import 'package:disassembler/disassembler.dart' as common;
import 'package:disassembler/exarmo.dart';
import 'package:disassembler/src/third_party/exarmo.g.dart' as native;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  test('Available Exarmo architectures match build configuration values', () {
    final Set<String> available = common.availableExarmoDecoders();
    expect(available, {'arm', 'arm64'});
    expect(() => common.requireExarmoDecoder('arm64'), returnsNormally);
    expect(
      () => common.requireExarmoDecoder('aarch64'),
      throwsUnsupportedError,
    );
    expect(() => available.add('unknown'), throwsUnsupportedError);
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    expect(
      decoder.decode(Uint8List.fromList([0x1f, 0x20, 0x03, 0xd5])),
      hasLength(1),
    );
  });

  test('AArch64 ABI mismatch cannot overwrite instruction storage', () {
    expect(
      native.exarmo_aarch64_instruction_size(),
      sizeOf<native.exarmo_aarch64_instruction>(),
    );
    expect(
      native.exarmo_aarch32_instruction_size(),
      sizeOf<native.exarmo_aarch32_instruction>(),
    );
  });

  test('AArch64 operands remain valid after decoder close', () {
    final Exarmo decoder = Exarmo(.aarch64);
    final ExarmoInstruction instruction = decoder
        .decode(Uint8List.fromList([0x20, 0x04, 0x40, 0xf9]), address: 0x1000)
        .single;
    decoder.close();
    expect(instruction.text, 'ldr\tx0, [x1, #0x8]');
    expect(instruction.mnemonicName, 'ldr');
    expect(instruction.address, 0x1000);
    expect(instruction.size, 4);
    final ExarmoAarch64Details details =
        instruction.details as ExarmoAarch64Details;
    expect(details.operands.length, 2);
    expect(details.operands[0].unnamed.reg.reg.num, 0);
    expect(details.operands[1].unnamed.mem.base.num, 1);
    expect(details.operands[1].unnamed.mem.offset.imm, 8);
    expect(details.tokens, isNotEmpty);
    expect(() => details.operands.clear(), throwsUnsupportedError);
    expect(() => instruction.bytes[0] = 0, throwsUnsupportedError);
  });

  test('AArch64 branch target preserves address arithmetic', () {
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    final ExarmoInstruction instruction = decoder
        .decode(Uint8List.fromList([0x20, 0x00, 0x00, 0x54]), address: 0x1000)
        .single;
    final ExarmoAarch64Details details =
        instruction.details as ExarmoAarch64Details;
    expect(details.branch.conditional, isTrue);
    expect(details.branch.has_target, isTrue);
    expect(details.branch.target, 0x1004);
    expect(details.flags.reads, isNonZero);
  });

  test('Carry condition aliases preserve unsigned branch semantics', () {
    final common.Disassembler decoder = common.Disassembler(
      .arm64,
      backend: .exarmo,
    );
    addTearDown(decoder.close);
    final List<common.Instruction> instructions = decoder.decode(
      Uint8List.fromList([0x22, 0x00, 0x00, 0x54, 0x23, 0x00, 0x00, 0x54]),
      address: 0x1000,
    );
    expect(instructions.map((common.Instruction value) => value.condition), [
      'hs',
      'lo',
    ]);
    final common.ExarmoInstructionDetails details =
        instructions.first.details as common.ExarmoInstructionDetails;
    final ExarmoAarch64Details raw =
        details.instruction.details as ExarmoAarch64Details;
    expect(
      raw.operands
          .singleWhere(
            (ExarmoAarch64Operand operand) =>
                operand.kind ==
                native.exarmo_aarch64_operand_kind.EXARMO_AARCH64_OPERAND_COND,
          )
          .unnamed
          .cond,
      2,
    );
  });

  test('Omitted extension shift cannot become negative address scaling', () {
    final common.Disassembler decoder = common.Disassembler(
      .arm64,
      backend: .exarmo,
    );
    addTearDown(decoder.close);
    final common.Instruction instruction = decoder
        .decode(Uint8List.fromList([0x28, 0x49, 0xa3, 0x38]))
        .single;
    final common.Operand operand = instruction.operands.last;
    expect(operand.kind, common.OperandKind.memory);
    expect(operand.extend, common.OperandExtend.uxtw);
    expect(operand.shift, common.OperandShift.none);
    expect(operand.shiftValue, 0);
    expect(decoder.registerName(operand.memory!.index), 'w3');
    final common.ExarmoInstructionDetails details =
        instruction.details as common.ExarmoInstructionDetails;
    final ExarmoAarch64Details raw =
        details.instruction.details as ExarmoAarch64Details;
    expect(raw.operands.last.unnamed.mem.offset.modifier.amount, -1);
  });

  test('Extended register offset preserves positive left shift', () {
    final common.Disassembler decoder = common.Disassembler(
      .arm64,
      backend: .exarmo,
    );
    addTearDown(decoder.close);
    final common.Instruction instruction = decoder
        .decode(Uint8List.fromList([0xc4, 0x58, 0x63, 0xb8]))
        .single;
    final common.Operand operand = instruction.operands.last;
    expect(operand.kind, common.OperandKind.memory);
    expect(operand.extend, common.OperandExtend.uxtw);
    expect(operand.shift, common.OperandShift.lsl);
    expect(operand.shiftValue, 2);
    expect(decoder.registerName(operand.memory!.index), 'w3');
    final common.Instruction add = decoder
        .decode(Uint8List.fromList([0x40, 0x40, 0x24, 0x8b]))
        .single;
    expect(add.operands.last.extend, common.OperandExtend.uxtw);
    expect(add.operands.last.shift, common.OperandShift.none);
    expect(add.operands.last.shiftValue, 0);
  });

  test('Invalid ARM64 bytes cannot truncate remaining instruction range', () {
    final common.Disassembler decoder = common.Disassembler(
      .arm64,
      backend: .exarmo,
    );
    addTearDown(decoder.close);
    final Uint8List bytes = Uint8List.fromList([
      0x1f,
      0x20,
      0x03,
      0xd5,
      0xc5,
      0x9d,
      0x1c,
      0x81,
      0x1f,
      0x20,
      0x03,
      0xd5,
    ]);
    final List<common.Instruction> instructions = decoder.decode(
      bytes,
      address: 0x1000,
    );
    expect(instructions.map((common.Instruction value) => value.valid), [
      true,
      false,
      true,
    ]);
    expect(instructions.map((common.Instruction value) => value.address), [
      0x1000,
      0x1004,
      0x1008,
    ]);
    expect(instructions[1].bytes, bytes.sublist(4, 8));
    expect(
      (instructions[1].details as common.InvalidInstructionDetails)
          .nativeStatus,
      isNonZero,
    );
    final Exarmo raw = Exarmo(.aarch64);
    addTearDown(raw.close);
    expect(raw.decode(bytes).length, 1);
    final common.DisassemblerBuffer buffer = common.DisassemblerBuffer(bytes);
    addTearDown(buffer.close);
    final common.DisassemblerReader reader = decoder.reader(buffer);
    addTearDown(reader.close);
    final common.DecodedBatch batch = common.DecodedBatch();
    reader.decode(batch);
    final int invalid = [
      for (int i = 0; i < batch.length; i++) i,
    ].firstWhere((int i) => !batch.valid(i));
    expect(batch.bytes(invalid), bytes.sublist(4, 8));
    batch.close();
    expect(() => batch.bytes(invalid), throwsRangeError);
    expect(() => batch.valid(invalid), throwsRangeError);
    expect(() => batch.instruction(invalid), throwsRangeError);
  });

  test('Invalid Thumb prefix cannot prevent 2 byte instruction progress', () {
    final common.Disassembler decoder = common.Disassembler(
      .thumb,
      backend: .exarmo,
    );
    addTearDown(decoder.close);
    final List<common.Instruction> instructions = decoder.decode(
      Uint8List.fromList([0xff, 0xff, 0x00, 0x00, 0x00, 0xbf]),
      address: 0x2000,
    );
    expect(instructions.first.valid, isFalse);
    expect(instructions.first.size, 2);
    expect(instructions.last.valid, isTrue);
    expect(instructions.last.address, 0x2004);
    expect(instructions.last.size, 2);
    expect(instructions.last.mnemonic, 'nop');
  });

  test('ARM operands preserve 32 bit register indices', () {
    final Exarmo decoder = Exarmo(.arm);
    addTearDown(decoder.close);
    final ExarmoInstruction instruction = decoder
        .decode(Uint8List.fromList([0x03, 0x20, 0x81, 0xe0]))
        .single;
    expect(instruction.mnemonicName, 'add');
    final ExarmoAarch32Details details =
        instruction.details as ExarmoAarch32Details;
    expect(
      details.operands
          .where(
            (ExarmoAarch32Operand operand) =>
                operand.kind ==
                native.exarmo_aarch32_operand_kind.EXARMO_AARCH32_OPERAND_REG,
          )
          .map((ExarmoAarch32Operand operand) => operand.unnamed.reg.reg.num),
      [2, 1, 3],
    );
  });

  test('Thumb IT state cannot become unconditional inside block', () {
    final Exarmo decoder = Exarmo(.thumb);
    addTearDown(decoder.close);
    final List<ExarmoInstruction> instructions = decoder.decode(
      Uint8List.fromList([0x08, 0xbf, 0x08, 0x46]),
    );
    expect(instructions.length, 2);
    expect(instructions[0].mnemonicName, 'it');
    final ExarmoAarch32Details details =
        instructions[1].details as ExarmoAarch32Details;
    expect(
      details.itStateBefore.kind,
      native.exarmo_aarch32_it_kind.EXARMO_AARCH32_IT_INSIDE,
    );
    expect(details.itStateBefore.cond, 0);
    expect(
      details.itStateAfter.kind,
      native.exarmo_aarch32_it_kind.EXARMO_AARCH32_IT_OUTSIDE,
    );
    expect(instructions[1].text, contains('moveq'));
  });

  test('Truncated input cannot reuse previous instruction output', () {
    for (final ExarmoMode mode in ExarmoMode.values) {
      final Exarmo decoder = Exarmo(mode);
      try {
        expect(decoder.decode(Uint8List.fromList([0x00])), isEmpty);
        expect(decoder.lastStatus, 7);
      } finally {
        decoder.close();
      }
    }
  });

  test('Decode cannot continue after native buffers are freed', () {
    final Exarmo decoder = Exarmo(.aarch64);
    decoder.close();
    decoder.close();
    expect(decoder.isClosed, isTrue);
    expect(() => decoder.decode(Uint8List(0)), throwsStateError);
  });

  test('Visitor failure cannot retain active decode state', () {
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    final Uint8List bytes = Uint8List.fromList([0x1f, 0x20, 0x03, 0xd5]);
    expect(
      () => decoder.visit(bytes, (_) => throw StateError('stop')),
      throwsStateError,
    );
    expect(decoder.decode(bytes).single.mnemonicName, 'nop');
  });

  test('Nested decode cannot overwrite active instruction buffers', () {
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    final Uint8List bytes = Uint8List.fromList([0x1f, 0x20, 0x03, 0xd5]);
    expect(
      decoder.visit(bytes, (_) {
        expect(() => decoder.decode(bytes), throwsStateError);
        expect(decoder.close, throwsStateError);
        return false;
      }),
      1,
    );
    expect(decoder.decode(bytes).length, 1);
  });

  test('Visitor cancellation cannot decode subsequent bytes', () {
    final Exarmo decoder = Exarmo(.thumb);
    addTearDown(decoder.close);
    final Uint8List bytes = Uint8List.fromList([0x00, 0xbf, 0x00, 0xbf]);
    expect(decoder.visit(bytes, (_) => false), 1);
    expect(decoder.decode(bytes, count: 1).length, 1);
    expect(() => decoder.decode(bytes, count: -1), throwsRangeError);
  });

  test('Public C API rejects null output storage', () {
    expect(
      native.exarmo_aarch64_decode_word(0xf9400420, nullptr),
      native.exarmo_aarch64_status.EXARMO_AARCH64_STATUS_FAILED,
    );
    final Pointer<native.exarmo_aarch32_it_state> state =
        calloc<native.exarmo_aarch32_it_state>();
    try {
      state.ref.kind = native.exarmo_aarch32_it_kind.EXARMO_AARCH32_IT_OUTSIDE;
      expect(
        native.exarmo_aarch32_decode_t32_word(0x46080000, state.ref, nullptr),
        native.exarmo_aarch32_status.EXARMO_AARCH32_STATUS_FAILED,
      );
    } finally {
      calloc.free(state);
    }
  });

  test('Input mutation cannot change copied instruction bytes', () {
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    final Uint8List bytes = Uint8List.fromList([
      0x1f,
      0x20,
      0x03,
      0xd5,
      0x1f,
      0x20,
      0x03,
      0xd5,
    ]);
    final List<ExarmoInstruction> instructions = [];
    decoder.visit(bytes, (ExarmoInstruction instruction) {
      instructions.add(instruction);
      bytes.fillRange(0, bytes.length, 0);
      return true;
    });
    expect(instructions.length, 2);
    expect(instructions[1].bytes, [0x1f, 0x20, 0x03, 0xd5]);
    expect(instructions[1].mnemonicName, 'nop');
  });

  test('Expired view cannot read reused native instruction storage', () {
    final Exarmo decoder = Exarmo(.aarch64);
    addTearDown(decoder.close);
    final Pointer<Uint8> bytes = calloc<Uint8>(4);
    ExarmoInstructionView? retained;
    try {
      bytes.asTypedList(4).setAll(0, [0x20, 0x04, 0x40, 0xf9]);
      expect(
        decoder.visitPointer(bytes, 4, (ExarmoInstructionView view) {
          retained = view;
          expect(view.operandCount, 2);
          expect(view.operands64[1].unnamed.mem.offset.imm, 8);
          expect(view.copy().mnemonicName, 'ldr');
          return true;
        }),
        1,
      );
      expect(() => retained!.mnemonic, throwsStateError);
      expect(() => retained!.copy(), throwsStateError);
      expect(
        () => decoder.visitPointer(nullptr, 4, (_) => true),
        throwsArgumentError,
      );
    } finally {
      calloc.free(bytes);
    }
  });

  test('Thumb instruction width cannot consume truncated halfword', () {
    final Exarmo decoder = Exarmo(.thumb);
    addTearDown(decoder.close);
    final List<ExarmoInstruction> instructions = decoder.decode(
      Uint8List.fromList([0x70, 0x47, 0x00, 0xf0, 0x00, 0xf8]),
      address: 0x1000,
    );
    expect(
      instructions.map((ExarmoInstruction instruction) => instruction.size),
      [2, 4],
    );
    expect(instructions[1].mnemonicName, 'bl');
    expect(decoder.decode(Uint8List.fromList([0x00, 0xf0])), isEmpty);
    expect(decoder.lastStatus, 7);
  });

  test('Register identities distinguish zero and stack pointers', () {
    final Exarmo decoder64 = Exarmo(.aarch64);
    final Exarmo decoder32 = Exarmo(.arm);
    addTearDown(decoder64.close);
    addTearDown(decoder32.close);
    for (final String value in ['x0', 'w0', 'xzr', 'wzr', 'sp', 'wsp', 'v31']) {
      expect(decoder64.registerName(decoder64.registerId(value)), value);
    }
    expect(decoder64.registerId('xzr'), isNot(decoder64.registerId('sp')));
    expect(decoder64.registerId('wzr'), isNot(decoder64.registerId('wsp')));
    expect(decoder64.registerId('x0'), isNot(decoder64.registerId('w0')));
    expect(decoder64.registerId('sp'), isNot(decoder32.registerId('sp')));
    expect(decoder64.registerId('r0'), 0);
    expect(decoder32.registerId('x0'), 0);
    expect(decoder64.registerName(decoder32.registerId('sp')), '');
    for (final String value in ['r0', 'sp', 'lr', 'pc', 's31', 'd31', 'q15']) {
      expect(decoder32.registerName(decoder32.registerId(value)), value);
    }
  });
}
