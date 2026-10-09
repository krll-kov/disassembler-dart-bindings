// Copyright 2026 Vector 35 Inc.
// SPDX-License-Identifier: Apache-2.0
import 'dart:ffi';

import 'exarmo.g.dart' as native;

final class ExarmoAarch32OperandUnionImm {
  final int value;
  final ExarmoAarch32Modifier modifier;

  const ExarmoAarch32OperandUnionImm({
    required this.value,
    required this.modifier,
  });

  factory ExarmoAarch32OperandUnionImm.copy(native.UnnamedStruct value) =>
      ExarmoAarch32OperandUnionImm(
        value: value.value,
        modifier: ExarmoAarch32Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch64OperandUnionImm {
  final int value;
  final ExarmoAarch64Modifier modifier;

  const ExarmoAarch64OperandUnionImm({
    required this.value,
    required this.modifier,
  });

  factory ExarmoAarch64OperandUnionImm.copy(native.UnnamedStruct$1 value) =>
      ExarmoAarch64OperandUnionImm(
        value: value.value,
        modifier: ExarmoAarch64Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch32OperandUnion {
  final ExarmoAarch32RegOperand reg;
  final ExarmoAarch32OperandUnionImm imm;
  final ExarmoAarch32FpImm fp_imm;
  final ExarmoAarch32Label label;
  final ExarmoAarch32Mem mem;
  final ExarmoAarch32RegList list;
  final int cond;
  final ExarmoAarch32Symbol symbol;
  final ExarmoAarch32Modifier modifier;

  const ExarmoAarch32OperandUnion({
    required this.reg,
    required this.imm,
    required this.fp_imm,
    required this.label,
    required this.mem,
    required this.list,
    required this.cond,
    required this.symbol,
    required this.modifier,
  });

  factory ExarmoAarch32OperandUnion.copy(native.UnnamedUnion value) =>
      ExarmoAarch32OperandUnion(
        reg: ExarmoAarch32RegOperand.copy(value.reg),
        imm: ExarmoAarch32OperandUnionImm.copy(value.imm),
        fp_imm: ExarmoAarch32FpImm.copy(value.fp_imm),
        label: ExarmoAarch32Label.copy(value.label),
        mem: ExarmoAarch32Mem.copy(value.mem),
        list: ExarmoAarch32RegList.copy(value.list),
        cond: value.cond,
        symbol: ExarmoAarch32Symbol.copy(value.symbol),
        modifier: ExarmoAarch32Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch64OperandUnion {
  final ExarmoAarch64RegOperand reg;
  final ExarmoAarch64OperandUnionImm imm;
  final ExarmoAarch64FpImm fp_imm;
  final ExarmoAarch64Label label;
  final ExarmoAarch64Mem mem;
  final ExarmoAarch64RegList list;
  final ExarmoAarch64Sysreg sysreg;
  final ExarmoAarch64Sysop sysop;
  final int cond;
  final ExarmoAarch64Symbol symbol;
  final ExarmoAarch64ZaSlice za_slice;
  final int tile_mask;
  final ExarmoAarch64Modifier modifier;

  const ExarmoAarch64OperandUnion({
    required this.reg,
    required this.imm,
    required this.fp_imm,
    required this.label,
    required this.mem,
    required this.list,
    required this.sysreg,
    required this.sysop,
    required this.cond,
    required this.symbol,
    required this.za_slice,
    required this.tile_mask,
    required this.modifier,
  });

  factory ExarmoAarch64OperandUnion.copy(native.UnnamedUnion$1 value) =>
      ExarmoAarch64OperandUnion(
        reg: ExarmoAarch64RegOperand.copy(value.reg),
        imm: ExarmoAarch64OperandUnionImm.copy(value.imm),
        fp_imm: ExarmoAarch64FpImm.copy(value.fp_imm),
        label: ExarmoAarch64Label.copy(value.label),
        mem: ExarmoAarch64Mem.copy(value.mem),
        list: ExarmoAarch64RegList.copy(value.list),
        sysreg: ExarmoAarch64Sysreg.copy(value.sysreg),
        sysop: ExarmoAarch64Sysop.copy(value.sysop),
        cond: value.cond,
        symbol: ExarmoAarch64Symbol.copy(value.symbol),
        za_slice: ExarmoAarch64ZaSlice.copy(value.za_slice),
        tile_mask: value.tile_mask,
        modifier: ExarmoAarch64Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch32Branch {
  final int kind;
  final bool conditional;
  final bool has_target;
  final int target;

  const ExarmoAarch32Branch({
    required this.kind,
    required this.conditional,
    required this.has_target,
    required this.target,
  });

  factory ExarmoAarch32Branch.copy(native.exarmo_aarch32_branch value) =>
      ExarmoAarch32Branch(
        kind: value.kind,
        conditional: value.conditional,
        has_target: value.has_target,
        target: value.target,
      );
}

final class ExarmoAarch32FlagEffect {
  final int writes;
  final int reads;
  final bool float_compare;

  const ExarmoAarch32FlagEffect({
    required this.writes,
    required this.reads,
    required this.float_compare,
  });

  factory ExarmoAarch32FlagEffect.copy(
    native.exarmo_aarch32_flag_effect value,
  ) => ExarmoAarch32FlagEffect(
    writes: value.writes,
    reads: value.reads,
    float_compare: value.float_compare,
  );
}

final class ExarmoAarch32FpImm {
  final double value;
  final int bits;
  final int width;

  const ExarmoAarch32FpImm({
    required this.value,
    required this.bits,
    required this.width,
  });

  factory ExarmoAarch32FpImm.copy(native.exarmo_aarch32_fp_imm value) =>
      ExarmoAarch32FpImm(
        value: value.value,
        bits: value.bits,
        width: value.width,
      );
}

final class ExarmoAarch32Instruction {
  final List<int> opaque;

  ExarmoAarch32Instruction({required List<int> opaque})
    : opaque = List<int>.unmodifiable(opaque);

  factory ExarmoAarch32Instruction.copy(
    native.exarmo_aarch32_instruction value,
  ) => ExarmoAarch32Instruction(
    opaque: <int>[for (int i0 = 0; i0 < 5; i0++) value.opaque[i0]],
  );
}

final class ExarmoAarch32ItState {
  final int kind;
  final int cond;
  final int mask;

  const ExarmoAarch32ItState({
    required this.kind,
    required this.cond,
    required this.mask,
  });

  factory ExarmoAarch32ItState.copy(native.exarmo_aarch32_it_state value) =>
      ExarmoAarch32ItState(
        kind: value.kind,
        cond: value.cond,
        mask: value.mask,
      );
}

final class ExarmoAarch32Label {
  final int offset;
  final int pc_ahead;
  final int pc_align;

  const ExarmoAarch32Label({
    required this.offset,
    required this.pc_ahead,
    required this.pc_align,
  });

  factory ExarmoAarch32Label.copy(native.exarmo_aarch32_label value) =>
      ExarmoAarch32Label(
        offset: value.offset,
        pc_ahead: value.pc_ahead,
        pc_align: value.pc_align,
      );
}

final class ExarmoAarch32Mem {
  final ExarmoAarch32Reg base;
  final ExarmoAarch32Offset offset;
  final int writeback;
  final int align;

  const ExarmoAarch32Mem({
    required this.base,
    required this.offset,
    required this.writeback,
    required this.align,
  });

  factory ExarmoAarch32Mem.copy(native.exarmo_aarch32_mem value) =>
      ExarmoAarch32Mem(
        base: ExarmoAarch32Reg.copy(value.base),
        offset: ExarmoAarch32Offset.copy(value.offset),
        writeback: value.writeback,
        align: value.align,
      );
}

final class ExarmoAarch32Modifier {
  final bool present;
  final int kind;
  final int amount;
  final bool has_by;
  final ExarmoAarch32Reg by;

  const ExarmoAarch32Modifier({
    required this.present,
    required this.kind,
    required this.amount,
    required this.has_by,
    required this.by,
  });

  factory ExarmoAarch32Modifier.copy(native.exarmo_aarch32_modifier value) =>
      ExarmoAarch32Modifier(
        present: value.present,
        kind: value.kind,
        amount: value.amount,
        has_by: value.has_by,
        by: ExarmoAarch32Reg.copy(value.by),
      );
}

final class ExarmoAarch32Offset {
  final int kind;
  final int imm;
  final ExarmoAarch32Reg reg;
  final bool subtract;
  final ExarmoAarch32Modifier modifier;

  const ExarmoAarch32Offset({
    required this.kind,
    required this.imm,
    required this.reg,
    required this.subtract,
    required this.modifier,
  });

  factory ExarmoAarch32Offset.copy(native.exarmo_aarch32_offset value) =>
      ExarmoAarch32Offset(
        kind: value.kind,
        imm: value.imm,
        reg: ExarmoAarch32Reg.copy(value.reg),
        subtract: value.subtract,
        modifier: ExarmoAarch32Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch32Operand {
  final int kind;
  final ExarmoAarch32OperandUnion unnamed;

  const ExarmoAarch32Operand({required this.kind, required this.unnamed});

  factory ExarmoAarch32Operand.copy(native.exarmo_aarch32_operand value) =>
      ExarmoAarch32Operand(
        kind: value.kind,
        unnamed: ExarmoAarch32OperandUnion.copy(value.unnamed),
      );
}

final class ExarmoAarch32Reg {
  final int class_;
  final int num;

  const ExarmoAarch32Reg({required this.class_, required this.num});

  factory ExarmoAarch32Reg.copy(native.exarmo_aarch32_reg value) =>
      ExarmoAarch32Reg(class_: value.class_, num: value.num);
}

final class ExarmoAarch32RegList {
  final int mask;
  final int file;
  final int lane;
  final int index;

  const ExarmoAarch32RegList({
    required this.mask,
    required this.file,
    required this.lane,
    required this.index,
  });

  factory ExarmoAarch32RegList.copy(native.exarmo_aarch32_reg_list value) =>
      ExarmoAarch32RegList(
        mask: value.mask,
        file: value.file,
        lane: value.lane,
        index: value.index,
      );
}

final class ExarmoAarch32RegOperand {
  final ExarmoAarch32Reg reg;
  final int index;
  final ExarmoAarch32Modifier modifier;
  final bool writeback;

  const ExarmoAarch32RegOperand({
    required this.reg,
    required this.index,
    required this.modifier,
    required this.writeback,
  });

  factory ExarmoAarch32RegOperand.copy(
    native.exarmo_aarch32_reg_operand value,
  ) => ExarmoAarch32RegOperand(
    reg: ExarmoAarch32Reg.copy(value.reg),
    index: value.index,
    modifier: ExarmoAarch32Modifier.copy(value.modifier),
    writeback: value.writeback,
  );
}

final class ExarmoAarch32Str {
  final int data;
  final int length;

  const ExarmoAarch32Str({required this.data, required this.length});

  factory ExarmoAarch32Str.copy(native.exarmo_aarch32_str value) =>
      ExarmoAarch32Str(data: value.data.address, length: value.length);
}

final class ExarmoAarch32Symbol {
  final int bits;
  final ExarmoAarch32Str name;

  const ExarmoAarch32Symbol({required this.bits, required this.name});

  factory ExarmoAarch32Symbol.copy(native.exarmo_aarch32_symbol value) =>
      ExarmoAarch32Symbol(
        bits: value.bits,
        name: ExarmoAarch32Str.copy(value.name),
      );
}

final class ExarmoAarch32Sysreg {
  final int space;
  final bool write;
  final int encoding;

  const ExarmoAarch32Sysreg({
    required this.space,
    required this.write,
    required this.encoding,
  });

  factory ExarmoAarch32Sysreg.copy(native.exarmo_aarch32_sysreg value) =>
      ExarmoAarch32Sysreg(
        space: value.space,
        write: value.write,
        encoding: value.encoding,
      );
}

final class ExarmoAarch32SysregDef {
  final int space;
  final bool readable;
  final bool writable;
  final int encoding;
  final ExarmoAarch32Str name;

  const ExarmoAarch32SysregDef({
    required this.space,
    required this.readable,
    required this.writable,
    required this.encoding,
    required this.name,
  });

  factory ExarmoAarch32SysregDef.copy(native.exarmo_aarch32_sysreg_def value) =>
      ExarmoAarch32SysregDef(
        space: value.space,
        readable: value.readable,
        writable: value.writable,
        encoding: value.encoding,
        name: ExarmoAarch32Str.copy(value.name),
      );
}

final class ExarmoAarch32TextSize {
  final int tokens;
  final int length;

  const ExarmoAarch32TextSize({required this.tokens, required this.length});

  factory ExarmoAarch32TextSize.copy(native.exarmo_aarch32_text_size value) =>
      ExarmoAarch32TextSize(tokens: value.tokens, length: value.length);
}

final class ExarmoAarch32Token {
  final int kind;
  final int offset;
  final int length;
  final int operand;
  final int value;

  const ExarmoAarch32Token({
    required this.kind,
    required this.offset,
    required this.length,
    required this.operand,
    required this.value,
  });

  factory ExarmoAarch32Token.copy(native.exarmo_aarch32_token value) =>
      ExarmoAarch32Token(
        kind: value.kind,
        offset: value.offset,
        length: value.length,
        operand: value.operand,
        value: value.value,
      );
}

final class ExarmoAarch64Arrangement {
  final int element;
  final int lanes;

  const ExarmoAarch64Arrangement({required this.element, required this.lanes});

  factory ExarmoAarch64Arrangement.copy(
    native.exarmo_aarch64_arrangement value,
  ) => ExarmoAarch64Arrangement(element: value.element, lanes: value.lanes);
}

final class ExarmoAarch64Branch {
  final int kind;
  final bool conditional;
  final bool has_target;
  final int target;

  const ExarmoAarch64Branch({
    required this.kind,
    required this.conditional,
    required this.has_target,
    required this.target,
  });

  factory ExarmoAarch64Branch.copy(native.exarmo_aarch64_branch value) =>
      ExarmoAarch64Branch(
        kind: value.kind,
        conditional: value.conditional,
        has_target: value.has_target,
        target: value.target,
      );
}

final class ExarmoAarch64FlagEffect {
  final int writes;
  final int reads;
  final bool float_compare;

  const ExarmoAarch64FlagEffect({
    required this.writes,
    required this.reads,
    required this.float_compare,
  });

  factory ExarmoAarch64FlagEffect.copy(
    native.exarmo_aarch64_flag_effect value,
  ) => ExarmoAarch64FlagEffect(
    writes: value.writes,
    reads: value.reads,
    float_compare: value.float_compare,
  );
}

final class ExarmoAarch64FpImm {
  final double value;
  final int bits;
  final int width;

  const ExarmoAarch64FpImm({
    required this.value,
    required this.bits,
    required this.width,
  });

  factory ExarmoAarch64FpImm.copy(native.exarmo_aarch64_fp_imm value) =>
      ExarmoAarch64FpImm(
        value: value.value,
        bits: value.bits,
        width: value.width,
      );
}

final class ExarmoAarch64Instruction {
  final List<int> opaque;

  ExarmoAarch64Instruction({required List<int> opaque})
    : opaque = List<int>.unmodifiable(opaque);

  factory ExarmoAarch64Instruction.copy(
    native.exarmo_aarch64_instruction value,
  ) => ExarmoAarch64Instruction(
    opaque: <int>[for (int i0 = 0; i0 < 3; i0++) value.opaque[i0]],
  );
}

final class ExarmoAarch64Intrinsic {
  final int id;
  final int argument_count;
  final List<ExarmoAarch64IntrinsicSource> arguments;
  final ExarmoAarch64IntrinsicOutput result;

  ExarmoAarch64Intrinsic({
    required this.id,
    required this.argument_count,
    required List<ExarmoAarch64IntrinsicSource> arguments,
    required this.result,
  }) : arguments = List<ExarmoAarch64IntrinsicSource>.unmodifiable(arguments);

  factory ExarmoAarch64Intrinsic.copy(native.exarmo_aarch64_intrinsic value) =>
      ExarmoAarch64Intrinsic(
        id: value.id,
        argument_count: value.argument_count,
        arguments: <ExarmoAarch64IntrinsicSource>[
          for (int i0 = 0; i0 < 5; i0++)
            ExarmoAarch64IntrinsicSource.copy(value.arguments[i0]),
        ],
        result: ExarmoAarch64IntrinsicOutput.copy(value.result),
      );
}

final class ExarmoAarch64IntrinsicDef {
  final ExarmoAarch64Str name;
  final int result;
  final int parameter_count;
  final List<int> parameters;

  ExarmoAarch64IntrinsicDef({
    required this.name,
    required this.result,
    required this.parameter_count,
    required List<int> parameters,
  }) : parameters = List<int>.unmodifiable(parameters);

  factory ExarmoAarch64IntrinsicDef.copy(
    native.exarmo_aarch64_intrinsic_def value,
  ) => ExarmoAarch64IntrinsicDef(
    name: ExarmoAarch64Str.copy(value.name),
    result: value.result,
    parameter_count: value.parameter_count,
    parameters: <int>[for (int i0 = 0; i0 < 5; i0++) value.parameters[i0]],
  );
}

final class ExarmoAarch64IntrinsicOutput {
  final int kind;
  final int operand;
  final int element;

  const ExarmoAarch64IntrinsicOutput({
    required this.kind,
    required this.operand,
    required this.element,
  });

  factory ExarmoAarch64IntrinsicOutput.copy(
    native.exarmo_aarch64_intrinsic_output value,
  ) => ExarmoAarch64IntrinsicOutput(
    kind: value.kind,
    operand: value.operand,
    element: value.element,
  );
}

final class ExarmoAarch64IntrinsicSource {
  final int kind;
  final int operand;
  final int shift;

  const ExarmoAarch64IntrinsicSource({
    required this.kind,
    required this.operand,
    required this.shift,
  });

  factory ExarmoAarch64IntrinsicSource.copy(
    native.exarmo_aarch64_intrinsic_source value,
  ) => ExarmoAarch64IntrinsicSource(
    kind: value.kind,
    operand: value.operand,
    shift: value.shift,
  );
}

final class ExarmoAarch64IntrinsicTypeDef {
  final ExarmoAarch64Str name;
  final int kind;
  final int lanes;
  final int vectors;
  final bool pointer;
  final bool readonly;
  final int element_bits;

  const ExarmoAarch64IntrinsicTypeDef({
    required this.name,
    required this.kind,
    required this.lanes,
    required this.vectors,
    required this.pointer,
    required this.readonly,
    required this.element_bits,
  });

  factory ExarmoAarch64IntrinsicTypeDef.copy(
    native.exarmo_aarch64_intrinsic_type_def value,
  ) => ExarmoAarch64IntrinsicTypeDef(
    name: ExarmoAarch64Str.copy(value.name),
    kind: value.kind,
    lanes: value.lanes,
    vectors: value.vectors,
    pointer: value.pointer,
    readonly: value.readonly,
    element_bits: value.element_bits,
  );
}

final class ExarmoAarch64Label {
  final int offset;
  final int pc_ahead;
  final int pc_align;

  const ExarmoAarch64Label({
    required this.offset,
    required this.pc_ahead,
    required this.pc_align,
  });

  factory ExarmoAarch64Label.copy(native.exarmo_aarch64_label value) =>
      ExarmoAarch64Label(
        offset: value.offset,
        pc_ahead: value.pc_ahead,
        pc_align: value.pc_align,
      );
}

final class ExarmoAarch64Mem {
  final ExarmoAarch64Reg base;
  final ExarmoAarch64Arrangement base_arrangement;
  final ExarmoAarch64Offset offset;
  final int writeback;

  const ExarmoAarch64Mem({
    required this.base,
    required this.base_arrangement,
    required this.offset,
    required this.writeback,
  });

  factory ExarmoAarch64Mem.copy(native.exarmo_aarch64_mem value) =>
      ExarmoAarch64Mem(
        base: ExarmoAarch64Reg.copy(value.base),
        base_arrangement: ExarmoAarch64Arrangement.copy(value.base_arrangement),
        offset: ExarmoAarch64Offset.copy(value.offset),
        writeback: value.writeback,
      );
}

final class ExarmoAarch64Modifier {
  final bool present;
  final int kind;
  final int amount;

  const ExarmoAarch64Modifier({
    required this.present,
    required this.kind,
    required this.amount,
  });

  factory ExarmoAarch64Modifier.copy(native.exarmo_aarch64_modifier value) =>
      ExarmoAarch64Modifier(
        present: value.present,
        kind: value.kind,
        amount: value.amount,
      );
}

final class ExarmoAarch64Offset {
  final int kind;
  final int imm;
  final bool mul_vl;
  final ExarmoAarch64Reg reg;
  final ExarmoAarch64Arrangement arrangement;
  final ExarmoAarch64Modifier modifier;

  const ExarmoAarch64Offset({
    required this.kind,
    required this.imm,
    required this.mul_vl,
    required this.reg,
    required this.arrangement,
    required this.modifier,
  });

  factory ExarmoAarch64Offset.copy(native.exarmo_aarch64_offset value) =>
      ExarmoAarch64Offset(
        kind: value.kind,
        imm: value.imm,
        mul_vl: value.mul_vl,
        reg: ExarmoAarch64Reg.copy(value.reg),
        arrangement: ExarmoAarch64Arrangement.copy(value.arrangement),
        modifier: ExarmoAarch64Modifier.copy(value.modifier),
      );
}

final class ExarmoAarch64Operand {
  final int kind;
  final ExarmoAarch64OperandUnion unnamed;

  const ExarmoAarch64Operand({required this.kind, required this.unnamed});

  factory ExarmoAarch64Operand.copy(native.exarmo_aarch64_operand value) =>
      ExarmoAarch64Operand(
        kind: value.kind,
        unnamed: ExarmoAarch64OperandUnion.copy(value.unnamed),
      );
}

final class ExarmoAarch64Reg {
  final int class_;
  final int num;

  const ExarmoAarch64Reg({required this.class_, required this.num});

  factory ExarmoAarch64Reg.copy(native.exarmo_aarch64_reg value) =>
      ExarmoAarch64Reg(class_: value.class_, num: value.num);
}

final class ExarmoAarch64RegList {
  final List<ExarmoAarch64Reg> regs;
  final int len;
  final ExarmoAarch64Arrangement arrangement;
  final int index;

  ExarmoAarch64RegList({
    required List<ExarmoAarch64Reg> regs,
    required this.len,
    required this.arrangement,
    required this.index,
  }) : regs = List<ExarmoAarch64Reg>.unmodifiable(regs);

  factory ExarmoAarch64RegList.copy(native.exarmo_aarch64_reg_list value) =>
      ExarmoAarch64RegList(
        regs: <ExarmoAarch64Reg>[
          for (int i0 = 0; i0 < 4; i0++) ExarmoAarch64Reg.copy(value.regs[i0]),
        ],
        len: value.len,
        arrangement: ExarmoAarch64Arrangement.copy(value.arrangement),
        index: value.index,
      );
}

final class ExarmoAarch64RegOperand {
  final ExarmoAarch64Reg reg;
  final ExarmoAarch64Arrangement arrangement;
  final int index;
  final bool has_index_reg;
  final ExarmoAarch64Reg index_reg;
  final int predication;
  final ExarmoAarch64Modifier modifier;

  const ExarmoAarch64RegOperand({
    required this.reg,
    required this.arrangement,
    required this.index,
    required this.has_index_reg,
    required this.index_reg,
    required this.predication,
    required this.modifier,
  });

  factory ExarmoAarch64RegOperand.copy(
    native.exarmo_aarch64_reg_operand value,
  ) => ExarmoAarch64RegOperand(
    reg: ExarmoAarch64Reg.copy(value.reg),
    arrangement: ExarmoAarch64Arrangement.copy(value.arrangement),
    index: value.index,
    has_index_reg: value.has_index_reg,
    index_reg: ExarmoAarch64Reg.copy(value.index_reg),
    predication: value.predication,
    modifier: ExarmoAarch64Modifier.copy(value.modifier),
  );
}

final class ExarmoAarch64Str {
  final int data;
  final int length;

  const ExarmoAarch64Str({required this.data, required this.length});

  factory ExarmoAarch64Str.copy(native.exarmo_aarch64_str value) =>
      ExarmoAarch64Str(data: value.data.address, length: value.length);
}

final class ExarmoAarch64Symbol {
  final int bits;
  final ExarmoAarch64Str name;

  const ExarmoAarch64Symbol({required this.bits, required this.name});

  factory ExarmoAarch64Symbol.copy(native.exarmo_aarch64_symbol value) =>
      ExarmoAarch64Symbol(
        bits: value.bits,
        name: ExarmoAarch64Str.copy(value.name),
      );
}

final class ExarmoAarch64Sysop {
  final int index;
  final int field;

  const ExarmoAarch64Sysop({required this.index, required this.field});

  factory ExarmoAarch64Sysop.copy(native.exarmo_aarch64_sysop value) =>
      ExarmoAarch64Sysop(index: value.index, field: value.field);
}

final class ExarmoAarch64SysopDef {
  final int encoding;
  final int instruction;
  final int op0;
  final int op1;
  final int crn;
  final int crm;
  final int op2;
  final int crm_names;
  final int reg_use;
  final int reg_access;
  final int reg_bits;
  final ExarmoAarch64Str name;

  const ExarmoAarch64SysopDef({
    required this.encoding,
    required this.instruction,
    required this.op0,
    required this.op1,
    required this.crn,
    required this.crm,
    required this.op2,
    required this.crm_names,
    required this.reg_use,
    required this.reg_access,
    required this.reg_bits,
    required this.name,
  });

  factory ExarmoAarch64SysopDef.copy(native.exarmo_aarch64_sysop_def value) =>
      ExarmoAarch64SysopDef(
        encoding: value.encoding,
        instruction: value.instruction,
        op0: value.op0,
        op1: value.op1,
        crn: value.crn,
        crm: value.crm,
        op2: value.op2,
        crm_names: value.crm_names,
        reg_use: value.reg_use,
        reg_access: value.reg_access,
        reg_bits: value.reg_bits,
        name: ExarmoAarch64Str.copy(value.name),
      );
}

final class ExarmoAarch64Sysreg {
  final int encoding;
  final bool write;
  final int op0;
  final int op1;
  final int crn;
  final int crm;
  final int op2;

  const ExarmoAarch64Sysreg({
    required this.encoding,
    required this.write,
    required this.op0,
    required this.op1,
    required this.crn,
    required this.crm,
    required this.op2,
  });

  factory ExarmoAarch64Sysreg.copy(native.exarmo_aarch64_sysreg value) =>
      ExarmoAarch64Sysreg(
        encoding: value.encoding,
        write: value.write,
        op0: value.op0,
        op1: value.op1,
        crn: value.crn,
        crm: value.crm,
        op2: value.op2,
      );
}

final class ExarmoAarch64SysregDef {
  final int encoding;
  final bool readable;
  final bool writable;
  final ExarmoAarch64Str name;

  const ExarmoAarch64SysregDef({
    required this.encoding,
    required this.readable,
    required this.writable,
    required this.name,
  });

  factory ExarmoAarch64SysregDef.copy(native.exarmo_aarch64_sysreg_def value) =>
      ExarmoAarch64SysregDef(
        encoding: value.encoding,
        readable: value.readable,
        writable: value.writable,
        name: ExarmoAarch64Str.copy(value.name),
      );
}

final class ExarmoAarch64TextSize {
  final int tokens;
  final int length;

  const ExarmoAarch64TextSize({required this.tokens, required this.length});

  factory ExarmoAarch64TextSize.copy(native.exarmo_aarch64_text_size value) =>
      ExarmoAarch64TextSize(tokens: value.tokens, length: value.length);
}

final class ExarmoAarch64Token {
  final int kind;
  final int offset;
  final int length;
  final int operand;
  final int value;

  const ExarmoAarch64Token({
    required this.kind,
    required this.offset,
    required this.length,
    required this.operand,
    required this.value,
  });

  factory ExarmoAarch64Token.copy(native.exarmo_aarch64_token value) =>
      ExarmoAarch64Token(
        kind: value.kind,
        offset: value.offset,
        length: value.length,
        operand: value.operand,
        value: value.value,
      );
}

final class ExarmoAarch64ZaSlice {
  final int array;
  final int tile;
  final int direction;
  final ExarmoAarch64Arrangement arrangement;
  final bool has_index;
  final ExarmoAarch64Reg index;
  final int offset;
  final int last;
  final bool mul_vl;
  final int vector_group;

  const ExarmoAarch64ZaSlice({
    required this.array,
    required this.tile,
    required this.direction,
    required this.arrangement,
    required this.has_index,
    required this.index,
    required this.offset,
    required this.last,
    required this.mul_vl,
    required this.vector_group,
  });

  factory ExarmoAarch64ZaSlice.copy(native.exarmo_aarch64_za_slice value) =>
      ExarmoAarch64ZaSlice(
        array: value.array,
        tile: value.tile,
        direction: value.direction,
        arrangement: ExarmoAarch64Arrangement.copy(value.arrangement),
        has_index: value.has_index,
        index: ExarmoAarch64Reg.copy(value.index),
        offset: value.offset,
        last: value.last,
        mul_vl: value.mul_vl,
        vector_group: value.vector_group,
      );
}
