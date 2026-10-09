import 'dart:ffi';

import '../third_party/capstone.g.dart' as native;

enum Architecture {
  arm(native.cs_arch.CS_ARCH_ARM),
  aarch64(native.cs_arch.CS_ARCH_AARCH64),
  systemz(native.cs_arch.CS_ARCH_SYSTEMZ),
  mips(native.cs_arch.CS_ARCH_MIPS),
  x86(native.cs_arch.CS_ARCH_X86),
  ppc(native.cs_arch.CS_ARCH_PPC),
  sparc(native.cs_arch.CS_ARCH_SPARC),
  xcore(native.cs_arch.CS_ARCH_XCORE),
  m68k(native.cs_arch.CS_ARCH_M68K),
  tms320c64x(native.cs_arch.CS_ARCH_TMS320C64X),
  m680x(native.cs_arch.CS_ARCH_M680X),
  evm(native.cs_arch.CS_ARCH_EVM),
  mos65xx(native.cs_arch.CS_ARCH_MOS65XX),
  wasm(native.cs_arch.CS_ARCH_WASM),
  bpf(native.cs_arch.CS_ARCH_BPF),
  riscv(native.cs_arch.CS_ARCH_RISCV),
  sh(native.cs_arch.CS_ARCH_SH),
  tricore(native.cs_arch.CS_ARCH_TRICORE),
  alpha(native.cs_arch.CS_ARCH_ALPHA),
  hppa(native.cs_arch.CS_ARCH_HPPA),
  loongarch(native.cs_arch.CS_ARCH_LOONGARCH),
  xtensa(native.cs_arch.CS_ARCH_XTENSA),
  arc(native.cs_arch.CS_ARCH_ARC);

  final int value;

  const Architecture(this.value);
}

final class Mode {
  static const littleEndian = native.cs_mode.CS_MODE_LITTLE_ENDIAN;
  static const arm = native.cs_mode.CS_MODE_ARM;
  static const mode16 = native.cs_mode.CS_MODE_16;
  static const mode32 = native.cs_mode.CS_MODE_32;
  static const mode64 = native.cs_mode.CS_MODE_64;
  static const x86Intel = native.cs_mode.CS_MODE_X86_INTEL;
  static const x86Amd = native.cs_mode.CS_MODE_X86_AMD;
  static const thumb = native.cs_mode.CS_MODE_THUMB;
  static const mclass = native.cs_mode.CS_MODE_MCLASS;
  static const v8 = native.cs_mode.CS_MODE_V8;
  static const appleProprietary = native.cs_mode.CS_MODE_APPLE_PROPRIETARY;
  static const v9 = native.cs_mode.CS_MODE_V9;
  static const qpx = native.cs_mode.CS_MODE_QPX;
  static const spe = native.cs_mode.CS_MODE_SPE;
  static const booke = native.cs_mode.CS_MODE_BOOKE;
  static const ps = native.cs_mode.CS_MODE_PS;
  static const aixOs = native.cs_mode.CS_MODE_AIX_OS;
  static const pwr7 = native.cs_mode.CS_MODE_PWR7;
  static const pwr8 = native.cs_mode.CS_MODE_PWR8;
  static const pwr9 = native.cs_mode.CS_MODE_PWR9;
  static const pwr10 = native.cs_mode.CS_MODE_PWR10;
  static const ppcIsaFuture = native.cs_mode.CS_MODE_PPC_ISA_FUTURE;
  static const modernAixAs = native.cs_mode.CS_MODE_MODERN_AIX_AS;
  static const msync = native.cs_mode.CS_MODE_MSYNC;
  static const m68k000 = native.cs_mode.CS_MODE_M68K_000;
  static const m68k010 = native.cs_mode.CS_MODE_M68K_010;
  static const m68k020 = native.cs_mode.CS_MODE_M68K_020;
  static const m68k030 = native.cs_mode.CS_MODE_M68K_030;
  static const m68k040 = native.cs_mode.CS_MODE_M68K_040;
  static const m68k060 = native.cs_mode.CS_MODE_M68K_060;
  static const m68kCpu32 = native.cs_mode.CS_MODE_M68K_CPU32;
  static const m68kCfIsaA = native.cs_mode.CS_MODE_M68K_CF_ISA_A;
  static const m68kCfIsaAPlus = native.cs_mode.CS_MODE_M68K_CF_ISA_A_PLUS;
  static const m68kCfIsaB = native.cs_mode.CS_MODE_M68K_CF_ISA_B;
  static const m68kCfIsaC = native.cs_mode.CS_MODE_M68K_CF_ISA_C;
  static const m68kCfUsp = native.cs_mode.CS_MODE_M68K_CF_USP;
  static const m68kCfDiv = native.cs_mode.CS_MODE_M68K_CF_DIV;
  static const m68kCfMac = native.cs_mode.CS_MODE_M68K_CF_MAC;
  static const m68kCfEmac = native.cs_mode.CS_MODE_M68K_CF_EMAC;
  static const m68kCfEmacB = native.cs_mode.CS_MODE_M68K_CF_EMAC_B;
  static const m68kCfFpu = native.cs_mode.CS_MODE_M68K_CF_FPU;
  static const m68kColdfire = native.cs_mode.CS_MODE_M68K_COLDFIRE;
  static const m68kCfv1 = native.cs_mode.CS_MODE_M68K_CFV1;
  static const m68kCfv2 = native.cs_mode.CS_MODE_M68K_CFV2;
  static const m68kCfv3 = native.cs_mode.CS_MODE_M68K_CFV3;
  static const m68kCfv4 = native.cs_mode.CS_MODE_M68K_CFV4;
  static const m68kCfv4e = native.cs_mode.CS_MODE_M68K_CFV4E;
  static const m68kCfv5 = native.cs_mode.CS_MODE_M68K_CFV5;
  static const m68kFeatureMask = native.cs_mode.CS_MODE_M68K_FEATURE_MASK;
  static const bigEndian = native.cs_mode.CS_MODE_BIG_ENDIAN;
  static const mips16 = native.cs_mode.CS_MODE_MIPS16;
  static const mips32 = native.cs_mode.CS_MODE_MIPS32;
  static const mips64 = native.cs_mode.CS_MODE_MIPS64;
  static const micro = native.cs_mode.CS_MODE_MICRO;
  static const mips1 = native.cs_mode.CS_MODE_MIPS1;
  static const mips2 = native.cs_mode.CS_MODE_MIPS2;
  static const mips32r2 = native.cs_mode.CS_MODE_MIPS32R2;
  static const mips32r3 = native.cs_mode.CS_MODE_MIPS32R3;
  static const mips32r5 = native.cs_mode.CS_MODE_MIPS32R5;
  static const mips32r6 = native.cs_mode.CS_MODE_MIPS32R6;
  static const mips3 = native.cs_mode.CS_MODE_MIPS3;
  static const mips4 = native.cs_mode.CS_MODE_MIPS4;
  static const mips5 = native.cs_mode.CS_MODE_MIPS5;
  static const mips64r2 = native.cs_mode.CS_MODE_MIPS64R2;
  static const mips64r3 = native.cs_mode.CS_MODE_MIPS64R3;
  static const mips64r5 = native.cs_mode.CS_MODE_MIPS64R5;
  static const mips64r6 = native.cs_mode.CS_MODE_MIPS64R6;
  static const octeon = native.cs_mode.CS_MODE_OCTEON;
  static const octeonp = native.cs_mode.CS_MODE_OCTEONP;
  static const nanomips = native.cs_mode.CS_MODE_NANOMIPS;
  static const nms1 = native.cs_mode.CS_MODE_NMS1;
  static const i7200 = native.cs_mode.CS_MODE_I7200;
  static const mipsNofloat = native.cs_mode.CS_MODE_MIPS_NOFLOAT;
  static const mipsPtr64 = native.cs_mode.CS_MODE_MIPS_PTR64;
  static const micro32r3 = native.cs_mode.CS_MODE_MICRO32R3;
  static const micro32r6 = native.cs_mode.CS_MODE_MICRO32R6;
  static const m680x6301 = native.cs_mode.CS_MODE_M680X_6301;
  static const m680x6309 = native.cs_mode.CS_MODE_M680X_6309;
  static const m680x6800 = native.cs_mode.CS_MODE_M680X_6800;
  static const m680x6801 = native.cs_mode.CS_MODE_M680X_6801;
  static const m680x6805 = native.cs_mode.CS_MODE_M680X_6805;
  static const m680x6808 = native.cs_mode.CS_MODE_M680X_6808;
  static const m680x6809 = native.cs_mode.CS_MODE_M680X_6809;
  static const m680x6811 = native.cs_mode.CS_MODE_M680X_6811;
  static const m680xCpu12 = native.cs_mode.CS_MODE_M680X_CPU12;
  static const m680xHcs08 = native.cs_mode.CS_MODE_M680X_HCS08;
  static const m680xRs08 = native.cs_mode.CS_MODE_M680X_RS08;
  static const m680xHcs12x = native.cs_mode.CS_MODE_M680X_HCS12X;
  static const bpfClassic = native.cs_mode.CS_MODE_BPF_CLASSIC;
  static const bpfExtended = native.cs_mode.CS_MODE_BPF_EXTENDED;
  static const riscv32 = native.cs_mode.CS_MODE_RISCV32;
  static const riscv64 = native.cs_mode.CS_MODE_RISCV64;
  static const riscvC = native.cs_mode.CS_MODE_RISCV_C;
  static const riscvFd = native.cs_mode.CS_MODE_RISCV_FD;
  static const riscvV = native.cs_mode.CS_MODE_RISCV_V;
  static const riscvZfinx = native.cs_mode.CS_MODE_RISCV_ZFINX;
  static const riscvZcmpZcmtZce = native.cs_mode.CS_MODE_RISCV_ZCMP_ZCMT_ZCE;
  static const riscvZicfiss = native.cs_mode.CS_MODE_RISCV_ZICFISS;
  static const riscvE = native.cs_mode.CS_MODE_RISCV_E;
  static const riscvA = native.cs_mode.CS_MODE_RISCV_A;
  static const riscvCorev = native.cs_mode.CS_MODE_RISCV_COREV;
  static const riscvThead = native.cs_mode.CS_MODE_RISCV_THEAD;
  static const riscvSifive = native.cs_mode.CS_MODE_RISCV_SIFIVE;
  static const riscvBitmanip = native.cs_mode.CS_MODE_RISCV_BITMANIP;
  static const riscvZba = native.cs_mode.CS_MODE_RISCV_ZBA;
  static const riscvZbb = native.cs_mode.CS_MODE_RISCV_ZBB;
  static const riscvZbc = native.cs_mode.CS_MODE_RISCV_ZBC;
  static const riscvZbkb = native.cs_mode.CS_MODE_RISCV_ZBKB;
  static const riscvZbkc = native.cs_mode.CS_MODE_RISCV_ZBKC;
  static const riscvZbkx = native.cs_mode.CS_MODE_RISCV_ZBKX;
  static const riscvZbs = native.cs_mode.CS_MODE_RISCV_ZBS;
  static const riscvVentana = native.cs_mode.CS_MODE_RISCV_VENTANA;
  static const mos65xx6502 = native.cs_mode.CS_MODE_MOS65XX_6502;
  static const mos65xx65c02 = native.cs_mode.CS_MODE_MOS65XX_65C02;
  static const mos65xxW65c02 = native.cs_mode.CS_MODE_MOS65XX_W65C02;
  static const mos65xx65816 = native.cs_mode.CS_MODE_MOS65XX_65816;
  static const mos65xx65816LongM = native.cs_mode.CS_MODE_MOS65XX_65816_LONG_M;
  static const mos65xx65816LongX = native.cs_mode.CS_MODE_MOS65XX_65816_LONG_X;
  static const mos65xx65816LongMx =
      native.cs_mode.CS_MODE_MOS65XX_65816_LONG_MX;
  static const sh2 = native.cs_mode.CS_MODE_SH2;
  static const sh2a = native.cs_mode.CS_MODE_SH2A;
  static const sh3 = native.cs_mode.CS_MODE_SH3;
  static const sh4 = native.cs_mode.CS_MODE_SH4;
  static const sh4a = native.cs_mode.CS_MODE_SH4A;
  static const shfpu = native.cs_mode.CS_MODE_SHFPU;
  static const shdsp = native.cs_mode.CS_MODE_SHDSP;
  static const tricore110 = native.cs_mode.CS_MODE_TRICORE_110;
  static const tricore120 = native.cs_mode.CS_MODE_TRICORE_120;
  static const tricore130 = native.cs_mode.CS_MODE_TRICORE_130;
  static const tricore131 = native.cs_mode.CS_MODE_TRICORE_131;
  static const tricore160 = native.cs_mode.CS_MODE_TRICORE_160;
  static const tricore161 = native.cs_mode.CS_MODE_TRICORE_161;
  static const tricore162 = native.cs_mode.CS_MODE_TRICORE_162;
  static const tricore180 = native.cs_mode.CS_MODE_TRICORE_180;
  static const hppa11 = native.cs_mode.CS_MODE_HPPA_11;
  static const hppa20 = native.cs_mode.CS_MODE_HPPA_20;
  static const hppa20w = native.cs_mode.CS_MODE_HPPA_20W;
  static const loongarch32 = native.cs_mode.CS_MODE_LOONGARCH32;
  static const loongarch64 = native.cs_mode.CS_MODE_LOONGARCH64;
  static const systemzArch8 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH8;
  static const systemzArch9 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH9;
  static const systemzArch10 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH10;
  static const systemzArch11 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH11;
  static const systemzArch12 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH12;
  static const systemzArch13 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH13;
  static const systemzArch14 = native.cs_mode.CS_MODE_SYSTEMZ_ARCH14;
  static const systemzZ10 = native.cs_mode.CS_MODE_SYSTEMZ_Z10;
  static const systemzZ196 = native.cs_mode.CS_MODE_SYSTEMZ_Z196;
  static const systemzZec12 = native.cs_mode.CS_MODE_SYSTEMZ_ZEC12;
  static const systemzZ13 = native.cs_mode.CS_MODE_SYSTEMZ_Z13;
  static const systemzZ14 = native.cs_mode.CS_MODE_SYSTEMZ_Z14;
  static const systemzZ15 = native.cs_mode.CS_MODE_SYSTEMZ_Z15;
  static const systemzZ16 = native.cs_mode.CS_MODE_SYSTEMZ_Z16;
  static const systemzGeneric = native.cs_mode.CS_MODE_SYSTEMZ_GENERIC;
  static const xtensaEsp32 = native.cs_mode.CS_MODE_XTENSA_ESP32;
  static const xtensaEsp32s2 = native.cs_mode.CS_MODE_XTENSA_ESP32S2;
  static const xtensaEsp8266 = native.cs_mode.CS_MODE_XTENSA_ESP8266;
  static const xtensaEsp32s3 = native.cs_mode.CS_MODE_XTENSA_ESP32S3;
}

