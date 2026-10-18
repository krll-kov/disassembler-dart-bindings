// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

#include <ctype.h>
#include <setjmp.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "batch.h"
#include "disassembler.h"

#if defined(DISASSEMBLER_ZYDIS)
#include <Zydis/Zydis.h>
#endif
#if defined(DISASSEMBLER_CAPSTONE)
#include <capstone/capstone.h>
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
#include "../third_party/exarmo/aarch32-capi/include/exarmo/aarch32.h"
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
#include "../third_party/exarmo/aarch64-capi/include/exarmo/aarch64.h"
#include "aarch64_effects.h"
#endif

enum {
  kBackendZydis = 0,
  kBackendExarmo = 1,
  kBackendCapstone = 2,
};

enum {
  kArchX86 = 0,
  kArchX64 = 1,
  kArchArm = 2,
  kArchThumb = 3,
  kArchArm64 = 4,
};

enum {
  kFlowNone = 0,
  kFlowCall = 1,
  kFlowJump = 2,
  kFlowReturn = 3,
  kFlowInterrupt = 4,
};

enum {
  kKindRegister = 0,
  kKindImmediate = 1,
  kKindMemory = 2,
  kKindOther = 3,
};

enum {
  kShiftNone = 0,
  kShiftLsl = 1,
  kShiftLsr = 2,
  kShiftAsr = 3,
  kShiftRor = 4,
  kShiftMsl = 5,
};

enum {
  kExtendNone = 0,
  kExtendUxtb = 1,
  kExtendUxth = 2,
  kExtendUxtw = 3,
  kExtendUxtx = 4,
  kExtendSxtb = 5,
  kExtendSxth = 6,
  kExtendSxtw = 7,
  kExtendSxtx = 8,
};

enum {
  kFlagValid = 1 << 0,
  kFlagConditional = 1 << 4,
  kFlagWriteback = 1 << 5,
  kFlagPostIndex = 1 << 6,
  kFlagVector = 1 << 7,
  kFlagWritesFlagsKnown = 1 << 8,
  kFlagWritesFlags = 1 << 9,
  kFlagRegisterAccess = 1 << 10,
  kFlagBrief = 1 << 11,
};

#define kConditionMnemonic 31

typedef struct Operand {
  int kind;
  int access;
  bool has_access;
  int size;
  int shift;
  int extend;
  bool zeroing;
  bool absolute;
  int broadcast;
  int element_bits;
  int lanes;
  int scale;
  int64_t reg;
  int64_t immediate;
  int64_t base;
  int64_t index;
  int64_t segment;
  int64_t displacement;
  int64_t shift_value;
} Operand;

typedef struct Context {
  int backend;
  int architecture;
#if defined(DISASSEMBLER_ZYDIS)
  ZydisDecoder zydis;
#endif
#if defined(DISASSEMBLER_CAPSTONE)
  csh capstone;
  cs_insn* insn;
  char (*mnemonics)[32];
  int32_t mnemonic_count;
  int32_t mnemonic_capacity;
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
  exarmo_aarch32_it_state it;
#endif
  struct Selection* selection;
} Context;

enum { kSelectionIdBytes = 1024, kFlowBits = 0xf };

#if defined(DISASSEMBLER_EXARMO_AARCH64)
enum { kBucketShift = 21, kBuckets = 1 << (32 - kBucketShift) };

// Words are bucketed by their top 11 bits, since nearly every A64 encoding
// fixes op0 in bits 28 to 25, so a bucket holds the few patterns left to test
typedef struct Arm64Prefilter {
  bool built;
  bool usable;
  uint32_t flows;
  uint32_t* start;
  uint16_t* members;
} Arm64Prefilter;
#endif

typedef struct Selection {
  bool skip_others;
  uint32_t flows;
  uint8_t ids[kSelectionIdBytes];
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  bool probed;
  uint8_t flow_of[EXARMO_AARCH64_ENCODING_COUNT];
  Arm64Prefilter prefilter;
#endif
} Selection;

static bool SelectedId(const Selection* s, int64_t id) {
  if (id < 0 || id >= kSelectionIdBytes * 8) return false;
  return (s->ids[id >> 3] >> (id & 7) & 1) != 0;
}

static void WriteOperand(disassembler_batch* batch, const Operand* o) {
  int64_t* r =
      batch->operands + (int64_t)batch->operand_count * DISASSEMBLER_OPERAND_STRIDE;
  r[0] = (int64_t)(o->kind & 7) | (o->has_access ? 1 << 3 : 0) |
         (int64_t)(o->access & 3) << 4 | (int64_t)(o->size & 0xff) << 8 |
         (int64_t)(o->shift & 0xf) << 16 | (int64_t)(o->extend & 0xf) << 20 |
         (o->zeroing ? 1 << 24 : 0) | (o->absolute ? 1 << 25 : 0) |
         (int64_t)(o->broadcast & 0xff) << 32 |
         (int64_t)(o->element_bits & 0xff) << 40 |
         (int64_t)(o->lanes & 0xff) << 48 | (int64_t)(uint8_t)(int8_t)o->scale
                                                << 56;
  r[1] = o->reg;
  r[2] = o->immediate;
  r[3] = o->base;
  r[4] = o->index;
  r[5] = o->segment;
  r[6] = o->displacement;
  r[7] = o->shift_value;
  batch->operand_count++;
}

typedef struct Record {
  uint64_t address;
  uint32_t size;
  int operand_count;
  int immediate_size;
  int condition;
  int64_t flags;
  int flow;
  int64_t id;
  int64_t mnemonic;
  int64_t canonical;
  int64_t extra;
  int32_t operand_start;
  int32_t register_start;
  int read_count;
  int written_count;
  uint32_t status;
} Record;

static void InitRecord(Record* r, const disassembler_batch* batch,
                       uint64_t address) {
  memset(r, 0, sizeof(*r));
  r->address = address;
  r->operand_start = batch->operand_count;
  r->register_start = batch->register_count;
  r->mnemonic = -1;
  r->canonical = -1;
}

static void WriteRecord(disassembler_batch* batch, const Record* r) {
  int64_t* out = batch->instructions +
                 (int64_t)batch->count * DISASSEMBLER_INSTRUCTION_STRIDE;
  out[0] = (int64_t)r->address;
  out[1] = (int64_t)r->size | (int64_t)(r->operand_count & 0xff) << 32 |
           (int64_t)(r->immediate_size & 0xff) << 40 |
           (int64_t)(r->condition & 0x1f) << 48;
  out[2] = r->flags | (int64_t)(r->flow & 7) << 1;
  out[3] = r->id;
  out[4] = r->mnemonic;
  out[5] = (r->canonical & 0xffffffff) | r->extra << 32;
  out[6] = (int64_t)(uint32_t)r->operand_start |
           (int64_t)(uint32_t)r->register_start << 32;
  out[7] = (int64_t)(r->read_count & 0xffff) |
           (int64_t)(r->written_count & 0xffff) << 16 |
           (int64_t)r->status << 32;
  batch->count++;
}

static bool Stops(uint32_t stop, int flow, bool valid) {
  if (!valid) return (stop & DISASSEMBLER_STOP_INVALID) != 0;
  switch (flow) {
    case kFlowJump: return (stop & DISASSEMBLER_STOP_JUMP) != 0;
    case kFlowCall: return (stop & DISASSEMBLER_STOP_CALL) != 0;
    case kFlowReturn: return (stop & DISASSEMBLER_STOP_RETURN) != 0;
    case kFlowInterrupt: return (stop & DISASSEMBLER_STOP_INTERRUPT) != 0;
    default: return false;
  }
}

static bool Selected(const Selection* s, int64_t id, int flow) {
  return s == NULL || SelectedId(s, id) || Stops(s->flows, flow, true);
}

// An instruction outside the selection whose flow is in `stop` is written
// even when the others are skipped, so the batch keeps what ended it
static bool Written(const Selection* s, bool selected, uint32_t stop, int flow,
                    bool valid) {
  if (s == NULL || selected || !s->skip_others) return true;
  return Stops(stop, flow, valid);
}

static bool HasRoom(const disassembler_batch* batch, int limit, int operands,
                    int registers) {
  return batch->count < limit &&
         batch->operand_count + operands <= batch->operand_capacity &&
         batch->register_count + registers <= batch->register_capacity;
}

static int ArmConditionCode(int value) {
  return value >= 0 && value <= 13 ? value + 1 : 0;
}

#if defined(DISASSEMBLER_ZYDIS)

static const char* kCanonicalJumps[][2] = {
    {"jz", "je"},    {"jnz", "jne"},  {"jc", "jb"},    {"jnae", "jb"},
    {"jnc", "jae"},  {"jnb", "jae"},  {"jna", "jbe"},  {"jnbe", "ja"},
    {"jpe", "jp"},   {"jpo", "jnp"},  {"jnge", "jl"},  {"jnl", "jge"},
    {"jng", "jle"},  {"jnle", "jg"},  {"sal", "shl"},
};

static int ZydisFlow(const ZydisDecodedInstruction* ins) {
  switch (ins->meta.category) {
    case ZYDIS_CATEGORY_CALL: return kFlowCall;
    case ZYDIS_CATEGORY_RET: return kFlowReturn;
    case ZYDIS_CATEGORY_COND_BR:
    case ZYDIS_CATEGORY_UNCOND_BR: return kFlowJump;
    case ZYDIS_CATEGORY_INTERRUPT: return kFlowInterrupt;
    default: return kFlowNone;
  }
}

