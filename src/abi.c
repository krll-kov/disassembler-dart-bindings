// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#include "abi.h"

#include <stddef.h>

#include <capstone/aarch64.h>
#include <capstone/capstone.h>
#include <capstone/cs_operand.h>
#include <capstone/x86.h>

_Static_assert(sizeof(cs_arch) == 4, "cs_arch must occupy 4 bytes");
_Static_assert(sizeof(cs_mode) == 4, "cs_mode must occupy 4 bytes");
_Static_assert(sizeof(cs_err) == 4, "cs_err must occupy 4 bytes");
_Static_assert(sizeof(cs_opt_type) == 4, "cs_opt_type must occupy 4 bytes");
_Static_assert(sizeof(cs_opt_value) == 4, "cs_opt_value must occupy 4 bytes");
_Static_assert(sizeof(cs_ac_type) == 4, "cs_ac_type must occupy 4 bytes");
_Static_assert(sizeof(x86_reg) == 4, "x86_reg must occupy 4 bytes");
_Static_assert(sizeof(x86_op_type) == 4, "x86_op_type must occupy 4 bytes");
_Static_assert(sizeof(aarch64_reg) == 4, "aarch64_reg must occupy 4 bytes");
_Static_assert(sizeof(aarch64_op_type) == 4,
               "aarch64_op_type must occupy 4 bytes");

size_t capstone_sizeof_insn(void) { return sizeof(cs_insn); }

size_t capstone_sizeof_detail(void) { return sizeof(cs_detail); }

size_t capstone_sizeof_x86(void) { return sizeof(cs_x86); }

size_t capstone_sizeof_aarch64(void) { return sizeof(cs_aarch64); }

size_t capstone_sizeof_architecture(cs_arch arch) {
  switch (arch) {
    case CS_ARCH_ARM: return sizeof(cs_arm);
    case CS_ARCH_AARCH64: return sizeof(cs_aarch64);
    case CS_ARCH_SYSTEMZ: return sizeof(cs_systemz);
    case CS_ARCH_MIPS: return sizeof(cs_mips);
    case CS_ARCH_X86: return sizeof(cs_x86);
    case CS_ARCH_PPC: return sizeof(cs_ppc);
    case CS_ARCH_SPARC: return sizeof(cs_sparc);
    case CS_ARCH_XCORE: return sizeof(cs_xcore);
    case CS_ARCH_M68K: return sizeof(cs_m68k);
    case CS_ARCH_TMS320C64X: return sizeof(cs_tms320c64x);
    case CS_ARCH_M680X: return sizeof(cs_m680x);
    case CS_ARCH_EVM: return sizeof(cs_evm);
    case CS_ARCH_MOS65XX: return sizeof(cs_mos65xx);
    case CS_ARCH_WASM: return sizeof(cs_wasm);
    case CS_ARCH_BPF: return sizeof(cs_bpf);
    case CS_ARCH_RISCV: return sizeof(cs_riscv);
    case CS_ARCH_SH: return sizeof(cs_sh);
    case CS_ARCH_TRICORE: return sizeof(cs_tricore);
    case CS_ARCH_ALPHA: return sizeof(cs_alpha);
    case CS_ARCH_HPPA: return sizeof(cs_hppa);
    case CS_ARCH_LOONGARCH: return sizeof(cs_loongarch);
    case CS_ARCH_XTENSA: return sizeof(cs_xtensa);
    case CS_ARCH_ARC: return sizeof(cs_arc);
    default: return 0;
  }
}

size_t capstone_offsetof_field(unsigned int structure, unsigned int field) {
  static const size_t kInsnOffsets[] = {
      offsetof(cs_insn, id), offsetof(cs_insn, alias_id),
      offsetof(cs_insn, address), offsetof(cs_insn, size),
      offsetof(cs_insn, bytes), offsetof(cs_insn, mnemonic),
      offsetof(cs_insn, op_str), offsetof(cs_insn, is_alias),
      offsetof(cs_insn, usesAliasDetails), offsetof(cs_insn, illegal),
      offsetof(cs_insn, detail)};
  static const size_t kDetailOffsets[] = {
      offsetof(cs_detail, regs_read), offsetof(cs_detail, regs_read_count),
      offsetof(cs_detail, regs_write), offsetof(cs_detail, regs_write_count),
      offsetof(cs_detail, groups), offsetof(cs_detail, groups_count),
      offsetof(cs_detail, writeback), offsetof(cs_detail, x86)};
  static const size_t kX86Offsets[] = {
      offsetof(cs_x86_op, type), offsetof(cs_x86_op, reg),
      offsetof(cs_x86_op, imm), offsetof(cs_x86_op, mem.base),
      offsetof(cs_x86_op, mem.index), offsetof(cs_x86_op, mem.scale),
      offsetof(cs_x86_op, mem.disp), offsetof(cs_x86_op, size),
      offsetof(cs_x86_op, access), offsetof(cs_x86_op, avx_bcast),
      offsetof(cs_x86_op, avx_zero_opmask)};
  static const size_t kAarch64Offsets[] = {
      offsetof(cs_aarch64_op, vector_index), offsetof(cs_aarch64_op, vas),
      offsetof(cs_aarch64_op, shift.type), offsetof(cs_aarch64_op, shift.value),
      offsetof(cs_aarch64_op, ext), offsetof(cs_aarch64_op, type),
      offsetof(cs_aarch64_op, is_vreg), offsetof(cs_aarch64_op, reg),
      offsetof(cs_aarch64_op, imm), offsetof(cs_aarch64_op, mem.base),
      offsetof(cs_aarch64_op, mem.index), offsetof(cs_aarch64_op, mem.disp),
      offsetof(cs_aarch64_op, access)};
  const size_t* offsets = NULL;
  size_t count = 0;
  switch (structure) {
    case 0:
      offsets = kInsnOffsets;
      count = sizeof(kInsnOffsets) / sizeof(kInsnOffsets[0]);
      break;
    case 1:
      offsets = kDetailOffsets;
      count = sizeof(kDetailOffsets) / sizeof(kDetailOffsets[0]);
      break;
    case 2:
      offsets = kX86Offsets;
      count = sizeof(kX86Offsets) / sizeof(kX86Offsets[0]);
      break;
    case 3:
      offsets = kAarch64Offsets;
      count = sizeof(kAarch64Offsets) / sizeof(kAarch64Offsets[0]);
      break;
    default: return (size_t)-1;
  }
  return field < count ? offsets[field] : (size_t)-1;
}
