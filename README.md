# Disassembler

Decode machine instructions in Dart with Zydis, exarmo or Capstone. Choose the engines and architectures your application needs. Dart's build hooks compile them into one native library.

## Installation

Add the dependency and native build settings to your application's `pubspec.yaml`:

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

This example enables Zydis for x86/x64 and exarmo for ARM64. Every engine is disabled by default. Omit an engine to exclude it, or use `backends: {}` to disable all native builds. The package's own settings enable all engines for its tests and do not affect your application.

## Build settings

Each entry in `backends` requires `architectures` and `features`:

| Engine | Architectures | Features |
| --- | --- | --- |
| `zydis` | `x86` | `decoder`, optional `encoder` and `formatter` |
| `exarmo` | `arm`, `arm64` | `decoder` |
| `capstone` | 23 architecture families listed below | `decoder` |

Every backend has the same 2 required fields. `architectures` selects instruction families. `x86` includes x86 and x64, while `arm` includes ARM32 and Thumb. `arm64` means AArch64 for every engine. `features` selects native components, with `decoder` required. Zydis can also include `encoder` and `formatter`. Capstone and exarmo do not expose independently selectable encoder or formatter components.

To use all 3 engines, put this complete configuration in your application's `pubspec.yaml`:

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

Capstone accepts `arm`, `arm64`, `m68k`, `mips`, `ppc`, `sparc`, `systemz`, `xcore`, `x86`, `tms320c64x`, `m680x`, `evm`, `mos65xx`, `wasm`, `bpf`, `riscv`, `sh`, `tricore`, `alpha`, `hppa`, `loongarch`, `xtensa` and `arc`. Its `x86` family also includes 16-bit decoding through the engine API.

`decoder` is required for every engine. Use `features: [decoder, encoder, formatter]` for Zydis when you need encoding or formatted instruction text. Capstone and exarmo accept only `decoder`. Unknown settings and empty lists stop the build with an error. Any combination of engines produces one native library.

Select an engine explicitly when creating `Disassembler`. An excluded engine or architecture throws `UnsupportedError`. The package does not switch to another engine automatically.

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

The common API supports `x86`, `x64`, `arm`, `thumb` and `arm64`. Each instruction has operands, branch information and register access when the engine provides it. Relative branch targets use absolute addresses. Register IDs differ between engines, so use `registerName` and `registerId` to work with them. Register access is `null` when unavailable, including exarmo's implicit register information.

For `postIndex == true`, the memory access uses the base before its update. The update remains in the engine's operand representation: a memory displacement or a separate immediate operand.

`Instruction.details` contains the engine's full output as `ZydisInstructionDetails`, `ExarmoInstructionDetails` or `CapstoneInstructionDetails`. Zydis and Capstone also use those types for invalid input. exarmo returns `InvalidInstructionDetails` with its native error code.

Import `zydis.dart`, `exarmo.dart` or `capstone.dart` to use an engine's API directly, including Capstone's additional architectures. The generated C bindings are in `zydis_native.dart`, `exarmo_native.dart` and `native.dart`, respectively.

Use `DisassemblerBuffer` and `decoder.reader(buffer)` to decode several ranges from the same bytes. `reader.visit` accepts `start`, `end` and `address`, and stops when its callback returns `false`. An `InstructionView` is valid only during that callback. Use `instruction.copy()` to keep it, and close the reader before closing its buffer. The instructions returned by `decode` remain valid after `decoder.close()`.

The common API returns `valid == false` for invalid input and continues decoding. Each engine's direct API has its own error handling. Successful decoding does not prove that the bytes are executable code.

Capstone Alpha11 supplies incomplete metadata for some instructions: `access = 0` and `avx_bcast = 0` for masked broadcast `VADDPS` bytes `62 f1 5c db 58 10`, and no groups for `VXORPS` bytes `62 f1 7c c9 57 c0`. The package preserves native values.

## Build requirements

