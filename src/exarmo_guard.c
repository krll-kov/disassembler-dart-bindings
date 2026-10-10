// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#include <setjmp.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#if defined(_MSC_VER)
#define DISASSEMBLER_THREAD_LOCAL __declspec(thread)
#define DISASSEMBLER_EXPORT __declspec(dllexport)
#else
#define DISASSEMBLER_THREAD_LOCAL _Thread_local
#define DISASSEMBLER_EXPORT __attribute__((used, visibility("default")))
#endif

// exarmo builds without std to keep its panic runtime out of the library, so
// a panic in the decoder returns here by longjmp instead of by unwinding
static DISASSEMBLER_THREAD_LOCAL jmp_buf* exarmo_guard;

bool exarmo_capi_try(void (*body)(void*), void* state) {
  jmp_buf here;
  jmp_buf* outer = exarmo_guard;
  exarmo_guard = &here;
  if (setjmp(here) != 0) {
    exarmo_guard = outer;
    return false;
  }
  body(state);
  exarmo_guard = outer;
  return true;
}

void exarmo_capi_panic(void) {
  jmp_buf* target = exarmo_guard;
  if (target == NULL) abort();
  longjmp(*target, 1);
}

uint32_t disassembler_exarmo_guard_probe(bool fail);

DISASSEMBLER_EXPORT uint32_t disassembler_exarmo_probe(bool fail) {
  return disassembler_exarmo_guard_probe(fail);
}