static int ZydisBroadcast(ZydisBroadcastMode mode) {
  switch (mode) {
    case ZYDIS_BROADCAST_MODE_1_TO_2: return 2;
    case ZYDIS_BROADCAST_MODE_1_TO_4: return 4;
    case ZYDIS_BROADCAST_MODE_1_TO_8: return 8;
    case ZYDIS_BROADCAST_MODE_1_TO_16: return 16;
    case ZYDIS_BROADCAST_MODE_1_TO_32: return 32;
    case ZYDIS_BROADCAST_MODE_1_TO_64: return 64;
    default: return 0;
  }
}

typedef struct RegisterAction {
  uint32_t reg;
  uint32_t actions;
} RegisterAction;

static void AddAction(RegisterAction* list, int* count, uint32_t reg,
                      uint32_t actions) {
  if (reg == ZYDIS_REGISTER_NONE) return;
  for (int i = 0; i < *count; i++) {
    if (list[i].reg == reg) {
      list[i].actions |= actions;
      return;
    }
  }
  list[*count].reg = reg;
  list[*count].actions = actions;
  (*count)++;
}

static void ZydisHead(const ZydisDecodedInstruction* ins, Record* r) {
  r->size = ins->length;
  r->id = ins->mnemonic;
  r->mnemonic = ins->mnemonic;
  r->canonical = ins->mnemonic;
  r->flow = ZydisFlow(ins);
  r->flags = kFlagValid;
  if (ins->meta.category == ZYDIS_CATEGORY_COND_BR) {
    r->flags |= kFlagConditional;
    r->condition = kConditionMnemonic;
  }
  r->immediate_size = ins->raw.imm[0].size / 8;
  if (ins->encoding == ZYDIS_INSTRUCTION_ENCODING_VEX ||
      ins->encoding == ZYDIS_INSTRUCTION_ENCODING_EVEX ||
      ins->encoding == ZYDIS_INSTRUCTION_ENCODING_XOP ||
      ins->encoding == ZYDIS_INSTRUCTION_ENCODING_MVEX)
    r->flags |= kFlagVector;
}

static void ZydisOperand(const Context* c, const ZydisDecodedInstruction* ins,
                         const ZydisDecodedOperand* op, uint64_t address,
                         Operand* o) {
  memset(o, 0, sizeof(*o));
  switch (op->type) {
    case ZYDIS_OPERAND_TYPE_REGISTER: o->kind = kKindRegister; break;
    case ZYDIS_OPERAND_TYPE_IMMEDIATE: o->kind = kKindImmediate; break;
    case ZYDIS_OPERAND_TYPE_MEMORY: o->kind = kKindMemory; break;
    default: o->kind = kKindOther; break;
  }
  o->has_access = true;
  if (op->actions & ZYDIS_OPERAND_ACTION_MASK_READ) o->access |= 1;
  if (op->actions & ZYDIS_OPERAND_ACTION_MASK_WRITE) o->access |= 2;
  if (o->kind == kKindImmediate) {
    int64_t value = op->imm.is_signed ? op->imm.value.s
                                      : (int64_t)op->imm.value.u;
    if (op->imm.is_relative) {
      value += (int64_t)address + ins->length;
      if (c->architecture == kArchX86) value &= 0xffffffff;
    }
    o->immediate = value;
  }
  if (o->kind == kKindRegister) o->reg = op->reg.value;
  o->size = (op->size + 7) / 8;
  o->zeroing = (o->access & 2) != 0 &&
               (ins->avx.mask.mode == ZYDIS_MASK_MODE_ZEROING ||
                ins->avx.mask.mode == ZYDIS_MASK_MODE_CONTROL_ZEROING);
  if (o->kind == kKindMemory) {
    o->broadcast = ZydisBroadcast(ins->avx.broadcast.mode);
    o->base = op->mem.base;
    o->index = op->mem.index;
    o->segment = op->mem.segment;
    o->scale = op->mem.scale;
    o->displacement = op->mem.disp.has_displacement ? op->mem.disp.value : 0;
  } else {
    o->scale = 1;
  }
  o->element_bits = op->element_size;
  o->lanes = op->element_count;
}

static void ZydisRegisters(const ZydisDecodedInstruction* ins,
                           const ZydisDecodedOperand* ops, Record* r,
                           disassembler_batch* batch) {
  RegisterAction actions[2 * 3 * ZYDIS_MAX_OPERAND_COUNT];
  int action_count = 0;
  for (int i = 0; i < ins->operand_count; i++) {
    const ZydisDecodedOperand* op = &ops[i];
    if (op->type == ZYDIS_OPERAND_TYPE_REGISTER) {
      AddAction(actions, &action_count, op->reg.value, op->actions);
    } else if (op->type == ZYDIS_OPERAND_TYPE_MEMORY) {
      AddAction(actions, &action_count, op->mem.segment,
                ZYDIS_OPERAND_ACTION_READ);
      AddAction(actions, &action_count, op->mem.base,
                ZYDIS_OPERAND_ACTION_READ);
      AddAction(actions, &action_count, op->mem.index,
                ZYDIS_OPERAND_ACTION_READ);
    }
  }
  for (int i = 0; i < action_count; i++) {
    if (actions[i].actions & ZYDIS_OPERAND_ACTION_MASK_READ)
      batch->registers[batch->register_count + r->read_count++] =
          actions[i].reg;
  }
  for (int i = 0; i < action_count; i++) {
    if (actions[i].actions & ZYDIS_OPERAND_ACTION_MASK_WRITE) {
      batch->registers[batch->register_count + r->read_count +
                       r->written_count++] = actions[i].reg;
      if (actions[i].reg == ZYDIS_REGISTER_FLAGS ||
          actions[i].reg == ZYDIS_REGISTER_EFLAGS ||
          actions[i].reg == ZYDIS_REGISTER_RFLAGS)
        r->flags |= kFlagWritesFlags;
    }
  }
  batch->register_count += r->read_count + r->written_count;
}

static void ZydisFull(const Context* c, const ZydisDecodedInstruction* ins,
                      const ZydisDecodedOperand* ops, Record* r,
                      disassembler_batch* batch) {
  r->flags |= kFlagRegisterAccess | kFlagWritesFlagsKnown;
  for (int i = 0; i < ins->operand_count_visible; i++) {
    Operand o;
    ZydisOperand(c, ins, &ops[i], r->address, &o);
    WriteOperand(batch, &o);
    r->operand_count++;
  }
  ZydisRegisters(ins, ops, r, batch);
}

static int32_t DecodeZydis(Context* c, const uint8_t* bytes, int64_t length,
                           uint64_t address, int32_t limit, uint32_t stop,
                           disassembler_batch* batch) {
  const int max_registers = 2 * 3 * ZYDIS_MAX_OPERAND_COUNT;
  const Selection* s = c->selection;
  ZydisDecoderContext context;
  ZydisDecodedInstruction ins;
  ZydisDecodedOperand ops[ZYDIS_MAX_OPERAND_COUNT];
  int64_t at = 0;
  while (at < length && HasRoom(batch, limit, ZYDIS_MAX_OPERAND_COUNT_VISIBLE,
                                max_registers)) {
    int64_t available = length - at;
    if (available > ZYDIS_MAX_INSTRUCTION_LENGTH)
      available = ZYDIS_MAX_INSTRUCTION_LENGTH;
    ZyanStatus status = ZydisDecoderDecodeInstruction(
        &c->zydis, &context, bytes + at, (ZyanUSize)available, &ins);
    Record r;
    InitRecord(&r, batch, address + (uint64_t)at);
    bool selected = true;
    if (ZYAN_SUCCESS(status)) {
      ZydisHead(&ins, &r);
      selected = Selected(s, r.id, r.flow);
      if (selected)
        status = ZydisDecoderDecodeOperands(&c->zydis, &context, &ins, ops,
                                            ins.operand_count);
    }
    if (!ZYAN_SUCCESS(status)) {
      InitRecord(&r, batch, address + (uint64_t)at);
      r.status = (uint32_t)status;
      r.size = 1;
      if (Written(s, false, stop, kFlowNone, false)) WriteRecord(batch, &r);
      at += 1;
      if (Stops(stop, kFlowNone, false)) break;
      continue;
    }
    r.status = (uint32_t)status;
    if (selected)
      ZydisFull(c, &ins, ops, &r, batch);
    else
      r.flags |= kFlagBrief;
    if (Written(s, selected, stop, r.flow, true)) WriteRecord(batch, &r);
    at += ins.length;
    if (Stops(stop, r.flow, true)) break;
  }
  batch->consumed = at;
  return DISASSEMBLER_STATUS_OK;
}

#endif

#if defined(DISASSEMBLER_EXARMO_ARM) || defined(DISASSEMBLER_EXARMO_AARCH64)

