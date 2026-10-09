import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';

import '../lib/src/c_library.dart';

void main() {
  final Uri root = Uri.base;
  final Uri archive = root.resolve('build/rust/libexarmo_combined.a');
  const Map<String, Object> settings = {
    'zydis': {
      'architectures': ['x86'],
      'features': ['decoder'],
    },
    'exarmo': {
      'architectures': ['arm', 'arm64'],
      'features': ['decoder'],
    },
    'capstone': {
      'architectures': ['x86'],
      'features': ['decoder'],
    },
  };
  test('Windows compilation prevents object name collisions', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'disassembler_windows_sources_',
    );
    try {
      final List<String> paths = [
        'first/Widget.c',
        'second/widget.C',
        'unique/disassembler_source_0.c',
        'unique/Other.c',
        'third/shared.c',
        'fourth/shared.cpp',
      ];
      final List<File> originals = [];
      for (int index = 0; index < paths.length; index++) {
        final File file = File.fromUri(directory.uri.resolve(paths[index]));
        await file.parent.create(recursive: true);
        await file.writeAsString('int fixture_$index = $index;\n');
        originals.add(file);
      }
      final List<String> sources = originals.map((file) => file.path).toList();
      final List<String> compiled = await windowsCompilationSources(
        sources,
        directory.uri.resolve('output/'),
      );
      final Set<String> objectNames = compiled.map((source) {
        final String basename = Uri.file(source).pathSegments.last;
        return basename.substring(0, basename.lastIndexOf('.')).toLowerCase();
      }).toSet();
      expect(objectNames.length, originals.length);
      for (int index = 0; index < paths.length; index++) {
        expect(
          await originals[index].readAsString(),
          'int fixture_$index = $index;\n',
        );
        if (index == 2 || index == 3) {
          expect(compiled[index], originals[index].path);
        } else {
          expect(
            await File(compiled[index]).readAsString(),
            '#include "${originals[index].path.replaceAll(r'\', '/')}"\n',
          );
        }
      }
      expect(compiled.last.endsWith('.cpp'), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
  for (int mask = 1; mask < 8; mask++) {
    final List<String> backends = [
      for (
        int bit = 0;
        bit < NativeConfiguration.availableBackends.length;
        bit++
      )
        if (mask & (1 << bit) != 0) NativeConfiguration.availableBackends[bit],
    ];
    test('Excluded native sources cannot inflate $backends build', () {
      final configuration = NativeConfiguration({
        'backends': {
          for (final backend in backends) backend: settings[backend],
        },
      });
      final library = disassemblerLibrary(
        root,
        OS.macOS,
        configuration,
        exarmoArchive: backends.contains('exarmo') ? archive : null,
      );
      expect(library.name, libraryName(OS.macOS));
      expect(library.assetName, 'disassembler.dart');
      final List<String> sources = library.sources
          .map((String path) => Uri.file(path).path)
          .toList();
      for (final String backend in NativeConfiguration.availableBackends) {
        expect(
          library.defines.containsKey('DISASSEMBLER_${backend.toUpperCase()}'),
          backends.contains(backend),
        );
      }
      expect(
        sources.any((String path) => path.contains('/third_party/capstone/')),
        backends.contains('capstone'),
      );
      expect(
        sources.any((String path) => path.contains('/third_party/zydis/')),
        backends.contains('zydis'),
      );
      expect(
        sources.any((String path) => path.endsWith('/src/exarmo_exports.c')),
        backends.contains('exarmo'),
      );
      expect(
        library.libraries.contains('exarmo_combined'),
        backends.contains('exarmo'),
      );
    });
  }
  test('Unconfigured consumers do not enable native backends', () {
    expect(NativeConfiguration({}).backends, isEmpty);
    expect(
      NativeConfiguration({'backends': <String, Object>{}}).backends,
      isEmpty,
    );
  });
  test('Invalid settings fail before native compilation', () {
    for (final Map<String, Object?> settings in [
      {
        'backends': ['capstone'],
      },
      {
        'backends': {'unknown': settings['zydis']},
      },
      {
        'backends': {'zydis': {}},
      },
      {
        'backends': {
          'exarmo': {
            'architectures': ['arm64'],
          },
        },
      },
      {
        'backends': {
          'capstone': {
            'features': ['decoder'],
          },
        },
      },
      {
        'backends': {
          'zydis': {
            'architectures': ['x86'],
            'features': [],
          },
        },
      },
      {
        'backends': {
          'zydis': {
            'architectures': ['x86'],
            'features': ['encoder'],
          },
        },
      },
      {
        'backends': {
          'exarmo': {
            'architectures': ['arm64'],
            'features': ['encoder'],
          },
        },
      },
      {
        'backends': {
          'zydis': {
            'architectures': ['arm64'],
            'features': ['decoder'],
          },
        },
      },
      {'backends': 'zydis'},
      {
        'backends': ['zydis', null],
      },
      {
        'backends': ['unknown'],
      },
      {
        'backend': ['zydis'],
      },
      {
        'backends': ['zydis'],
        'capstone_decoders': ['x86'],
      },
      {
        'backends': ['capstone'],
        'capstone_decoders': [],
      },
      {
        'backends': ['capstone'],
        'capstone_decoders': 'x86',
      },
    ]) {
      expect(
        () => NativeConfiguration(settings),
        throwsArgumentError,
        reason: '$settings',
      );
    }
  });
  test('Unsupported Capstone architecture fails before compilation', () {
    final configuration = NativeConfiguration({
      'backends': {
        'capstone': {
          'architectures': ['wrong'],
          'features': ['decoder'],
        },
      },
    });
    expect(
      () => disassemblerLibrary(root, OS.windows, configuration),
      throwsArgumentError,
    );
  });
  test('Duplicate features cannot duplicate native source files', () {
    final configuration = NativeConfiguration({
      'backends': {
        'zydis': {
          'architectures': ['x86'],
          'features': ['decoder', 'decoder'],
        },
      },
    });
    final library = disassemblerLibrary(root, OS.linux, configuration);
    expect(configuration.backends, ['zydis']);
    expect(library.sources.toSet().length, library.sources.length);
  });
  test('Windows library keeps dynamic CRT across backend selections', () {
    final configuration = NativeConfiguration({
      'backends': {'zydis': settings['zydis'], 'exarmo': settings['exarmo']},
    });
    final library = disassemblerLibrary(
      root,
      OS.windows,
      configuration,
      exarmoArchive: archive,
    );
    expect(library.name, 'disassembler_windows_plugin');
    expect(library.flags, ['/MD']);
    expect(library.pic, isTrue);
  });
  test('Selective Capstone build excludes unrequested architectures', () {
    final configuration = NativeConfiguration({
      'backends': {
        'zydis': settings['zydis'],
        'capstone': settings['capstone'],
      },
    });
    final library = disassemblerLibrary(root, OS.macOS, configuration);
    expect(library.defines, contains('CAPSTONE_X86_SUPPORT'));
    expect(library.defines, isNot(contains('CAPSTONE_AARCH64_SUPPORT')));
    expect(
      library.sources.any((String path) => path.contains('/arch/AArch64/')),
      isFalse,
    );
  });
  test('AArch64 selection excludes ARM32 native exports', () {
    final configuration = NativeConfiguration({
      'backends': {
        'exarmo': {
          'architectures': ['arm64'],
          'features': ['decoder'],
        },
      },
    });
    final library = disassemblerLibrary(
      root,
      OS.macOS,
      configuration,
      exarmoArchive: archive,
    );
    expect(library.defines, contains('DISASSEMBLER_EXARMO_AARCH64'));
    expect(library.defines, isNot(contains('DISASSEMBLER_EXARMO_ARM')));
  });
  test('Decoder selection excludes Zydis encoder and formatter sources', () {
    final library = disassemblerLibrary(
      root,
      OS.macOS,
      NativeConfiguration({
        'backends': {'zydis': settings['zydis']},
      }),
    );
    expect(library.sources.any((v) => v.endsWith('/Encoder.c')), isFalse);
    expect(library.sources.any((v) => v.endsWith('/Formatter.c')), isFalse);
    expect(library.defines, contains('ZYDIS_DISABLE_ENCODER'));
    expect(library.defines, contains('ZYDIS_DISABLE_FORMATTER'));
  });
}
