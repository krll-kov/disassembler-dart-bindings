@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ffi';

import 'package:capstone/capstone.dart';
import 'package:capstone/instructions.dart' as native;
import 'package:capstone/native.dart' as raw;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

const _smokeFixtures = <(String, Architecture, int, int, List<(int, String)>)>[
  (
    'x86 resolver instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode32,
    0x10000000,
    [
      (0x1020, '51'),
      (0x1021, '6884200010'),
      (0x1026, 'ff74240c'),
      (0x102a, 'ff1500200010'),
      (0x1030, '890424'),
      (0x1033, '8b0424'),
    ],
  ),
  (
    'x86 control instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode32,
    0x10000000,
    [
      (0x1010, '51'),
      (0x1011, '68a0200010'),
      (0x1016, 'ff74240c'),
      (0x101a, 'ff1500200010'),
      (0x1020, '890424'),
      (0x1023, '8b0424'),
    ],
  ),
  (
    'x86 concatenation instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode32,
    0x10000000,
    [
      (0x1010, '56'),
      (0x1011, '8b742408'),
      (0x1015, '57'),
      (0x1016, '85f6'),
      (0x1018, '7436'),
      (0x101a, '8b7c2410'),
    ],
  ),
  (
    'x86 independent data instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode32,
    0x10000000,
    [(0x1010, 'b878200010'), (0x1015, 'c3')],
  ),
  (
    'x64 resolver instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [
      (0x1020, '4883ec28'),
      (0x1024, '488d1501110000'),
      (0x102b, 'ff15cf0f0000'),
      (0x1031, '4889442438'),
      (0x1036, '488b442438'),
      (0x103b, '4883c428'),
    ],
  ),
  (
    'x64 control instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [
      (0x1010, '4883ec28'),
      (0x1014, '488d152d110000'),
      (0x101b, 'ff15df0f0000'),
      (0x1021, '4889442438'),
      (0x1026, '488b442438'),
      (0x102b, '4883c428'),
    ],
  ),
  (
    'x64 concatenation instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [
      (0x1010, '48895c2408'),
      (0x1015, '57'),
      (0x1016, '4883ec20'),
      (0x101a, '488bfa'),
      (0x101d, '488bd9'),
      (0x1020, '4885c9'),
    ],
  ),
  (
    'x64 independent data instruction boundaries remain exact',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [(0x1010, '488d05f9100000'), (0x1017, 'c3')],
  ),
  (
    'ARM64 resolver instruction boundaries remain exact',
    Architecture.aarch64,
    0,
    0x180000000,
    [
      (0x1150, 'fe0f1ff8'),
      (0x1154, 'ff4300d1'),
      (0x1158, '080000b0'),
      (0x115c, '01710491'),
      (0x1160, '080000b0'),
      (0x1164, '080140f9'),
    ],
  ),
  (
    'ARM64 control instruction boundaries remain exact',
    Architecture.aarch64,
    0,
    0x180000000,
    [
      (0x1140, 'fe0f1ff8'),
      (0x1144, 'ff4300d1'),
      (0x1148, '080000b0'),
      (0x114c, '01e10491'),
      (0x1150, '080000b0'),
      (0x1154, '080140f9'),
    ],
  ),
  (
    'ARM64 concatenation instruction boundaries remain exact',
    Architecture.aarch64,
    0,
    0x180000000,
    [
      (0x1140, '3f8000f1'),
      (0x1144, '042840fa'),
      (0x1148, '20030054'),
      (0x114c, 'f353bea9'),
      (0x1150, 'f57b01a9'),
      (0x1154, 'f40300aa'),
    ],
  ),
  (
    'ARM64 independent data instruction boundaries remain exact',
    Architecture.aarch64,
    0,
    0x180000000,
    [(0x1140, '080000b0'), (0x1144, '00410491'), (0x1148, 'c0035fd6')],
  ),
  (
    'x64 84-byte padding preserves consuming instructions',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [
      (0x111c, 'e8dffeffff'),
      (0x1121, '48634c2420'),
      (0x1126, '89448c30'),
      (0x112a, 'ebdb'),
      (0x112c, '48837c247000'),
      (0x1132, '7408'),
    ],
  ),
  (
    'x64 86-byte padding preserves consuming instructions',
    Architecture.x86,
    Mode.mode64,
    0x180000000,
    [
      (0x111c, 'e8dffeffff'),
      (0x1121, '48634c2420'),
      (0x1126, '89448c30'),
      (0x112a, 'ebdb'),
      (0x112c, '48837c247000'),
      (0x1132, '7408'),
    ],
  ),
  (
    'ARM64 hash resolver instruction boundaries remain exact',
    Architecture.aarch64,
    0,
    0x180000000,
    [
      (0x114c, 'a8030018'),
      (0x1150, 'e80300b9'),
      (0x1154, 'e80b40f9'),
      (0x1158, 'e80700f9'),
      (0x115c, '04000014'),
      (0x1160, 'e80740f9'),
    ],
  ),
];