enum Syntax {
  defaultSyntax(native.cs_opt_value.CS_OPT_SYNTAX_DEFAULT),
  intel(native.cs_opt_value.CS_OPT_SYNTAX_INTEL),
  att(native.cs_opt_value.CS_OPT_SYNTAX_ATT),
  noregname(native.cs_opt_value.CS_OPT_SYNTAX_NOREGNAME),
  masm(native.cs_opt_value.CS_OPT_SYNTAX_MASM),
  motorola(native.cs_opt_value.CS_OPT_SYNTAX_MOTOROLA),
  csRegAlias(native.cs_opt_value.CS_OPT_SYNTAX_CS_REG_ALIAS),
  percent(native.cs_opt_value.CS_OPT_SYNTAX_PERCENT),
  noDollar(native.cs_opt_value.CS_OPT_SYNTAX_NO_DOLLAR),
  real(native.cs_opt_value.CS_OPT_SYNTAX_REAL),
  uncompressedReal(native.cs_opt_value.CS_OPT_SYNTAX_UNCOMPRESSED_REAL),
  aarch64ExplicitWideImm(
    native.cs_opt_value.CS_OPT_SYNTAX_AARCH64_EXPLICIT_WIDE_IMM,
  ),
  alias(native.cs_opt_value.CS_OPT_SYNTAX_ALIAS);

  final int value;

  const Syntax(this.value);
}

sealed class ArchitectureDetails {
  const ArchitectureDetails();
}

ArchitectureDetails copyArchitectureDetails(
  native.cs_detail detail,
  int architecture,
) => switch (architecture) {
  native.cs_arch.CS_ARCH_X86 => X86Details.copy(detail.unnamed.x86),
  native.cs_arch.CS_ARCH_AARCH64 => Aarch64Details.copy(detail.unnamed.aarch64),
  native.cs_arch.CS_ARCH_SYSTEMZ => SystemzDetails.copy(detail.unnamed.systemz),
  native.cs_arch.CS_ARCH_ARM => ArmDetails.copy(detail.unnamed.arm),
  native.cs_arch.CS_ARCH_M68K => M68kDetails.copy(detail.unnamed.m68k),
  native.cs_arch.CS_ARCH_MIPS => MipsDetails.copy(detail.unnamed.mips),
  native.cs_arch.CS_ARCH_PPC => PpcDetails.copy(detail.unnamed.ppc),
  native.cs_arch.CS_ARCH_SPARC => SparcDetails.copy(detail.unnamed.sparc),
  native.cs_arch.CS_ARCH_XCORE => XcoreDetails.copy(detail.unnamed.xcore),
  native.cs_arch.CS_ARCH_TMS320C64X => Tms320c64xDetails.copy(
    detail.unnamed.tms320c64x,
  ),
  native.cs_arch.CS_ARCH_M680X => M680xDetails.copy(detail.unnamed.m680x),
  native.cs_arch.CS_ARCH_EVM => EvmDetails.copy(detail.unnamed.evm),
  native.cs_arch.CS_ARCH_MOS65XX => Mos65xxDetails.copy(detail.unnamed.mos65xx),
  native.cs_arch.CS_ARCH_WASM => WasmDetails.copy(detail.unnamed.wasm),
  native.cs_arch.CS_ARCH_BPF => BpfDetails.copy(detail.unnamed.bpf),
  native.cs_arch.CS_ARCH_RISCV => RiscvDetails.copy(detail.unnamed.riscv),
  native.cs_arch.CS_ARCH_SH => ShDetails.copy(detail.unnamed.sh),
  native.cs_arch.CS_ARCH_TRICORE => TricoreDetails.copy(detail.unnamed.tricore),
  native.cs_arch.CS_ARCH_ALPHA => AlphaDetails.copy(detail.unnamed.alpha),
  native.cs_arch.CS_ARCH_HPPA => HppaDetails.copy(detail.unnamed.hppa),
  native.cs_arch.CS_ARCH_LOONGARCH => LoongarchDetails.copy(
    detail.unnamed.loongarch,
  ),
  native.cs_arch.CS_ARCH_XTENSA => XtensaDetails.copy(detail.unnamed.xtensa),
  native.cs_arch.CS_ARCH_ARC => ArcDetails.copy(detail.unnamed.arc),
  _ => throw UnsupportedError('Capstone architecture detail: $architecture'),
};