static int64_t ExarmoRegister(int architecture, int reg_class, int number) {
  if (number < 0 || number > 255) return 0;
  if (architecture == kArchArm64) {
#if defined(DISASSEMBLER_EXARMO_AARCH64)
    if (reg_class == EXARMO_AARCH64_REG_W_SP && number != 31)
      reg_class = EXARMO_AARCH64_REG_W;
    else if (reg_class == EXARMO_AARCH64_REG_X_SP && number != 31)
      reg_class = EXARMO_AARCH64_REG_X;
    if (number > 31) return 0;
    switch (reg_class) {
      case EXARMO_AARCH64_REG_W:
      case EXARMO_AARCH64_REG_W_SP:
      case EXARMO_AARCH64_REG_X:
      case EXARMO_AARCH64_REG_X_SP:
      case EXARMO_AARCH64_REG_B:
      case EXARMO_AARCH64_REG_H:
      case EXARMO_AARCH64_REG_S:
      case EXARMO_AARCH64_REG_D:
      case EXARMO_AARCH64_REG_Q:
      case EXARMO_AARCH64_REG_V:
      case EXARMO_AARCH64_REG_Z: break;
      case EXARMO_AARCH64_REG_P:
      case EXARMO_AARCH64_REG_PN:
      case EXARMO_AARCH64_REG_ZA_TILE:
        if (number >= 16) return 0;
        break;
      case EXARMO_AARCH64_REG_ZT0:
        if (number != 0) return 0;
        break;
      default: return 0;
    }
    return 0x20000 | reg_class << 8 | number;
#else
    return 0;
#endif
  }
#if defined(DISASSEMBLER_EXARMO_ARM)
  switch (reg_class) {
    case EXARMO_AARCH32_REG_CORE:
      if (number > 15) return 0;
      break;
    case EXARMO_AARCH32_REG_S:
    case EXARMO_AARCH32_REG_D:
      if (number >= 32) return 0;
      break;
    case EXARMO_AARCH32_REG_Q:
      if (number >= 16) return 0;
      break;
    default: return 0;
  }
  return 0x10000 | reg_class << 8 | number;
#else
  return 0;
#endif
}

static void InvalidExarmo(disassembler_batch* batch, uint64_t address,
                          uint32_t size, uint32_t status) {
  Record r;
  InitRecord(&r, batch, address);
  r.size = size;
  r.status = status;
  WriteRecord(batch, &r);
}

#endif

#if defined(DISASSEMBLER_EXARMO_AARCH64)

static int ExarmoFlow64(int kind) {
  switch (kind) {
    case EXARMO_AARCH64_BRANCH_DIRECT:
    case EXARMO_AARCH64_BRANCH_INDIRECT: return kFlowJump;
    case EXARMO_AARCH64_BRANCH_DIRECT_CALL:
    case EXARMO_AARCH64_BRANCH_INDIRECT_CALL: return kFlowCall;
    case EXARMO_AARCH64_BRANCH_RETURN:
    case EXARMO_AARCH64_BRANCH_EXCEPTION_RETURN: return kFlowReturn;
    case EXARMO_AARCH64_BRANCH_SYSTEM_CALL:
    case EXARMO_AARCH64_BRANCH_EXCEPTION:
    case EXARMO_AARCH64_BRANCH_HALT: return kFlowInterrupt;
    default: return kFlowNone;
  }
}

static int Extend64(bool present, int kind) {
  if (!present) return kExtendNone;
  switch (kind) {
    case EXARMO_AARCH64_MOD_UXTB: return kExtendUxtb;
    case EXARMO_AARCH64_MOD_UXTH: return kExtendUxth;
    case EXARMO_AARCH64_MOD_UXTW: return kExtendUxtw;
    case EXARMO_AARCH64_MOD_UXTX: return kExtendUxtx;
    case EXARMO_AARCH64_MOD_SXTB: return kExtendSxtb;
    case EXARMO_AARCH64_MOD_SXTH: return kExtendSxth;
    case EXARMO_AARCH64_MOD_SXTW: return kExtendSxtw;
    case EXARMO_AARCH64_MOD_SXTX: return kExtendSxtx;
    default: return kExtendNone;
  }
}

static int Shift64(bool present, int kind, int amount) {
  if (!present) return kShiftNone;
  if (amount > 0 && Extend64(present, kind) != kExtendNone) return kShiftLsl;
  switch (kind) {
    case EXARMO_AARCH64_MOD_LSL: return kShiftLsl;
    case EXARMO_AARCH64_MOD_LSR: return kShiftLsr;
    case EXARMO_AARCH64_MOD_ASR: return kShiftAsr;
    case EXARMO_AARCH64_MOD_ROR: return kShiftRor;
    case EXARMO_AARCH64_MOD_MSL: return kShiftMsl;
    default: return kShiftNone;
  }
}

static int Width64(int reg_class) {
  switch (reg_class) {
    case EXARMO_AARCH64_REG_W:
    case EXARMO_AARCH64_REG_W_SP:
    case EXARMO_AARCH64_REG_S: return 4;
    case EXARMO_AARCH64_REG_X:
    case EXARMO_AARCH64_REG_X_SP:
    case EXARMO_AARCH64_REG_D: return 8;
    case EXARMO_AARCH64_REG_B: return 1;
    case EXARMO_AARCH64_REG_H: return 2;
    case EXARMO_AARCH64_REG_Q:
    case EXARMO_AARCH64_REG_V: return 16;
    default: return 0;
  }
}

static int64_t ShiftAmount(bool present, int amount) {
  return present && amount != -1 ? amount : 0;
}

static void Operand64(const exarmo_aarch64_operand* op, uint64_t address,
                      Operand* o) {
  memset(o, 0, sizeof(*o));
  o->scale = 1;
  o->kind = kKindOther;
  switch (op->kind) {
    case EXARMO_AARCH64_OPERAND_REG: {
      const exarmo_aarch64_reg_operand* v = &op->reg;
      if (v->modifier.present && v->modifier.kind == EXARMO_AARCH64_MOD_MUL)
        return;
      o->kind = kKindRegister;
      o->reg = ExarmoRegister(kArchArm64, v->reg.class_, v->reg.num);
      o->size = Width64(v->reg.class_);
      o->shift =
          Shift64(v->modifier.present, v->modifier.kind, v->modifier.amount);
      o->shift_value = ShiftAmount(v->modifier.present, v->modifier.amount);
      o->extend = Extend64(v->modifier.present, v->modifier.kind);
      o->zeroing = v->predication == 0x7a;
      o->element_bits = v->arrangement.element;
      o->lanes = v->arrangement.lanes;
      return;
    }
    case EXARMO_AARCH64_OPERAND_IMM: {
      const exarmo_aarch64_modifier* m = &op->imm.modifier;
      if (m->present && m->kind == EXARMO_AARCH64_MOD_MUL) return;
      o->kind = kKindImmediate;
      o->immediate = op->imm.value;
      o->shift = Shift64(m->present, m->kind, m->amount);
      o->shift_value = ShiftAmount(m->present, m->amount);
      o->extend = Extend64(m->present, m->kind);
      return;
    }
    case EXARMO_AARCH64_OPERAND_LABEL: {
      const exarmo_aarch64_label* l = &op->label;
      o->kind = kKindImmediate;
      o->immediate =
          (int64_t)((address + l->pc_ahead) & ~((uint64_t)l->pc_align - 1)) +
          l->offset;
      return;
    }
    case EXARMO_AARCH64_OPERAND_MEM: {
      const exarmo_aarch64_mem* m = &op->mem;
      const exarmo_aarch64_offset* off = &m->offset;
      if (off->mul_vl ||
          (off->modifier.present && off->modifier.kind == EXARMO_AARCH64_MOD_MUL))
        return;
      const bool has_index = off->kind == EXARMO_AARCH64_OFFSET_REG ||
                             off->kind == EXARMO_AARCH64_OFFSET_VECTOR;
      o->kind = kKindMemory;
      o->base = ExarmoRegister(kArchArm64, m->base.class_, m->base.num);
      o->index =
          has_index ? ExarmoRegister(kArchArm64, off->reg.class_, off->reg.num)
                    : 0;
      o->displacement = off->kind == EXARMO_AARCH64_OFFSET_IMM ? off->imm : 0;
      o->shift = Shift64(off->modifier.present, off->modifier.kind,
                         off->modifier.amount);
      o->shift_value =
          ShiftAmount(off->modifier.present, off->modifier.amount);
      o->extend = Extend64(off->modifier.present, off->modifier.kind);
      o->element_bits = off->arrangement.element;
      o->lanes = off->arrangement.lanes;
      return;
    }
    default: return;
  }
}

enum {
  kArm64MaxWrites = 8,
  kArm64MaxRegisters = 2 * EXARMO_AARCH64_MAX_OPERANDS + kArm64MaxWrites,
};

static int64_t Arm64Written(const Aarch64Write* write, uint32_t word) {
  if (write->kind == kWriteFixed)
    return ExarmoRegister(kArchArm64, write->register_class, write->number);
  const int value = (int)((word >> write->lsb) & ((1u << write->width) - 1));
  if (write->kind == kWriteStackPointer)
    return value == 31
               ? ExarmoRegister(kArchArm64, EXARMO_AARCH64_REG_X_SP, 31)
               : 0;
  if (write->register_class == EXARMO_AARCH64_REG_X && value == 31) return 0;
  return ExarmoRegister(kArchArm64, write->register_class,
                        value + write->number);
}

// W5 in an operand and X5 in the table are one register, and so are the
// views B5 to Q5 and Z5 of one vector, so registers compare by storage
static int64_t Arm64Storage(int64_t reg) {
  const int reg_class = (int)(reg >> 8 & 0xff);
  const int number = (int)(reg & 0xff);
  switch (reg_class) {
    case EXARMO_AARCH64_REG_W:
    case EXARMO_AARCH64_REG_X: return number == 31 ? -1 : number;
    case EXARMO_AARCH64_REG_W_SP:
    case EXARMO_AARCH64_REG_X_SP: return number == 31 ? 0x100 : number;
    case EXARMO_AARCH64_REG_B:
    case EXARMO_AARCH64_REG_H:
    case EXARMO_AARCH64_REG_S:
    case EXARMO_AARCH64_REG_D:
    case EXARMO_AARCH64_REG_Q:
    case EXARMO_AARCH64_REG_V:
    case EXARMO_AARCH64_REG_Z: return 0x200 | number;
    case EXARMO_AARCH64_REG_P:
    case EXARMO_AARCH64_REG_PN: return 0x300 | number;
    default: return reg;
  }
}

