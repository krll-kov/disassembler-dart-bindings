// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';

import '../lib/src/c_library.dart';
import '../lib/src/rust_library.dart';
import '../lib/src/third_party/capstone.record_use_mapping.g.dart' as capstone;
import '../lib/src/third_party/disassembler.record_use_mapping.g.dart'
    as common;
import '../lib/src/third_party/zydis.record_use_mapping.g.dart' as zydis;
import '../lib/src/third_party/exarmo.record_use_mapping.g.dart' as exarmo;

Future<void> main(List<String> args) async {
  await link(args, (LinkInput input, LinkOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    final NativeConfiguration configuration = NativeConfiguration.fromHook(
      input,
    );
    if (configuration.backends.isEmpty) return;
    final Map<String, String> mappings = {
      ...common.recordUseMapping,
      if (configuration.backends.contains('capstone'))
        ...capstone.recordUseMapping,
      if (configuration.backends.contains('zydis'))
        for (final MapEntry<String, String> entry
            in zydis.recordUseMapping.entries)
          if (_zydisEnabled(entry.value, configuration.zydisFeatures))
            entry.key: entry.value,
      if (configuration.backends.contains('exarmo'))
        for (final MapEntry<String, String> entry
            in exarmo.recordUseMapping.entries)
          if (entry.value.startsWith('exarmo_aarch32_')
              ? configuration.exarmoDecoders.contains('arm')
              : configuration.exarmoDecoders.contains('aarch64'))
            entry.key: entry.value,
    };
    final Set<String> knownMethods = {
      ...common.recordUseMapping.keys,
      ...capstone.recordUseMapping.keys,
      ...zydis.recordUseMapping.keys,
      ...exarmo.recordUseMapping.keys,
    };
    final Set<String>? symbols = input.recordedUses?.calls.keys
        .cast<Method>()
        .expand((Method method) {
          if (!knownMethods.contains(method.name)) {
            throw StateError('Unknown native function: ${method.name}');
          }
          final String? symbol = mappings[method.name];
          return symbol == null ? const <String>[] : [symbol];
        })
        .toSet();
    // Record use names the typed data call of _decodeInPlace by a compiler
    // made helper, so the symbol stays whenever any native function is used
    if (symbols != null && symbols.isNotEmpty) {
      symbols.addAll(const [
        'disassembler_decode',
        'disassembler_call_targets',
        'disassembler_select',
      ]);
    }
    if (symbols != null && configuration.backends.contains('exarmo')) {
      if (configuration.exarmoDecoders.contains('arm')) {
        symbols.add('exarmo_aarch32_sysregs');
      }
      if (configuration.exarmoDecoders.contains('aarch64')) {
        symbols.addAll(const [
          'exarmo_aarch64_sysregs',
          'exarmo_aarch64_sysops',
        ]);
      }
    }
    if (symbols != null && symbols.isEmpty) return;
    for (final String backend in configuration.backends) {
      output.dependencies.add(input.packageRoot.resolve('$backend.json'));
    }
    Uri? archive;
    List<String> libraries = const [];
    if (configuration.backends.contains('exarmo')) {
      output.dependencies.addAll(await rustDependencies(input.packageRoot));
      final rust = await buildExarmo(
        input.packageRoot,
        input.outputDirectoryShared,
        input.config.code,
        decoders: configuration.exarmoDecoders,
      );
      archive = rust.archive;
      libraries = rust.libraries;
    }
    final library = disassemblerLibrary(
      input.packageRoot,
      input.config.code.targetOS,
      configuration,
      exarmoArchive: archive,
      exarmoLibraries: libraries,
    );
    output.dependencies.addAll(library.sources.map(Uri.file));
    if (input.config.code.targetOS == OS.windows) {
      final List<String> compiled = await windowsCompilationSources(
        library.sources,
        input.outputDirectory,
      );
      library.sources.replaceRange(0, library.sources.length, compiled);
    }
    await library.link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(
        // MSVC writes the link time into the PE header, so each build of the
        // same sources got a new SHA-256 without the antivirus reputation of
        // the last one, and /Brepro writes a content hash there instead
        flags: [if (input.config.code.targetOS == OS.windows) '/Brepro'],
        symbolsToKeep: symbols,
      ),
    );
  });
}

bool _zydisEnabled(String symbol, List<String> features) {
  if (symbol.startsWith('ZydisDecoder')) return features.contains('decoder');
  if (symbol.startsWith('ZydisEncoder')) return features.contains('encoder');
  if (symbol.startsWith('ZydisFormatter') ||
      symbol.startsWith('ZydisDisassemble')) {
    return features.contains('formatter');
  }
  return true;
}