final class CsAarch64OpShift {
  final int type;
  final int value;

  const CsAarch64OpShift({required this.type, required this.value});

  factory CsAarch64OpShift.copy(native.UnnamedStruct value) =>
      CsAarch64OpShift(type: value.type, value: value.value);
}

final class CsArmOpShift {
  final int type;
  final int value;

  const CsArmOpShift({required this.type, required this.value});

  factory CsArmOpShift.copy(native.UnnamedStruct$1 value) =>
      CsArmOpShift(type: value.type, value: value.value);
}

final class Tms320c64xDetailsCondition {
  final int reg;
  final int zero;

  const Tms320c64xDetailsCondition({required this.reg, required this.zero});

  factory Tms320c64xDetailsCondition.copy(native.UnnamedStruct$2 value) =>
      Tms320c64xDetailsCondition(reg: value.reg, zero: value.zero);
}

final class Tms320c64xDetailsFunit {
  final int unit;
  final int side;
  final int crosspath;

  const Tms320c64xDetailsFunit({
    required this.unit,
    required this.side,
    required this.crosspath,
  });

  factory Tms320c64xDetailsFunit.copy(native.UnnamedStruct$3 value) =>
      Tms320c64xDetailsFunit(
        unit: value.unit,
        side: value.side,
        crosspath: value.crosspath,
      );
}

final class X86DetailsUnion {
  final int eflags;
  final int fpu_flags;

  const X86DetailsUnion({required this.eflags, required this.fpu_flags});

  factory X86DetailsUnion.copy(native.UnnamedUnion$1 value) =>
      X86DetailsUnion(eflags: value.eflags, fpu_flags: value.fpu_flags);
}

final class CsPpcOpUnion {
  final int reg;
  final int imm;
  final PpcOpMem mem;

  const CsPpcOpUnion({required this.reg, required this.imm, required this.mem});

  factory CsPpcOpUnion.copy(native.UnnamedUnion$10 value) => CsPpcOpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: PpcOpMem.copy(value.mem),
  );
}

final class CsSparcOpUnion {
  final int reg;
  final int imm;
  final SparcOpMem mem;
  final int membar_tag;
  final int asi;

  const CsSparcOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
    required this.membar_tag,
    required this.asi,
  });

  factory CsSparcOpUnion.copy(native.UnnamedUnion$11 value) => CsSparcOpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: SparcOpMem.copy(value.mem),
    membar_tag: value.membar_tag,
    asi: value.asi,
  );
}

final class CsXcoreOpUnion {
  final int reg;
  final int imm;
  final XcoreOpMem mem;

  const CsXcoreOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsXcoreOpUnion.copy(native.UnnamedUnion$12 value) => CsXcoreOpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: XcoreOpMem.copy(value.mem),
  );
}

final class CsTms320c64xOpUnion {
  final int reg;
  final int imm;
  final Tms320c64xOpMem mem;

  const CsTms320c64xOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsTms320c64xOpUnion.copy(native.UnnamedUnion$13 value) =>
      CsTms320c64xOpUnion(
        reg: value.reg,
        imm: value.imm,
        mem: Tms320c64xOpMem.copy(value.mem),
      );
}

final class CsM680xOpUnion {
  final int imm;
  final int reg;
  final M680xOpIdx idx;
  final M680xOpRel rel;
  final M680xOpExt ext;
  final int direct_addr;
  final int const_val;

  const CsM680xOpUnion({
    required this.imm,
    required this.reg,
    required this.idx,
    required this.rel,
    required this.ext,
    required this.direct_addr,
    required this.const_val,
  });

  factory CsM680xOpUnion.copy(native.UnnamedUnion$14 value) => CsM680xOpUnion(
    imm: value.imm,
    reg: value.reg,
    idx: M680xOpIdx.copy(value.idx),
    rel: M680xOpRel.copy(value.rel),
    ext: M680xOpExt.copy(value.ext),
    direct_addr: value.direct_addr,
    const_val: value.const_val,
  );
}

final class CsMos65xxOpUnion {
  final int reg;
  final int imm;
  final int mem;

  const CsMos65xxOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsMos65xxOpUnion.copy(native.UnnamedUnion$15 value) =>
      CsMos65xxOpUnion(reg: value.reg, imm: value.imm, mem: value.mem);
}

final class CsWasmOpUnion {
  final int int7;
  final int varuint32;
  final int varuint64;
  final int uint32;
  final int uint64;
  final List<int> immediate;
  final CsWasmBrtable brtable;

  CsWasmOpUnion({
    required this.int7,
    required this.varuint32,
    required this.varuint64,
    required this.uint32,
    required this.uint64,
    required List<int> immediate,
    required this.brtable,
  }) : immediate = List<int>.unmodifiable(immediate);

  factory CsWasmOpUnion.copy(native.UnnamedUnion$16 value) => CsWasmOpUnion(
    int7: value.int7,
    varuint32: value.varuint32,
    varuint64: value.varuint64,
    uint32: value.uint32,
    uint64: value.uint64,
    immediate: <int>[for (int i0 = 0; i0 < 2; i0++) value.immediate[i0]],
    brtable: CsWasmBrtable.copy(value.brtable),
  );
}

final class CsBpfOpUnion {
  final int reg;
  final int imm;
  final int off;
  final BpfOpMem mem;
  final int mmem;
  final int msh;
  final int ext;

  const CsBpfOpUnion({
    required this.reg,
    required this.imm,
    required this.off,
    required this.mem,
    required this.mmem,
    required this.msh,
    required this.ext,
  });

  factory CsBpfOpUnion.copy(native.UnnamedUnion$17 value) => CsBpfOpUnion(
    reg: value.reg,
    imm: value.imm,
    off: value.off,
    mem: BpfOpMem.copy(value.mem),
    mmem: value.mmem,
    msh: value.msh,
    ext: value.ext,
  );
}

final class CsRiscvOpUnion {
  final int reg;
  final int imm;
  final double dimm;
  final RiscvOpMem mem;
  final int csr;

  const CsRiscvOpUnion({
    required this.reg,
    required this.imm,
    required this.dimm,
    required this.mem,
    required this.csr,
  });

  factory CsRiscvOpUnion.copy(native.UnnamedUnion$18 value) => CsRiscvOpUnion(
    reg: value.reg,
    imm: value.imm,
    dimm: value.dimm,
    mem: RiscvOpMem.copy(value.mem),
    csr: value.csr,
  );
}

final class CsShOpUnion {
  final int imm;
  final int reg;
  final ShOpMem mem;
  final ShOpDsp dsp;

  const CsShOpUnion({
    required this.imm,
    required this.reg,
    required this.mem,
    required this.dsp,
  });

  factory CsShOpUnion.copy(native.UnnamedUnion$19 value) => CsShOpUnion(
    imm: value.imm,
    reg: value.reg,
    mem: ShOpMem.copy(value.mem),
    dsp: ShOpDsp.copy(value.dsp),
  );
}

final class CsX86OpUnion {
  final int reg;
  final int imm;
  final X86OpMem mem;

  const CsX86OpUnion({required this.reg, required this.imm, required this.mem});

  factory CsX86OpUnion.copy(native.UnnamedUnion$2 value) => CsX86OpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: X86OpMem.copy(value.mem),
  );
}

final class CsTricoreOpUnion {
  final int reg;
  final int imm;
  final TricoreOpMem mem;

  const CsTricoreOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsTricoreOpUnion.copy(native.UnnamedUnion$20 value) =>
      CsTricoreOpUnion(
        reg: value.reg,
        imm: value.imm,
        mem: TricoreOpMem.copy(value.mem),
      );
}

final class CsAlphaOpUnion {
  final int reg;
  final int imm;

  const CsAlphaOpUnion({required this.reg, required this.imm});

  factory CsAlphaOpUnion.copy(native.UnnamedUnion$21 value) =>
      CsAlphaOpUnion(reg: value.reg, imm: value.imm);
}

final class CsHppaOpUnion {
  final int reg;
  final int imm;
  final HppaMem mem;

  const CsHppaOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsHppaOpUnion.copy(native.UnnamedUnion$22 value) => CsHppaOpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: HppaMem.copy(value.mem),
  );
}

final class CsLoongarchOpUnion {
  final int reg;
  final int imm;
  final LoongarchOpMem mem;

  const CsLoongarchOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsLoongarchOpUnion.copy(native.UnnamedUnion$23 value) =>
      CsLoongarchOpUnion(
        reg: value.reg,
        imm: value.imm,
        mem: LoongarchOpMem.copy(value.mem),
      );
}

final class CsXtensaOpUnion {
  final int reg;
  final int imm;
  final CsXtensaOpMem mem;

  const CsXtensaOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsXtensaOpUnion.copy(native.UnnamedUnion$24 value) => CsXtensaOpUnion(
    reg: value.reg,
    imm: value.imm,
    mem: CsXtensaOpMem.copy(value.mem),
  );
}

final class CsArcOpUnion {
  final int reg;
  final int imm;

  const CsArcOpUnion({required this.reg, required this.imm});

  factory CsArcOpUnion.copy(native.UnnamedUnion$25 value) =>
      CsArcOpUnion(reg: value.reg, imm: value.imm);
}

final class CsAarch64OpUnion {
  final int reg;
  final int imm;
  final Aarch64ImmRange imm_range;
  final double fp;
  final Aarch64OpMem mem;
  final Aarch64OpSme sme;
  final Aarch64OpPred pred;

  const CsAarch64OpUnion({
    required this.reg,
    required this.imm,
    required this.imm_range,
    required this.fp,
    required this.mem,
    required this.sme,
    required this.pred,
  });

