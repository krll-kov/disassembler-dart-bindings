# Disassembler

Dart decoding of machine instructions with Zydis, exarmo or Capstone. The build hooks compile the engines and architectures you select into one native library.

## Installation

Add the dependency and the build settings to your application's `pubspec.yaml`:

```yaml
dependencies:
  disassembler:
    git:
      url: https://github.com/krll-kov/capstone-dart-bindings

hooks:
  user_defines:
    disassembler:
      backends:
        zydis:
          architectures: [x86]
          features: [decoder]
        exarmo:
          architectures: [arm64]
          features: [decoder]
```

This enables Zydis for x86 and x64 and exarmo for ARM64. Every engine is off by default: omit an engine to exclude it, or use `backends: {}` to build no native code. The settings in this package's own `pubspec.yaml` enable every engine for its tests and do not affect your application.

## Build settings

Each engine under `backends` takes 2 required lists, `architectures` and `features`. Unknown keys and empty lists stop the build with an error.

`architectures` selects instruction families. `x86` covers x86 and x64, `arm` covers ARM32 and Thumb, and `arm64` is AArch64 for every engine. Zydis accepts `x86`, exarmo accepts `arm` and `arm64`, and Capstone accepts `arm`, `arm64`, `m68k`, `mips`, `ppc`, `sparc`, `systemz`, `xcore`, `x86`, `tms320c64x`, `m680x`, `evm`, `mos65xx`, `wasm`, `bpf`, `riscv`, `sh`, `tricore`, `alpha`, `hppa`, `loongarch`, `xtensa` and `arc`. Capstone's `x86` also decodes 16-bit code through its own API.

`features` must contain `decoder`. Zydis also accepts `encoder` and `formatter` for encoding and instruction text, and Capstone and exarmo accept only `decoder`.

All 3 engines together:

```yaml
hooks:
  user_defines:
    disassembler:
      backends:
        zydis:
          architectures: [x86]
          features: [decoder, encoder, formatter]
        exarmo:
          architectures: [arm64]
          features: [decoder]
        capstone:
          architectures: [x86, arm64]
          features: [decoder]
```

`Disassembler` takes the engine explicitly. An engine or architecture left out of the build throws `UnsupportedError`, and the package never falls back to another engine.

## Decoding

```dart
import 'dart:typed_data';
import 'package:disassembler/disassembler.dart';

void main() {
  final decoder = Disassembler(
    DisassemblerArch.x64,
    backend: DisassemblerBackend.zydis,
  );
  try {
    final bytes = Uint8List.fromList([0x48, 0x8b, 0x43, 0x08, 0xc3]);
    for (final instruction in decoder.decode(bytes, address: 0x1000)) {
      print('${instruction.address.toRadixString(16)} ${instruction.mnemonic}');
      for (final operand in instruction.operands) {
        if (operand.kind == OperandKind.memory) {
          print(operand.memory!.displacement);
        }
      }
    }
  } finally {
    decoder.close();
  }
}
```

The common API decodes `x86`, `x64`, `arm`, `thumb` and `arm64`. An instruction has operands, control flow and, where the engine reports it, register access. Relative branch targets are absolute addresses. Register IDs differ between engines, so convert them with `registerName` and `registerId`. Register access is `null` where the engine has none. Zydis reports it for every instruction. exarmo has no register access of its own, so the package reads the registers each A64 encoding writes and whether each operand is read or written from `src/aarch64_effects.h`, a table generated from the ASL of Arm's A64 ISA XML (FAT-2026-06); 3622 of 4746 encodings are in the table, and SME writes to ZA, SVE writes to register ranges, MOPS, `eret`, `msr` of SM and the 81 encodings added in 2026-09 return `null`. Capstone reports it through `cs_regs_access`.

A panic inside exarmo returns to C by `longjmp` and decodes as an invalid instruction, so a malformed word never terminates the process; `test/exarmo_guard_test.dart` checks 2000 panics on 4 threads.

With `postIndex == true` the memory access uses the base before its update. The update stays where the engine puts it: in the memory displacement or in a separate immediate operand.

`Instruction.details` holds the engine's full output as `ZydisInstructionDetails`, `ExarmoInstructionDetails` or `CapstoneInstructionDetails`. Zydis and Capstone use the same types for invalid input, and exarmo returns `InvalidInstructionDetails` with its native status.

Invalid input gives `valid == false` and decoding continues. A successful decode does not prove the bytes are code. Each engine's own API is in `zydis.dart`, `exarmo.dart` and `capstone.dart`, including Capstone's other architectures, with its own error handling. The generated C bindings are in `zydis_native.dart`, `exarmo_native.dart` and `native.dart`.

## Batch decoding

