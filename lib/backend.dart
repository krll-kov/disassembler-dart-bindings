import 'src/third_party/disassembler.g.dart' as native;

enum DisassemblerBackend { zydis, exarmo, capstone }

Set<DisassemblerBackend> availableBackends() {
  final int mask = _nativeMask(native.disassembler_backend_mask);
  return Set<DisassemblerBackend>.unmodifiable({
    for (final DisassemblerBackend backend in DisassemblerBackend.values)
      if (mask & (1 << backend.index) != 0) backend,
  });
}

int _nativeMask(int Function() read) {
  try {
    return read();
  } on ArgumentError catch (error) {
    if ('${error.message}'.contains(
      "No asset with id 'package:disassembler/disassembler.dart' found",
    )) {
      return 0;
    }
    rethrow;
  }
}

Set<String> availableExarmoDecoders() => _available(
  _nativeMask(native.disassembler_exarmo_decoder_mask),
  ['arm', 'arm64'],
);

Set<String> availableZydisFeatures() => _available(
  _nativeMask(native.disassembler_zydis_feature_mask),
  ['decoder', 'encoder', 'formatter'],
);

Set<String> _available(int mask, List<String> values) => Set.unmodifiable({
  for (int bit = 0; bit < values.length; bit++)
    if (mask & (1 << bit) != 0) values[bit],
});

void requireExarmoDecoder(String decoder) {
  requireBackend(DisassemblerBackend.exarmo);
  if (!availableExarmoDecoders().contains(decoder)) {
    throw UnsupportedError(
      'exarmo decoder $decoder is excluded from this build',
    );
  }
}

void requireZydisFeature(String feature) {
  requireBackend(DisassemblerBackend.zydis);
  if (!availableZydisFeatures().contains(feature)) {
    throw UnsupportedError(
      'Zydis feature $feature is excluded from this build',
    );
  }
}

void requireBackend(DisassemblerBackend backend) {
  if (!availableBackends().contains(backend)) {
    throw UnsupportedError(
      '${backend.name} is excluded from this native build. '
      'Enable it in hooks.user_defines.disassembler.backends',
    );
  }
}