  factory CsAarch64OpUnion.copy(native.UnnamedUnion$3 value) =>
      CsAarch64OpUnion(
        reg: value.reg,
        imm: value.imm,
        imm_range: Aarch64ImmRange.copy(value.imm_range),
        fp: value.fp,
        mem: Aarch64OpMem.copy(value.mem),
        sme: Aarch64OpSme.copy(value.sme),
        pred: Aarch64OpPred.copy(value.pred),
      );
}

final class Aarch64OpSmeSliceOffset {
  final int imm;
  final Aarch64ImmRange imm_range;

  const Aarch64OpSmeSliceOffset({required this.imm, required this.imm_range});

  factory Aarch64OpSmeSliceOffset.copy(native.UnnamedUnion$4 value) =>
      Aarch64OpSmeSliceOffset(
        imm: value.imm,
        imm_range: Aarch64ImmRange.copy(value.imm_range),
      );
}

final class CsSystemzOpUnion {
  final int reg;
  final int imm;
  final SystemzOpMem mem;

  const CsSystemzOpUnion({
    required this.reg,
    required this.imm,
    required this.mem,
  });

  factory CsSystemzOpUnion.copy(native.UnnamedUnion$5 value) =>
      CsSystemzOpUnion(
        reg: value.reg,
        imm: value.imm,
        mem: SystemzOpMem.copy(value.mem),
      );
}

final class CsArmOpUnion {
  final int reg;
  final ArmSysop sysop;
  final int imm;
  final int pred;
  final double fp;
  final ArmOpMem mem;
  final int setend;

  const CsArmOpUnion({
    required this.reg,
    required this.sysop,
    required this.imm,
    required this.pred,
    required this.fp,
    required this.mem,
    required this.setend,
  });

  factory CsArmOpUnion.copy(native.UnnamedUnion$6 value) => CsArmOpUnion(
    reg: value.reg,
    sysop: ArmSysop.copy(value.sysop),
    imm: value.imm,
    pred: value.pred,
    fp: value.fp,
    mem: ArmOpMem.copy(value.mem),
    setend: value.setend,
  );
}

final class CsM68kOpUnion {
  final int imm;
  final double dimm;
  final double simm;
  final M68kOpFpExtended fp_extended;
  final M68kOpFpPacked fp_packed;
  final int reg;
  final CsM68kOpRegPair reg_pair;

  const CsM68kOpUnion({
    required this.imm,
    required this.dimm,
    required this.simm,
    required this.fp_extended,
    required this.fp_packed,
    required this.reg,
    required this.reg_pair,
  });

  factory CsM68kOpUnion.copy(native.UnnamedUnion$7 value) => CsM68kOpUnion(
    imm: value.imm,
    dimm: value.dimm,
    simm: value.simm,
    fp_extended: M68kOpFpExtended.copy(value.fp_extended),
    fp_packed: M68kOpFpPacked.copy(value.fp_packed),
    reg: value.reg,
    reg_pair: CsM68kOpRegPair.copy(value.reg_pair),
  );
}

final class M68kOpSizeUnion {
  final int cpu_size;
  final int fpu_size;

  const M68kOpSizeUnion({required this.cpu_size, required this.fpu_size});

  factory M68kOpSizeUnion.copy(native.UnnamedUnion$8 value) =>
      M68kOpSizeUnion(cpu_size: value.cpu_size, fpu_size: value.fpu_size);
}

final class CsMipsOpUnion {
  final int reg;
  final int imm;
  final int uimm;
  final MipsOpMem mem;

  const CsMipsOpUnion({
    required this.reg,
    required this.imm,
    required this.uimm,
    required this.mem,
  });

  factory CsMipsOpUnion.copy(native.UnnamedUnion$9 value) => CsMipsOpUnion(
    reg: value.reg,
    imm: value.imm,
    uimm: value.uimm,
    mem: MipsOpMem.copy(value.mem),
  );
}

final class Aarch64ImmRange {
  final int first;
  final int offset;

  const Aarch64ImmRange({required this.first, required this.offset});

  factory Aarch64ImmRange.copy(native.aarch64_imm_range value) =>
      Aarch64ImmRange(first: value.first, offset: value.offset);
}

final class Aarch64OpMem {
  final int base;
  final int index;
  final int disp;

  const Aarch64OpMem({
    required this.base,
    required this.index,
    required this.disp,
  });

  factory Aarch64OpMem.copy(native.aarch64_op_mem value) =>
      Aarch64OpMem(base: value.base, index: value.index, disp: value.disp);
}

final class Aarch64OpPred {
  final int reg;
  final int vec_select;
  final int imm_index;

  const Aarch64OpPred({
    required this.reg,
    required this.vec_select,
    required this.imm_index,
  });

  factory Aarch64OpPred.copy(native.aarch64_op_pred value) => Aarch64OpPred(
    reg: value.reg,
    vec_select: value.vec_select,
    imm_index: value.imm_index,
  );
}

final class Aarch64OpSme {
  final int type;
  final int tile;
  final int slice_reg;
  final Aarch64OpSmeSliceOffset slice_offset;
  final bool has_range_offset;
  final bool is_vertical;

  const Aarch64OpSme({
    required this.type,
    required this.tile,
    required this.slice_reg,
    required this.slice_offset,
    required this.has_range_offset,
    required this.is_vertical,
  });

  factory Aarch64OpSme.copy(native.aarch64_op_sme value) => Aarch64OpSme(
    type: value.type,
    tile: value.tile,
    slice_reg: value.slice_reg,
    slice_offset: Aarch64OpSmeSliceOffset.copy(value.slice_offset),
    has_range_offset: value.has_range_offset,
    is_vertical: value.is_vertical,
  );
}

final class Aarch64Sysop {
  final Aarch64SysopReg reg;
  final Aarch64SysopImm imm;
  final Aarch64SysopAlias alias;
  final int sub_type;

  const Aarch64Sysop({
    required this.reg,
    required this.imm,
    required this.alias,
    required this.sub_type,
  });

  factory Aarch64Sysop.copy(native.aarch64_sysop value) => Aarch64Sysop(
    reg: Aarch64SysopReg.copy(value.reg),
    imm: Aarch64SysopImm.copy(value.imm),
    alias: Aarch64SysopAlias.copy(value.alias),
    sub_type: value.sub_type,
  );
}

final class Aarch64SysopAlias {
  final int svcr;
  final int at;
  final int db;
  final int dc;
  final int isb;
  final int tsb;
  final int prfm;
  final int sveprfm;
  final int rprfm;
  final int pstateimm0_15;
  final int pstateimm0_1;
  final int psb;
  final int bti;
  final int svepredpat;
  final int sveveclenspecifier;
  final int raw_val;

  const Aarch64SysopAlias({
    required this.svcr,
    required this.at,
    required this.db,
    required this.dc,
    required this.isb,
    required this.tsb,
    required this.prfm,
    required this.sveprfm,
    required this.rprfm,
    required this.pstateimm0_15,
    required this.pstateimm0_1,
    required this.psb,
    required this.bti,
    required this.svepredpat,
    required this.sveveclenspecifier,
    required this.raw_val,
  });

  factory Aarch64SysopAlias.copy(native.aarch64_sysop_alias value) =>
      Aarch64SysopAlias(
        svcr: value.svcr,
        at: value.at,
        db: value.db,
        dc: value.dc,
        isb: value.isb,
        tsb: value.tsb,
        prfm: value.prfm,
        sveprfm: value.sveprfm,
        rprfm: value.rprfm,
        pstateimm0_15: value.pstateimm0_15,
        pstateimm0_1: value.pstateimm0_1,
        psb: value.psb,
        bti: value.bti,
        svepredpat: value.svepredpat,
        sveveclenspecifier: value.sveveclenspecifier,
        raw_val: value.raw_val,
      );
}

final class Aarch64SysopImm {
  final int dbnxs;
  final int exactfpimm;
  final int raw_val;

  const Aarch64SysopImm({
    required this.dbnxs,
    required this.exactfpimm,
    required this.raw_val,
  });

  factory Aarch64SysopImm.copy(native.aarch64_sysop_imm value) =>
      Aarch64SysopImm(
        dbnxs: value.dbnxs,
        exactfpimm: value.exactfpimm,
        raw_val: value.raw_val,
      );
}

final class Aarch64SysopReg {
  final int sysreg;
  final int tlbi;
  final int ic;
  final int raw_val;

  const Aarch64SysopReg({
    required this.sysreg,
    required this.tlbi,
    required this.ic,
    required this.raw_val,
  });

  factory Aarch64SysopReg.copy(native.aarch64_sysop_reg value) =>
      Aarch64SysopReg(
        sysreg: value.sysreg,
        tlbi: value.tlbi,
        ic: value.ic,
        raw_val: value.raw_val,
      );
}

final class ArmOpMem {
  final int base;
  final int index;
  final int scale;
  final int disp;
  final int align;

  const ArmOpMem({
    required this.base,
    required this.index,
    required this.scale,
    required this.disp,
    required this.align,
  });

  factory ArmOpMem.copy(native.arm_op_mem value) => ArmOpMem(
    base: value.base,
    index: value.index,
    scale: value.scale,
    disp: value.disp,
    align: value.align,
  );
}

final class ArmSysop {
  final ArmSysopReg reg;
  final int psr_bits;
  final int sysm;
  final int msr_mask;

  const ArmSysop({
    required this.reg,
    required this.psr_bits,
    required this.sysm,
    required this.msr_mask,
  });

  factory ArmSysop.copy(native.arm_sysop value) => ArmSysop(
    reg: ArmSysopReg.copy(value.reg),
    psr_bits: value.psr_bits,
    sysm: value.sysm,
    msr_mask: value.msr_mask,
  );
}

