import 'dart:ffi';

import 'zydis.g.dart' as native;

final class ZydisDecodedInstructionRawUnion {
  final ZydisDecodedInstructionRawRex rex;
  final ZydisDecodedInstructionRawXop xop;
  final ZydisDecodedInstructionRawVex vex;
  final ZydisDecodedInstructionRawEvex evex;
  final ZydisDecodedInstructionRawMvex mvex;

  const ZydisDecodedInstructionRawUnion({
    required this.rex,
    required this.xop,
    required this.vex,
    required this.evex,
    required this.mvex,
  });

  factory ZydisDecodedInstructionRawUnion.copy(native.UnnamedUnion value) =>
      ZydisDecodedInstructionRawUnion(
        rex: ZydisDecodedInstructionRawRex.copy(value.rex),
        xop: ZydisDecodedInstructionRawXop.copy(value.xop),
        vex: ZydisDecodedInstructionRawVex.copy(value.vex),
        evex: ZydisDecodedInstructionRawEvex.copy(value.evex),
        mvex: ZydisDecodedInstructionRawMvex.copy(value.mvex),
      );
}

final class ZydisDecodedOperandUnion {
  final ZydisDecodedOperandReg reg;
  final ZydisDecodedOperandMem mem;
  final ZydisDecodedOperandPtr ptr;
  final ZydisDecodedOperandImm imm;

  const ZydisDecodedOperandUnion({
    required this.reg,
    required this.mem,
    required this.ptr,
    required this.imm,
  });

  factory ZydisDecodedOperandUnion.copy(native.UnnamedUnion$1 value) =>
      ZydisDecodedOperandUnion(
        reg: ZydisDecodedOperandReg.copy(value.reg),
        mem: ZydisDecodedOperandMem.copy(value.mem),
        ptr: ZydisDecodedOperandPtr.copy(value.ptr),
        imm: ZydisDecodedOperandImm.copy(value.imm),
      );
}

final class ZydisAccessedFlags {
  final int tested;
  final int modified;
  final int set_0;
  final int set_1;
  final int undefined;

  const ZydisAccessedFlags({
    required this.tested,
    required this.modified,
    required this.set_0,
    required this.set_1,
    required this.undefined,
  });

  factory ZydisAccessedFlags.copy(native.ZydisAccessedFlags value) =>
      ZydisAccessedFlags(
        tested: value.tested,
        modified: value.modified,
        set_0: value.set_0,
        set_1: value.set_1,
        undefined: value.undefined,
      );
}

final class ZydisDecodedInstruction {
  final int machine_mode;
  final int mnemonic;
  final int length;
  final int encoding;
  final int opcode_map;
  final int opcode;
  final int stack_width;
  final int operand_width;
  final int address_width;
  final int operand_count;
  final int operand_count_visible;
  final int attributes;
  final ZydisAccessedFlags? cpu_flags;
  final ZydisAccessedFlags? fpu_flags;
  final ZydisDecodedInstructionAvx avx;
  final ZydisDecodedInstructionMeta meta$1;
  final ZydisDecodedInstructionRaw raw;

  const ZydisDecodedInstruction({
    required this.machine_mode,
    required this.mnemonic,
    required this.length,
    required this.encoding,
    required this.opcode_map,
    required this.opcode,
    required this.stack_width,
    required this.operand_width,
    required this.address_width,
    required this.operand_count,
    required this.operand_count_visible,
    required this.attributes,
    required this.cpu_flags,
    required this.fpu_flags,
    required this.avx,
    required this.meta$1,
    required this.raw,
  });

  factory ZydisDecodedInstruction.copy(native.ZydisDecodedInstruction value) =>
      ZydisDecodedInstruction(
        machine_mode: value.machine_mode,
        mnemonic: value.mnemonic,
        length: value.length,
        encoding: value.encoding,
        opcode_map: value.opcode_map,
        opcode: value.opcode,
        stack_width: value.stack_width,
        operand_width: value.operand_width,
        address_width: value.address_width,
        operand_count: value.operand_count,
        operand_count_visible: value.operand_count_visible,
        attributes: value.attributes,
        cpu_flags: value.cpu_flags.address == 0
            ? null
            : ZydisAccessedFlags.copy(value.cpu_flags.ref),
        fpu_flags: value.fpu_flags.address == 0
            ? null
            : ZydisAccessedFlags.copy(value.fpu_flags.ref),
        avx: ZydisDecodedInstructionAvx.copy(value.avx),
        meta$1: ZydisDecodedInstructionMeta.copy(value.meta$1),
        raw: ZydisDecodedInstructionRaw.copy(value.raw),
      );
}