static int Arm64WrittenIndex(const int64_t* written, int count, int64_t reg) {
  if (reg == 0) return -1;
  const int64_t storage = Arm64Storage(reg);
  for (int i = 0; i < count; i++)
    if (Arm64Storage(written[i]) == storage) return i;
  return -1;
}

static uint32_t Le32(const uint8_t* p) {
  return (uint32_t)p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 |
         (uint32_t)p[3] << 24;
}

enum { kFlowUnknown = 0xff };

static bool Arm64Probe(uint32_t word, exarmo_aarch64_instruction* ins) {
  const uint8_t bytes[4] = {(uint8_t)(word & 0xff), (uint8_t)((word >> 8) & 0xff),
                            (uint8_t)((word >> 16) & 0xff),
                            (uint8_t)(word >> 24)};
  return exarmo_aarch64_decode_bytes(bytes, 4, ins) == EXARMO_AARCH64_STATUS_OK;
}

// exarmo has no table of branch kinds, so the flow of an encoding comes from
// decoding its fixed bits with the open bits zero, all one or alternating:
// 388 of 4665 patterns are unallocated with zeros, 28 with all three words
static void Arm64ProbeFlows(Selection* s) {
  for (int e = 0; e < EXARMO_AARCH64_ENCODING_COUNT; e++) {
    s->flow_of[e] = kFlowUnknown;
    const Aarch64Pattern* p = &kAarch64Patterns[e];
    if (p->mask == 0) continue;
    const uint32_t words[3] = {p->value, p->value | ~p->mask,
                               p->value | (~p->mask & 0x55555555u)};
    exarmo_aarch64_instruction ins;
    for (int w = 0; w < 3; w++) {
      if (!Arm64Probe(words[w], &ins)) continue;
      const exarmo_aarch64_branch branch =
          exarmo_aarch64_instruction_branch(&ins, 0);
      s->flow_of[e] = (uint8_t)ExarmoFlow64(branch.kind);
      break;
    }
  }
  s->probed = true;
}

// An encoding whose probe words are all unallocated has no known flow and is
// tested by its pattern whenever a flow is selected, since it may be a branch;
// an encoding without a pattern is reached by a flow selection only by its id
static bool Arm64Wanted(const Selection* s, uint32_t flows, int e) {
  if (SelectedId(s, e)) return true;
  if (flows == 0 || kAarch64Patterns[e].mask == 0) return false;
  return s->flow_of[e] == kFlowUnknown || Stops(flows, s->flow_of[e], true);
}

static bool Arm64InBucket(const Aarch64Pattern* p, uint32_t bucket) {
  const uint32_t top = ~0u << kBucketShift;
  return ((bucket << kBucketShift) & p->mask & top) == (p->value & top);
}

static void Arm64FreePrefilter(Arm64Prefilter* f) {
  free(f->start);
  free(f->members);
  f->start = NULL;
  f->members = NULL;
}

static void Arm64Build(Selection* s, uint32_t flows) {
  Arm64Prefilter* f = &s->prefilter;
  Arm64FreePrefilter(f);
  f->built = true;
  f->flows = flows;
  f->usable = false;
  uint32_t* start = calloc(kBuckets + 1, sizeof(uint32_t));
  uint32_t* fill = calloc(kBuckets, sizeof(uint32_t));
  if (start == NULL || fill == NULL) {
    free(start);
    free(fill);
    return;
  }
  uint64_t total = 0;
  for (int e = 0; e < EXARMO_AARCH64_ENCODING_COUNT; e++) {
    if (!Arm64Wanted(s, flows, e)) continue;
    if (kAarch64Patterns[e].mask == 0) {
      free(start);
      free(fill);
      return;
    }
    for (uint32_t b = 0; b < kBuckets; b++)
      if (Arm64InBucket(&kAarch64Patterns[e], b)) {
        start[b + 1]++;
        total++;
      }
  }
  for (uint32_t b = 1; b <= kBuckets; b++) start[b] += start[b - 1];
  uint16_t* members = malloc((total + 1) * sizeof(uint16_t));
  if (members == NULL) {
    free(start);
    free(fill);
    return;
  }
  for (int e = 0; e < EXARMO_AARCH64_ENCODING_COUNT; e++) {
    if (!Arm64Wanted(s, flows, e)) continue;
    for (uint32_t b = 0; b < kBuckets; b++)
      if (Arm64InBucket(&kAarch64Patterns[e], b))
        members[start[b] + fill[b]++] = (uint16_t)e;
  }
  free(fill);
  f->start = start;
  f->members = members;
  f->usable = true;
}

// Skipping by pattern leaves invalid words undecoded, so a stop on invalid
// input decodes every word instead
static const Arm64Prefilter* Arm64PrefilterFor(Context* c, uint32_t stop) {
  Selection* s = c->selection;
  if (s == NULL || !s->skip_others ||
      (stop & DISASSEMBLER_STOP_INVALID) != 0)
    return NULL;
  const uint32_t flows = (s->flows | stop) & kFlowBits;
  if (!s->prefilter.built || s->prefilter.flows != flows) Arm64Build(s, flows);
  return s->prefilter.usable ? &s->prefilter : NULL;
}

static bool Arm64Candidate(const Arm64Prefilter* f, uint32_t word) {
  const uint32_t bucket = word >> kBucketShift;
  for (uint32_t m = f->start[bucket]; m < f->start[bucket + 1]; m++) {
    const Aarch64Pattern* p = &kAarch64Patterns[f->members[m]];
    if ((word & p->mask) == p->value) return true;
  }
  return false;
}

typedef struct Arm64Full {
  exarmo_aarch64_operand ops[EXARMO_AARCH64_MAX_OPERANDS];
  size_t count;
  const Aarch64Effect* effect;
  bool known;
  int64_t written[kArm64MaxWrites];
  int written_count;
  int64_t read[2 * EXARMO_AARCH64_MAX_OPERANDS];
  int read_count;
} Arm64Full;

static void Arm64Head(const exarmo_aarch64_instruction* ins, uint64_t pc,
                      uint8_t size, Record* r) {
  r->size = size;
  const int encoding = exarmo_aarch64_instruction_encoding(ins);
  r->id = encoding;
  r->mnemonic = exarmo_aarch64_instruction_mnemonic(ins);
  r->canonical = exarmo_aarch64_encoding_mnemonic(encoding);
  if (!exarmo_aarch64_instruction_unpredictable(ins)) r->flags |= kFlagValid;
  const exarmo_aarch64_branch branch =
      exarmo_aarch64_instruction_branch(ins, pc);
  r->flow = ExarmoFlow64(branch.kind);
  if (branch.conditional) r->flags |= kFlagConditional;
}

static int32_t Arm64Writes(uint32_t word, Arm64Full* f) {
  const Aarch64Effect* effect = f->effect;
  for (int k = effect->write_start;
       k < effect->write_start + effect->write_count; k++) {
    const int64_t reg = Arm64Written(&kAarch64Writes[k], word);
    if (reg == 0 || Arm64WrittenIndex(f->written, f->written_count, reg) >= 0)
      continue;
    if (f->written_count == kArm64MaxWrites) return DISASSEMBLER_STATUS_FAILED;
    f->written[f->written_count++] = reg;
  }
  return DISASSEMBLER_STATUS_OK;
}

static void Arm64Operand(const exarmo_aarch64_operand* op, uint64_t pc,
                         Arm64Full* f, Record* r, disassembler_batch* batch) {
  if (op->kind == EXARMO_AARCH64_OPERAND_MEM) {
    if (op->mem.writeback != EXARMO_AARCH64_WRITEBACK_NONE)
      r->flags |= kFlagWriteback;
    if (op->mem.writeback == EXARMO_AARCH64_WRITEBACK_POST)
      r->flags |= kFlagPostIndex;
  }
  Operand o;
  Operand64(op, pc, &o);
  if (f->known && o.kind == kKindRegister) {
    o.has_access = true;
    const int index = Arm64WrittenIndex(f->written, f->written_count, o.reg);
    o.access = index >= 0 ? 2 : 1;
    if (index >= 0) f->written[index] = o.reg;
    if (o.access == 1 && o.reg != 0) f->read[f->read_count++] = o.reg;
  } else if (f->known && o.kind == kKindMemory) {
    o.has_access = true;
    o.access = ((f->effect->flags & kEffectReadsMemory) != 0 ? 1 : 0) |
               ((f->effect->flags & kEffectWritesMemory) != 0 ? 2 : 0);
    if (o.base != 0) f->read[f->read_count++] = o.base;
    if (o.index != 0) f->read[f->read_count++] = o.index;
  }
  WriteOperand(batch, &o);
  r->operand_count++;
}