final class ArmSysopReg {
  final int mclasssysreg;
  final int bankedreg;
  final int raw_val;

  const ArmSysopReg({
    required this.mclasssysreg,
    required this.bankedreg,
    required this.raw_val,
  });

  factory ArmSysopReg.copy(native.arm_sysop_reg value) => ArmSysopReg(
    mclasssysreg: value.mclasssysreg,
    bankedreg: value.bankedreg,
    raw_val: value.raw_val,
  );
}

final class BpfOpMem {
  final int base;
  final int disp;

  const BpfOpMem({required this.base, required this.disp});

  factory BpfOpMem.copy(native.bpf_op_mem value) =>
      BpfOpMem(base: value.base, disp: value.disp);
}

final class Aarch64Details extends ArchitectureDetails {
  final int cc;
  final bool update_flags;
  final bool post_index;
  final bool is_doing_sme;
  final int op_count;
  final List<CsAarch64Op> operands;

  Aarch64Details({
    required this.cc,
    required this.update_flags,
    required this.post_index,
    required this.is_doing_sme,
    required this.op_count,
    required List<CsAarch64Op> operands,
  }) : operands = List<CsAarch64Op>.unmodifiable(operands);

  factory Aarch64Details.copy(native.cs_aarch64 value) => Aarch64Details(
    cc: value.cc,
    update_flags: value.update_flags,
    post_index: value.post_index,
    is_doing_sme: value.is_doing_sme,
    op_count: value.op_count,
    operands: <CsAarch64Op>[
      for (int i0 = 0; i0 < 16; i0++) CsAarch64Op.copy(value.operands[i0]),
    ],
  );
}

final class CsAarch64Op {
  final int vector_index;
  final int vas;
  final CsAarch64OpShift shift;
  final int ext;
  final int type;
  final bool is_vreg;
  final CsAarch64OpUnion unnamed;
  final Aarch64Sysop sysop;
  final int access;
  final bool is_list_member;

  const CsAarch64Op({
    required this.vector_index,
    required this.vas,
    required this.shift,
    required this.ext,
    required this.type,
    required this.is_vreg,
    required this.unnamed,
    required this.sysop,
    required this.access,
    required this.is_list_member,
  });

  factory CsAarch64Op.copy(native.cs_aarch64_op value) => CsAarch64Op(
    vector_index: value.vector_index,
    vas: value.vas,
    shift: CsAarch64OpShift.copy(value.shift),
    ext: value.ext,
    type: value.type,
    is_vreg: value.is_vreg,
    unnamed: CsAarch64OpUnion.copy(value.unnamed),
    sysop: Aarch64Sysop.copy(value.sysop),
    access: value.access,
    is_list_member: value.is_list_member,
  );
}

final class AlphaDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsAlphaOp> operands;

  AlphaDetails({required this.op_count, required List<CsAlphaOp> operands})
    : operands = List<CsAlphaOp>.unmodifiable(operands);

  factory AlphaDetails.copy(native.cs_alpha value) => AlphaDetails(
    op_count: value.op_count,
    operands: <CsAlphaOp>[
      for (int i0 = 0; i0 < 3; i0++) CsAlphaOp.copy(value.operands[i0]),
    ],
  );
}

final class CsAlphaOp {
  final int type;
  final CsAlphaOpUnion unnamed;
  final int access;

  const CsAlphaOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsAlphaOp.copy(native.cs_alpha_op value) => CsAlphaOp(
    type: value.type,
    unnamed: CsAlphaOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class ArcDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsArcOp> operands;

  ArcDetails({required this.op_count, required List<CsArcOp> operands})
    : operands = List<CsArcOp>.unmodifiable(operands);

  factory ArcDetails.copy(native.cs_arc value) => ArcDetails(
    op_count: value.op_count,
    operands: <CsArcOp>[
      for (int i0 = 0; i0 < 8; i0++) CsArcOp.copy(value.operands[i0]),
    ],
  );
}

final class CsArcOp {
  final int type;
  final CsArcOpUnion unnamed;
  final int access;

  const CsArcOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsArcOp.copy(native.cs_arc_op value) => CsArcOp(
    type: value.type,
    unnamed: CsArcOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class ArmDetails extends ArchitectureDetails {
  final bool usermode;
  final int vector_size;
  final int vector_data;
  final int cps_mode;
  final int cps_flag;
  final int cc;
  final int vcc;
  final bool update_flags;
  final bool post_index;
  final int mem_barrier;
  final int pred_mask;
  final int op_count;
  final List<CsArmOp> operands;

  ArmDetails({
    required this.usermode,
    required this.vector_size,
    required this.vector_data,
    required this.cps_mode,
    required this.cps_flag,
    required this.cc,
    required this.vcc,
    required this.update_flags,
    required this.post_index,
    required this.mem_barrier,
    required this.pred_mask,
    required this.op_count,
    required List<CsArmOp> operands,
  }) : operands = List<CsArmOp>.unmodifiable(operands);

  factory ArmDetails.copy(native.cs_arm value) => ArmDetails(
    usermode: value.usermode,
    vector_size: value.vector_size,
    vector_data: value.vector_data,
    cps_mode: value.cps_mode,
    cps_flag: value.cps_flag,
    cc: value.cc,
    vcc: value.vcc,
    update_flags: value.update_flags,
    post_index: value.post_index,
    mem_barrier: value.mem_barrier,
    pred_mask: value.pred_mask,
    op_count: value.op_count,
    operands: <CsArmOp>[
      for (int i0 = 0; i0 < 36; i0++) CsArmOp.copy(value.operands[i0]),
    ],
  );
}

final class CsArmOp {
  final int vector_index;
  final CsArmOpShift shift;
  final int type;
  final CsArmOpUnion unnamed;
  final bool subtracted;
  final int access;
  final int neon_lane;

  const CsArmOp({
    required this.vector_index,
    required this.shift,
    required this.type,
    required this.unnamed,
    required this.subtracted,
    required this.access,
    required this.neon_lane,
  });

  factory CsArmOp.copy(native.cs_arm_op value) => CsArmOp(
    vector_index: value.vector_index,
    shift: CsArmOpShift.copy(value.shift),
    type: value.type,
    unnamed: CsArmOpUnion.copy(value.unnamed),
    subtracted: value.subtracted,
    access: value.access,
    neon_lane: value.neon_lane,
  );
}

final class BpfDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsBpfOp> operands;

  BpfDetails({required this.op_count, required List<CsBpfOp> operands})
    : operands = List<CsBpfOp>.unmodifiable(operands);

  factory BpfDetails.copy(native.cs_bpf value) => BpfDetails(
    op_count: value.op_count,
    operands: <CsBpfOp>[
      for (int i0 = 0; i0 < 4; i0++) CsBpfOp.copy(value.operands[i0]),
    ],
  );
}

final class CsBpfOp {
  final int type;
  final CsBpfOpUnion unnamed;
  final bool is_signed;
  final bool is_pkt;
  final int access;

  const CsBpfOp({
    required this.type,
    required this.unnamed,
    required this.is_signed,
    required this.is_pkt,
    required this.access,
  });

  factory CsBpfOp.copy(native.cs_bpf_op value) => CsBpfOp(
    type: value.type,
    unnamed: CsBpfOpUnion.copy(value.unnamed),
    is_signed: value.is_signed,
    is_pkt: value.is_pkt,
    access: value.access,
  );
}

final class EvmDetails extends ArchitectureDetails {
  final int pop;
  final int push;
  final int fee;

  const EvmDetails({required this.pop, required this.push, required this.fee});

  factory EvmDetails.copy(native.cs_evm value) =>
      EvmDetails(pop: value.pop, push: value.push, fee: value.fee);
}

final class HppaDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsHppaOp> operands;

  HppaDetails({required this.op_count, required List<CsHppaOp> operands})
    : operands = List<CsHppaOp>.unmodifiable(operands);

  factory HppaDetails.copy(native.cs_hppa value) => HppaDetails(
    op_count: value.op_count,
    operands: <CsHppaOp>[
      for (int i0 = 0; i0 < 5; i0++) CsHppaOp.copy(value.operands[i0]),
    ],
  );
}

final class CsHppaOp {
  final int type;
  final CsHppaOpUnion unnamed;
  final int access;