Uint8List _bytes(String hex) => Uint8List.fromList([
  for (var offset = 0; offset < hex.length; offset += 2)
    int.parse(hex.substring(offset, offset + 2), radix: 16),
]);

(int, int, List<int>) _nativeMemoryMetadata(Uint8List bytes) {
  return using((Arena arena) {
    final instance = arena<UintPtr>();
    expect(
      raw.cs_open(raw.cs_arch.CS_ARCH_X86, raw.cs_mode.CS_MODE_64, instance),
      0,
    );
    try {
      expect(
        raw.cs_option(
          instance.value,
          raw.cs_opt_type.CS_OPT_DETAIL,
          raw.cs_opt_value.CS_OPT_ON | raw.cs_opt_value.CS_OPT_DETAIL_REAL,
        ),
        0,
      );
      final buffer = arena<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final output = arena<Pointer<raw.cs_insn>>();
      final count = raw.cs_disasm(
        instance.value,
        buffer,
        bytes.length,
        0,
        0,
        output,
      );
      expect(count, 1);
      try {
        final detail = output.value.ref.detail.ref;
        final memory = detail.unnamed.x86.operands[3];
        return (
          memory.access,
          memory.avx_bcast,
          [for (var i = 0; i < detail.groups_count; i++) detail.groups[i]],
        );
      } finally {
        raw.cs_free(output.value, count);
      }
    } finally {
      raw.cs_close(instance);
    }
  });
}