static int32_t Arm64Body(const exarmo_aarch64_instruction* ins,
                         const uint8_t* bytes, uint64_t pc, Record* r,
                         disassembler_batch* batch) {
  r->flags |= kFlagWritesFlagsKnown;
  if (exarmo_aarch64_instruction_flags(ins).writes != 0)
    r->flags |= kFlagWritesFlags;
  Arm64Full f;
  f.count = exarmo_aarch64_instruction_operands(ins, f.ops,
                                                EXARMO_AARCH64_MAX_OPERANDS);
  if (f.count > EXARMO_AARCH64_MAX_OPERANDS) return DISASSEMBLER_STATUS_FAILED;
  static const Aarch64Effect none = {0, 0, 0};
  f.effect = r->id < EXARMO_AARCH64_ENCODING_COUNT ? &kAarch64Effects[r->id]
                                                   : &none;
  f.known = (f.effect->flags & kEffectKnown) != 0;
  f.written_count = 0;
  f.read_count = 0;
  if (f.known) {
    if (Arm64Writes(Le32(bytes), &f) != DISASSEMBLER_STATUS_OK)
      return DISASSEMBLER_STATUS_FAILED;
    r->flags |= kFlagRegisterAccess;
  }
  bool has_condition = false;
  for (size_t i = 0; i < f.count; i++) {
    const exarmo_aarch64_operand* op = &f.ops[i];
    if (!has_condition && op->kind == EXARMO_AARCH64_OPERAND_COND) {
      has_condition = true;
      r->condition = op->cond < 14 ? op->cond + 1 : 0;
    }
    Arm64Operand(op, pc, &f, r, batch);
  }
  for (int i = 0; i < f.read_count; i++)
    batch->registers[batch->register_count + r->read_count++] =
        (uint32_t)f.read[i];
  for (int i = 0; i < f.written_count; i++)
    batch->registers[batch->register_count + r->read_count +
                     r->written_count++] = (uint32_t)f.written[i];
  batch->register_count += r->read_count + r->written_count;
  return DISASSEMBLER_STATUS_OK;
}

static int32_t DecodeArm64(Context* c, const uint8_t* bytes, int64_t length,
                           uint64_t address, int32_t limit, uint32_t stop,
                           disassembler_batch* batch) {
  const Selection* s = c->selection;
  const Arm64Prefilter* filter = Arm64PrefilterFor(c, stop);
  exarmo_aarch64_instruction ins;
  int64_t at = 0;
  while (at < length && HasRoom(batch, limit, EXARMO_AARCH64_MAX_OPERANDS,
                                kArm64MaxRegisters)) {
    const uint64_t pc = address + (uint64_t)at;
    if (filter != NULL && length - at >= 4 &&
        !Arm64Candidate(filter, Le32(bytes + at))) {
      at += 4;
      continue;
    }
    const exarmo_aarch64_status status =
        exarmo_aarch64_decode_bytes(bytes + at, (size_t)(length - at), &ins);
    if (status != EXARMO_AARCH64_STATUS_OK) {
      const int64_t remaining = length - at;
      const uint32_t size = remaining < 4 ? (uint32_t)remaining : 4;
      if (Written(s, false, stop, kFlowNone, false))
        InvalidExarmo(batch, pc, size, status);
      at += size;
      if (Stops(stop, kFlowNone, false)) break;
      continue;
    }
    const uint8_t size = exarmo_aarch64_instruction_length(&ins);
    if (size < 1 || size > length - at) return DISASSEMBLER_STATUS_FAILED;
    Record r;
    InitRecord(&r, batch, pc);
    Arm64Head(&ins, pc, size, &r);
    const bool selected = Selected(s, r.id, r.flow);
    if (!selected)
      r.flags |= kFlagBrief;
    else if (Arm64Body(&ins, bytes + at, pc, &r, batch) != DISASSEMBLER_STATUS_OK)
      return DISASSEMBLER_STATUS_FAILED;
    if (Written(s, selected, stop, r.flow, (r.flags & kFlagValid) != 0))
      WriteRecord(batch, &r);
    at += size;
    if (Stops(stop, r.flow, (r.flags & kFlagValid) != 0)) break;
  }
  batch->consumed = at;
  return DISASSEMBLER_STATUS_OK;
}

#endif

#if defined(DISASSEMBLER_EXARMO_ARM)

static int ExarmoFlow32(int kind) {
  switch (kind) {
    case EXARMO_AARCH32_BRANCH_DIRECT:
    case EXARMO_AARCH32_BRANCH_INDIRECT: return kFlowJump;
    case EXARMO_AARCH32_BRANCH_DIRECT_CALL:
    case EXARMO_AARCH32_BRANCH_INDIRECT_CALL: return kFlowCall;
    case EXARMO_AARCH32_BRANCH_RETURN:
    case EXARMO_AARCH32_BRANCH_EXCEPTION_RETURN: return kFlowReturn;
    case EXARMO_AARCH32_BRANCH_SYSTEM_CALL:
    case EXARMO_AARCH32_BRANCH_EXCEPTION:
    case EXARMO_AARCH32_BRANCH_HALT: return kFlowInterrupt;
    default: return kFlowNone;
  }
}

static int Shift32(bool present, int kind) {
  if (!present) return kShiftNone;
  switch (kind) {
    case EXARMO_AARCH32_MOD_LSL: return kShiftLsl;
    case EXARMO_AARCH32_MOD_LSR: return kShiftLsr;
    case EXARMO_AARCH32_MOD_ASR: return kShiftAsr;
    case EXARMO_AARCH32_MOD_ROR: return kShiftRor;
    default: return kShiftNone;
  }
}

static int Width32(int reg_class) {
  switch (reg_class) {
    case EXARMO_AARCH32_REG_CORE:
    case EXARMO_AARCH32_REG_S: return 4;
    case EXARMO_AARCH32_REG_D: return 8;
    case EXARMO_AARCH32_REG_Q: return 16;
    default: return 0;
  }
}

static int64_t ShiftAmount32(bool present, int amount) {
  return present && amount != -1 ? amount : 0;
}

static void Operand32(const exarmo_aarch32_operand* op, uint64_t address,
                      Operand* o) {
  memset(o, 0, sizeof(*o));
  o->scale = 1;
  o->kind = kKindOther;
  switch (op->kind) {
    case EXARMO_AARCH32_OPERAND_REG: {
      const exarmo_aarch32_reg_operand* v = &op->reg;
      if (v->modifier.has_by ||
          (v->modifier.present && v->modifier.kind == EXARMO_AARCH32_MOD_RRX))
        return;
      o->kind = kKindRegister;
      o->reg = ExarmoRegister(kArchArm, v->reg.class_, v->reg.num);
      o->size = Width32(v->reg.class_);
      o->shift = Shift32(v->modifier.present, v->modifier.kind);
      o->shift_value = ShiftAmount32(v->modifier.present, v->modifier.amount);
      return;
    }
    case EXARMO_AARCH32_OPERAND_IMM: {
      const exarmo_aarch32_modifier* m = &op->imm.modifier;
      o->kind = kKindImmediate;
      o->immediate = op->imm.value;
      o->shift = Shift32(m->present, m->kind);
      o->shift_value = ShiftAmount32(m->present, m->amount);
      return;
    }
    case EXARMO_AARCH32_OPERAND_LABEL: {
      const exarmo_aarch32_label* l = &op->label;
      o->kind = kKindImmediate;
      o->immediate =
          ((int64_t)((address + l->pc_ahead) & ~((uint64_t)l->pc_align - 1)) +
           l->offset) &
          0xffffffff;
      return;
    }
    case EXARMO_AARCH32_OPERAND_MEM: {
      const exarmo_aarch32_mem* m = &op->mem;
      const exarmo_aarch32_offset* off = &m->offset;
      if (off->modifier.has_by ||
          (off->modifier.present && off->modifier.kind == EXARMO_AARCH32_MOD_RRX))
        return;
      o->kind = kKindMemory;
      o->base = ExarmoRegister(kArchArm, m->base.class_, m->base.num);
      o->index = off->kind == EXARMO_AARCH32_OFFSET_REG
                     ? ExarmoRegister(kArchArm, off->reg.class_, off->reg.num)
                     : 0;
      o->scale = off->subtract ? -1 : 1;
      o->displacement = off->kind == EXARMO_AARCH32_OFFSET_IMM ? off->imm : 0;
      o->shift = Shift32(off->modifier.present, off->modifier.kind);
      o->shift_value =
          ShiftAmount32(off->modifier.present, off->modifier.amount);
      return;
    }
    default: return;
  }
}

