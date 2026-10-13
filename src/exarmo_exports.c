// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#if defined(_WIN32)
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32=_exarmo_aarch32_decode_a32")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32_bytes=_exarmo_aarch32_decode_a32_bytes")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32_bytes")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32_word=_exarmo_aarch32_decode_a32_word")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_a32_word")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32=_exarmo_aarch32_decode_t32")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32_bytes=_exarmo_aarch32_decode_t32_bytes")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32_bytes")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32_word=_exarmo_aarch32_decode_t32_word")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_decode_t32_word")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_length=_exarmo_aarch32_encoding_length")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_length")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_mnemonic=_exarmo_aarch32_encoding_mnemonic")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_mnemonic")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_name=_exarmo_aarch32_encoding_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_encoding_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_branch=_exarmo_aarch32_instruction_branch")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_branch")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_encoding=_exarmo_aarch32_instruction_encoding")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_encoding")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_flags=_exarmo_aarch32_instruction_flags")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_flags")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_length=_exarmo_aarch32_instruction_length")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_length")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_mnemonic=_exarmo_aarch32_instruction_mnemonic")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_mnemonic")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_operands=_exarmo_aarch32_instruction_operands")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_operands")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_size=_exarmo_aarch32_instruction_size")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_size")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_sysreg=_exarmo_aarch32_instruction_sysreg")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_sysreg")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_text=_exarmo_aarch32_instruction_text")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_text")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_tokens=_exarmo_aarch32_instruction_tokens")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_tokens")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_unpredictable=_exarmo_aarch32_instruction_unpredictable")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_instruction_unpredictable")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_it_state_after=_exarmo_aarch32_it_state_after")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_it_state_after")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_mnemonic_name=_exarmo_aarch32_mnemonic_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_mnemonic_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_sysreg_name=_exarmo_aarch32_sysreg_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_sysreg_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_sysregs=_exarmo_aarch32_sysregs,DATA")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_sysregs,DATA")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch32_t32_length=_exarmo_aarch32_t32_length")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch32_t32_length")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode=_exarmo_aarch64_decode")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode_bytes=_exarmo_aarch64_decode_bytes")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode_bytes")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode_word=_exarmo_aarch64_decode_word")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_decode_word")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_length=_exarmo_aarch64_encoding_length")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_length")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_mnemonic=_exarmo_aarch64_encoding_mnemonic")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_mnemonic")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_name=_exarmo_aarch64_encoding_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_encoding_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_branch=_exarmo_aarch64_instruction_branch")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_branch")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_encoding=_exarmo_aarch64_instruction_encoding")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_encoding")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_flags=_exarmo_aarch64_instruction_flags")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_flags")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_intrinsics=_exarmo_aarch64_instruction_intrinsics")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_intrinsics")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_length=_exarmo_aarch64_instruction_length")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_length")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_mnemonic=_exarmo_aarch64_instruction_mnemonic")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_mnemonic")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_operands=_exarmo_aarch64_instruction_operands")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_operands")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_size=_exarmo_aarch64_instruction_size")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_size")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_text=_exarmo_aarch64_instruction_text")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_text")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_tokens=_exarmo_aarch64_instruction_tokens")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_tokens")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_unpredictable=_exarmo_aarch64_instruction_unpredictable")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_instruction_unpredictable")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_intrinsic_at=_exarmo_aarch64_intrinsic_at")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_intrinsic_at")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_intrinsic_type_at=_exarmo_aarch64_intrinsic_type_at")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_intrinsic_type_at")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_mnemonic_name=_exarmo_aarch64_mnemonic_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_mnemonic_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysops=_exarmo_aarch64_sysops,DATA")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysops,DATA")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysreg_name=_exarmo_aarch64_sysreg_name")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysreg_name")
#endif
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_M_IX86)
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysregs=_exarmo_aarch64_sysregs,DATA")
#else
#pragma comment(linker, "/EXPORT:exarmo_aarch64_sysregs,DATA")
#endif
#endif
#else
#include "../third_party/exarmo/aarch32-capi/include/exarmo/aarch32.h"
#include "../third_party/exarmo/aarch64-capi/include/exarmo/aarch64.h"
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
__attribute__((used, visibility("default")))
const void *const disassembler_exarmo_exports[] = {
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_a32,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_a32_bytes,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_a32_word,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_t32,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_t32_bytes,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_decode_t32_word,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_encoding_length,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_encoding_mnemonic,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_encoding_name,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_branch,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_encoding,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_flags,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_length,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_mnemonic,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_operands,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_size,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_sysreg,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_text,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_tokens,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_instruction_unpredictable,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_it_state_after,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_mnemonic_name,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_sysreg_name,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_sysregs,
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  (const void *)&exarmo_aarch32_t32_length,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_decode,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_decode_bytes,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_decode_word,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_encoding_length,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_encoding_mnemonic,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_encoding_name,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_branch,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_encoding,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_flags,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_intrinsics,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_length,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_mnemonic,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_operands,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_size,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_text,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_tokens,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_instruction_unpredictable,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_intrinsic_at,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_intrinsic_type_at,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_mnemonic_name,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_sysops,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_sysreg_name,
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  (const void *)&exarmo_aarch64_sysregs,
#endif
};
#pragma GCC diagnostic pop
#endif