Use Dart 3.13 or later and a native compiler: Xcode Command Line Tools on macOS, Visual Studio C++ Build Tools on Windows, GCC or Clang on Linux, Android NDK for Android, or full Xcode for iOS. Normal Dart and Flutter commands run the build hooks. Generated bindings are included, so applications do not need ffigen or libclang.

exarmo also requires Rust 1.91.1 or later, Cargo and the Rust standard library for your build target. For Android ARM64, install it with `rustup target add aarch64-linux-android`. Rust dependencies are vendored and build offline. Zydis and Capstone do not require Rust. The native library's architecture must match your application, independently of the instructions you decode.

### Windows

1. Install Visual Studio or Visual Studio Build Tools with **Desktop development with C++** and a Windows SDK. Flutter Windows projects also need these tools.
2. If you enable exarmo, install Rust 1.91.1 or later using [rustup-init.exe](https://rust-lang.org/tools/install/). Choose the installer for your computer: x64 for an x64 PC, ARM64 for Windows on ARM, including Parallels on Apple Silicon. Zydis and Capstone do not need Rust.
3. After installing Rust, restart your terminal and IDE. The installer adds `%USERPROFILE%\.cargo\bin` to `PATH`, but already running programs keep their previous environment.
4. In your Flutter project directory, run these commands for an x64 application:

```powershell
cargo --version
rustc --version
rustup target add x86_64-pc-windows-msvc
flutter pub get
flutter build windows --release
```

The first 3 commands are needed only when using exarmo. If `cargo` is still not found, check that `%USERPROFILE%\.cargo\bin\cargo.exe` exists. If it exists, refresh `PATH` for the current PowerShell session:

```powershell
$env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
```

The build hooks compile the selected engines and package `disassembler_windows_plugin.dll` automatically. Applications using the DLL need the Microsoft Visual C++ Redistributable for their architecture, which provides `VCRUNTIME140.dll`. UCRT is already part of Windows 10 and 11. C uses `/MD`, and Rust builds with `crt-static` disabled. `/MT` is not used.

## Native library locations

| Platform | Flutter artifact | Location |
| --- | --- | --- |
| Windows | `disassembler_windows_plugin.dll` | Beside application `.exe` |
| Linux | `lib_disassembler_linux_plugin.so` | Application bundle's `lib/` |
| Android | `lib_disassembler_android_plugin.so` | APK's `lib/<ABI>/` |
| macOS | `lib_disassembler_macos_plugin.framework` | `Contents/Frameworks/` |
| iOS | `lib_disassembler_ios_plugin.framework` | Application's `Frameworks/` |

Apple compiler output is `liblib_disassembler_macos_plugin.dylib` or `liblib_disassembler_ios_plugin.dylib`. Flutter removes the first `lib` when creating frameworks. Dart CLI bundles retain the `.dylib` filename. Code asset lookup handles these paths.

## Updating engines

The package includes Zydis 4.1.1 with Zycore 1.5.2, exarmo 0.4.0 and Capstone 6.0.0-Alpha11. Each engine's JSON manifest records its source commit. To update an engine, run its script from the package directory with an upstream release tag:

```sh
dart pub get
dart run tool/update_zydis.dart v4.1.1
dart run tool/update_exarmo.dart v0.4.0
dart run tool/update_capstone.dart 6.0.0-Alpha11
dart analyze
dart test --concurrency=2
```

These scripts replace the included source and regenerate bindings and models. They require Git and LLVM/libclang. Review the changes and run the tests on your target platforms before releasing an update.

To compile for Android ARM64 without running the result:

```sh
dart run tool/build_target.dart android arm64 zydis,exarmo,capstone
```

This command builds all 3 engines for Android API 21 and includes Capstone's x86/AArch64 decoders. Decoder tests read instruction bytes. They do not load or execute PE files.

## Licenses

The Dart package uses BSD-3-Clause, Zydis and Zycore use MIT, and exarmo uses Apache-2.0. Capstone includes its own license and licenses for LLVM-derived code. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) lists the license texts and notices to include when distributing the native library, including Arm ACLE attribution and Rust runtime notices.
