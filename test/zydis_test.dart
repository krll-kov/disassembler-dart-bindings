import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:disassembler/zydis.dart';
import 'package:disassembler/zydis_native.dart' as native;
import 'package:test/test.dart';

void main() {
  late Zydis decoder;
  setUp(() => decoder = Zydis());
  tearDown(() => decoder.close());

  test('Zydis encoder emits requested register operands', () {
    using((arena) {
      final request = arena<native.ZydisEncoderRequest>();
      request.ref.machine_mode = ZydisMachineMode.ZYDIS_MACHINE_MODE_LONG_64;
      request.ref.mnemonic = ZydisMnemonic.ZYDIS_MNEMONIC_MOV;
      request.ref.operand_count = 2;
      request.ref.operands[0].type =
          ZydisOperandType.ZYDIS_OPERAND_TYPE_REGISTER;
      request.ref.operands[0].reg.value = ZydisRegister.ZYDIS_REGISTER_RAX;
      request.ref.operands[1].type =
          ZydisOperandType.ZYDIS_OPERAND_TYPE_REGISTER;
      request.ref.operands[1].reg.value = ZydisRegister.ZYDIS_REGISTER_RBX;
      final bytes = arena<Uint8>(ZYDIS_MAX_INSTRUCTION_LENGTH);
      final length = arena<Size>()..value = ZYDIS_MAX_INSTRUCTION_LENGTH;
      final status = native.ZydisEncoderEncodeInstruction(
        request,
        bytes.cast(),
        length,
      );
      expect(status & 0x80000000, 0);
      expect(length.value, 3);
      final instruction = decoder
          .decode(bytes.asTypedList(length.value))
          .single;
      expect(instruction.mnemonic, 'mov');
      expect(
        instruction.visibleOperands.map((operand) => operand.unnamed.reg.value),
        [ZydisRegister.ZYDIS_REGISTER_RAX, ZydisRegister.ZYDIS_REGISTER_RBX],
      );
    });
  });

  test('Zydis formatter emits Intel operand text', () {
    using((arena) {
      final rawDecoder = arena<native.ZydisDecoder>();
      final rawInstruction = arena<native.ZydisDecodedInstruction>();
      final operands = arena<native.ZydisDecodedOperand>(
        ZYDIS_MAX_OPERAND_COUNT,
      );
      final bytes = arena<Uint8>(3);
      bytes.asTypedList(3).setAll(0, [0x48, 0x89, 0xd8]);
      expect(
        native.ZydisDecoderInit(
              rawDecoder,
              ZydisMachineMode.ZYDIS_MACHINE_MODE_LONG_64,
              ZydisStackWidth.ZYDIS_STACK_WIDTH_64,
            ) &
            0x80000000,
        0,
      );
      expect(
        native.ZydisDecoderDecodeFull(
              rawDecoder,
              bytes.cast(),
              3,
              rawInstruction,
              operands,
            ) &
            0x80000000,
        0,
      );
      final formatter = arena<native.ZydisFormatter>();
      expect(
        native.ZydisFormatterInit(
              formatter,
              ZydisFormatterStyle.ZYDIS_FORMATTER_STYLE_INTEL,
            ) &
            0x80000000,
        0,
      );
      final text = arena<Char>(64);
      expect(
        native.ZydisFormatterFormatInstruction(
              formatter,
              rawInstruction,
              operands,
              rawInstruction.ref.operand_count_visible,
              text,
              64,
              0x1000,
              nullptr,
            ) &
            0x80000000,
        0,
      );
      expect(text.cast<Utf8>().toDartString(), 'mov rax, rbx');
    });
  });

  test('Zydis retains 64-bit immediate and partial register width', () {
    final instructions = decoder.decode(
      Uint8List.fromList([
        0x48,
        0xb8,
        0x88,
        0x77,
        0x66,
        0x55,
        0x44,
        0x33,
        0x22,
        0x11,
        0xb8,
        0x78,
        0x56,
        0x34,
        0x12,
      ]),
      address: 0x180000000,
    );
    expect(instructions.map((value) => value.size), [10, 5]);
    expect(instructions.last.address, 0x18000000a);
    expect(
      instructions.first.operands[1].unnamed.imm.value.u,
      0x1122334455667788,
    );
    expect(instructions.first.operands[0].size, 64);
    expect(instructions.last.operands[0].size, 32);
    expect(
      instructions.last.registersWritten,
      contains(ZydisRegister.ZYDIS_REGISTER_EAX),
    );
  });

  test('Zydis retains RIP memory displacement and address reads', () {
    final instruction = decoder
        .decode(Uint8List.fromList([0x48, 0x8b, 0x05, 0x78, 0x56, 0x34, 0x12]))
        .single;
    final memory = instruction.operands[1].unnamed.mem;
    expect(memory.base, ZydisRegister.ZYDIS_REGISTER_RIP);
    expect(memory.disp.has_displacement, 1);
    expect(memory.disp.value, 0x12345678);
    expect(
      instruction.registersRead,
      contains(ZydisRegister.ZYDIS_REGISTER_RIP),
    );
    expect(
      instruction.registersWritten,
      contains(ZydisRegister.ZYDIS_REGISTER_RAX),
    );
  });

  test('Zydis includes hidden stack operands in 32-bit mode', () {
    final x86 = Zydis(
      machineMode: ZydisMachineMode.ZYDIS_MACHINE_MODE_LEGACY_32,
      stackWidth: ZydisStackWidth.ZYDIS_STACK_WIDTH_32,
    );
    try {
      final instruction = x86
          .decode(Uint8List.fromList([0xff, 0x34, 0x24]))
          .single;
      expect(instruction.mnemonic, 'push');
      expect(instruction.visibleOperands, hasLength(1));
      expect(instruction.operands.length, greaterThan(1));
      expect(
        instruction.operands[0].unnamed.mem.base,
        ZydisRegister.ZYDIS_REGISTER_ESP,
      );
      expect(
        instruction.registersRead,
        contains(ZydisRegister.ZYDIS_REGISTER_ESP),
      );
      expect(
        instruction.registersWritten,
        contains(ZydisRegister.ZYDIS_REGISTER_ESP),
      );
    } finally {
      x86.close();
    }
  });

  test('Zydis copies CPU flag actions after decoder close', () {
    final instruction = decoder
        .decode(Uint8List.fromList([0x48, 0x01, 0xd8]))
        .single;
    decoder.close();
    expect(instruction.mnemonic, 'add');
    expect(
      instruction.details!.cpu_flags!.modified & ZYDIS_CPUFLAG_ZF,
      isNot(0),
    );
    expect(
      instruction.registersWritten,
      contains(ZydisRegister.ZYDIS_REGISTER_RFLAGS),
    );
  });

  test('Zydis retains conditional register and flag actions', () {
    final instruction = decoder
        .decode(Uint8List.fromList([0x0f, 0x44, 0xc3]))
        .single;
    expect(instruction.mnemonic, 'cmovz');
    expect(
      instruction.registerActions[ZydisRegister.ZYDIS_REGISTER_EAX]! &
          ZydisOperandAction.ZYDIS_OPERAND_ACTION_CONDWRITE,
      isNot(0),
    );
    expect(
      instruction.registersRead,
      contains(ZydisRegister.ZYDIS_REGISTER_RFLAGS),
    );
    expect(instruction.details!.cpu_flags!.tested & ZYDIS_CPUFLAG_ZF, isNot(0));
    expect(decoder.registerId('EAX'), ZydisRegister.ZYDIS_REGISTER_EAX);
    expect(
      decoder.registerId('unknown_register'),
      ZydisRegister.ZYDIS_REGISTER_NONE,
    );
  });

  test('Zydis retains upstream AVX2 table operands', () {
    final instruction = decoder
        .decode(Uint8List.fromList([0xc5, 0x0d, 0xd5, 0xe6]))
        .single;
    expect(instruction.mnemonic, 'vpmullw');
    expect(
      instruction.details!.encoding,
      ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_VEX,
    );
    expect(
      instruction.operands.take(3).map((value) => value.unnamed.reg.value),
      [
        ZydisRegister.ZYDIS_REGISTER_YMM12,
        ZydisRegister.ZYDIS_REGISTER_YMM14,
        ZydisRegister.ZYDIS_REGISTER_YMM6,
      ],
    );
    expect(instruction.details!.avx.vector_length, 256);
  });

  test('Zydis retains upstream AVX512 mask and compressed displacement', () {
    final instruction = decoder
        .decode(Uint8List.fromList([0x62, 0xb1, 0x25, 0x41, 0x74, 0x78, 0x06]))
        .single;
    expect(instruction.mnemonic, 'vpcmpeqb');
    expect(
      instruction.details!.encoding,
      ZydisInstructionEncoding.ZYDIS_INSTRUCTION_ENCODING_EVEX,
    );
    expect(instruction.details!.avx.mask.reg, ZydisRegister.ZYDIS_REGISTER_K1);
    expect(
      instruction.details!.avx.mask.mode,
      ZydisMaskMode.ZYDIS_MASK_MODE_ZEROING,
    );
    expect(instruction.operands[3].unnamed.mem.disp.value, 0x180);
    expect(instruction.operands[3].size, 512);
    expect(
      instruction.registersWritten,
      contains(ZydisRegister.ZYDIS_REGISTER_K7),
    );
    expect(
      instruction.registersRead,
      contains(ZydisRegister.ZYDIS_REGISTER_ZMM27),
    );
  });

  test('Zydis reports truncated input with original status', () {
    expect(
      () => decoder.decode(Uint8List.fromList([0x0f])),
      throwsA(
        isA<ZydisException>().having(
          (error) => error.status,
          'status',
          ZYDIS_STATUS_NO_MORE_DATA,
        ),
      ),
    );
    expect(decoder.decode(Uint8List(0)), isEmpty);
  });

  test('Zydis exposes invalid gaps without changing following addresses', () {
    final instructions = decoder.decode(
      Uint8List.fromList([0x60, 0x90]),
      address: 0x1000,
      invalid: ZydisInvalidPolicy.skipByte,
    );
    expect(instructions.first.valid, isFalse);
    expect(instructions.first.size, 1);
    expect(instructions.last.address + instructions.last.size, 0x1002);
    expect(
      decoder.decode(
        Uint8List.fromList([0x0f]),
        invalid: ZydisInvalidPolicy.stop,
      ),
      isEmpty,
    );
  });

  test('Zydis expires views and retains immutable copies', () {
    ZydisInstructionView? savedView;
    ZydisInstruction? savedCopy;
    decoder.visit(Uint8List.fromList([0x90, 0xc3]), (view) {
      savedView ??= view;
      savedCopy ??= view.copy();
      return true;
    });
    expect(() => savedView!.details, throwsStateError);
    expect(savedCopy!.mnemonic, 'nop');
    expect(() => savedCopy!.bytes[0] = 0, throwsUnsupportedError);
    expect(() => savedCopy!.operands.clear(), throwsUnsupportedError);
    expect(
      () => savedCopy!.details!.raw.prefixes.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'Zydis retained views reject bytes and register access after callback',
    () {
      ZydisInstructionView? saved;
      decoder.visit(Uint8List.fromList([0x48, 0x01, 0xd8]), (view) {
        saved = view;
        expect(view.bytes, [0x48, 0x01, 0xd8]);
        expect(view.bytes, [0x48, 0x01, 0xd8]);
        final actions = view.registerActions;
        expect(view.registerActions, actions);
        expect(view.registersRead, contains(ZydisRegister.ZYDIS_REGISTER_RBX));
        expect(
          view.registersWritten,
          contains(ZydisRegister.ZYDIS_REGISTER_RAX),
        );
        final operand = view.operand(1);
        operand.actions = ZydisOperandAction.ZYDIS_OPERAND_ACTION_WRITE;
        operand.unnamed.reg.value = ZydisRegister.ZYDIS_REGISTER_RCX;
        expect(
          view.registerActions,
          isNot(contains(ZydisRegister.ZYDIS_REGISTER_RBX)),
        );
        expect(
          view.registersRead,
          isNot(contains(ZydisRegister.ZYDIS_REGISTER_RCX)),
        );
        expect(
          view.registersWritten,
          contains(ZydisRegister.ZYDIS_REGISTER_RCX),
        );
        expect(() => view.bytes[0] = 0, throwsUnsupportedError);
        expect(() => actions.clear(), throwsUnsupportedError);
        return true;
      });
      expect(() => saved!.bytes, throwsStateError);
      expect(() => saved!.registerActions, throwsStateError);
      expect(() => saved!.registersRead, throwsStateError);
      expect(() => saved!.registersWritten, throwsStateError);
    },
  );

  test('Zydis reads supplied native buffer without taking ownership', () {
    final Pointer<Uint8> bytes = calloc(2);
    try {
      bytes.asTypedList(2).setAll(0, [0x90, 0xc3]);
      final List<String> mnemonics = [];
      decoder.visitPointer(bytes, 2, (view) {
        mnemonics.add(view.copy().mnemonic);
        if (view.address == 0) {
          final copied = view.copy();
          final borrowed = view.bytes;
          bytes[0] = 0xcc;
          expect(view.bytes[0], 0xcc);
          expect(borrowed[0], 0xcc);
          expect(copied.bytes[0], 0x90);
          bytes[0] = 0x90;
        }
        return true;
      });
      expect(mnemonics, ['nop', 'ret']);
      expect(bytes[0], 0x90);
    } finally {
      calloc.free(bytes);
    }
  });

  test('Zydis releases decoder after early callback return', () {
    int count = 0;
    decoder.visit(Uint8List.fromList([0x90, 0x90]), (view) {
      count++;
      expect(() => decoder.close(), throwsStateError);
      expect(() => decoder.decode(Uint8List(0)), throwsStateError);
      return false;
    });
    expect(count, 1);
    expect(decoder.decode(Uint8List.fromList([0xc3])).single.mnemonic, 'ret');
    decoder.close();
    decoder.close();
    expect(() => decoder.decode(Uint8List(0)), throwsStateError);
  });
}
