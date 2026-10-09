// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:ffi' as ffi;

import 'package:disassembler/capstone.dart';
import 'package:disassembler/src/third_party/capstone.g.dart' as native;
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void _verifyOffsets<T extends ffi.NativeType>(
  int size,
  int structure,
  List<void Function(ffi.Pointer<T>)> writers, {
  Set<int> booleanFields = const {},
}) {
  final bytes = calloc<ffi.Uint8>(size);
  try {
    for (var field = 0; field < writers.length; field++) {
      bytes.asTypedList(size).fillRange(0, size, 0);
      writers[field](bytes.cast<T>());
      final offset = native.capstone_offsetof_field(structure, field);
      expect(offset, lessThan(size));
      expect(
        bytes[offset],
        booleanFields.contains(field) ? 1 : 0x5a,
        reason: 'Structure $structure field $field',
      );
    }
  } finally {
    calloc.free(bytes);
  }
}

void main() {
  test('cs_insn matches native size', () {
    expect(ffi.sizeOf<native.cs_insn>(), native.capstone_sizeof_insn());
  });

  test('cs_detail matches native size', () {
    expect(ffi.sizeOf<native.cs_detail>(), native.capstone_sizeof_detail());
  });

  test('cs_x86 matches native size', () {
    expect(ffi.sizeOf<native.cs_x86>(), native.capstone_sizeof_x86());
  });

  test('cs_aarch64 matches native size', () {
    expect(ffi.sizeOf<native.cs_aarch64>(), native.capstone_sizeof_aarch64());
  });

  test('All 23 architecture details match native sizes', () {
    final sizes = <Architecture, int>{
      Architecture.arm: ffi.sizeOf<native.cs_arm>(),
      Architecture.aarch64: ffi.sizeOf<native.cs_aarch64>(),
      Architecture.systemz: ffi.sizeOf<native.cs_systemz>(),
      Architecture.mips: ffi.sizeOf<native.cs_mips>(),
      Architecture.x86: ffi.sizeOf<native.cs_x86>(),
      Architecture.ppc: ffi.sizeOf<native.cs_ppc>(),
      Architecture.sparc: ffi.sizeOf<native.cs_sparc>(),
      Architecture.xcore: ffi.sizeOf<native.cs_xcore>(),
      Architecture.m68k: ffi.sizeOf<native.cs_m68k>(),
      Architecture.tms320c64x: ffi.sizeOf<native.cs_tms320c64x>(),
      Architecture.m680x: ffi.sizeOf<native.cs_m680x>(),
      Architecture.evm: ffi.sizeOf<native.cs_evm>(),
      Architecture.mos65xx: ffi.sizeOf<native.cs_mos65xx>(),
      Architecture.wasm: ffi.sizeOf<native.cs_wasm>(),
      Architecture.bpf: ffi.sizeOf<native.cs_bpf>(),
      Architecture.riscv: ffi.sizeOf<native.cs_riscv>(),
      Architecture.sh: ffi.sizeOf<native.cs_sh>(),
      Architecture.tricore: ffi.sizeOf<native.cs_tricore>(),
      Architecture.alpha: ffi.sizeOf<native.cs_alpha>(),
      Architecture.hppa: ffi.sizeOf<native.cs_hppa>(),
      Architecture.loongarch: ffi.sizeOf<native.cs_loongarch>(),
      Architecture.xtensa: ffi.sizeOf<native.cs_xtensa>(),
      Architecture.arc: ffi.sizeOf<native.cs_arc>(),
    };
    expect(sizes.keys, unorderedEquals(Architecture.values));
    for (final entry in sizes.entries) {
      expect(
        entry.value,
        native.capstone_sizeof_architecture(entry.key.value),
        reason: entry.key.name,
      );
    }
  });

  test('Common instruction fields match native offsets', () {
    _verifyOffsets<native.cs_insn>(
      ffi.sizeOf<native.cs_insn>(),
      0,
      [
        (p) => p.ref.id = 0x5a,
        (p) => p.ref.alias_id = 0x5a,
        (p) => p.ref.address = 0x5a,
        (p) => p.ref.size = 0x5a,
        (p) => p.ref.bytes[0] = 0x5a,
        (p) => p.ref.mnemonic[0] = 0x5a,
        (p) => p.ref.op_str[0] = 0x5a,
        (p) => p.ref.is_alias = true,
        (p) => p.ref.usesAliasDetails = true,
        (p) => p.ref.illegal = true,
        (p) => p.ref.detail = ffi.Pointer<native.cs_detail>.fromAddress(0x5a),
      ],
      booleanFields: {7, 8, 9},
    );
  });

  test('Common detail fields match native offsets', () {
    _verifyOffsets<native.cs_detail>(
      ffi.sizeOf<native.cs_detail>(),
      1,
      [
        (p) => p.ref.regs_read[0] = 0x5a,
        (p) => p.ref.regs_read_count = 0x5a,
        (p) => p.ref.regs_write[0] = 0x5a,
        (p) => p.ref.regs_write_count = 0x5a,
        (p) => p.ref.groups[0] = 0x5a,
        (p) => p.ref.groups_count = 0x5a,
        (p) => p.ref.writeback = true,
        (p) => p.ref.unnamed.x86.prefix[0] = 0x5a,
      ],
      booleanFields: {6},
    );
  });

  test('x86 operand unions match native offsets', () {
    _verifyOffsets<native.cs_x86_op>(
      ffi.sizeOf<native.cs_x86_op>(),
      2,
      [
        (p) => p.ref.type = 0x5a,
        (p) => p.ref.unnamed.reg = 0x5a,
        (p) => p.ref.unnamed.imm = 0x5a,
        (p) => p.ref.unnamed.mem.base = 0x5a,
        (p) => p.ref.unnamed.mem.index = 0x5a,
        (p) => p.ref.unnamed.mem.scale = 0x5a,
        (p) => p.ref.unnamed.mem.disp = 0x5a,
        (p) => p.ref.size = 0x5a,
        (p) => p.ref.access = 0x5a,
        (p) => p.ref.avx_bcast = 0x5a,
        (p) => p.ref.avx_zero_opmask = true,
      ],
      booleanFields: {10},
    );
  });

  test('AArch64 nested operand fields match native offsets', () {
    _verifyOffsets<native.cs_aarch64_op>(
      ffi.sizeOf<native.cs_aarch64_op>(),
      3,
      [
        (p) => p.ref.vector_index = 0x5a,
        (p) => p.ref.vas = 0x5a,
        (p) => p.ref.shift.type = 0x5a,
        (p) => p.ref.shift.value = 0x5a,
        (p) => p.ref.ext = 0x5a,
        (p) => p.ref.type = 0x5a,
        (p) => p.ref.is_vreg = true,
        (p) => p.ref.unnamed.reg = 0x5a,
        (p) => p.ref.unnamed.imm = 0x5a,
        (p) => p.ref.unnamed.mem.base = 0x5a,
        (p) => p.ref.unnamed.mem.index = 0x5a,
        (p) => p.ref.unnamed.mem.disp = 0x5a,
        (p) => p.ref.access = 0x5a,
      ],
      booleanFields: {6},
    );
  });
}
