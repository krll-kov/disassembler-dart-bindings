// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#ifndef DISASSEMBLER_BATCH_H_
#define DISASSEMBLER_BATCH_H_

#include <stdint.h>

#define DISASSEMBLER_INSTRUCTION_STRIDE 8
#define DISASSEMBLER_OPERAND_STRIDE 8

#define DISASSEMBLER_STOP_JUMP 1
#define DISASSEMBLER_STOP_CALL 2
#define DISASSEMBLER_STOP_RETURN 4
#define DISASSEMBLER_STOP_INTERRUPT 8
#define DISASSEMBLER_STOP_INVALID 16

#define DISASSEMBLER_STATUS_OK 0
#define DISASSEMBLER_STATUS_UNSUPPORTED -1
#define DISASSEMBLER_STATUS_CAPACITY -2
#define DISASSEMBLER_STATUS_FAILED -3

typedef struct disassembler_batch {
  int64_t* instructions;
  int64_t* operands;
  uint32_t* registers;
  int32_t instruction_capacity;
  int32_t operand_capacity;
  int32_t register_capacity;
  int32_t count;
  int32_t operand_count;
  int32_t register_count;
  int64_t consumed;
} disassembler_batch;

#endif