static int32_t DecodeArm32(Context* c, const uint8_t* bytes, int64_t length,
                           uint64_t address, int32_t limit, uint32_t stop,
                           bool resume, disassembler_batch* batch) {
  const bool thumb = c->architecture == kArchThumb;
  if (!resume) {
    c->it.kind = EXARMO_AARCH32_IT_OUTSIDE;
    c->it.cond = 0;
    c->it.mask = 0;
  }
  exarmo_aarch32_instruction ins;
  exarmo_aarch32_operand ops[EXARMO_AARCH32_MAX_OPERANDS];
  int64_t at = 0;
  while (at < length && HasRoom(batch, limit, EXARMO_AARCH32_MAX_OPERANDS, 0)) {
    const uint64_t pc = address + (uint64_t)at;
    const exarmo_aarch32_it_state before = c->it;
    const exarmo_aarch32_status status =
        thumb ? exarmo_aarch32_decode_t32_bytes(
                    bytes + at, (size_t)(length - at), c->it, &ins)
              : exarmo_aarch32_decode_a32_bytes(bytes + at,
                                                (size_t)(length - at), &ins);
    if (status != EXARMO_AARCH32_STATUS_OK) {
      const int unit = thumb ? 2 : 4;
      const int64_t remaining = length - at;
      const uint32_t size =
          remaining < unit ? (uint32_t)remaining : (uint32_t)unit;
      InvalidExarmo(batch, pc, size, status);
      c->it.kind = EXARMO_AARCH32_IT_OUTSIDE;
      c->it.cond = 0;
      c->it.mask = 0;
      at += size;
      if (Stops(stop, kFlowNone, false)) break;
      continue;
    }
    const uint8_t size = exarmo_aarch32_instruction_length(&ins);
    if (size < 1 || size > length - at) return DISASSEMBLER_STATUS_FAILED;
    Record r;
    InitRecord(&r, batch, pc);
    r.size = size;
    const int encoding = exarmo_aarch32_instruction_encoding(&ins);
    r.id = encoding;
    r.mnemonic = exarmo_aarch32_instruction_mnemonic(&ins);
    r.canonical = exarmo_aarch32_encoding_mnemonic(encoding);
    r.extra = (int64_t)before.kind | (int64_t)before.cond << 8 |
              (int64_t)before.mask << 16;
    if (!exarmo_aarch32_instruction_unpredictable(&ins)) r.flags |= kFlagValid;
    r.flags |= kFlagWritesFlagsKnown;
    if (exarmo_aarch32_instruction_flags(&ins).writes != 0)
      r.flags |= kFlagWritesFlags;
    const exarmo_aarch32_branch branch =
        exarmo_aarch32_instruction_branch(&ins, pc);
    r.flow = ExarmoFlow32(branch.kind);
    const size_t count = exarmo_aarch32_instruction_operands(
        &ins, ops, EXARMO_AARCH32_MAX_OPERANDS);
    if (count > EXARMO_AARCH32_MAX_OPERANDS) return DISASSEMBLER_STATUS_FAILED;
    bool has_condition = false;
    for (size_t i = 0; i < count; i++) {
      const exarmo_aarch32_operand* op = &ops[i];
      if (!has_condition && op->kind == EXARMO_AARCH32_OPERAND_COND) {
        has_condition = true;
        r.condition = op->cond < 14 ? op->cond + 1 : 0;
      }
      if (op->kind == EXARMO_AARCH32_OPERAND_MEM) {
        if (op->mem.writeback != EXARMO_AARCH32_WRITEBACK_NONE)
          r.flags |= kFlagWriteback;
        if (op->mem.writeback == EXARMO_AARCH32_WRITEBACK_POST)
          r.flags |= kFlagPostIndex;
      } else if (op->kind == EXARMO_AARCH32_OPERAND_REG && op->reg.writeback) {
        r.flags |= kFlagWriteback;
      }
      Operand o;
      Operand32(op, pc, &o);
      WriteOperand(batch, &o);
      r.operand_count++;
    }
    if (branch.conditional || r.condition != 0) r.flags |= kFlagConditional;
    WriteRecord(batch, &r);
    at += size;
    if (thumb) c->it = exarmo_aarch32_it_state_after(c->it, &ins);
    if (Stops(stop, r.flow, (r.flags & kFlagValid) != 0)) break;
  }
  batch->consumed = at;
  return DISASSEMBLER_STATUS_OK;
}

#endif

#if defined(DISASSEMBLER_CAPSTONE)

static int RegisterSize(const char* name) {
  if (name == NULL) return 0;
  if (strcmp(name, "sp") == 0 || strcmp(name, "xzr") == 0 || name[0] == 'x')
    return 8;
  if (strcmp(name, "wsp") == 0 || strcmp(name, "wzr") == 0 || name[0] == 'w')
    return 4;
  if (name[0] == 'q' || name[0] == 'v') return 16;
  if (name[0] == 'd') return 8;
  if (name[0] == 's') return 4;
  if (name[0] == 'h') return 2;
  if (name[0] == 'b') return 1;
  if (name[0] == 'r' || strcmp(name, "lr") == 0 || strcmp(name, "pc") == 0)
    return 4;
  return 0;
}

static bool NameIs(const char* name, const char* expected) {
  if (name == NULL) return false;
  for (; *name && *expected; name++, expected++) {
    if (tolower((unsigned char)*name) != *expected) return false;
  }
  return *name == 0 && *expected == 0;
}

static int64_t InternMnemonic(Context* c, const char* text) {
  char lower[32];
  int n = 0;
  for (; n < 31 && text[n]; n++) lower[n] = (char)tolower((unsigned char)text[n]);
  lower[n] = 0;
  for (int32_t i = 0; i < c->mnemonic_count; i++) {
    if (strcmp(c->mnemonics[i], lower) == 0) return i;
  }
  if (c->mnemonic_count == c->mnemonic_capacity) {
    const int32_t capacity = c->mnemonic_capacity ? c->mnemonic_capacity * 2 : 256;
    char(*grown)[32] = realloc(c->mnemonics, (size_t)capacity * 32);
    if (grown == NULL) return -1;
    c->mnemonics = grown;
    c->mnemonic_capacity = capacity;
  }
  memcpy(c->mnemonics[c->mnemonic_count], lower, 32);
  return c->mnemonic_count++;
}

static int CapstoneFlow(const cs_detail* detail) {
  for (int i = 0; i < detail->groups_count; i++) {
    switch (detail->groups[i]) {
      case CS_GRP_CALL: return kFlowCall;
      case CS_GRP_RET:
      case CS_GRP_IRET: return kFlowReturn;
      case CS_GRP_JUMP: return kFlowJump;
      case CS_GRP_INT: return kFlowInterrupt;
      default: break;
    }
  }
  return kFlowNone;
}

static int Aarch64Shift(int value) {
  switch (value) {
    case AARCH64_SFT_LSL: return kShiftLsl;
    case AARCH64_SFT_LSR: return kShiftLsr;
    case AARCH64_SFT_ASR: return kShiftAsr;
    case AARCH64_SFT_ROR: return kShiftRor;
    case AARCH64_SFT_MSL: return kShiftMsl;
    default: return kShiftNone;
  }
}

static int Aarch64Extend(int value) {
  switch (value) {
    case AARCH64_EXT_UXTB: return kExtendUxtb;
    case AARCH64_EXT_UXTH: return kExtendUxth;
    case AARCH64_EXT_UXTW: return kExtendUxtw;
    case AARCH64_EXT_UXTX: return kExtendUxtx;
    case AARCH64_EXT_SXTB: return kExtendSxtb;
    case AARCH64_EXT_SXTH: return kExtendSxth;
    case AARCH64_EXT_SXTW: return kExtendSxtw;
    case AARCH64_EXT_SXTX: return kExtendSxtx;
    default: return kExtendNone;
  }
}

static int ArmShift(int value) {
  switch (value) {
    case ARM_SFT_LSL: return kShiftLsl;
    case ARM_SFT_LSR: return kShiftLsr;
    case ARM_SFT_ASR: return kShiftAsr;
    case ARM_SFT_ROR: return kShiftRor;
    default: return kShiftNone;
  }
}

static int CapstoneOperands(Context* c, const cs_detail* detail,
                            disassembler_batch* batch) {
  int count = 0;
  Operand o;
  switch (c->architecture) {
    case kArchX86:
    case kArchX64:
      for (int i = 0; i < detail->x86.op_count; i++) {
        const cs_x86_op* op = &detail->x86.operands[i];
        memset(&o, 0, sizeof(o));
        o.scale = 1;
        switch (op->type) {
          case X86_OP_REG: o.kind = kKindRegister; break;
          case X86_OP_IMM: o.kind = kKindImmediate; break;
          case X86_OP_MEM: o.kind = kKindMemory; break;
          default: o.kind = kKindOther; break;
        }
        if (o.kind == kKindRegister) o.reg = op->reg;
        if (o.kind == kKindImmediate) o.immediate = op->imm;
        o.size = op->size;
        o.has_access = true;
        o.access = op->access;
        o.zeroing = op->avx_zero_opmask;
        o.broadcast = op->avx_bcast > 0 ? 1 << op->avx_bcast : 0;
        if (o.kind == kKindMemory) {
          o.base = op->mem.base;
          o.index = op->mem.index;
          o.segment = op->mem.segment;
          o.scale = op->mem.scale;
          o.displacement = op->mem.disp;
        }
        WriteOperand(batch, &o);
        count++;
      }
      break;
    case kArchArm64:
      for (int i = 0; i < detail->aarch64.op_count; i++) {
        const cs_aarch64_op* op = &detail->aarch64.operands[i];
        memset(&o, 0, sizeof(o));
        o.scale = 1;
        switch (op->type) {
          case AARCH64_OP_REG:
          case AARCH64_OP_MEM_REG: o.kind = kKindRegister; break;
          case AARCH64_OP_IMM:
          case AARCH64_OP_MEM_IMM: o.kind = kKindImmediate; break;
          case AARCH64_OP_MEM: o.kind = kKindMemory; break;
          default: o.kind = kKindOther; break;
        }
        if (o.kind == kKindRegister) o.reg = op->reg;
        if (o.kind == kKindImmediate) o.immediate = op->imm;
        o.size = RegisterSize(o.reg ? cs_reg_name(c->capstone, (unsigned)o.reg)
                                    : NULL);
        o.has_access = true;
        o.access = op->access;
        o.shift = Aarch64Shift(op->shift.type);
        o.shift_value = op->shift.value;
        o.extend = Aarch64Extend(op->ext);
        if (o.kind == kKindMemory) {
          o.base = op->mem.base;
          o.index = op->mem.index;
          o.displacement = op->mem.disp;
          o.absolute = op->mem.base == 0 && op->mem.index == 0;
        }
        WriteOperand(batch, &o);
        count++;
      }
      break;
    default:
      for (int i = 0; i < detail->arm.op_count; i++) {
        const cs_arm_op* op = &detail->arm.operands[i];
        memset(&o, 0, sizeof(o));
        o.scale = 1;
        switch (op->type) {
          case ARM_OP_REG: o.kind = kKindRegister; break;
          case ARM_OP_IMM: o.kind = kKindImmediate; break;
          case ARM_OP_MEM: o.kind = kKindMemory; break;
          default: o.kind = kKindOther; break;
        }
        if (o.kind == kKindRegister) {
          o.reg = op->reg;
          const char* name = cs_reg_name(c->capstone, (unsigned)op->reg);
          o.size = name != NULL && strcmp(name, "sp") == 0 ? 4
                                                           : RegisterSize(name);
        }
        if (o.kind == kKindImmediate) o.immediate = op->imm;
        o.has_access = true;
        o.access = op->access;
        o.shift = ArmShift(op->shift.type);
        o.shift_value = op->shift.value;
        if (o.kind == kKindMemory) {
          o.base = op->mem.base;
          o.index = op->mem.index;
          o.scale = op->mem.scale;
          o.displacement = op->mem.disp;
        }
        WriteOperand(batch, &o);
        count++;
      }
      break;
  }
  return count;
}