  const CsHppaOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsHppaOp.copy(native.cs_hppa_op value) => CsHppaOp(
    type: value.type,
    unnamed: CsHppaOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class LoongarchDetails extends ArchitectureDetails {
  final int format;
  final int op_count;
  final List<CsLoongarchOp> operands;

  LoongarchDetails({
    required this.format,
    required this.op_count,
    required List<CsLoongarchOp> operands,
  }) : operands = List<CsLoongarchOp>.unmodifiable(operands);

  factory LoongarchDetails.copy(native.cs_loongarch value) => LoongarchDetails(
    format: value.format,
    op_count: value.op_count,
    operands: <CsLoongarchOp>[
      for (int i0 = 0; i0 < 8; i0++) CsLoongarchOp.copy(value.operands[i0]),
    ],
  );
}

final class CsLoongarchOp {
  final int type;
  final CsLoongarchOpUnion unnamed;
  final int access;

  const CsLoongarchOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsLoongarchOp.copy(native.cs_loongarch_op value) => CsLoongarchOp(
    type: value.type,
    unnamed: CsLoongarchOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class M680xDetails extends ArchitectureDetails {
  final int flags;
  final int op_count;
  final List<CsM680xOp> operands;

  M680xDetails({
    required this.flags,
    required this.op_count,
    required List<CsM680xOp> operands,
  }) : operands = List<CsM680xOp>.unmodifiable(operands);

  factory M680xDetails.copy(native.cs_m680x value) => M680xDetails(
    flags: value.flags,
    op_count: value.op_count,
    operands: <CsM680xOp>[
      for (int i0 = 0; i0 < 9; i0++) CsM680xOp.copy(value.operands[i0]),
    ],
  );
}

final class CsM680xOp {
  final int type;
  final CsM680xOpUnion unnamed;
  final int size;
  final int access;

  const CsM680xOp({
    required this.type,
    required this.unnamed,
    required this.size,
    required this.access,
  });

  factory CsM680xOp.copy(native.cs_m680x_op value) => CsM680xOp(
    type: value.type,
    unnamed: CsM680xOpUnion.copy(value.unnamed),
    size: value.size,
    access: value.access,
  );
}

final class M68kDetails extends ArchitectureDetails {
  final List<CsM68kOp> operands;
  final M68kOpSize op_size;
  final int op_count;

  M68kDetails({
    required List<CsM68kOp> operands,
    required this.op_size,
    required this.op_count,
  }) : operands = List<CsM68kOp>.unmodifiable(operands);

  factory M68kDetails.copy(native.cs_m68k value) => M68kDetails(
    operands: <CsM68kOp>[
      for (int i0 = 0; i0 < 6; i0++) CsM68kOp.copy(value.operands[i0]),
    ],
    op_size: M68kOpSize.copy(value.op_size),
    op_count: value.op_count,
  );
}

final class CsM68kOp {
  final CsM68kOpUnion unnamed;
  final M68kOpMem mem;
  final M68kOpBrDisp br_disp;
  final int register_bits;
  final int type;
  final int address_mode;
  final int flags;

  const CsM68kOp({
    required this.unnamed,
    required this.mem,
    required this.br_disp,
    required this.register_bits,
    required this.type,
    required this.address_mode,
    required this.flags,
  });

  factory CsM68kOp.copy(native.cs_m68k_op value) => CsM68kOp(
    unnamed: CsM68kOpUnion.copy(value.unnamed),
    mem: M68kOpMem.copy(value.mem),
    br_disp: M68kOpBrDisp.copy(value.br_disp),
    register_bits: value.register_bits,
    type: value.type,
    address_mode: value.address_mode,
    flags: value.flags,
  );
}

final class CsM68kOpRegPair {
  final int reg_0;
  final int reg_1;

  const CsM68kOpRegPair({required this.reg_0, required this.reg_1});

  factory CsM68kOpRegPair.copy(native.cs_m68k_op_reg_pair value) =>
      CsM68kOpRegPair(reg_0: value.reg_0, reg_1: value.reg_1);
}

final class MipsDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsMipsOp> operands;

  MipsDetails({required this.op_count, required List<CsMipsOp> operands})
    : operands = List<CsMipsOp>.unmodifiable(operands);

  factory MipsDetails.copy(native.cs_mips value) => MipsDetails(
    op_count: value.op_count,
    operands: <CsMipsOp>[
      for (int i0 = 0; i0 < 16; i0++) CsMipsOp.copy(value.operands[i0]),
    ],
  );
}

final class CsMipsOp {
  final int type;
  final CsMipsOpUnion unnamed;
  final bool is_reglist;
  final bool is_unsigned;
  final int access;

  const CsMipsOp({
    required this.type,
    required this.unnamed,
    required this.is_reglist,
    required this.is_unsigned,
    required this.access,
  });

  factory CsMipsOp.copy(native.cs_mips_op value) => CsMipsOp(
    type: value.type,
    unnamed: CsMipsOpUnion.copy(value.unnamed),
    is_reglist: value.is_reglist,
    is_unsigned: value.is_unsigned,
    access: value.access,
  );
}

final class Mos65xxDetails extends ArchitectureDetails {
  final int am;
  final bool modifies_flags;
  final int op_count;
  final List<CsMos65xxOp> operands;

  Mos65xxDetails({
    required this.am,
    required this.modifies_flags,
    required this.op_count,
    required List<CsMos65xxOp> operands,
  }) : operands = List<CsMos65xxOp>.unmodifiable(operands);

  factory Mos65xxDetails.copy(native.cs_mos65xx value) => Mos65xxDetails(
    am: value.am,
    modifies_flags: value.modifies_flags,
    op_count: value.op_count,
    operands: <CsMos65xxOp>[
      for (int i0 = 0; i0 < 3; i0++) CsMos65xxOp.copy(value.operands[i0]),
    ],
  );
}

final class CsMos65xxOp {
  final int type;
  final CsMos65xxOpUnion unnamed;

  const CsMos65xxOp({required this.type, required this.unnamed});

  factory CsMos65xxOp.copy(native.cs_mos65xx_op value) => CsMos65xxOp(
    type: value.type,
    unnamed: CsMos65xxOpUnion.copy(value.unnamed),
  );
}

final class PpcDetails extends ArchitectureDetails {
  final PpcBc bc;
  final bool update_cr0;
  final int format;
  final int op_count;
  final List<CsPpcOp> operands;

  PpcDetails({
    required this.bc,
    required this.update_cr0,
    required this.format,
    required this.op_count,
    required List<CsPpcOp> operands,
  }) : operands = List<CsPpcOp>.unmodifiable(operands);

  factory PpcDetails.copy(native.cs_ppc value) => PpcDetails(
    bc: PpcBc.copy(value.bc),
    update_cr0: value.update_cr0,
    format: value.format,
    op_count: value.op_count,
    operands: <CsPpcOp>[
      for (int i0 = 0; i0 < 8; i0++) CsPpcOp.copy(value.operands[i0]),
    ],
  );
}

final class CsPpcOp {
  final int type;
  final CsPpcOpUnion unnamed;
  final int access;

  const CsPpcOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsPpcOp.copy(native.cs_ppc_op value) => CsPpcOp(
    type: value.type,
    unnamed: CsPpcOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class RiscvDetails extends ArchitectureDetails {
  final bool need_effective_addr;
  final int op_count;
  final List<CsRiscvOp> operands;
  final int rounding_mode;

  RiscvDetails({
    required this.need_effective_addr,
    required this.op_count,
    required List<CsRiscvOp> operands,
    required this.rounding_mode,
  }) : operands = List<CsRiscvOp>.unmodifiable(operands);

  factory RiscvDetails.copy(native.cs_riscv value) => RiscvDetails(
    need_effective_addr: value.need_effective_addr,
    op_count: value.op_count,
    operands: <CsRiscvOp>[
      for (int i0 = 0; i0 < 8; i0++) CsRiscvOp.copy(value.operands[i0]),
    ],
    rounding_mode: value.rounding_mode,
  );
}

final class CsRiscvOp {
  final int type;
  final CsRiscvOpUnion unnamed;
  final int access;

  const CsRiscvOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsRiscvOp.copy(native.cs_riscv_op value) => CsRiscvOp(
    type: value.type,
    unnamed: CsRiscvOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class ShDetails extends ArchitectureDetails {
  final int insn;
  final int size;
  final int op_count;
  final List<CsShOp> operands;

  ShDetails({
    required this.insn,
    required this.size,
    required this.op_count,
    required List<CsShOp> operands,
  }) : operands = List<CsShOp>.unmodifiable(operands);

  factory ShDetails.copy(native.cs_sh value) => ShDetails(
    insn: value.insn,
    size: value.size,
    op_count: value.op_count,
    operands: <CsShOp>[
      for (int i0 = 0; i0 < 3; i0++) CsShOp.copy(value.operands[i0]),
    ],
  );
}

final class CsShOp {
  final int type;
  final CsShOpUnion unnamed;

  const CsShOp({required this.type, required this.unnamed});

  factory CsShOp.copy(native.cs_sh_op value) =>
      CsShOp(type: value.type, unnamed: CsShOpUnion.copy(value.unnamed));
}

final class SparcDetails extends ArchitectureDetails {
  final int cc;
  final int cc_field;
  final int hint;
  final int format;
  final int op_count;
  final List<CsSparcOp> operands;

  SparcDetails({
    required this.cc,
    required this.cc_field,
    required this.hint,
    required this.format,
    required this.op_count,
    required List<CsSparcOp> operands,
  }) : operands = List<CsSparcOp>.unmodifiable(operands);

  factory SparcDetails.copy(native.cs_sparc value) => SparcDetails(
    cc: value.cc,
    cc_field: value.cc_field,
    hint: value.hint,
    format: value.format,
    op_count: value.op_count,
    operands: <CsSparcOp>[
      for (int i0 = 0; i0 < 6; i0++) CsSparcOp.copy(value.operands[i0]),
    ],
  );
}

final class CsSparcOp {
  final int type;
  final CsSparcOpUnion unnamed;
  final int access;

  const CsSparcOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsSparcOp.copy(native.cs_sparc_op value) => CsSparcOp(
    type: value.type,
    unnamed: CsSparcOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class SystemzDetails extends ArchitectureDetails {
  final int cc;
  final int format;
  final int op_count;
  final List<CsSystemzOp> operands;

  SystemzDetails({
    required this.cc,
    required this.format,
    required this.op_count,
    required List<CsSystemzOp> operands,
  }) : operands = List<CsSystemzOp>.unmodifiable(operands);

  factory SystemzDetails.copy(native.cs_systemz value) => SystemzDetails(
    cc: value.cc,
    format: value.format,
    op_count: value.op_count,
    operands: <CsSystemzOp>[
      for (int i0 = 0; i0 < 6; i0++) CsSystemzOp.copy(value.operands[i0]),
    ],
  );
}

final class CsSystemzOp {
  final int type;
  final CsSystemzOpUnion unnamed;
  final int access;
  final int imm_width;

  const CsSystemzOp({
    required this.type,
    required this.unnamed,
    required this.access,
    required this.imm_width,
  });

  factory CsSystemzOp.copy(native.cs_systemz_op value) => CsSystemzOp(
    type: value.type,
    unnamed: CsSystemzOpUnion.copy(value.unnamed),
    access: value.access,
    imm_width: value.imm_width,
  );
}

final class Tms320c64xDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsTms320c64xOp> operands;
  final Tms320c64xDetailsCondition condition;
  final Tms320c64xDetailsFunit funit;
  final int parallel;

  Tms320c64xDetails({
    required this.op_count,
    required List<CsTms320c64xOp> operands,
    required this.condition,
    required this.funit,
    required this.parallel,
  }) : operands = List<CsTms320c64xOp>.unmodifiable(operands);

  factory Tms320c64xDetails.copy(native.cs_tms320c64x value) =>
      Tms320c64xDetails(
        op_count: value.op_count,
        operands: <CsTms320c64xOp>[
          for (int i0 = 0; i0 < 8; i0++)
            CsTms320c64xOp.copy(value.operands[i0]),
        ],
        condition: Tms320c64xDetailsCondition.copy(value.condition),
        funit: Tms320c64xDetailsFunit.copy(value.funit),
        parallel: value.parallel,
      );
}

final class CsTms320c64xOp {
  final int type;
  final CsTms320c64xOpUnion unnamed;

  const CsTms320c64xOp({required this.type, required this.unnamed});

  factory CsTms320c64xOp.copy(native.cs_tms320c64x_op value) => CsTms320c64xOp(
    type: value.type,
    unnamed: CsTms320c64xOpUnion.copy(value.unnamed),
  );
}

final class TricoreDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsTricoreOp> operands;
  final bool update_flags;

  TricoreDetails({
    required this.op_count,
    required List<CsTricoreOp> operands,
    required this.update_flags,
  }) : operands = List<CsTricoreOp>.unmodifiable(operands);

  factory TricoreDetails.copy(native.cs_tricore value) => TricoreDetails(
    op_count: value.op_count,
    operands: <CsTricoreOp>[
      for (int i0 = 0; i0 < 8; i0++) CsTricoreOp.copy(value.operands[i0]),
    ],
    update_flags: value.update_flags,
  );
}

final class CsTricoreOp {
  final int type;
  final CsTricoreOpUnion unnamed;
  final int access;

  const CsTricoreOp({
    required this.type,
    required this.unnamed,
    required this.access,
  });

  factory CsTricoreOp.copy(native.cs_tricore_op value) => CsTricoreOp(
    type: value.type,
    unnamed: CsTricoreOpUnion.copy(value.unnamed),
    access: value.access,
  );
}

final class WasmDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsWasmOp> operands;

  WasmDetails({required this.op_count, required List<CsWasmOp> operands})
    : operands = List<CsWasmOp>.unmodifiable(operands);

  factory WasmDetails.copy(native.cs_wasm value) => WasmDetails(
    op_count: value.op_count,
    operands: <CsWasmOp>[
      for (int i0 = 0; i0 < 2; i0++) CsWasmOp.copy(value.operands[i0]),
    ],
  );
}

final class CsWasmBrtable {
  final int length;
  final int address;
  final int default_target;

  const CsWasmBrtable({
    required this.length,
    required this.address,
    required this.default_target,
  });

  factory CsWasmBrtable.copy(native.cs_wasm_brtable value) => CsWasmBrtable(
    length: value.length,
    address: value.address,
    default_target: value.default_target,
  );
}

final class CsWasmOp {
  final int type;
  final int size;
  final CsWasmOpUnion unnamed;

  const CsWasmOp({
    required this.type,
    required this.size,
    required this.unnamed,
  });

  factory CsWasmOp.copy(native.cs_wasm_op value) => CsWasmOp(
    type: value.type,
    size: value.size,
    unnamed: CsWasmOpUnion.copy(value.unnamed),
  );
}

final class X86Details extends ArchitectureDetails {
  final List<int> prefix;
  final List<int> opcode;
  final int rex;
  final int addr_size;
  final int modrm;
  final int sib;
  final int disp;
  final int sib_index;
  final int sib_scale;
  final int sib_base;
  final int xop_cc;
  final int sse_cc;
  final int avx_cc;
  final bool avx_sae;
  final int avx_rm;
  final X86DetailsUnion unnamed;
  final int op_count;
  final List<CsX86Op> operands;
  final CsX86Encoding encoding;

  X86Details({
    required List<int> prefix,
    required List<int> opcode,
    required this.rex,
    required this.addr_size,
    required this.modrm,
    required this.sib,
    required this.disp,
    required this.sib_index,
    required this.sib_scale,
    required this.sib_base,
    required this.xop_cc,
    required this.sse_cc,
    required this.avx_cc,
    required this.avx_sae,
    required this.avx_rm,
    required this.unnamed,
    required this.op_count,
    required List<CsX86Op> operands,
    required this.encoding,
  }) : prefix = List<int>.unmodifiable(prefix),
       opcode = List<int>.unmodifiable(opcode),
       operands = List<CsX86Op>.unmodifiable(operands);

  factory X86Details.copy(native.cs_x86 value) => X86Details(
    prefix: <int>[for (int i0 = 0; i0 < 4; i0++) value.prefix[i0]],
    opcode: <int>[for (int i0 = 0; i0 < 4; i0++) value.opcode[i0]],
    rex: value.rex,
    addr_size: value.addr_size,
    modrm: value.modrm,
    sib: value.sib,
    disp: value.disp,
    sib_index: value.sib_index,
    sib_scale: value.sib_scale,
    sib_base: value.sib_base,
    xop_cc: value.xop_cc,
    sse_cc: value.sse_cc,
    avx_cc: value.avx_cc,
    avx_sae: value.avx_sae,
    avx_rm: value.avx_rm,
    unnamed: X86DetailsUnion.copy(value.unnamed),
    op_count: value.op_count,
    operands: <CsX86Op>[
      for (int i0 = 0; i0 < 8; i0++) CsX86Op.copy(value.operands[i0]),
    ],
    encoding: CsX86Encoding.copy(value.encoding),
  );
}

final class CsX86Encoding {
  final int modrm_offset;
  final int disp_offset;
  final int disp_size;
  final int imm_offset;
  final int imm_size;

  const CsX86Encoding({
    required this.modrm_offset,
    required this.disp_offset,
    required this.disp_size,
    required this.imm_offset,
    required this.imm_size,
  });

  factory CsX86Encoding.copy(native.cs_x86_encoding value) => CsX86Encoding(
    modrm_offset: value.modrm_offset,
    disp_offset: value.disp_offset,
    disp_size: value.disp_size,
    imm_offset: value.imm_offset,
    imm_size: value.imm_size,
  );
}

final class CsX86Op {
  final int type;
  final CsX86OpUnion unnamed;
  final int size;
  final int access;
  final int avx_bcast;
  final bool avx_zero_opmask;

  const CsX86Op({
    required this.type,
    required this.unnamed,
    required this.size,
    required this.access,
    required this.avx_bcast,
    required this.avx_zero_opmask,
  });

  factory CsX86Op.copy(native.cs_x86_op value) => CsX86Op(
    type: value.type,
    unnamed: CsX86OpUnion.copy(value.unnamed),
    size: value.size,
    access: value.access,
    avx_bcast: value.avx_bcast,
    avx_zero_opmask: value.avx_zero_opmask,
  );
}

final class XcoreDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsXcoreOp> operands;

  XcoreDetails({required this.op_count, required List<CsXcoreOp> operands})
    : operands = List<CsXcoreOp>.unmodifiable(operands);

  factory XcoreDetails.copy(native.cs_xcore value) => XcoreDetails(
    op_count: value.op_count,
    operands: <CsXcoreOp>[
      for (int i0 = 0; i0 < 8; i0++) CsXcoreOp.copy(value.operands[i0]),
    ],
  );
}

final class CsXcoreOp {
  final int type;
  final CsXcoreOpUnion unnamed;

  const CsXcoreOp({required this.type, required this.unnamed});

  factory CsXcoreOp.copy(native.cs_xcore_op value) =>
      CsXcoreOp(type: value.type, unnamed: CsXcoreOpUnion.copy(value.unnamed));
}

final class XtensaDetails extends ArchitectureDetails {
  final int op_count;
  final List<CsXtensaOp> operands;
  final int format;

  XtensaDetails({
    required this.op_count,
    required List<CsXtensaOp> operands,
    required this.format,
  }) : operands = List<CsXtensaOp>.unmodifiable(operands);

  factory XtensaDetails.copy(native.cs_xtensa value) => XtensaDetails(
    op_count: value.op_count,
    operands: <CsXtensaOp>[
      for (int i0 = 0; i0 < 8; i0++) CsXtensaOp.copy(value.operands[i0]),
    ],
    format: value.format,
  );
}

final class CsXtensaOp {
  final int type;
  final int access;
  final CsXtensaOpUnion unnamed;

  const CsXtensaOp({
    required this.type,
    required this.access,
    required this.unnamed,
  });

  factory CsXtensaOp.copy(native.cs_xtensa_op value) => CsXtensaOp(
    type: value.type,
    access: value.access,
    unnamed: CsXtensaOpUnion.copy(value.unnamed),
  );
}

final class CsXtensaOpMem {
  final int base;
  final int disp;

  const CsXtensaOpMem({required this.base, required this.disp});

  factory CsXtensaOpMem.copy(native.cs_xtensa_op_mem value) =>
      CsXtensaOpMem(base: value.base, disp: value.disp);
}

final class HppaMem {
  final int base;
  final int space;

  const HppaMem({required this.base, required this.space});

  factory HppaMem.copy(native.hppa_mem value) =>
      HppaMem(base: value.base, space: value.space);
}

final class LoongarchOpMem {
  final int base;
  final int index;
  final int disp;

  const LoongarchOpMem({
    required this.base,
    required this.index,
    required this.disp,
  });

  factory LoongarchOpMem.copy(native.loongarch_op_mem value) =>
      LoongarchOpMem(base: value.base, index: value.index, disp: value.disp);
}

final class M680xOpExt {
  final int address;
  final bool indirect;

  const M680xOpExt({required this.address, required this.indirect});

  factory M680xOpExt.copy(native.m680x_op_ext value) =>
      M680xOpExt(address: value.address, indirect: value.indirect);
}

final class M680xOpIdx {
  final int base_reg;
  final int offset_reg;
  final int offset;
  final int offset_addr;
  final int offset_bits;
  final int inc_dec;
  final int flags;

  const M680xOpIdx({
    required this.base_reg,
    required this.offset_reg,
    required this.offset,
    required this.offset_addr,
    required this.offset_bits,
    required this.inc_dec,
    required this.flags,
  });

  factory M680xOpIdx.copy(native.m680x_op_idx value) => M680xOpIdx(
    base_reg: value.base_reg,
    offset_reg: value.offset_reg,
    offset: value.offset,
    offset_addr: value.offset_addr,
    offset_bits: value.offset_bits,
    inc_dec: value.inc_dec,
    flags: value.flags,
  );
}

final class M680xOpRel {
  final int address;
  final int offset;

  const M680xOpRel({required this.address, required this.offset});

  factory M680xOpRel.copy(native.m680x_op_rel value) =>
      M680xOpRel(address: value.address, offset: value.offset);
}

final class M68kOpBrDisp {
  final int disp;
  final int disp_size;

  const M68kOpBrDisp({required this.disp, required this.disp_size});

  factory M68kOpBrDisp.copy(native.m68k_op_br_disp value) =>
      M68kOpBrDisp(disp: value.disp, disp_size: value.disp_size);
}

final class M68kOpFpExtended {
  final int significand;
  final int sign_exp;
  final int reserved;

  const M68kOpFpExtended({
    required this.significand,
    required this.sign_exp,
    required this.reserved,
  });

  factory M68kOpFpExtended.copy(native.m68k_op_fp_extended value) =>
      M68kOpFpExtended(
        significand: value.significand,
        sign_exp: value.sign_exp,
        reserved: value.reserved,
      );
}

final class M68kOpFpPacked {
  final int header;
  final int fraction;

  const M68kOpFpPacked({required this.header, required this.fraction});

  factory M68kOpFpPacked.copy(native.m68k_op_fp_packed value) =>
      M68kOpFpPacked(header: value.header, fraction: value.fraction);
}

final class M68kOpMem {
  final int base_reg;
  final int index_reg;
  final int in_base_reg;
  final int in_disp;
  final int out_disp;
  final int disp;
  final int scale;
  final int bitfield;
  final int width;
  final int offset;
  final int index_size;
  final int in_disp_size;
  final int out_disp_size;
  final int disp_size;
  final int address;

  const M68kOpMem({
    required this.base_reg,
    required this.index_reg,
    required this.in_base_reg,
    required this.in_disp,
    required this.out_disp,
    required this.disp,
    required this.scale,
    required this.bitfield,
    required this.width,
    required this.offset,
    required this.index_size,
    required this.in_disp_size,
    required this.out_disp_size,
    required this.disp_size,
    required this.address,
  });

  factory M68kOpMem.copy(native.m68k_op_mem value) => M68kOpMem(
    base_reg: value.base_reg,
    index_reg: value.index_reg,
    in_base_reg: value.in_base_reg,
    in_disp: value.in_disp,
    out_disp: value.out_disp,
    disp: value.disp,
    scale: value.scale,
    bitfield: value.bitfield,
    width: value.width,
    offset: value.offset,
    index_size: value.index_size,
    in_disp_size: value.in_disp_size,
    out_disp_size: value.out_disp_size,
    disp_size: value.disp_size,
    address: value.address,
  );
}

final class M68kOpSize {
  final int type;
  final M68kOpSizeUnion unnamed;

  const M68kOpSize({required this.type, required this.unnamed});

  factory M68kOpSize.copy(native.m68k_op_size value) => M68kOpSize(
    type: value.type,
    unnamed: M68kOpSizeUnion.copy(value.unnamed),
  );
}

final class MipsOpMem {
  final int base;
  final int disp;

  const MipsOpMem({required this.base, required this.disp});

  factory MipsOpMem.copy(native.mips_op_mem value) =>
      MipsOpMem(base: value.base, disp: value.disp);
}

final class PpcBc {
  final int bo;
  final int bi;
  final int crX_bit;
  final int crX;
  final int hint;
  final int pred_cr;
  final int pred_ctr;
  final int bh;

  const PpcBc({
    required this.bo,
    required this.bi,
    required this.crX_bit,
    required this.crX,
    required this.hint,
    required this.pred_cr,
    required this.pred_ctr,
    required this.bh,
  });

  factory PpcBc.copy(native.ppc_bc value) => PpcBc(
    bo: value.bo,
    bi: value.bi,
    crX_bit: value.crX_bit,
    crX: value.crX,
    hint: value.hint,
    pred_cr: value.pred_cr,
    pred_ctr: value.pred_ctr,
    bh: value.bh,
  );
}

final class PpcOpMem {
  final int base;
  final int disp;
  final int offset;

  const PpcOpMem({
    required this.base,
    required this.disp,
    required this.offset,
  });

  factory PpcOpMem.copy(native.ppc_op_mem value) =>
      PpcOpMem(base: value.base, disp: value.disp, offset: value.offset);
}

final class RiscvOpMem {
  final int base;
  final int disp;

  const RiscvOpMem({required this.base, required this.disp});

  factory RiscvOpMem.copy(native.riscv_op_mem value) =>
      RiscvOpMem(base: value.base, disp: value.disp);
}

final class ShOpDsp {
  final int insn;
  final List<int> operand;
  final List<int> r;
  final int cc;
  final int imm;
  final int size;

  ShOpDsp({
    required this.insn,
    required List<int> operand,
    required List<int> r,
    required this.cc,
    required this.imm,
    required this.size,
  }) : operand = List<int>.unmodifiable(operand),
       r = List<int>.unmodifiable(r);

  factory ShOpDsp.copy(native.sh_op_dsp value) => ShOpDsp(
    insn: value.insn,
    operand: <int>[for (int i0 = 0; i0 < 2; i0++) value.operand[i0]],
    r: <int>[for (int i0 = 0; i0 < 6; i0++) value.r[i0]],
    cc: value.cc,
    imm: value.imm,
    size: value.size,
  );
}

final class ShOpMem {
  final int address;
  final int reg;
  final int disp;

  const ShOpMem({required this.address, required this.reg, required this.disp});

  factory ShOpMem.copy(native.sh_op_mem value) =>
      ShOpMem(address: value.address, reg: value.reg, disp: value.disp);
}

final class SparcOpMem {
  final int base;
  final int index;
  final int disp;

  const SparcOpMem({
    required this.base,
    required this.index,
    required this.disp,
  });

  factory SparcOpMem.copy(native.sparc_op_mem value) =>
      SparcOpMem(base: value.base, index: value.index, disp: value.disp);
}

final class SystemzOpMem {
  final int am;
  final int base;
  final int index;
  final int length;
  final int disp;

  const SystemzOpMem({
    required this.am,
    required this.base,
    required this.index,
    required this.length,
    required this.disp,
  });

  factory SystemzOpMem.copy(native.systemz_op_mem value) => SystemzOpMem(
    am: value.am,
    base: value.base,
    index: value.index,
    length: value.length,
    disp: value.disp,
  );
}

final class Tms320c64xOpMem {
  final int base;
  final int disp;
  final int unit;
  final int scaled;
  final int disptype;
  final int direction;
  final int modify;

  const Tms320c64xOpMem({
    required this.base,
    required this.disp,
    required this.unit,
    required this.scaled,
    required this.disptype,
    required this.direction,
    required this.modify,
  });

  factory Tms320c64xOpMem.copy(native.tms320c64x_op_mem value) =>
      Tms320c64xOpMem(
        base: value.base,
        disp: value.disp,
        unit: value.unit,
        scaled: value.scaled,
        disptype: value.disptype,
        direction: value.direction,
        modify: value.modify,
      );
}

final class TricoreOpMem {
  final int base;
  final int disp;

  const TricoreOpMem({required this.base, required this.disp});

  factory TricoreOpMem.copy(native.tricore_op_mem value) =>
      TricoreOpMem(base: value.base, disp: value.disp);
}

final class X86OpMem {
  final int segment;
  final int base;
  final int index;
  final int scale;
  final int disp;

  const X86OpMem({
    required this.segment,
    required this.base,
    required this.index,
    required this.scale,
    required this.disp,
  });

  factory X86OpMem.copy(native.x86_op_mem value) => X86OpMem(
    segment: value.segment,
    base: value.base,
    index: value.index,
    scale: value.scale,
    disp: value.disp,
  );
}

final class XcoreOpMem {
  final int base;
  final int index;
  final int disp;
  final int direct;

  const XcoreOpMem({
    required this.base,
    required this.index,
    required this.disp,
    required this.direct,
  });

  factory XcoreOpMem.copy(native.xcore_op_mem value) => XcoreOpMem(
    base: value.base,
    index: value.index,
    disp: value.disp,
    direct: value.direct,
  );
}