final class ZydisDecodedInstructionAvx {
  final int vector_length;
  final ZydisDecodedInstructionAvxMask mask;
  final ZydisDecodedInstructionAvxBroadcast broadcast;
  final ZydisDecodedInstructionAvxRounding rounding;
  final ZydisDecodedInstructionAvxSwizzle swizzle;
  final ZydisDecodedInstructionAvxConversion conversion;
  final int has_sae;
  final int has_eviction_hint;

  const ZydisDecodedInstructionAvx({
    required this.vector_length,
    required this.mask,
    required this.broadcast,
    required this.rounding,
    required this.swizzle,
    required this.conversion,
    required this.has_sae,
    required this.has_eviction_hint,
  });

  factory ZydisDecodedInstructionAvx.copy(
    native.ZydisDecodedInstructionAvx value,
  ) => ZydisDecodedInstructionAvx(
    vector_length: value.vector_length,
    mask: ZydisDecodedInstructionAvxMask.copy(value.mask),
    broadcast: ZydisDecodedInstructionAvxBroadcast.copy(value.broadcast),
    rounding: ZydisDecodedInstructionAvxRounding.copy(value.rounding),
    swizzle: ZydisDecodedInstructionAvxSwizzle.copy(value.swizzle),
    conversion: ZydisDecodedInstructionAvxConversion.copy(value.conversion),
    has_sae: value.has_sae,
    has_eviction_hint: value.has_eviction_hint,
  );
}

final class ZydisDecodedInstructionAvxBroadcast {
  final int is_static;
  final int mode;

  const ZydisDecodedInstructionAvxBroadcast({
    required this.is_static,
    required this.mode,
  });

  factory ZydisDecodedInstructionAvxBroadcast.copy(
    native.ZydisDecodedInstructionAvxBroadcast value,
  ) => ZydisDecodedInstructionAvxBroadcast(
    is_static: value.is_static,
    mode: value.mode,
  );
}

final class ZydisDecodedInstructionAvxConversion {
  final int mode;

  const ZydisDecodedInstructionAvxConversion({required this.mode});

  factory ZydisDecodedInstructionAvxConversion.copy(
    native.ZydisDecodedInstructionAvxConversion value,
  ) => ZydisDecodedInstructionAvxConversion(mode: value.mode);
}

final class ZydisDecodedInstructionAvxMask {
  final int mode;
  final int reg;

  const ZydisDecodedInstructionAvxMask({required this.mode, required this.reg});

  factory ZydisDecodedInstructionAvxMask.copy(
    native.ZydisDecodedInstructionAvxMask value,
  ) => ZydisDecodedInstructionAvxMask(mode: value.mode, reg: value.reg);
}

final class ZydisDecodedInstructionAvxRounding {
  final int mode;

  const ZydisDecodedInstructionAvxRounding({required this.mode});

  factory ZydisDecodedInstructionAvxRounding.copy(
    native.ZydisDecodedInstructionAvxRounding value,
  ) => ZydisDecodedInstructionAvxRounding(mode: value.mode);
}

final class ZydisDecodedInstructionAvxSwizzle {
  final int mode;

  const ZydisDecodedInstructionAvxSwizzle({required this.mode});

  factory ZydisDecodedInstructionAvxSwizzle.copy(
    native.ZydisDecodedInstructionAvxSwizzle value,
  ) => ZydisDecodedInstructionAvxSwizzle(mode: value.mode);
}

final class ZydisDecodedInstructionMeta {
  final int category;
  final int isa_set;
  final int isa_ext;
  final int branch_type;
  final int exception_class;

  const ZydisDecodedInstructionMeta({
    required this.category,
    required this.isa_set,
    required this.isa_ext,
    required this.branch_type,
    required this.exception_class,
  });