void main() {
  test('VEX and EVEX instructions preserve instruction identity', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    addTearDown(decoder.close);
    final bytes = _bytes('c5f1efc262f17c4858c1');
    final decoded = decoder.decode(bytes, address: 0x1000).toList();
    expect(decoded, hasLength(2));
    expect(decoded[0].id, native.x86_insn.X86_INS_VPXOR);
    expect(decoded[0].size, 4);
    expect(decoded[0].address, 0x1000);
    expect(decoded[1].id, native.x86_insn.X86_INS_VADDPS);
    expect(decoded[1].size, 6);
    expect(decoded[1].address, 0x1004);
    expect(decoded[0].bytes, orderedEquals(bytes.sublist(0, 4)));
    expect(decoded[1].bytes, orderedEquals(bytes.sublist(4)));
    final first = decoded[0].details as X86Details;
    final second = decoded[1].details as X86Details;
    expect(first.op_count, 3);
    expect(second.op_count, 3);
    expect(
      first.operands.take(first.op_count).map((operand) => operand.unnamed.reg),
      [
        native.x86_reg.X86_REG_XMM0,
        native.x86_reg.X86_REG_XMM1,
        native.x86_reg.X86_REG_XMM2,
      ],
    );
    expect(first.operands.take(first.op_count).map((operand) => operand.size), [
      16,
      16,
      16,
    ]);
    expect(
      first.operands.take(first.op_count).map((operand) => operand.access),
      [
        native.cs_ac_type.CS_AC_WRITE,
        native.cs_ac_type.CS_AC_READ,
        native.cs_ac_type.CS_AC_READ,
      ],
    );
    expect(
      decoded[0].registerAccess!.read,
      containsAll([native.x86_reg.X86_REG_XMM1, native.x86_reg.X86_REG_XMM2]),
    );
    expect(
      decoded[0].registerAccess!.written,
      contains(native.x86_reg.X86_REG_XMM0),
    );
    expect(
      second.operands
          .take(second.op_count)
          .map((operand) => operand.unnamed.reg),
      [
        native.x86_reg.X86_REG_ZMM0,
        native.x86_reg.X86_REG_ZMM0,
        native.x86_reg.X86_REG_ZMM1,
      ],
    );
    expect(
      second.operands.take(second.op_count).map((operand) => operand.size),
      [64, 64, 64],
    );
    expect(
      second.operands.take(second.op_count).map((operand) => operand.access),
      [
        native.cs_ac_type.CS_AC_WRITE,
        native.cs_ac_type.CS_AC_READ,
        native.cs_ac_type.CS_AC_READ,
      ],
    );
    expect(decoder.registerName(second.operands[0].unnamed.reg), 'zmm0');
  });

  test('x86 indirect arguments retain memory widths and offsets', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode32);
    addTearDown(decoder.close);
    final decoded = decoder.decode(_bytes('ff74240cff1500200010'));
    expect(decoded, hasLength(2));
    final push = decoded[0];
    expect(push.id, native.x86_insn.X86_INS_PUSH);
    final pushDetails = push.details as X86Details;
    expect(pushDetails.op_count, 1);
    final argument = pushDetails.operands[0];
    expect(argument.type, native.x86_op_type.X86_OP_MEM);
    expect(argument.size, 4);
    expect(argument.access, native.cs_ac_type.CS_AC_READ);
    expect(argument.unnamed.mem.base, native.x86_reg.X86_REG_ESP);
    expect(argument.unnamed.mem.index, native.x86_reg.X86_REG_INVALID);
    expect(argument.unnamed.mem.scale, 1);
    expect(argument.unnamed.mem.disp, 12);
    expect(push.registerAccess!.read, contains(native.x86_reg.X86_REG_ESP));
    expect(push.registerAccess!.written, contains(native.x86_reg.X86_REG_ESP));
    final call = decoded[1];
    expect(call.id, native.x86_insn.X86_INS_CALL);
    expect(call.groups, contains(native.cs_group_type.CS_GRP_CALL));
    final callDetails = call.details as X86Details;
    expect(callDetails.op_count, 1);
    expect(callDetails.operands[0].type, native.x86_op_type.X86_OP_MEM);
    expect(callDetails.operands[0].size, 4);
    expect(
      callDetails.operands[0].unnamed.mem.base,
      native.x86_reg.X86_REG_INVALID,
    );
    expect(callDetails.operands[0].unnamed.mem.disp, 0x10002000);
  });

  test('Missing EVEX metadata remains unchanged during conversion', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    addTearDown(decoder.close);
    final decoded = decoder.decode(_bytes('62f17cc957c062f15cdb5810'));
    expect(decoded, hasLength(2));
    final xor = decoded[0];
    expect(xor.id, native.x86_insn.X86_INS_VXORPS);
    final xorDetails = xor.details as X86Details;
    expect(xorDetails.op_count, 4);
    expect(xorDetails.operands.take(4).map((operand) => operand.unnamed.reg), [
      native.x86_reg.X86_REG_ZMM0,
      native.x86_reg.X86_REG_K1,
      native.x86_reg.X86_REG_ZMM0,
      native.x86_reg.X86_REG_ZMM0,
    ]);
    expect(
      xorDetails.operands.take(4).map((operand) => operand.avx_zero_opmask),
      [false, true, false, false],
    );
    expect(xorDetails.operands[1].access, native.cs_ac_type.CS_AC_READ);
    expect(xor.registerAccess!.read, contains(native.x86_reg.X86_REG_K1));
    expect(xor.groups, isEmpty);
    final add = decoded[1];
    expect(add.id, native.x86_insn.X86_INS_VADDPS);
    final addDetails = add.details as X86Details;
    expect(addDetails.op_count, 4);
    expect(addDetails.operands[0].unnamed.reg, native.x86_reg.X86_REG_ZMM2);
    expect(addDetails.operands[1].unnamed.reg, native.x86_reg.X86_REG_K3);
    expect(addDetails.operands[1].avx_zero_opmask, isTrue);
    expect(addDetails.operands[2].unnamed.reg, native.x86_reg.X86_REG_ZMM4);
    final memory = addDetails.operands[3];
    expect(memory.type, native.x86_op_type.X86_OP_MEM);
    expect(memory.size, 4);
    final (access, broadcast, groups) = _nativeMemoryMetadata(
      _bytes('62f15cdb5810'),
    );
    expect(access, 0);
    expect(memory.access, access);
    expect(memory.unnamed.mem.base, native.x86_reg.X86_REG_RAX);
    expect(memory.unnamed.mem.disp, 0);
    expect(broadcast, native.x86_avx_bcast.X86_AVX_BCAST_INVALID);
    expect(memory.avx_bcast, broadcast);
    expect(groups, contains(native.x86_insn_group.X86_GRP_AVX512));
    expect(add.groups, groups);
  });

  test('RIP relative addresses retain signed displacement', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    addTearDown(decoder.close);
    final instruction = decoder
        .decode(_bytes('488d1501110000'), address: 0x180001024)
        .single;
    expect(instruction.id, native.x86_insn.X86_INS_LEA);
    final details = instruction.details as X86Details;
    expect(details.op_count, 2);
    expect(details.operands[0].type, native.x86_op_type.X86_OP_REG);
    expect(details.operands[0].unnamed.reg, native.x86_reg.X86_REG_RDX);
    expect(details.operands[0].size, 8);
    expect(details.operands[0].access, native.cs_ac_type.CS_AC_WRITE);
    final memory = details.operands[1].unnamed.mem;
    expect(memory.base, native.x86_reg.X86_REG_RIP);
    expect(memory.index, native.x86_reg.X86_REG_INVALID);
    expect(memory.disp, 0x1101);
    expect(instruction.address + instruction.size + memory.disp, 0x18000212c);
    final negative = decoder
        .decode(_bytes('488d05f9ffffff'), address: 0x2000)
        .single;
    final negativeMemory =
        (negative.details as X86Details).operands[1].unnamed.mem;
    expect(negativeMemory.disp, -7);
    expect(negative.address + negative.size + negativeMemory.disp, 0x2000);
  });

  test('AL AX and EAX writes retain partial register widths', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    addTearDown(decoder.close);
    final decoded = decoder.decode(_bytes('b07f66b83412b878563412'));
    expect(decoded, hasLength(3));
    const expected = [
      (native.x86_reg.X86_REG_AL, 1, 0x7f),
      (native.x86_reg.X86_REG_AX, 2, 0x1234),
      (native.x86_reg.X86_REG_EAX, 4, 0x12345678),
    ];
    for (var index = 0; index < expected.length; index++) {
      final instruction = decoded[index];
      final (register, size, immediate) = expected[index];
      expect(instruction.id, native.x86_insn.X86_INS_MOV);
      final details = instruction.details as X86Details;
      expect(details.op_count, 2);
      expect(details.operands[0].type, native.x86_op_type.X86_OP_REG);
      expect(details.operands[0].unnamed.reg, register);
      expect(details.operands[0].size, size);
      expect(details.operands[0].access, native.cs_ac_type.CS_AC_WRITE);
      expect(details.operands[1].type, native.x86_op_type.X86_OP_IMM);
      expect(details.operands[1].unnamed.imm, immediate);
      expect(instruction.registerAccess!.written, contains(register));
    }
  });

  test('ARM64 page and literal addresses retain absolute values', () {
    final decoder = Capstone(Architecture.aarch64);
    addTearDown(decoder.close);
    final page = decoder
        .decode(_bytes('080000b0'), address: 0x180001158)
        .single;
    expect(page.id, native.aarch64_insn.AARCH64_INS_ADRP);
    final pageDetails = page.details as Aarch64Details;
    expect(pageDetails.op_count, 2);
    expect(
      pageDetails.operands[0].unnamed.reg,
      native.aarch64_reg.AARCH64_REG_X8,
    );
    expect(pageDetails.operands[0].access, native.cs_ac_type.CS_AC_WRITE);
    expect(pageDetails.operands[1].type, native.aarch64_op_type.AARCH64_OP_IMM);
    expect(pageDetails.operands[1].unnamed.imm, 0x180002000);
    final literal = decoder
        .decode(_bytes('a8030018'), address: 0x18000114c)
        .single;
    expect(literal.id, native.aarch64_insn.AARCH64_INS_LDR);
    final literalDetails = literal.details as Aarch64Details;
    expect(
      literalDetails.operands[0].unnamed.reg,
      native.aarch64_reg.AARCH64_REG_W8,
    );
    expect(
      literalDetails.operands[1].type,
      native.aarch64_op_type.AARCH64_OP_MEM,
    );
    expect(
      literalDetails.operands[1].unnamed.mem.base,
      native.aarch64_reg.AARCH64_REG_INVALID,
    );
    expect(
      literalDetails.operands[1].unnamed.mem.index,
      native.aarch64_reg.AARCH64_REG_INVALID,
    );
    expect(literalDetails.operands[1].unnamed.mem.disp, 0x1800011c0);
    final load = decoder.decode(_bytes('080140f9')).single;
    final loadDetails = load.details as Aarch64Details;
    expect(
      loadDetails.operands[0].unnamed.reg,
      native.aarch64_reg.AARCH64_REG_X8,
    );
    expect(loadDetails.operands[1].type, native.aarch64_op_type.AARCH64_OP_MEM);
    expect(
      loadDetails.operands[1].unnamed.mem.base,
      native.aarch64_reg.AARCH64_REG_X8,
    );
    expect(loadDetails.operands[1].unnamed.mem.disp, 0);
    expect(
      load.registerAccess!.read,
      contains(native.aarch64_reg.AARCH64_REG_X8),
    );
    expect(
      load.registerAccess!.written,
      contains(native.aarch64_reg.AARCH64_REG_X8),
    );
  });

  test('ARM64 indexed stores preserve extension and shift', () {
    final decoder = Capstone(Architecture.aarch64);
    addTearDown(decoder.close);
    final instruction = decoder.decode(_bytes('a05a34b8')).single;
    expect(instruction.id, native.aarch64_insn.AARCH64_INS_STR);
    final details = instruction.details as Aarch64Details;
    expect(details.operands[0].unnamed.reg, native.aarch64_reg.AARCH64_REG_W0);
    expect(details.operands[0].access, native.cs_ac_type.CS_AC_READ);
    final address = details.operands[1];
    expect(address.type, native.aarch64_op_type.AARCH64_OP_MEM);
    expect(address.access, native.cs_ac_type.CS_AC_WRITE);
    expect(address.unnamed.mem.base, native.aarch64_reg.AARCH64_REG_X21);
    expect(address.unnamed.mem.index, native.aarch64_reg.AARCH64_REG_W20);
    expect(address.unnamed.mem.disp, 0);
    expect(address.ext, native.aarch64_extender.AARCH64_EXT_UXTW);
    expect(address.shift.type, native.aarch64_shifter.AARCH64_SFT_LSL);
    expect(address.shift.value, 2);
    expect(
      instruction.registerAccess!.read,
      containsAll([
        native.aarch64_reg.AARCH64_REG_W0,
        native.aarch64_reg.AARCH64_REG_X21,
        native.aarch64_reg.AARCH64_REG_W20,
      ]),
    );
    final update = decoder.decode(_bytes('fe0f1ff8')).single;
    expect(update.writeback, isTrue);
    final updateDetails = update.details as Aarch64Details;
    expect(updateDetails.post_index, isFalse);
    expect(
      updateDetails.operands[1].unnamed.mem.base,
      native.aarch64_reg.AARCH64_REG_SP,
    );
    expect(updateDetails.operands[1].unnamed.mem.disp, -16);
  });

  test('Invalid and incomplete x86 bytes preserve address continuity', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode32);
    addTearDown(decoder.close);
    final decoded = decoder
        .decode(_bytes('f090900f'), address: 0x1234)
        .toList();
    expect(decoded, hasLength(4));
    expect(decoded.map((instruction) => instruction.id), [
      0,
      native.x86_insn.X86_INS_NOP,
      native.x86_insn.X86_INS_NOP,
      0,
    ]);
    expect(decoded.map((instruction) => instruction.address), [
      0x1234,
      0x1235,
      0x1236,
      0x1237,
    ]);
    expect(decoded.map((instruction) => instruction.size), [1, 1, 1, 1]);
  });

  test(
    'Invalid ARM64 words and trailing bytes preserve address continuity',
    () {
      final decoder = Capstone(Architecture.aarch64);
      addTearDown(decoder.close);
      final decoded = decoder.decode(
        _bytes('ffffffffc0035fd6aabb'),
        address: 0x4000,
      );
      expect(decoded, hasLength(3));
      expect(decoded.map((instruction) => instruction.id), [
        0,
        native.aarch64_insn.AARCH64_INS_RET,
        0,
      ]);
      expect(decoded.map((instruction) => instruction.address), [
        0x4000,
        0x4004,
        0x4008,
      ]);
      expect(decoded.map((instruction) => instruction.size), [4, 4, 2]);
      expect(decoded.last.bytes, orderedEquals([0xaa, 0xbb]));
    },
  );

  test('Empty input has no instruction or gap', () {
    for (final (architecture, mode) in [
      (Architecture.x86, Mode.mode32),
      (Architecture.x86, Mode.mode64),
      (Architecture.aarch64, 0),
    ]) {
      final decoder = Capstone(architecture, mode: mode);
      try {
        expect(decoder.decode(Uint8List(0), address: 0x1000), isEmpty);
      } finally {
        decoder.close();
      }
    }
  });

  test('Instruction bytes survive subsequent decoding and close', () {
    final decoder = Capstone(Architecture.x86, mode: Mode.mode64);
    final bytes = _bytes('488d1501110000b07f');
    Instruction? retained;
    late List<int> expectedRegistersRead;
    late List<int> expectedRegistersWritten;
    var count = 0;
    decoder.visit(bytes, (instruction) {
      if (count++ == 0) {
        retained = instruction;
        expectedRegistersRead = List<int>.of(instruction.registerAccess!.read);
        expectedRegistersWritten = List<int>.of(
          instruction.registerAccess!.written,
        );
      } else {
        expect(instruction.id, native.x86_insn.X86_INS_MOV);
        expect(retained!.bytes, orderedEquals(_bytes('488d1501110000')));
        final details = retained!.details as X86Details;
        expect(details.operands[0].unnamed.reg, native.x86_reg.X86_REG_RDX);
        expect(details.operands[1].unnamed.mem.disp, 0x1101);
      }
      return true;
    }, address: 0x180001024);
    expect(count, 2);
    final first = retained!;
    decoder.decode(_bytes('62f17c4858c1')).toList();
    decoder.close();
    bytes.fillRange(0, bytes.length, 0);
    expect(first.bytes, orderedEquals(_bytes('488d1501110000')));
    expect(first.id, native.x86_insn.X86_INS_LEA);
    expect(first.address, 0x180001024);
    final details = first.details as X86Details;
    expect(details.operands[0].unnamed.reg, native.x86_reg.X86_REG_RDX);
    expect(details.operands[1].unnamed.mem.base, native.x86_reg.X86_REG_RIP);
    expect(details.operands[1].unnamed.mem.disp, 0x1101);
    expect(first.registerAccess!.read, orderedEquals(expectedRegistersRead));
    expect(
      first.registerAccess!.written,
      orderedEquals(expectedRegistersWritten),
    );
    expect(() => first.bytes[0] = 0, throwsUnsupportedError);
    expect(() => details.operands.clear(), throwsUnsupportedError);
    expect(() => first.registerAccess!.read.clear(), throwsUnsupportedError);
    expect(() => first.registerAccess!.written.clear(), throwsUnsupportedError);
    expect(() => first.groups.clear(), throwsUnsupportedError);
  });

  for (final (title, architecture, mode, imageBase, instructions)
      in _smokeFixtures) {
    test(title, () {
      final decoder = Capstone(architecture, mode: mode);
      addTearDown(decoder.close);
      for (final (rva, hex) in instructions) {
        final bytes = _bytes(hex);
        final decoded = decoder
            .decode(bytes, address: imageBase + rva)
            .toList();
        expect(decoded, hasLength(1), reason: 'RVA 0x${rva.toRadixString(16)}');
        final instruction = decoded.single;
        expect(instruction.id, greaterThan(0));
        expect(instruction.size, bytes.length);
        expect(instruction.address, imageBase + rva);
        expect(instruction.bytes, orderedEquals(bytes));
      }
    });
  }
}
