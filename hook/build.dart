// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

import '../lib/src/c_library.dart';
import '../lib/src/rust_library.dart';

Future<void> main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) return;
    final NativeConfiguration configuration = NativeConfiguration.fromHook(
      input,
    );
    if (configuration.backends.isEmpty) return;
    for (final String backend in configuration.backends) {
      output.dependencies.add(input.packageRoot.resolve('$backend.json'));
    }
    Uri? archive;
    List<String> libraries = const [];
    if (configuration.backends.contains('exarmo')) {
      output.dependencies.addAll(await rustDependencies(input.packageRoot));
      archive = exarmoArchive(
        input.outputDirectoryShared,
        input.config.code,
        decoders: configuration.exarmoDecoders,
      );
      if (!input.config.linkingEnabled) {
        final rust = await buildExarmo(
          input.packageRoot,
          input.outputDirectoryShared,
          input.config.code,
          decoders: configuration.exarmoDecoders,
        );
        archive = rust.archive;
        libraries = rust.libraries;
      }
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
    await library.build(input: input, output: output);
  });
}