static int32_t DecodeCapstone(Context* c, const uint8_t* bytes, int64_t length,
                              uint64_t address, int32_t limit, uint32_t stop,
                              disassembler_batch* batch) {
  const uint8_t* cursor = bytes;
  size_t remaining = (size_t)length;
  uint64_t position = address;
  while (remaining > 0 && HasRoom(batch, limit, 48, 128)) {
    const uint64_t start = position;
    const size_t before = remaining;
    const bool decoded =
        cs_disasm_iter(c->capstone, &cursor, &remaining, &position, c->insn);
    Record r;
    if (!decoded) {
      const cs_err error = cs_errno(c->capstone);
      if (error != CS_ERR_OK) return DISASSEMBLER_STATUS_FAILED;
      InitRecord(&r, batch, start);
      r.size = (uint32_t)before;
      WriteRecord(batch, &r);
      remaining = 0;
      break;
    }
    const cs_insn* ins = c->insn;
    InitRecord(&r, batch, ins->address);
    r.size = ins->size;
    r.id = ins->id;
    r.mnemonic = InternMnemonic(c, ins->mnemonic);
    r.canonical = ins->id;
    const cs_detail* detail = ins->id != 0 ? ins->detail : NULL;
    if (ins->id != 0) r.flags |= kFlagValid;
    if (detail != NULL) {
      r.flow = CapstoneFlow(detail);
      r.operand_count = CapstoneOperands(c, detail, batch);
      cs_regs read;
      cs_regs written;
      uint8_t read_count = 0;
      uint8_t written_count = 0;
      const cs_err access = cs_regs_access(c->capstone, ins, read, &read_count,
                                           written, &written_count);
      if (access == CS_ERR_OK) {
        r.flags |= kFlagRegisterAccess | kFlagWritesFlagsKnown;
        for (int i = 0; i < read_count; i++)
          batch->registers[batch->register_count + r.read_count++] = read[i];
        for (int i = 0; i < written_count; i++) {
          batch->registers[batch->register_count + r.read_count +
                           r.written_count++] = written[i];
          const char* name = cs_reg_name(c->capstone, written[i]);
          if (NameIs(name, "eflags") || NameIs(name, "rflags") ||
              NameIs(name, "nzcv") || NameIs(name, "cpsr"))
            r.flags |= kFlagWritesFlags;
        }
        batch->register_count += r.read_count + r.written_count;
      } else if (access != CS_ERR_ARCH) {
        return DISASSEMBLER_STATUS_FAILED;
      }
      const char* name = cs_insn_name(c->capstone, ins->id);
      if (c->architecture == kArchArm64) {
        r.condition = ArmConditionCode(detail->aarch64.cc);
        if (detail->aarch64.post_index) r.flags |= kFlagPostIndex;
      } else if (c->architecture == kArchArm ||
                 c->architecture == kArchThumb) {
        r.condition = ArmConditionCode(detail->arm.cc);
        if (detail->arm.post_index) r.flags |= kFlagPostIndex;
      } else {
        if (r.flow == kFlowJump && !NameIs(name, "jmp"))
          r.condition = kConditionMnemonic;
        r.immediate_size = detail->x86.encoding.imm_size;
        for (int i = 0; i < detail->groups_count; i++) {
          if (detail->groups[i] == X86_GRP_AVX ||
              detail->groups[i] == X86_GRP_AVX2 ||
              detail->groups[i] == X86_GRP_AVX512)
            r.flags |= kFlagVector;
        }
      }
      if (r.condition != 0 || NameIs(name, "cbz") || NameIs(name, "cbnz") ||
          NameIs(name, "tbz") || NameIs(name, "tbnz"))
        r.flags |= kFlagConditional;
      if (detail->writeback) r.flags |= kFlagWriteback;
    }
    WriteRecord(batch, &r);
    if (Stops(stop, r.flow, (r.flags & kFlagValid) != 0)) break;
  }
  batch->consumed = length - (int64_t)remaining;
  return DISASSEMBLER_STATUS_OK;
}

#endif

void* disassembler_open(int32_t backend, int32_t architecture) {
  Context* c = calloc(1, sizeof(Context));
  if (c == NULL) return NULL;
  c->backend = backend;
  c->architecture = architecture;
  switch (backend) {
#if defined(DISASSEMBLER_ZYDIS)
    case kBackendZydis:
      if (architecture != kArchX86 && architecture != kArchX64) break;
      if (!ZYAN_SUCCESS(ZydisDecoderInit(
              &c->zydis,
              architecture == kArchX64 ? ZYDIS_MACHINE_MODE_LONG_64
                                       : ZYDIS_MACHINE_MODE_LEGACY_32,
              architecture == kArchX64 ? ZYDIS_STACK_WIDTH_64
                                       : ZYDIS_STACK_WIDTH_32)))
        break;
      return c;
#endif
#if defined(DISASSEMBLER_EXARMO_ARM) || defined(DISASSEMBLER_EXARMO_AARCH64)
    case kBackendExarmo:
#if defined(DISASSEMBLER_EXARMO_AARCH64)
      if (architecture == kArchArm64) return c;
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
      if (architecture == kArchArm || architecture == kArchThumb) return c;
#endif
      break;
#endif
#if defined(DISASSEMBLER_CAPSTONE)
    case kBackendCapstone: {
      cs_arch arch;
      int mode = 0;
      switch (architecture) {
        case kArchX86: arch = CS_ARCH_X86; mode = CS_MODE_32; break;
        case kArchX64: arch = CS_ARCH_X86; mode = CS_MODE_64; break;
        case kArchArm: arch = CS_ARCH_ARM; break;
        case kArchThumb: arch = CS_ARCH_ARM; mode = CS_MODE_THUMB; break;
        default: arch = CS_ARCH_AARCH64; break;
      }
      if (cs_open(arch, (cs_mode)mode, &c->capstone) != CS_ERR_OK) break;
      if (cs_option(c->capstone, CS_OPT_DETAIL,
                    CS_OPT_ON | CS_OPT_DETAIL_REAL) != CS_ERR_OK ||
          cs_option(c->capstone, CS_OPT_SKIPDATA, CS_OPT_ON) != CS_ERR_OK) {
        cs_close(&c->capstone);
        break;
      }
      c->insn = cs_malloc(c->capstone);
      if (c->insn == NULL) {
        cs_close(&c->capstone);
        break;
      }
      return c;
    }
#endif
    default: break;
  }
  free(c);
  return NULL;
}

int32_t disassembler_decode(void* context, const uint8_t* bytes,
                            int64_t length, uint64_t address, int32_t limit,
                            uint32_t stop, int32_t resume,
                            disassembler_batch* batch) {
  Context* c = context;
  batch->count = 0;
  batch->operand_count = 0;
  batch->register_count = 0;
  batch->consumed = 0;
  if (limit <= 0 || limit > batch->instruction_capacity)
    limit = batch->instruction_capacity;
  if (length <= 0) return DISASSEMBLER_STATUS_OK;
  int32_t status = DISASSEMBLER_STATUS_UNSUPPORTED;
  switch (c->backend) {
#if defined(DISASSEMBLER_ZYDIS)
    case kBackendZydis:
      status = DecodeZydis(c, bytes, length, address, limit, stop, batch);
      break;
#endif
#if defined(DISASSEMBLER_EXARMO_ARM) || defined(DISASSEMBLER_EXARMO_AARCH64)
    case kBackendExarmo:
#if defined(DISASSEMBLER_EXARMO_AARCH64)
      if (c->architecture == kArchArm64) {
        status = DecodeArm64(c, bytes, length, address, limit, stop, batch);
        break;
      }
#endif
#if defined(DISASSEMBLER_EXARMO_ARM)
      status = DecodeArm32(c, bytes, length, address, limit, stop, resume != 0,
                           batch);
#endif
      break;
#endif
#if defined(DISASSEMBLER_CAPSTONE)
    case kBackendCapstone:
      status = DecodeCapstone(c, bytes, length, address, limit, stop, batch);
      break;
#endif
    default: break;
  }
  (void)resume;
  // A skipping selection consumes a range without a selected instruction and
  // writes nothing, which is not the batch being too small
  if (status == DISASSEMBLER_STATUS_OK && batch->count == 0 &&
      batch->consumed == 0)
    return DISASSEMBLER_STATUS_CAPACITY;
  return status;
}