  factory ZydisDecodedInstructionMeta.copy(
    native.ZydisDecodedInstructionMeta value,
  ) => ZydisDecodedInstructionMeta(
    category: value.category,
    isa_set: value.isa_set,
    isa_ext: value.isa_ext,
    branch_type: value.branch_type,
    exception_class: value.exception_class,
  );
}

final class ZydisDecodedInstructionModRm {
  final int mod;
  final int reg;
  final int rm;
  final int offset;

  const ZydisDecodedInstructionModRm({
    required this.mod,
    required this.reg,
    required this.rm,
    required this.offset,
  });

  factory ZydisDecodedInstructionModRm.copy(
    native.ZydisDecodedInstructionModRm value,
  ) => ZydisDecodedInstructionModRm(
    mod: value.mod,
    reg: value.reg,
    rm: value.rm,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRaw {
  final int prefix_count;
  final List<ZydisDecodedInstructionRawPrefixes> prefixes;
  final int encoding2;
  final ZydisDecodedInstructionRawUnion unnamed;
  final ZydisDecodedInstructionModRm modrm;
  final ZydisDecodedInstructionRawSib sib;
  final ZydisDecodedInstructionRawDisp disp;
  final List<ZydisDecodedInstructionRawImm> imm;

  ZydisDecodedInstructionRaw({
    required this.prefix_count,
    required List<ZydisDecodedInstructionRawPrefixes> prefixes,
    required this.encoding2,
    required this.unnamed,
    required this.modrm,
    required this.sib,
    required this.disp,
    required List<ZydisDecodedInstructionRawImm> imm,
  }) : prefixes = List<ZydisDecodedInstructionRawPrefixes>.unmodifiable(
         prefixes,
       ),
       imm = List<ZydisDecodedInstructionRawImm>.unmodifiable(imm);

  factory ZydisDecodedInstructionRaw.copy(
    native.ZydisDecodedInstructionRaw value,
  ) => ZydisDecodedInstructionRaw(
    prefix_count: value.prefix_count,
    prefixes: <ZydisDecodedInstructionRawPrefixes>[
      for (int i0 = 0; i0 < 15; i0++)
        ZydisDecodedInstructionRawPrefixes.copy(value.prefixes[i0]),
    ],
    encoding2: value.encoding2,
    unnamed: ZydisDecodedInstructionRawUnion.copy(value.unnamed),
    modrm: ZydisDecodedInstructionModRm.copy(value.modrm),
    sib: ZydisDecodedInstructionRawSib.copy(value.sib),
    disp: ZydisDecodedInstructionRawDisp.copy(value.disp),
    imm: <ZydisDecodedInstructionRawImm>[
      for (int i0 = 0; i0 < 2; i0++)
        ZydisDecodedInstructionRawImm.copy(value.imm[i0]),
    ],
  );
}

final class ZydisDecodedInstructionRawDisp {
  final int value;
  final int size;
  final int offset;

  const ZydisDecodedInstructionRawDisp({
    required this.value,
    required this.size,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawDisp.copy(
    native.ZydisDecodedInstructionRawDisp value,
  ) => ZydisDecodedInstructionRawDisp(
    value: value.value,
    size: value.size,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawEvex {
  final int R;
  final int X;
  final int B;
  final int R2;
  final int mmm;
  final int W;
  final int vvvv;
  final int pp;
  final int z;
  final int L2;
  final int L;
  final int b;
  final int V2;
  final int aaa;
  final int offset;

  const ZydisDecodedInstructionRawEvex({
    required this.R,
    required this.X,
    required this.B,
    required this.R2,
    required this.mmm,
    required this.W,
    required this.vvvv,
    required this.pp,
    required this.z,
    required this.L2,
    required this.L,
    required this.b,
    required this.V2,
    required this.aaa,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawEvex.copy(
    native.ZydisDecodedInstructionRawEvex value,
  ) => ZydisDecodedInstructionRawEvex(
    R: value.R,
    X: value.X,
    B: value.B,
    R2: value.R2,
    mmm: value.mmm,
    W: value.W,
    vvvv: value.vvvv,
    pp: value.pp,
    z: value.z,
    L2: value.L2,
    L: value.L,
    b: value.b,
    V2: value.V2,
    aaa: value.aaa,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawImm {
  final int is_signed;
  final int is_relative;
  final ZydisDecodedInstructionRawImmValue value;
  final int size;
  final int offset;

  const ZydisDecodedInstructionRawImm({
    required this.is_signed,
    required this.is_relative,
    required this.value,
    required this.size,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawImm.copy(
    native.ZydisDecodedInstructionRawImm value,
  ) => ZydisDecodedInstructionRawImm(
    is_signed: value.is_signed,
    is_relative: value.is_relative,
    value: ZydisDecodedInstructionRawImmValue.copy(value.value),
    size: value.size,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawImmValue {
  final int u;
  final int s;

  const ZydisDecodedInstructionRawImmValue({required this.u, required this.s});

  factory ZydisDecodedInstructionRawImmValue.copy(
    native.ZydisDecodedInstructionRawImmValue value,
  ) => ZydisDecodedInstructionRawImmValue(u: value.u, s: value.s);
}

final class ZydisDecodedInstructionRawMvex {
  final int R;
  final int X;
  final int B;
  final int R2;
  final int mmmm;
  final int W;
  final int vvvv;
  final int pp;
  final int E;
  final int SSS;
  final int V2;
  final int kkk;
  final int offset;

  const ZydisDecodedInstructionRawMvex({
    required this.R,
    required this.X,
    required this.B,
    required this.R2,
    required this.mmmm,
    required this.W,
    required this.vvvv,
    required this.pp,
    required this.E,
    required this.SSS,
    required this.V2,
    required this.kkk,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawMvex.copy(
    native.ZydisDecodedInstructionRawMvex value,
  ) => ZydisDecodedInstructionRawMvex(
    R: value.R,
    X: value.X,
    B: value.B,
    R2: value.R2,
    mmmm: value.mmmm,
    W: value.W,
    vvvv: value.vvvv,
    pp: value.pp,
    E: value.E,
    SSS: value.SSS,
    V2: value.V2,
    kkk: value.kkk,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawPrefixes {
  final int type;
  final int value;

  const ZydisDecodedInstructionRawPrefixes({
    required this.type,
    required this.value,
  });

  factory ZydisDecodedInstructionRawPrefixes.copy(
    native.ZydisDecodedInstructionRawPrefixes value,
  ) => ZydisDecodedInstructionRawPrefixes(type: value.type, value: value.value);
}

final class ZydisDecodedInstructionRawRex {
  final int W;
  final int R;
  final int X;
  final int B;
  final int offset;

  const ZydisDecodedInstructionRawRex({
    required this.W,
    required this.R,
    required this.X,
    required this.B,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawRex.copy(
    native.ZydisDecodedInstructionRawRex value,
  ) => ZydisDecodedInstructionRawRex(
    W: value.W,
    R: value.R,
    X: value.X,
    B: value.B,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawSib {
  final int scale;
  final int index;
  final int base;
  final int offset;

  const ZydisDecodedInstructionRawSib({
    required this.scale,
    required this.index,
    required this.base,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawSib.copy(
    native.ZydisDecodedInstructionRawSib value,
  ) => ZydisDecodedInstructionRawSib(
    scale: value.scale,
    index: value.index,
    base: value.base,
    offset: value.offset,
  );
}

final class ZydisDecodedInstructionRawVex {
  final int R;
  final int X;
  final int B;
  final int m_mmmm;
  final int W;
  final int vvvv;
  final int L;
  final int pp;
  final int offset;
  final int size;

  const ZydisDecodedInstructionRawVex({
    required this.R,
    required this.X,
    required this.B,
    required this.m_mmmm,
    required this.W,
    required this.vvvv,
    required this.L,
    required this.pp,
    required this.offset,
    required this.size,
  });

  factory ZydisDecodedInstructionRawVex.copy(
    native.ZydisDecodedInstructionRawVex value,
  ) => ZydisDecodedInstructionRawVex(
    R: value.R,
    X: value.X,
    B: value.B,
    m_mmmm: value.m_mmmm,
    W: value.W,
    vvvv: value.vvvv,
    L: value.L,
    pp: value.pp,
    offset: value.offset,
    size: value.size,
  );
}

final class ZydisDecodedInstructionRawXop {
  final int R;
  final int X;
  final int B;
  final int m_mmmm;
  final int W;
  final int vvvv;
  final int L;
  final int pp;
  final int offset;

  const ZydisDecodedInstructionRawXop({
    required this.R,
    required this.X,
    required this.B,
    required this.m_mmmm,
    required this.W,
    required this.vvvv,
    required this.L,
    required this.pp,
    required this.offset,
  });

  factory ZydisDecodedInstructionRawXop.copy(
    native.ZydisDecodedInstructionRawXop value,
  ) => ZydisDecodedInstructionRawXop(
    R: value.R,
    X: value.X,
    B: value.B,
    m_mmmm: value.m_mmmm,
    W: value.W,
    vvvv: value.vvvv,
    L: value.L,
    pp: value.pp,
    offset: value.offset,
  );
}

final class ZydisDecodedOperand {
  final int id;
  final int visibility;
  final int actions;
  final int encoding;
  final int size;
  final int element_type;
  final int element_size;
  final int element_count;
  final int attributes;
  final int type;
  final ZydisDecodedOperandUnion unnamed;

  const ZydisDecodedOperand({
    required this.id,
    required this.visibility,
    required this.actions,
    required this.encoding,
    required this.size,
    required this.element_type,
    required this.element_size,
    required this.element_count,
    required this.attributes,
    required this.type,
    required this.unnamed,
  });

  factory ZydisDecodedOperand.copy(native.ZydisDecodedOperand value) =>
      ZydisDecodedOperand(
        id: value.id,
        visibility: value.visibility,
        actions: value.actions,
        encoding: value.encoding,
        size: value.size,
        element_type: value.element_type,
        element_size: value.element_size,
        element_count: value.element_count,
        attributes: value.attributes,
        type: value.type,
        unnamed: ZydisDecodedOperandUnion.copy(value.unnamed),
      );
}

final class ZydisDecodedOperandImm {
  final int is_signed;
  final int is_relative;
  final ZydisDecodedOperandImmValue value;

  const ZydisDecodedOperandImm({
    required this.is_signed,
    required this.is_relative,
    required this.value,
  });

  factory ZydisDecodedOperandImm.copy(native.ZydisDecodedOperandImm value) =>
      ZydisDecodedOperandImm(
        is_signed: value.is_signed,
        is_relative: value.is_relative,
        value: ZydisDecodedOperandImmValue.copy(value.value),
      );
}

final class ZydisDecodedOperandImmValue {
  final int u;
  final int s;

  const ZydisDecodedOperandImmValue({required this.u, required this.s});

  factory ZydisDecodedOperandImmValue.copy(
    native.ZydisDecodedOperandImmValue value,
  ) => ZydisDecodedOperandImmValue(u: value.u, s: value.s);
}

final class ZydisDecodedOperandMem {
  final int type;
  final int segment;
  final int base;
  final int index;
  final int scale;
  final ZydisDecodedOperandMemDisp disp;

  const ZydisDecodedOperandMem({
    required this.type,
    required this.segment,
    required this.base,
    required this.index,
    required this.scale,
    required this.disp,
  });

  factory ZydisDecodedOperandMem.copy(native.ZydisDecodedOperandMem value) =>
      ZydisDecodedOperandMem(
        type: value.type,
        segment: value.segment,
        base: value.base,
        index: value.index,
        scale: value.scale,
        disp: ZydisDecodedOperandMemDisp.copy(value.disp),
      );
}

final class ZydisDecodedOperandMemDisp {
  final int has_displacement;
  final int value;

  const ZydisDecodedOperandMemDisp({
    required this.has_displacement,
    required this.value,
  });

  factory ZydisDecodedOperandMemDisp.copy(
    native.ZydisDecodedOperandMemDisp value,
  ) => ZydisDecodedOperandMemDisp(
    has_displacement: value.has_displacement,
    value: value.value,
  );
}

final class ZydisDecodedOperandPtr {
  final int segment;
  final int offset;

  const ZydisDecodedOperandPtr({required this.segment, required this.offset});

  factory ZydisDecodedOperandPtr.copy(native.ZydisDecodedOperandPtr value) =>
      ZydisDecodedOperandPtr(segment: value.segment, offset: value.offset);
}

final class ZydisDecodedOperandReg {
  final int value;

  const ZydisDecodedOperandReg({required this.value});

  factory ZydisDecodedOperandReg.copy(native.ZydisDecodedOperandReg value) =>
      ZydisDecodedOperandReg(value: value.value);
}