`decode` creates an object per instruction. For large inputs use `DisassemblerBuffer`, `decoder.reader(buffer)` and `DecodedBatch`: one native call writes instructions, operands and register lists into the batch's arrays, and you read fields by index, such as `batch.address(i)`, `batch.canonicalMnemonic(i)`, `batch.operandImmediate(i, k)` and `batch.registersWritten(i)`. Each indexed operand accessor repeats two bound checks and the row computation, so a loop that reads several fields of one operand takes `batch.operandRow(i, k)` once and reads through the `At` accessors, `batch.operandKindAt(row)`, `batch.operandRegisterAt(row)`, `batch.memoryDisplacementAt(row)` and the rest. `batch.registersWritten(i)` allocates a list; `batch.registerIds` with `batch.registersWrittenStart(i)` and `batch.registersWrittenCount(i)` reads the same ids in place.

```dart
final buffer = DisassemblerBuffer(bytes);
final reader = decoder.reader(buffer);
final batch = DecodedBatch();
try {
  reader.visit(batch, (batch) {
    for (int i = 0; i < batch.length; i++) {
      print('${batch.address(i).toRadixString(16)} ${batch.mnemonic(i)}');
    }
    return true;
  }, address: 0x1000);
} finally {
  batch.close();
  reader.close();
  buffer.close();
}
```

`reader.decode(batch, start: ..., end: ..., address: ...)` fills the batch once and returns the instruction count, and `start + batch.consumed` is the next offset. `address` is the address of the byte at `start`. `reader.visit` repeats `decode` up to `end` and stops when the callback returns `false`. Both take `stopAfter`, a set of `ControlFlow` values, and `stopAfterInvalid`, and stop after the first instruction that matches, so a basic block costs no decoding after its branch. Thumb IT state is kept between `decode` calls only with `resume: true`, and `visit` passes it between its own batches.

The next decode overwrites the batch, so copy an instruction with `batch.instruction(i)` to keep it. Close the reader before its buffer. Instructions from `decoder.decode` stay valid after `decoder.close()`.

`reader.callTargets(start: ..., end: ..., address: ...)` returns the targets of direct calls in a linear decode of the range, in order, from one native call that fills no batch. It returns `null` for Capstone and for 32-bit ARM, where `decode` gives the same calls.

## Selective decoding

`DecodeSelection` limits operand and register decoding to the instructions a reader uses: those whose `ControlFlow` is in `flows` or whose engine id, as `batch.id(i)` returns it, is in `ids`. Zydis ids are `ZydisMnemonic` values from `zydis_native.dart` and exarmo ARM64 ids are `exarmo_aarch64_encoding` values from `exarmo_native.dart`. Pass it as `select:` to `reader.decode` or `reader.visit`. The other instructions are written with address, size, id, mnemonics and flow but no operands, register access or condition code, and `batch.brief(i)` is true for them. With `skipOthers: true` they are not written at all, `consumed` still covers their bytes, and an instruction that a `stopAfter` flow ends the decode on is written in any case, so `batch.stopped` keeps working. Capstone and 32-bit ARM throw `UnsupportedError` on a selection.

Zydis decodes the instruction first and its operands only for a selected one. exarmo ARM64 does the same, and with `skipOthers` it tests every word against the fixed bits of the selected encodings before it decodes any, from a table generated out of Arm's A64 ISA XML into `src/aarch64_effects.h`: 4665 of 4746 encodings have a pattern and `DecodeSelection.arm64Pattern(id)` returns its mask and value. A selection by flow covers every encoding whose probe word branches and the 28 encodings whose probe words are all unallocated. The 81 encodings added in 2026-09 have no pattern, so a selection by one of their ids decodes every word and a selection by flow does not reach them. `stopAfterInvalid` also decodes every word, since a skipped word is never found invalid.

Linear decode of the executable section, best of 5, Apple M4 Max, ns per instruction. The id sets are 66 ARM64 encodings that match 61% of the words and 29 x86 mnemonics that match 85% of the instructions.

| Decode | ntdll ARM64, 777 K | vk_swiftshader ARM64, 3.6 M | OwHelper x64, 4.6 M |
| --- | --- | --- | --- |
| full batch | 85 | 89 | 68 |
| brief, calls selected | 47 | 48 | 39 |
| brief, calls and the id set | 71 | 80 | 65 |
| skipping, calls selected | 4.3 | 6.4 | 38 |
| skipping, calls and the id set | 60 | 75 | 65 |

## Known engine gaps

Capstone 6.0.0-Alpha11 reports `access = 0` and `avx_bcast = 0` for the masked broadcast `VADDPS` bytes `62 f1 5c db 58 10`, and no groups for the `VXORPS` bytes `62 f1 7c c9 57 c0`. The package passes these values through unchanged.

## Build requirements

Dart 3.13 or later and a native compiler: Xcode Command Line Tools on macOS, Visual Studio with the "Desktop development with C++" workload and a Windows SDK on Windows, GCC or Clang on Linux, the Android NDK for Android, or full Xcode for iOS. Flutter for Windows already requires that Visual Studio workload, so on Windows only a Dart CLI application installs it separately. Normal Dart and Flutter commands run the build hooks. The generated bindings are checked in, so applications need neither ffigen nor libclang.

