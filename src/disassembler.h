#ifndef DISASSEMBLER_H_
#define DISASSEMBLER_H_

#include <stdint.h>

#include "batch.h"

#if defined(_WIN32)
#define DISASSEMBLER_API __declspec(dllexport)
#else
#define DISASSEMBLER_API __attribute__((visibility("default")))
#endif

DISASSEMBLER_API unsigned int disassembler_backend_mask(void);
DISASSEMBLER_API unsigned int disassembler_exarmo_decoder_mask(void);
DISASSEMBLER_API unsigned int disassembler_zydis_feature_mask(void);

DISASSEMBLER_API void* disassembler_open(int32_t backend,
                                         int32_t architecture);
DISASSEMBLER_API int32_t disassembler_decode(void* context,
                                             const uint8_t* bytes,
                                             int64_t length, uint64_t address,
                                             int32_t limit, uint32_t stop,
                                             int32_t resume,
                                             disassembler_batch* batch);
// Writes targets of direct calls in a linear decode of `bytes` up to
// `capacity` and sets `consumed`; returns the count, or
// DISASSEMBLER_STATUS_UNSUPPORTED for a backend without it.
DISASSEMBLER_API int64_t disassembler_call_targets(void* context,
                                                   const uint8_t* bytes,
                                                   int64_t length,
                                                   uint64_t address,
                                                   uint64_t* targets,
                                                   int64_t capacity,
                                                   int64_t* consumed);
DISASSEMBLER_API const char* disassembler_mnemonic(void* context, int64_t key);
DISASSEMBLER_API void disassembler_close(void* context);

#endif
