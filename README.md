# Disassembler for Dart

Decode instruction bytes with Zydis, exarmo or Capstone through one Dart API. The package builds selected engines into one native library through Dart code asset hooks. It never executes decoded code.

## Add and configure

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

All backends are disabled by default. Without `backends`, no native library is built. Put this configuration in the consuming application's `pubspec.yaml`. The package's own configuration enables all engines for tests and is not inherited by consumers.

| Backend | `architectures` | `features` |
| --- | --- | --- |
| `zydis` | `[x86]` | `decoder`, optional `encoder` and `formatter` |
| `exarmo` | `arm`, `arm64` | `decoder` |
| `capstone` | 23 architecture families listed below | `decoder` |

Every backend has the same 2 required fields. `architectures` selects instruction families. `x86` includes x86 and x64, while `arm` includes ARM32 and Thumb. `arm64` means AArch64 for every engine. `features` selects native components, with `decoder` required. Zydis can also include `encoder` and `formatter`. Capstone and exarmo do not expose independently selectable encoder or formatter components.

To use all 3 engines, add another entry to the same map:

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

Capstone architecture values: `arm`, `arm64`, `m68k`, `mips`, `ppc`, `sparc`, `systemz`, `xcore`, `x86`, `tms320c64x`, `m680x`, `evm`, `mos65xx`, `wasm`, `bpf`, `riscv`, `sh`, `tricore`, `alpha`, `hppa`, `loongarch`, `xtensa`, `arc`. Its `x86` family also includes 16 bit decoding through the engine API. Unknown settings, unsupported components and empty lists fail during the build.

Remove an engine's entry to exclude it. `backends: {}` disables all engines. Selecting 2 or 3 engines still produces one library. An excluded engine or exarmo architecture throws `UnsupportedError` through the common API. Backend selection is explicit, with no fallback to another engine.

## Decode

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

The common API supports `x86`, `x64`, `arm`, `thumb` and `arm64`. Instructions include operands, branch information and register access when available. Relative branch targets are absolute addresses. Register IDs belong to the selected engine, so use `registerName` and `registerId`. Missing register access is `null`, including exarmo's unavailable implicit register information.

For `postIndex == true`, the memory access uses the base before its update. The update remains in the engine's operand representation: a memory displacement or a separate immediate operand.

For valid instructions, `Instruction.details` preserves full typed output as `ZydisInstructionDetails`, `ExarmoInstructionDetails` or `CapstoneInstructionDetails`. Invalid records use `InvalidInstructionDetails`, including the native failure status when available. Engine APIs remain available from `zydis.dart`, `exarmo.dart` and `capstone.dart`. Capstone's existing models and additional architectures remain available through its engine API. Raw generated C APIs are exported from `zydis_native.dart`, `exarmo_native.dart` and `native.dart` respectively.

For repeated ranges, allocate `DisassemblerBuffer` once and reuse `decoder.reader(buffer)`. `reader.visit` accepts `start`, `end` and `address`. Returning `false` stops decoding. The callback's `InstructionView` expires after the callback returns, so retain `instruction.copy()` if needed. Close the reader before closing its buffer. `decode` returns owned instructions that remain valid after closing the decoder.

The common API reports invalid input with `valid == false` and advances through it. Engine APIs expose their own invalid-input policies. Decoding does not prove that a byte range contains executable instructions.

## Build and deployment

Dart 3.13 or later is required. Normal Dart and Flutter commands invoke hooks. Consumers do not need ffigen or libclang. Use Xcode Command Line Tools on macOS, Visual Studio C++ Build Tools on Windows, GCC or Clang on Linux, Android NDK for Android, and full Xcode for iOS.

If exarmo is selected, install Rust 1.91.1 or later, Cargo, and the Rust standard library for the target, for example `rustup target add aarch64-linux-android`. Its vendored dependencies build offline. Capstone and Zydis builds do not require Rust. The native library must match the application's architecture, independently of the instruction architecture being decoded.

| Platform | Flutter artifact | Location |
| --- | --- | --- |
| Windows | `disassembler_windows_plugin.dll` | Beside application `.exe` |
| Linux | `lib_disassembler_linux_plugin.so` | Application bundle's `lib/` |
| Android | `lib_disassembler_android_plugin.so` | APK's `lib/<ABI>/` |
| macOS | `lib_disassembler_macos_plugin.framework` | `Contents/Frameworks/` |
| iOS | `lib_disassembler_ios_plugin.framework` | Application's `Frameworks/` |

Apple compiler output is `liblib_disassembler_macos_plugin.dylib` or `liblib_disassembler_ios_plugin.dylib`. Flutter removes the first `lib` when creating frameworks. Dart CLI bundles retain the `.dylib` filename. Code asset lookup handles these paths.

Windows C compilation uses `/MD`. Rust disables `crt-static`, so `/MT` is not used. Install Microsoft Visual C++ Redistributable matching the application's architecture and build tools. Windows 10 and 11 supply Universal C Runtime. Exact DLL imports depend on selected engines and compiler version.

## Update and test

Pinned versions are Zydis 4.1.1 with Zycore 1.5.2, exarmo 0.4.0, and Capstone 6.0.0-Alpha11. Manifests record exact commits. From the package directory, use the relevant updater with an exact upstream tag:

```sh
dart pub get
dart run tool/update_zydis.dart v4.1.1
dart run tool/update_exarmo.dart v0.4.0
dart run tool/update_capstone.dart 6.0.0-Alpha11
dart analyze
dart test --concurrency=2
```

Updaters replace vendored source and regenerate bindings and models. Maintainers need Git and LLVM/libclang. Review generated changes and run tests on target platforms before releasing. To compile Android arm64 without running it:

```sh
dart run tool/build_target.dart android arm64 zydis,exarmo,capstone
```

This command uses Capstone's x86/AArch64 decoders and Android API 21. ABI and decoder tests use bytes as data, with no loading or execution of PE files.

Capstone Alpha11 supplies incomplete metadata for some instructions: `access = 0` and `avx_bcast = 0` for masked broadcast `VADDPS` bytes `62 f1 5c db 58 10`, and no groups for `VXORPS` bytes `62 f1 7c c9 57 c0`. The package preserves native values.

## Licenses

The Dart package uses BSD-3-Clause. Zydis and Zycore use MIT. exarmo uses Apache-2.0 and retains Arm ACLE attribution. Capstone retains its license and licenses of LLVM-derived code. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) links complete license texts and notices to include with binary distributions.

## Earlier Capstone validation

These measurements cover the previous Capstone-only package and do not establish support for the combined library: macOS arm64 and Windows x64 each passed 100 tests with all 23 Capstone decoders and AOT linkage. Windows x64 runtime imports were checked in Windows 11 ARM64 VM. Android arm64 compiled all 23 decoders with NDK r28c for API 21, without runtime tests. iOS arm64 compiled all 23 decoders with iOS 27 SDK for iOS 15 or later, with Flutter framework packaging and ad-hoc signature checked, without runtime tests. The earlier x86/AArch64 build passed 43 tests. The retained upstream oracle fixture contains 284 expectations across 23 Capstone decoders.
