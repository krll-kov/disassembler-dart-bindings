// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#ifndef CAPSTONE_SRC_ABI_H_
#define CAPSTONE_SRC_ABI_H_

#include <stddef.h>

#include <capstone/capstone.h>

#ifdef __cplusplus
extern "C" {
#endif

CAPSTONE_EXPORT size_t capstone_sizeof_insn(void);
CAPSTONE_EXPORT size_t capstone_sizeof_detail(void);
CAPSTONE_EXPORT size_t capstone_sizeof_x86(void);
CAPSTONE_EXPORT size_t capstone_sizeof_aarch64(void);
CAPSTONE_EXPORT size_t capstone_sizeof_architecture(cs_arch arch);
CAPSTONE_EXPORT size_t capstone_offsetof_field(unsigned int structure,
                                              unsigned int field);

#ifdef __cplusplus
}
#endif

#endif