#if defined(DISASSEMBLER_ZYDIS)
static int64_t ZydisCallTargets(Context* c, const uint8_t* bytes,
                                int64_t length, uint64_t address,
                                uint64_t* targets, int64_t capacity,
                                int64_t* consumed) {
  ZydisDecoderContext context;
  ZydisDecodedInstruction ins;
  ZydisDecodedOperand ops[ZYDIS_MAX_OPERAND_COUNT];
  int64_t count = 0;
  int64_t at = 0;
  while (at < length && count < capacity) {
    int64_t available = length - at;
    if (available > ZYDIS_MAX_INSTRUCTION_LENGTH)
      available = ZYDIS_MAX_INSTRUCTION_LENGTH;
    if (!ZYAN_SUCCESS(ZydisDecoderDecodeInstruction(
            &c->zydis, &context, bytes + at, (ZyanUSize)available, &ins))) {
      at += 1;
      continue;
    }
    if (ZydisFlow(&ins) == kFlowCall &&
        ZYAN_SUCCESS(ZydisDecoderDecodeOperands(&c->zydis, &context, &ins, ops,
                                                ins.operand_count_visible))) {
      bool found = false;
      int64_t target = 0;
      for (int i = 0; i < ins.operand_count_visible; i++) {
        const ZydisDecodedOperand* op = &ops[i];
        if (op->type != ZYDIS_OPERAND_TYPE_IMMEDIATE) continue;
        target = op->imm.is_signed ? op->imm.value.s
                                   : (int64_t)op->imm.value.u;
        if (op->imm.is_relative) {
          target += (int64_t)(address + (uint64_t)at) + ins.length;
          if (c->architecture == kArchX86) target &= 0xffffffff;
        }
        found = true;
      }
      if (found) targets[count++] = (uint64_t)target;
    }
    at += ins.length;
  }
  *consumed = at;
  return count;
}
#endif

#if defined(DISASSEMBLER_EXARMO_AARCH64)
static int64_t Arm64CallTargets(const uint8_t* bytes, int64_t length,
                                uint64_t address, uint64_t* targets,
                                int64_t capacity, int64_t* consumed) {
  exarmo_aarch64_instruction ins;
  int64_t count = 0;
  int64_t at = 0;
  while (at < length && count < capacity) {
    const uint64_t pc = address + (uint64_t)at;
    if (exarmo_aarch64_decode_bytes(bytes + at, (size_t)(length - at), &ins) !=
        EXARMO_AARCH64_STATUS_OK) {
      at += length - at < 4 ? length - at : 4;
      continue;
    }
    const exarmo_aarch64_branch branch =
        exarmo_aarch64_instruction_branch(&ins, pc);
    if (ExarmoFlow64(branch.kind) == kFlowCall && branch.has_target)
      targets[count++] = branch.target;
    at += exarmo_aarch64_instruction_length(&ins);
  }
  *consumed = at;
  return count;
}
#endif

int64_t disassembler_call_targets(void* context, const uint8_t* bytes,
                                  int64_t length, uint64_t address,
                                  uint64_t* targets, int64_t capacity,
                                  int64_t* consumed) {
  Context* c = context;
  *consumed = 0;
  if (length <= 0 || capacity <= 0) return 0;
  switch (c->backend) {
#if defined(DISASSEMBLER_ZYDIS)
    case kBackendZydis:
      return ZydisCallTargets(c, bytes, length, address, targets, capacity,
                              consumed);
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
    case kBackendExarmo:
      if (c->architecture != kArchArm64) break;
      return Arm64CallTargets(bytes, length, address, targets, capacity,
                              consumed);
#endif
    default: break;
  }
  return DISASSEMBLER_STATUS_UNSUPPORTED;
}

const char* disassembler_mnemonic(void* context, int64_t key) {
  Context* c = context;
#if defined(DISASSEMBLER_CAPSTONE)
  if (c->backend == kBackendCapstone && key >= 0 && key < c->mnemonic_count)
    return c->mnemonics[key];
#endif
  (void)c;
  (void)key;
  return NULL;
}

static void FreeSelection(Selection* s) {
  if (s == NULL) return;
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  Arm64FreePrefilter(&s->prefilter);
#endif
  free(s);
}

static bool SupportsSelection(const Context* c) {
#if defined(DISASSEMBLER_ZYDIS)
  if (c->backend == kBackendZydis) return true;
#endif
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  if (c->backend == kBackendExarmo && c->architecture == kArchArm64)
    return true;
#endif
  (void)c;
  return false;
}

int32_t disassembler_select(void* context, uint32_t flows, const uint8_t* ids,
                            int64_t id_bytes, int32_t skip_others) {
  Context* c = context;
  if (c == NULL) return DISASSEMBLER_STATUS_FAILED;
  if (flows == 0 && id_bytes == 0) {
    FreeSelection(c->selection);
    c->selection = NULL;
    return DISASSEMBLER_STATUS_OK;
  }
  if (id_bytes < 0 || id_bytes > kSelectionIdBytes)
    return DISASSEMBLER_STATUS_CAPACITY;
  if (!SupportsSelection(c)) return DISASSEMBLER_STATUS_UNSUPPORTED;
  Selection* s = c->selection;
  if (s == NULL) {
    s = calloc(1, sizeof(Selection));
    if (s == NULL) return DISASSEMBLER_STATUS_FAILED;
    c->selection = s;
  }
  memset(s->ids, 0, sizeof(s->ids));
  if (id_bytes > 0) memcpy(s->ids, ids, (size_t)id_bytes);
  s->flows = flows & kFlowBits;
  s->skip_others = skip_others != 0;
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  s->prefilter.built = false;
  if (c->architecture == kArchArm64 && !s->probed) Arm64ProbeFlows(s);
#endif
  return DISASSEMBLER_STATUS_OK;
}

int32_t disassembler_exarmo_pattern(int32_t encoding, uint32_t* mask,
                                    uint32_t* value) {
#if defined(DISASSEMBLER_EXARMO_AARCH64)
  if (encoding < 0 || encoding >= EXARMO_AARCH64_ENCODING_COUNT)
    return DISASSEMBLER_STATUS_FAILED;
  const Aarch64Pattern* p = &kAarch64Patterns[encoding];
  if (p->mask == 0) return DISASSEMBLER_STATUS_FAILED;
  *mask = p->mask;
  *value = p->value;
  return DISASSEMBLER_STATUS_OK;
#else
  (void)encoding;
  (void)mask;
  (void)value;
  return DISASSEMBLER_STATUS_UNSUPPORTED;
#endif
}

void disassembler_close(void* context) {
  Context* c = context;
  if (c == NULL) return;
#if defined(DISASSEMBLER_CAPSTONE)
  if (c->backend == kBackendCapstone) {
    cs_free(c->insn, 1);
    cs_close(&c->capstone);
    free(c->mnemonics);
  }
#endif
  FreeSelection(c->selection);
  free(c);
}

#if defined(DISASSEMBLER_EXARMO_ARM) || defined(DISASSEMBLER_EXARMO_AARCH64)
#if defined(_MSC_VER)
#define DISASSEMBLER_THREAD_LOCAL __declspec(thread)
#else
#define DISASSEMBLER_THREAD_LOCAL _Thread_local
#endif

// setjmp of Apple and Bionic saves signal mask with 2 system calls, 61% of
// scan time of 20 MB ARM64 DLL, and panic changes no mask to restore
#if defined(__APPLE__) || defined(__ANDROID__)
typedef sigjmp_buf ExarmoJump;
#define DISASSEMBLER_SETJMP(buffer) sigsetjmp(buffer, 0)
#define DISASSEMBLER_LONGJMP(buffer) siglongjmp(buffer, 1)
#else
typedef jmp_buf ExarmoJump;
#define DISASSEMBLER_SETJMP(buffer) setjmp(buffer)
#define DISASSEMBLER_LONGJMP(buffer) longjmp(buffer, 1)
#endif

// exarmo builds without std, so a decoder panic returns here by longjmp, and
// these sit beside disassembler_open because the link hook takes C objects
// from an archive only for symbols that are still undefined
static DISASSEMBLER_THREAD_LOCAL ExarmoJump* exarmo_guard;

bool exarmo_capi_try(void (*body)(void*), void* state) {
  ExarmoJump here;
  ExarmoJump* outer = exarmo_guard;
  exarmo_guard = &here;
  if (DISASSEMBLER_SETJMP(here) != 0) {
    exarmo_guard = outer;
    return false;
  }
  body(state);
  exarmo_guard = outer;
  return true;
}

void exarmo_capi_panic(void) {
  ExarmoJump* target = exarmo_guard;
  if (target == NULL) abort();
  DISASSEMBLER_LONGJMP(*target);
}

uint32_t disassembler_exarmo_guard_probe(bool fail);

DISASSEMBLER_API uint32_t disassembler_exarmo_probe(bool fail) {
  return disassembler_exarmo_guard_probe(fail);
}
#endif