exarmo also needs Rust 1.91.1 or later, and the build hook finds or installs it. The hook uses `cargo` from `PATH`, then the toolchain of `rustup` from `PATH` or from `~/.cargo/bin`, or `%USERPROFILE%\.cargo\bin` on Windows, which also covers an IDE started before Rust was installed. Dart on Windows cannot open the `cargo.exe` symlink that rustup creates (errno 448), so the hook runs the toolchain's own `cargo.exe` and `rustc.exe` from `rustup which`. When rustup manages the toolchain, the hook runs `rustup target add` for the build target. Without any Rust, the hook downloads rustup-init 1.29.1 from `static.rust-lang.org`, checks its SHA-256 against the hash in the package and installs Rust 1.91.1 with the minimal profile into its shared output directory, without changing `PATH` or the shell profile. Rustup-init is pinned for Windows x64, ARM64 and x86, macOS x64 and ARM64, and Linux x64 and ARM64 hosts. The first such build needs network access and 523 MB of disk on macOS ARM64, and later builds reuse the toolchain. Rust dependencies of exarmo are vendored and build offline. Zydis and Capstone need no Rust. The native library is built for your application's architecture, regardless of the instructions you decode.

### Windows

Build from your Flutter project directory with `flutter pub get` and `flutter build windows --release`. Rust needs no manual step, since the hook finds or installs it as described above. The hooks build `disassembler_windows_plugin.dll` and bundle it. C compiles with `/MD` and Rust with `crt-static` off, so the DLL needs the Microsoft Visual C++ Redistributable for its architecture, which provides `VCRUNTIME140.dll`. UCRT ships with Windows 10 and 11.

## Native library locations

| Platform | Flutter artifact | Location |
| --- | --- | --- |
| Windows | `disassembler_windows_plugin.dll` | Next to the application `.exe` |
| Linux | `lib_disassembler_linux_plugin.so` | `lib/` of the application bundle |
| Android | `lib_disassembler_android_plugin.so` | `lib/<ABI>/` of the APK |
| macOS | `lib_disassembler_macos_plugin.framework` | `Contents/Frameworks/` |
| iOS | `lib_disassembler_ios_plugin.framework` | `Frameworks/` of the application |

On Apple platforms the compiler writes `liblib_disassembler_macos_plugin.dylib` or `liblib_disassembler_ios_plugin.dylib`. Flutter drops the first `lib` when it creates the framework, and Dart CLI bundles keep the `.dylib` name. Code asset lookup finds both.

## Updating engines

The package includes Zydis 4.1.1 with Zycore 1.5.2, exarmo 0.4.0 and Capstone 6.0.0-Alpha11, and each engine's JSON manifest records its source commit. Run an engine's script from the package directory with an upstream release tag:

```sh
dart pub get
dart run tool/update_zydis.dart v4.1.1
dart run tool/update_exarmo.dart v0.4.0
dart run tool/update_capstone.dart 6.0.0-Alpha11
dart analyze
dart test --concurrency=2
```

The scripts replace the vendored sources and regenerate the bindings and models, and they need Git and LLVM with libclang. Review the diff and run the tests on your target platforms before releasing an update.

`update_exarmo.dart` applies `tool/exarmo.patch` to the staged sources before it replaces `third_party/exarmo`: the upstream C API links std for `catch_unwind`, which adds `LoadLibraryA` and `NtWriteFile` imports to the native library, so the package builds it without std, and the patch adds `exarmo_aarch64_instruction_summary`, which returns the encoding, mnemonic, length, unpredictability, flag effect and branch of an instruction in one guarded call, since the 6 calls the batch decoder made for them were 33 of its 89 ns an instruction. The update stops when the patch does not fit the new tag. After an exarmo update, regenerate `src/aarch64_effects.h` with `dart tool/generate_exarmo_effects.dart <ISA_A64_xml directory>`, where the directory is the unpacked A64 ISA XML from Arm's machine-readable architecture specification; the table is keyed by `EXARMO_AARCH64_ENC_` names, so `src/batch.c` does not compile against the table of another exarmo version. `--check` compares the checked-in table with the XML and changes nothing. Run it with `dart`, not `dart run`, since `dart run` builds the native library first.

To compile for Android ARM64 without running anything:

```sh
dart run tool/build_target.dart android arm64 zydis,exarmo,capstone
```

This builds all 3 engines for Android API 21 with Capstone's x86 and AArch64 decoders. The decoder tests read instruction bytes and never load or run PE files.

## Licenses

The Dart package is BSD-3-Clause, Zydis and Zycore are MIT, and exarmo is Apache-2.0. Capstone has its own license plus the licenses of its LLVM-derived code. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists the license texts and notices to ship with the native library, including the Arm ACLE attribution and the Rust runtime notices.
