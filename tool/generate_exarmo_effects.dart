// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

/// Generates `src/aarch64_effects.h`: the registers and memory that each A64
/// encoding of exarmo reads and writes, from the ASL in Arm's
/// machine-readable A64 ISA XML.
///
/// ```sh
/// dart tool/generate_exarmo_effects.dart <ISA_A64_xml directory> [--check]
/// ```
///
/// `dart run` would build the native library first, and `src/batch.c` does
/// not compile against a table of another exarmo version.
library;

import 'dart:io';

import 'package:xml/xml.dart';

Future<void> main(List<String> arguments) async {
  final List<String> paths = [
    for (final String argument in arguments)
      if (!argument.startsWith('--')) argument,
  ];
  if (paths.length != 1) {
    stderr.writeln(
      'Usage: dart tool/generate_exarmo_effects.dart '
      '<ISA_A64_xml directory> [--check]',
    );
    exitCode = 64;
    return;
  }
  generateExarmoEffects(
    Platform.script.resolve('../'),
    Directory(paths.single),
    check: arguments.contains('--check'),
  );
}

void generateExarmoEffects(Uri root, Directory isa, {bool check = false}) {
  final Asl asl = Asl.load(isa);
  final Map<String, EncodingEffect> effects = {};
  final Map<String, Set<String>> mnemonics = {};
  final Map<String, String> aliases = {};
  for (final FileSystemEntity entity in isa.listSync()..sort(_byPath)) {
    if (entity is! File || !entity.path.endsWith('.xml')) continue;
    final XmlDocument document = XmlDocument.parse(entity.readAsStringSync());
    final XmlElement? section = document.getElement('instructionsection');
    if (section == null) continue;
    asl.readInstruction(section, effects, mnemonics, aliases);
  }
  final ExarmoEncodings exarmo = ExarmoEncodings.read(
    File.fromUri(
      root.resolve('third_party/exarmo/aarch64/src/generated/encoding.rs'),
    ),
  );
  final List<EncodingEffect?> table = [
    for (int i = 0; i < exarmo.names.length; i++)
      _match(exarmo.names[i], exarmo.mnemonics[i], effects, mnemonics, aliases),
  ];
  final String generated = _header(_release(isa), exarmo.names, table);
  final File destination = File.fromUri(root.resolve('src/aarch64_effects.h'));
  if (check) {
    if (!destination.existsSync() ||
        destination.readAsStringSync() != generated)
      throw StateError('src/aarch64_effects.h differs from the ISA XML');
  } else {
    destination.writeAsStringSync(generated);
  }
  final int known = table.whereType<EncodingEffect>().length;
  stdout.writeln('$known of ${table.length} exarmo A64 encodings known');
}

int _byPath(FileSystemEntity a, FileSystemEntity b) => a.path.compareTo(b.path);

String _release(Directory isa) =>
    isa.uri.pathSegments.lastWhere((String segment) => segment.isNotEmpty);

/// The exarmo name of an XML encoding: `ADD_32_addsub_imm` is
/// `Add32AddsubImm`.
String exarmoName(String xmlName) => [
  for (final String part in xmlName.split('_'))
    if (part.isNotEmpty)
      part[0].toUpperCase() + part.substring(1).toLowerCase(),
].join();

// exarmo splits some XML encodings by a bit the ASL reads, such as
// `AddhnAsimddiffN2` for ADDHN2, so the longest XML name that starts the
// exarmo name is that encoding, when the mnemonics agree
EncodingEffect? _match(
  String name,
  String mnemonic,
  Map<String, EncodingEffect> effects,
  Map<String, Set<String>> mnemonics,
  Map<String, String> aliases,
) {
  String? found = effects.containsKey(name) || aliases.containsKey(name)
      ? name
      : null;
  if (found == null) {
    for (final String candidate in [...effects.keys, ...aliases.keys]) {
      if (name.startsWith(candidate) &&
          (found == null || candidate.length > found.length)) {
        found = candidate;
      }
    }
  }
  if (found == null || !mnemonics[found]!.contains(mnemonic)) return null;
  final EncodingEffect? effect = effects[aliases[found] ?? found];
  return effect != null && effect.known ? effect : null;
}

/// A register write: a field of the instruction word, or a fixed register.
final class RegisterWrite implements Comparable<RegisterWrite> {
  /// [registerClass] is an `EXARMO_AARCH64_REG_` constant.
  final String registerClass;

  /// The field holding the register number, or null for [number].
  final ({int lsb, int width})? field;

  /// The register number, or what [field] adds to the number it holds.
  final int number;

  /// Whether the write goes to SP when [field] holds 31, and nowhere
  /// otherwise.
  final bool stackPointer;

  const RegisterWrite(
    this.registerClass,
    this.field,
    this.number, {
    this.stackPointer = false,
  });

  String get source =>
      '{${stackPointer
          ? 'kWriteStackPointer'
          : field == null
          ? 'kWriteFixed'
          : 'kWriteField'}, '
      '$registerClass, ${field?.lsb ?? 0}, ${field?.width ?? 0}, $number}';

  @override
  int compareTo(RegisterWrite other) => source.compareTo(other.source);

  @override
  bool operator ==(Object other) =>
      other is RegisterWrite && other.source == source;

  @override
  int get hashCode => source.hashCode;
}

/// What an encoding writes and whether its memory operand is read or written.
final class EncodingEffect {
  /// Why the effect is unknown, or null when it is known.
  final String? unknownReason;
  final Set<RegisterWrite> writes;
  final bool readsMemory;
  final bool writesMemory;

  const EncodingEffect(
    this.writes, {
    required this.readsMemory,
    required this.writesMemory,
  }) : unknownReason = null;

  const EncodingEffect.unknown(String this.unknownReason)
    : writes = const {},
      readsMemory = true,
      writesMemory = true;

  bool get known => unknownReason == null;
}

// Entries name `EXARMO_AARCH64_ENC_` constants, so an exarmo update that drops
// or renames an encoding fails to compile until the table is generated again
String _header(
  String release,
  List<String> names,
  List<EncodingEffect?> table,
) {
  final StringBuffer out = StringBuffer()
    ..writeln('// Copyright (c) 2026, swiftsoft')
    ..writeln('// SPDX-License-Identifier: BSD-3-Clause')
    ..writeln()
    ..writeln(
      '// Generated by tool/generate_exarmo_effects.dart from $release.',
    )
    ..writeln('// Do not edit.')
    ..writeln()
    ..writeln('#ifndef DISASSEMBLER_AARCH64_EFFECTS_H_')
    ..writeln('#define DISASSEMBLER_AARCH64_EFFECTS_H_')
    ..writeln()
    ..writeln('#include <stdint.h>')
    ..writeln()
    ..writeln('enum {')
    ..writeln('  kEffectKnown = 1,')
    ..writeln('  kEffectReadsMemory = 2,')
    ..writeln('  kEffectWritesMemory = 4,')
    ..writeln('};')
    ..writeln()
    ..writeln('enum { kWriteField, kWriteStackPointer, kWriteFixed };')
    ..writeln()
    ..writeln('typedef struct Aarch64Write {')
    ..writeln('  uint8_t kind;')
    ..writeln('  uint8_t register_class;')
    ..writeln('  uint8_t lsb;')
    ..writeln('  uint8_t width;')
    ..writeln('  uint8_t number;')
    ..writeln('} Aarch64Write;')
    ..writeln()
    ..writeln('typedef struct Aarch64Effect {')
    ..writeln('  uint8_t flags;')
    ..writeln('  uint8_t write_count;')
    ..writeln('  uint16_t write_start;')
    ..writeln('} Aarch64Effect;')
    ..writeln()
    ..writeln(
      'static const Aarch64Effect '
      'kAarch64Effects[EXARMO_AARCH64_ENCODING_COUNT] = {',
    );
  final List<RegisterWrite> writes = [];
  for (int i = 0; i < table.length; i++) {
    final EncodingEffect? effect = table[i];
    if (effect == null) continue;
    final String flags = [
      'kEffectKnown',
      if (effect.readsMemory) 'kEffectReadsMemory',
      if (effect.writesMemory) 'kEffectWritesMemory',
    ].join(' | ');
    final List<RegisterWrite> sorted = [...effect.writes]..sort();
    out.writeln(
      '    [EXARMO_AARCH64_ENC_${names[i]}] = '
      '{$flags, ${sorted.length}, ${writes.length}},',
    );
    writes.addAll(sorted);
  }
  out
    ..writeln('};')
    ..writeln()
    ..writeln('static const Aarch64Write kAarch64Writes[] = {');
  for (final RegisterWrite write in writes) {
    out.writeln('    ${write.source},');
  }
  if (writes.isEmpty) out.writeln('    {0, 0, 0, 0, 0},');
  out
    ..writeln('};')
    ..writeln()
    ..writeln('#endif  // DISASSEMBLER_AARCH64_EFFECTS_H_');
  return out.toString();
}

/// The A64 encodings of the vendored exarmo, in the order of its
/// `Encoding` enum, which is the number its C API returns.
final class ExarmoEncodings {
  final List<String> names;
  final List<String> mnemonics;

  ExarmoEncodings(this.names, this.mnemonics);

  factory ExarmoEncodings.read(File source) {
    final String text = source.readAsStringSync();
    final List<String> names = _variants(text, 'pub enum Encoding {');
    final int table = text.indexOf('static MNEMONIC_OF:');
    final List<String> mnemonics = [
      for (final RegExpMatch match in RegExp(
        r'Mnemonic::(\w+),',
      ).allMatches(text.substring(table, text.indexOf('];', table))))
        match.group(1)!,
    ];
    if (names.length != mnemonics.length)
      throw StateError('exarmo encodings and mnemonics differ in count');
    return ExarmoEncodings(names, mnemonics);
  }

  static List<String> _variants(String text, String opening) {
    final int start = text.indexOf(opening) + opening.length;
    return [
      for (final String line
          in text.substring(start, text.indexOf('\n}', start)).split('\n'))
        if (RegExp(r'^\s+[A-Z]\w*,$').hasMatch(line))
          line.trim().replaceAll(',', ''),
    ];
  }
}

/// ASL statements of the XML: a statement is a list of tokens, or a block.
sealed class Statement {
  const Statement();
}

final class SimpleStatement extends Statement {
  final List<String> tokens;
  const SimpleStatement(this.tokens);
}

final class IfStatement extends Statement {
  final List<({List<String> condition, List<Statement> body})> arms;
  final List<Statement> otherwise;
  const IfStatement(this.arms, this.otherwise);
}

final class CaseStatement extends Statement {
  final List<String> subject;

  /// The labels of each arm, empty for `otherwise`.
  final List<({List<List<String>> labels, List<Statement> body})> arms;

  const CaseStatement(this.subject, this.arms);
}

/// A loop, or a `begin` block when [head] is null.
final class BlockStatement extends Statement {
  final List<String>? head;
  final List<Statement> body;
  const BlockStatement(this.head, this.body);
}

final RegExp _token = RegExp(
  r"""\s+|//[^\n]*|/\*[\s\S]*?\*/|'[01x ]*'|"(?:[^"\\]|\\.)*"|0x[0-9A-Fa-f_]+|\d+|[A-Za-z_][\w.]*|<=>|=>|<=|>=|==|!=|&&|\|\||<<|>>|\+:|\*:|::|[{}()\[\],;:=<>+\-*/!^&|.?]""",
);

List<String> tokenize(String source) {
  final List<String> tokens = [];
  int position = 0;
  while (position < source.length) {
    final Match? match = _token.matchAsPrefix(source, position);
    if (match == null) {
      tokens.add(source[position++]);
      continue;
    }
    final String token = match.group(0)!;
    position = match.end;
    if (token.trim().isEmpty ||
        token.startsWith('//') ||
        token.startsWith('/*'))
      continue;
    tokens.add(token);
  }
  return tokens;
}

List<Statement> parseAsl(String source) => _Parser(tokenize(source)).block({});

final class _Parser {
  final List<String> _tokens;
  int _at = 0;

  _Parser(this._tokens);

  String? get _next => _at < _tokens.length ? _tokens[_at] : null;

  void _skip(String token) {
    if (_next == token) _at++;
  }

  /// Tokens before the first of [stops] outside brackets.
  List<String> _until(Set<String> stops) {
    final List<String> tokens = [];
    int depth = 0;
    while (_at < _tokens.length) {
      final String token = _tokens[_at];
      if (depth == 0 && stops.contains(token)) break;
      if ('([{'.contains(token)) depth++;
      if (')]}'.contains(token)) depth--;
      tokens.add(token);
      _at++;
    }
    return tokens;
  }

  List<Statement> block(Set<String> stops) {
    final List<Statement> statements = [];
    while (_next != null && !stops.contains(_next)) {
      final Statement? statement = _statement();
      if (statement != null) statements.add(statement);
    }
    return statements;
  }

  Statement? _statement() {
    switch (_next) {
      case 'if':
        _at++;
        const Set<String> armEnd = {'elsif', 'else', 'end'};
        final arms = <({List<String> condition, List<Statement> body})>[];
        while (true) {
          final List<String> condition = _until({'then'});
          _skip('then');
          arms.add((condition: condition, body: block(armEnd)));
          if (_next != 'elsif') break;
          _at++;
        }
        List<Statement> otherwise = const [];
        if (_next == 'else') {
          _at++;
          otherwise = block({'end'});
        }
        _skip('end');
        _skip(';');
        return IfStatement(arms, otherwise);
      case 'case':
        _at++;
        final List<String> subject = _until({'of'});
        _skip('of');
        final arms = <({List<List<String>> labels, List<Statement> body})>[];
        while (_next == 'when' || _next == 'otherwise') {
          final bool otherwise = _tokens[_at++] == 'otherwise';
          final List<String> labels = _until({'=>'});
          _skip('=>');
          arms.add((
            labels: otherwise ? const [] : _split(labels),
            body: block({'when', 'otherwise', 'end'}),
          ));
        }
        _skip('end');
        _skip(';');
        return CaseStatement(subject, arms);
      case 'for' || 'while':
        _at++;
        final List<String> head = _until({'do'});
        _skip('do');
        final List<Statement> body = block({'end'});
        _skip('end');
        _skip(';');
        return BlockStatement(head, body);
      case 'repeat':
        _at++;
        final List<Statement> body = block({'until'});
        _skip('until');
        _until({';'});
        _skip(';');
        return BlockStatement(const [], body);
      case 'begin':
        _at++;
        final List<Statement> body = block({'end'});
        _skip('end');
        _skip(';');
        return BlockStatement(null, body);
      case 'end' || 'getter' || 'setter' || 'readonly':
        _at++;
        _skip(';');
        return null;
    }
    final List<String> tokens = _until({';'});
    _skip(';');
    return SimpleStatement(tokens);
  }

  static List<List<String>> _split(List<String> tokens) {
    final List<List<String>> parts = [[]];
    int depth = 0;
    for (final String token in tokens) {
      if ('([{'.contains(token)) depth++;
      if (')]}'.contains(token)) depth--;
      if (token == ',' && depth == 0) {
        parts.add([]);
      } else {
        parts.last.add(token);
      }
    }
    return parts;
  }
}

Iterable<Statement> _all(List<Statement> statements) sync* {
  for (final Statement statement in statements) {
    yield statement;
    switch (statement) {
      case IfStatement(:final arms, :final otherwise):
        for (final arm in arms) yield* _all(arm.body);
        yield* _all(otherwise);
      case CaseStatement(:final arms):
        for (final arm in arms) yield* _all(arm.body);
      case BlockStatement(:final body):
        yield* _all(body);
      case SimpleStatement():
        break;
    }
  }
}

/// Splits `lhs = rhs` at an `=` outside brackets; null [lhs] when there is
/// none.
({List<String>? lhs, List<String> rhs}) splitAssignment(List<String> tokens) {
  int depth = 0;
  for (int i = 0; i < tokens.length; i++) {
    final String token = tokens[i];
    if ('([{'.contains(token)) depth++;
    if (')]}'.contains(token)) depth--;
    if (token == '=' && depth == 0)
      return (lhs: tokens.sublist(0, i), rhs: tokens.sublist(i + 1));
  }
  return (lhs: null, rhs: tokens);
}

const Set<String> _keywords = {
  'if', 'then', 'elsif', 'else', 'end', 'case', 'of', 'when', 'otherwise', //
  'for', 'to', 'downto', 'do', 'while', 'repeat', 'until', 'let', 'var',
  'constant', 'return', 'begin', 'func', 'getter', 'setter', 'accessor',
  'readonly', 'assert', 'throw', 'try', 'catch', 'pass', 'where',
};

/// The name and the index of `(` of a call that starts at [tokens][at],
/// past an optional `{width}`.
({String name, int open})? callAt(List<String> tokens, int at) {
  final String name = tokens[at];
  if (!RegExp(r'^[A-Za-z_]').hasMatch(name) || _keywords.contains(name))
    return null;
  int i = at + 1;
  if (i < tokens.length && tokens[i] == '{') {
    for (int depth = 0; i < tokens.length; i++) {
      if (tokens[i] == '{') depth++;
      if (tokens[i] == '}' && --depth == 0) {
        i++;
        break;
      }
    }
  }
  return i < tokens.length && tokens[i] == '(' ? (name: name, open: i) : null;
}

Iterable<String> callsIn(List<String> tokens) sync* {
  for (int i = 0; i < tokens.length; i++) {
    final call = callAt(tokens, i);
    if (call != null) yield call.name;
  }
}

/// The comma separated arguments of the call whose `(` is [tokens][open].
List<List<String>> argumentsAt(List<String> tokens, int open) {
  final List<List<String>> arguments = [];
  List<String> current = [];
  int depth = 0;
  for (int i = open; i < tokens.length; i++) {
    final String token = tokens[i];
    if ('([{'.contains(token) && depth++ == 0) continue;
    if (')]}'.contains(token) && --depth == 0) {
      arguments.add(current);
      break;
    }
    if (token == ',' && depth == 1) {
      arguments.add(current);
      current = [];
      continue;
    }
    current.add(token);
  }
  return arguments;
}

final class UnknownEffect implements Exception {
  final String reason;
  const UnknownEffect(this.reason);

  @override
  String toString() => reason;
}

/// A named field of the instruction word, with the bits that an encoding
/// fixes, most significant first, and null where it leaves them open.
typedef Field = ({int lsb, int width, List<bool?> bits});

/// The shared ASL functions, and which of them write registers or memory.
final class Asl {
  // Address translation, exceptions, debug, trace and error reporting write
  // page tables, system registers or trace buffers, not memory at the
  // operand address, and a load reached a page table write through them
  static final RegExp _sideEffects = RegExp(
    r'^(aarch64|shared)/(translation|exceptions|debug|trace|'
    r'functions/externalaborts|functions/ras)/',
  );

  static const Map<String, String> _registerClasses = {
    'X': 'EXARMO_AARCH64_REG_X',
    'V': 'EXARMO_AARCH64_REG_V',
    'Vpart': 'EXARMO_AARCH64_REG_V',
    'Z': 'EXARMO_AARCH64_REG_Z',
    'P': 'EXARMO_AARCH64_REG_P',
  };

  static const Set<String> _registerSetters = {
    'X.set', 'SP.set', 'V.set', 'Vpart.set', 'Z.set', 'P.set', 'FFR.set', //
    'ZT0.set', '_R.set', '_Z.set', '_P.set',
  };

  /// Bodies of each function, a getter as `Name.get` and a setter as
  /// `Name.set`.
  final Map<String, List<List<Statement>>> functions;
  final Set<String> memoryWriters;
  final Set<String> memoryReaders;
  final Set<String> registerWriters;

  Asl._(
    this.functions,
    this.memoryWriters,
    this.memoryReaders,
    this.registerWriters,
  );

  factory Asl.load(Directory isa) {
    final XmlDocument shared = XmlDocument.parse(
      File('${isa.path}/shared_pseudocode.xml').readAsStringSync(),
    );
    final Map<String, List<List<Statement>>> functions = {};
    void add(String name, String body) =>
        (functions[name] ??= []).add(parseAsl(body));
    for (final XmlElement ps in shared.findAllElements('ps')) {
      if (_sideEffects.hasMatch(ps.getAttribute('name') ?? '')) continue;
      final String source = ps.innerText;
      for (final RegExpMatch match in RegExp(
        r'^(func|accessor|getter|setter)\s+([A-Za-z_][\w.]*)([\s\S]*?)^end;',
        multiLine: true,
      ).allMatches(source)) {
        final String kind = match.group(1)!;
        final String name = match.group(2)!;
        final String rest = match.group(3)!;
        final String body = rest.substring(rest.indexOf('begin') + 5);
        if (kind == 'accessor') {
          final RegExpMatch? getter = RegExp(
            r'^\s*(?:readonly\s+)?getter\b([\s\S]*?)^ {4}end;',
            multiLine: true,
          ).firstMatch(rest);
          final RegExpMatch? setter = RegExp(
            r'^\s*setter\b([\s\S]*?)^ {4}end;',
            multiLine: true,
          ).firstMatch(rest);
          if (getter != null) add('$name.get', getter.group(1)!);
          if (setter != null) add('$name.set', setter.group(1)!);
        } else {
          add(kind == 'func' ? name : '$name.${kind.substring(0, 3)}', body);
        }
      }
    }
    final Map<String, Set<String>> edges = {
      for (final MapEntry(:key, :value) in functions.entries)
        key: {
          for (final List<Statement> body in value)
            for (final String target in _targets(body))
              _resolve(target, functions),
        },
    };
    return Asl._(
      functions,
      _reaching(edges, const {'PhysMemWrite', '_Mem.set', 'PhysMemTagWrite'}),
      // A store reaches a read of allocation tags through its setter, so
      // reads do not pass through setters
      _reaching(edges, const {'PhysMemRead', '_Mem.get'}, setters: false),
      _reaching(edges, _registerSetters),
    );
  }

  static String _resolve(String name, Map<String, Object> functions) =>
      functions.containsKey(name) || name.endsWith('.set')
      ? name
      : functions.containsKey('$name.get')
      ? '$name.get'
      : name;

  /// Functions and setters that [body] reaches.
  static Set<String> _targets(List<Statement> body) {
    final Set<String> targets = {};
    for (final Statement statement in _all(body)) {
      switch (statement) {
        case IfStatement(:final arms):
          for (final arm in arms) targets.addAll(callsIn(arm.condition));
        case CaseStatement(:final subject):
          targets.addAll(callsIn(subject));
        case BlockStatement(:final head):
          targets.addAll(callsIn(head ?? const []));
        case SimpleStatement(:final tokens):
          final (:lhs, :rhs) = splitAssignment(tokens);
          targets.addAll(callsIn(rhs));
          if (lhs == null || lhs.isEmpty || _declares(lhs)) continue;
          final call = callAt(lhs, 0);
          targets.add('${call?.name ?? lhs.first}.set');
          if (call != null) targets.addAll(callsIn(lhs.sublist(call.open)));
      }
    }
    return targets;
  }

  static Set<String> _reaching(
    Map<String, Set<String>> edges,
    Set<String> roots, {
    bool setters = true,
  }) {
    final Set<String> reached = {...roots};
    for (bool changed = true; changed;) {
      changed = false;
      for (final MapEntry(:key, :value) in edges.entries) {
        if (reached.contains(key) || !setters && key.endsWith('.set')) continue;
        if (value.any(reached.contains)) changed = reached.add(key);
      }
    }
    return reached;
  }

  static bool _declares(List<String> lhs) =>
      lhs.first == 'let' || lhs.first == 'var' || lhs.first == 'constant';

  /// Adds the effect of every encoding of [section] to [effects] by exarmo
  /// name, the mnemonics it is written with to [mnemonics] and an alias to
  /// [aliases].
  void readInstruction(
    XmlElement section,
    Map<String, EncodingEffect> effects,
    Map<String, Set<String>> mnemonics,
    Map<String, String> aliases,
  ) {
    final bool alias = section.findAllElements('aliasto').isNotEmpty;
    final List<List<Statement>> execute = _sections(section, 'execute');
    final List<List<Statement>> postdecode = _sections(section, 'postdecode');
    for (final XmlElement iclass in section.findAllElements('iclass')) {
      final List<List<Statement>> decode = _sections(iclass, 'decode');
      for (final XmlElement encoding in iclass.findElements('encoding')) {
        final String name = exarmoName(encoding.getAttribute('name')!);
        final String mnemonic = _mnemonic(encoding) ?? _mnemonic(iclass) ?? '';
        // `ADDHN{2}` is ADDHN2 when Q is set, and exarmo names that form
        final String template =
            encoding.getElement('asmtemplate')?.innerText ?? '';
        mnemonics[name] = {
          mnemonic,
          if (RegExp(r'^\w+\{2\}').hasMatch(template)) '${mnemonic}2',
        };
        if (alias) {
          // The first link of the equivalent template is its mnemonic, which
          // names the encoding; later links name operands such as `Pd`
          final String? href = encoding
              .findAllElements('equivalent_to')
              .firstOrNull
              ?.findAllElements('a')
              .firstOrNull
              ?.getAttribute('href');
          if (href != null && href.contains('#'))
            aliases[name] = exarmoName(href.substring(href.indexOf('#') + 1));
          continue;
        }
        effects[name] = _effect([
          ...decode,
          ...postdecode,
          ...execute,
        ], _fields(iclass, encoding));
      }
    }
  }

  /// The mnemonic an encoding is written with: an alias page names its own
  /// as `alias_mnemonic` and the one it aliases as `mnemonic`.
  static String? _mnemonic(XmlElement element) {
    final Map<String, String> docvars = {
      for (final XmlElement docvar
          in element.getElement('docvars')?.findElements('docvar') ??
              const <XmlElement>[])
        docvar.getAttribute('key')!: docvar.getAttribute('value')!,
    };
    final String? mnemonic = docvars['alias_mnemonic'] ?? docvars['mnemonic'];
    return mnemonic == null ? null : exarmoName(mnemonic);
  }

  static List<List<Statement>> _sections(XmlElement root, String section) => [
    for (final XmlElement text in root.findAllElements('pstext'))
      if (text.getAttribute('section')?.toLowerCase() == section)
        parseAsl(text.innerText),
  ];

  /// The named fields of [encoding], with the bits its pattern fixes.
  static Map<String, Field> _fields(XmlElement iclass, XmlElement encoding) {
    final Map<String, Field> fields = {};
    for (final XmlElement box
        in iclass.getElement('regdiagram')!.findElements('box')) {
      final String? name = box.getAttribute('name');
      if (name == null) continue;
      final int hibit = int.parse(box.getAttribute('hibit')!);
      final int width = int.parse(box.getAttribute('width') ?? '1');
      fields[name] = (
        lsb: hibit - width + 1,
        width: width,
        bits: _cells(box, width),
      );
    }
    for (final XmlElement box in encoding.findElements('box')) {
      final Field? field = fields[box.getAttribute('name')];
      if (field == null) continue;
      final List<bool?> bits = _cells(box, field.width);
      fields[box.getAttribute('name')!] = (
        lsb: field.lsb,
        width: field.width,
        bits: [for (int i = 0; i < field.width; i++) bits[i] ?? field.bits[i]],
      );
    }
    return fields;
  }

  // `!= 11111` and the should-be bits `(0)` leave a bit open, since an
  // instruction may hold another value there
  static List<bool?> _cells(XmlElement box, int width) {
    final List<bool?> bits = [];
    for (final XmlElement cell in box.findElements('c')) {
      final int span = int.parse(cell.getAttribute('colspan') ?? '1');
      final String text = cell.innerText.trim();
      final bool literal =
          text.length == span && RegExp(r'^[01x]+$').hasMatch(text);
      for (int i = 0; i < span; i++) {
        bits.add(literal && text[i] != 'x' ? text[i] == '1' : null);
      }
    }
    while (bits.length < width) bits.add(null);
    return bits.sublist(0, width);
  }

  EncodingEffect _effect(
    List<List<Statement>> bodies,
    Map<String, Field> fields,
  ) {
    final _Evaluator evaluator = _Evaluator(this, fields);
    try {
      Map<String, _Value?>? environment = {};
      for (final List<Statement> body in bodies) {
        if (environment == null) break;
        environment = evaluator.run(body, environment, const {});
      }
    } on UnknownEffect catch (error) {
      return EncodingEffect.unknown(error.reason);
    }
    return EncodingEffect(
      evaluator.writes,
      readsMemory: evaluator.readsMemory,
      writesMemory: evaluator.writesMemory,
    );
  }
}

/// A value of the ASL of one encoding; null where it is not known.
sealed class _Value {
  const _Value();
}

/// Bits, most significant first: null for an unknown bit, and in a literal
/// pattern `'x'` matches any bit.
final class _Bits extends _Value {
  final List<bool?> bits;
  final bool pattern;
  const _Bits(this.bits, {this.pattern = false});

  @override
  bool operator ==(Object other) =>
      other is _Bits &&
      !pattern &&
      !other.pattern &&
      bits.length == other.bits.length &&
      !bits.contains(null) &&
      [for (int i = 0; i < bits.length; i++) bits[i] == other.bits[i]]
          .every((bool equal) => equal);

  @override
  int get hashCode => bits.length;
}

final class _Bool extends _Value {
  final bool value;
  const _Bool(this.value);

  @override
  bool operator ==(Object other) => other is _Bool && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class _Int extends _Value {
  final int value;
  const _Int(this.value);

  @override
  bool operator ==(Object other) => other is _Int && other.value == value;

  @override
  int get hashCode => value;
}

/// A constant of an ASL enumeration, such as `FPConvOp_MOV_ItoF`.
final class _Enum extends _Value {
  final String name;
  const _Enum(this.name);

  @override
  bool operator ==(Object other) => other is _Enum && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// `UInt(field) + delta` for a field the encoding leaves open.
final class _FieldNumber extends _Value {
  final String field;
  final int delta;
  const _FieldNumber(this.field, this.delta);

  @override
  bool operator ==(Object other) =>
      other is _FieldNumber && other.field == field && other.delta == delta;

  @override
  int get hashCode => Object.hash(field, delta);
}

/// Runs the ASL of one encoding over every path its fixed bits allow, and
/// collects what the paths write.
final class _Evaluator {
  static const Set<String> _ending = {
    'EndOfDecode', 'unreachable', 'Unreachable', 'UNDEFINED', 'Undefined', //
    'return', 'throw', 'EndOfInstruction',
  };

  final Asl _asl;
  final Map<String, Field> _fields;
  final Set<RegisterWrite> writes = {};
  bool readsMemory = false;
  bool writesMemory = false;

  _Evaluator(this._asl, this._fields);

  /// The environment after [body], or null when no path through it ends
  /// normally; [stackPointerFields] are the fields that the enclosing
  /// branches found 31.
  Map<String, _Value?>? run(
    List<Statement> body,
    Map<String, _Value?> environment,
    Set<String> stackPointerFields,
  ) {
    Map<String, _Value?>? current = {...environment};
    for (final Statement statement in body) {
      if (current == null) return null;
      current = _statement(statement, current, stackPointerFields);
    }
    return current;
  }

  Map<String, _Value?>? _statement(
    Statement statement,
    Map<String, _Value?> environment,
    Set<String> stackPointerFields,
  ) {
    switch (statement) {
      case IfStatement(:final arms, :final otherwise):
        final List<Map<String, _Value?>?> ends = [];
        Set<String> open = stackPointerFields;
        for (final arm in arms) {
          _calls(arm.condition);
          final _Value? condition = _Expression(
            arm.condition,
            environment,
            _fields,
          ).value();
          final String? field = _testsFor31(arm.condition, environment);
          if (condition == const _Bool(false)) continue;
          final bool equal = !arm.condition.contains('!=');
          ends.add(
            run(arm.body, environment, {
              ...open,
              if (field != null && equal) field,
            }),
          );
          if (condition == const _Bool(true)) return _join(ends);
          if (field != null && !equal) open = {...open, field};
        }
        ends.add(run(otherwise, environment, open));
        return _join(ends);
      case CaseStatement(:final subject, :final arms):
        _calls(subject);
        final _Value? value = _Expression(
          subject,
          environment,
          _fields,
        ).value();
        final List<Map<String, _Value?>?> ends = [];
        for (final arm in arms) {
          final _Value? match = arm.labels.isEmpty
              ? null
              : _anyLabel(value, arm.labels, environment);
          if (match == const _Bool(false)) continue;
          ends.add(run(arm.body, environment, stackPointerFields));
          if (match == const _Bool(true) || arm.labels.isEmpty) break;
        }
        return _join(ends);
      case BlockStatement(:final head, :final body):
        _calls(head ?? const []);
        if (head == null) return run(body, environment, stackPointerFields);
        // A loop may run any number of times, so names it assigns hold no
        // known value inside it or after it
        final Map<String, _Value?> unknown = {
          ...environment,
          for (final String name in _assigned([statement])) name: null,
        };
        return _join([unknown, run(body, unknown, stackPointerFields)]);
      case SimpleStatement(:final tokens):
        return _simple(tokens, environment, stackPointerFields);
    }
  }

  /// Whether [value] matches one of [labels]: a bit pattern, a constant or
  /// a number.
  _Value? _anyLabel(
    _Value? value,
    List<List<String>> labels,
    Map<String, _Value?> environment,
  ) {
    bool unknown = false;
    for (final List<String> label in labels) {
      final _Value? match = _equals(
        value,
        _Expression(label, environment, _fields).value(),
      );
      if (match == const _Bool(true)) return match;
      if (match == null) unknown = true;
    }
    return unknown ? null : const _Bool(false);
  }

  /// The field that `name == 31` or `name != 31` tests, when [tokens] is one.
  String? _testsFor31(List<String> tokens, Map<String, _Value?> environment) {
    if (tokens case [final String name, '==' || '!=', '31']) {
      final _Value? value = environment[name];
      if (value case _FieldNumber(:final field, delta: 0)) return field;
    }
    return null;
  }

  Map<String, _Value?>? _simple(
    List<String> tokens,
    Map<String, _Value?> environment,
    Set<String> stackPointerFields,
  ) {
    if (tokens.isNotEmpty && _ending.contains(tokens.first)) return null;
    final (:lhs, :rhs) = splitAssignment(tokens);
    _calls(rhs);
    if (lhs == null) {
      if (tokens case ['var', final String name, ...]) {
        return {...environment, name: null};
      }
      return environment;
    }
    if (lhs.isEmpty) return environment;
    if (Asl._declares(lhs) && lhs.length >= 2) {
      return {
        ...environment,
        lhs[1]: _Expression(rhs, environment, _fields).value(),
      };
    }
    if (lhs.length == 1 && RegExp(r'^[a-z_]\w*$').hasMatch(lhs.single)) {
      return {
        ...environment,
        lhs.single: _Expression(rhs, environment, _fields).value(),
      };
    }
    if (lhs.first == '(') {
      return {
        ...environment,
        for (final String name in lhs)
          if (RegExp(r'^[a-z_]\w*$').hasMatch(name)) name: null,
      };
    }
    final call = callAt(lhs, 0);
    final String name = call?.name ?? lhs.first;
    if (call == null) {
      // A slice such as `result[7:0] = byte` changes part of a local
      return RegExp(r'^[a-z_]\w*$').hasMatch(name)
          ? {...environment, name: null}
          : environment;
    }
    _calls(lhs.sublist(call.open));
    if (name == 'SP') {
      writes.add(
        stackPointerFields.isEmpty
            ? const RegisterWrite('EXARMO_AARCH64_REG_X_SP', null, 31)
            : RegisterWrite(
                'EXARMO_AARCH64_REG_X_SP',
                _field(stackPointerFields.first),
                0,
                stackPointer: true,
              ),
      );
      return environment;
    }
    final String? registerClass = Asl._registerClasses[name];
    if (registerClass != null) {
      final RegisterWrite? write = _register(
        registerClass,
        argumentsAt(lhs, call.open).first,
        environment,
        stackPointerFields,
      );
      if (write != null) writes.add(write);
      return environment;
    }
    if (name.startsWith('ZA') ||
        name == 'FFR' ||
        name == 'ZT0' ||
        name == '_ZA')
      throw UnknownEffect('writes $name');
    _reach('$name.set');
    return environment;
  }

  RegisterWrite? _register(
    String registerClass,
    List<String> index,
    Map<String, _Value?> environment,
    Set<String> stackPointerFields,
  ) {
    final bool general = registerClass == 'EXARMO_AARCH64_REG_X';
    switch (_Expression(index, environment, _fields).value()) {
      case _Int(:final int value):
        return general && value == 31
            ? null
            : RegisterWrite(registerClass, null, value);
      case _FieldNumber(:final String field, :final int delta):
        if (general && delta == 0 && stackPointerFields.contains(field))
          return null;
        return RegisterWrite(registerClass, _field(field), delta);
      default:
        throw UnknownEffect('register ${index.join(' ')}');
    }
  }

  ({int lsb, int width}) _field(String name) {
    final Field field = _fields[name] ?? (throw UnknownEffect('field $name'));
    return (lsb: field.lsb, width: field.width);
  }

  void _calls(List<String> tokens) {
    for (final String name in callsIn(tokens)) _reach(name);
  }

  void _reach(String name) {
    final String target = Asl._resolve(name, _asl.functions);
    if (_asl.memoryWriters.contains(target)) writesMemory = true;
    if (_asl.memoryReaders.contains(target)) readsMemory = true;
    if (_asl.registerWriters.contains(target) &&
        !Asl._registerSetters.contains(target))
      throw UnknownEffect('$name writes registers');
  }

  static Set<String> _assigned(List<Statement> body) => {
    for (final Statement statement in _all(body))
      if (statement case SimpleStatement(:final tokens))
        if (splitAssignment(tokens).lhs case final List<String> lhs)
          for (final String name in lhs)
            if (RegExp(r'^[a-z_]\w*$').hasMatch(name)) name,
    for (final Statement statement in _all(body))
      if (statement case BlockStatement(head: [final String name, ...])) name,
  };

  static Map<String, _Value?>? _join(List<Map<String, _Value?>?> ends) {
    final List<Map<String, _Value?>> reached = ends.nonNulls.toList();
    if (reached.isEmpty) return null;
    final Map<String, _Value?> first = reached.first;
    return {
      for (final String name in {for (final end in reached) ...end.keys})
        name:
            reached.every(
              (Map<String, _Value?> end) =>
                  end.containsKey(name) && end[name] == first[name],
            )
            ? first[name]
            : null,
    };
  }
}

/// True or false when [left] and [right] are known to be equal or not,
/// with a pattern bit `x` matching any bit.
_Value? _equals(_Value? left, _Value? right) {
  if (left == null || right == null) return null;
  if (left is _Bits && right is _Bits) {
    if (left.bits.length != right.bits.length) return null;
    bool known = true;
    for (int i = 0; i < left.bits.length; i++) {
      final bool? a = left.bits[i];
      final bool? b = right.bits[i];
      if (left.pattern && a == null || right.pattern && b == null) continue;
      if (a == null || b == null) {
        known = false;
      } else if (a != b) {
        return const _Bool(false);
      }
    }
    return known ? const _Bool(true) : null;
  }
  if (left.runtimeType != right.runtimeType) return null;
  return _Bool(left == right);
}

/// One ASL expression of an encoding, evaluated where its fixed bits allow.
final class _Expression {
  final List<String> _tokens;
  final Map<String, _Value?> _environment;
  final Map<String, Field> _fields;
  int _at = 0;

  _Expression(this._tokens, this._environment, this._fields);

  String? get _next => _at < _tokens.length ? _tokens[_at] : null;

  /// The value, or null when it is unknown or the expression is not one
  /// this evaluator reads.
  _Value? value() {
    final _Value? result = _conditional();
    return _at == _tokens.length ? result : null;
  }

  _Value? _conditional() {
    if (_next != 'if') return _or();
    _at++;
    return _ifTail();
  }

  /// The rest of `if c then a elsif ... else b` after `if` or `elsif`.
  _Value? _ifTail() {
    final _Value? condition = _conditional();
    if (_next != 'then') return _fail();
    _at++;
    final _Value? whenTrue = _conditional();
    final _Value? whenFalse;
    if (_next == 'elsif') {
      _at++;
      whenFalse = _ifTail();
    } else if (_next == 'else') {
      _at++;
      whenFalse = _conditional();
    } else {
      return _fail();
    }
    if (condition == const _Bool(true)) return whenTrue;
    if (condition == const _Bool(false)) return whenFalse;
    return whenTrue != null && whenTrue == whenFalse ? whenTrue : null;
  }

  _Value? _or() {
    _Value? left = _and();
    while (_next == '||') {
      _at++;
      final _Value? right = _and();
      left = left == const _Bool(true) || right == const _Bool(true)
          ? const _Bool(true)
          : left == const _Bool(false) && right == const _Bool(false)
          ? const _Bool(false)
          : null;
    }
    return left;
  }

  _Value? _and() {
    _Value? left = _comparison();
    while (_next == '&&') {
      _at++;
      final _Value? right = _comparison();
      left = left == const _Bool(false) || right == const _Bool(false)
          ? const _Bool(false)
          : left == const _Bool(true) && right == const _Bool(true)
          ? const _Bool(true)
          : null;
    }
    return left;
  }

  _Value? _comparison() {
    final _Value? left = _sum();
    final String? operator = _next;
    if (operator == '==' || operator == '!=') {
      _at++;
      final _Value? equal = _equals(left, _sum());
      return operator == '==' || equal == null
          ? equal
          : _Bool(equal != const _Bool(true));
    }
    if (const {'<', '>', '<=', '>=', 'IN'}.contains(operator)) {
      _at++;
      _sum();
      return null;
    }
    return left;
  }

  _Value? _sum() {
    _Value? left = _product();
    while (_next == '+' || _next == '-') {
      final bool add = _tokens[_at++] == '+';
      final _Value? right = _product();
      left = switch ((left, right)) {
        (_Int(value: final a), _Int(value: final b)) => _Int(
          add ? a + b : a - b,
        ),
        (_FieldNumber(:final field, :final delta), _Int(value: final b)) =>
          _FieldNumber(field, add ? delta + b : delta - b),
        _ => null,
      };
    }
    return left;
  }

  _Value? _product() {
    _Value? left = _concatenation();
    while (const {
      '*', '/', 'DIV', 'MOD', '<<', '>>', 'AND', 'OR', 'XOR', 'EOR', '^', //
    }.contains(_next)) {
      _at++;
      _concatenation();
      left = null;
    }
    return left;
  }

  _Value? _concatenation() {
    _Value? left = _unary();
    while (_next == '::') {
      _at++;
      final _Value? right = _unary();
      left = left is _Bits && right is _Bits && !left.pattern && !right.pattern
          ? _Bits([...left.bits, ...right.bits])
          : null;
    }
    return left;
  }

  _Value? _unary() {
    if (_next == '!' || _next == 'NOT') {
      _at++;
      final _Value? operand = _unary();
      return operand is _Bool ? _Bool(!operand.value) : null;
    }
    if (_next == '-') {
      _at++;
      final _Value? operand = _unary();
      return operand is _Int ? _Int(-operand.value) : null;
    }
    return _postfix(_primary());
  }

  _Value? _postfix(_Value? value) {
    while (_next == '[') {
      _at++;
      final _Value? high = _sum();
      _Value? low = high;
      if (_next == ':') {
        _at++;
        low = _sum();
      }
      if (_next != ']') return _fail();
      _at++;
      value = value is _Bits && high is _Int && low is _Int
          ? _slice(value, high.value, low.value)
          : null;
    }
    return value;
  }

  static _Value? _slice(_Bits value, int high, int low) {
    final int width = value.bits.length;
    if (low < 0 || high < low || high >= width) return null;
    return _Bits(value.bits.sublist(width - 1 - high, width - low));
  }

  _Value? _primary() {
    final String? token = _next;
    if (token == null) return null;
    _at++;
    if (token == '(') {
      final _Value? inner = _conditional();
      if (_next != ')') return _fail();
      _at++;
      return inner;
    }
    if (token.startsWith("'")) {
      final String bits = token
          .substring(1, token.length - 1)
          .replaceAll(' ', '');
      return _Bits([
        for (final String bit in bits.split('')) bit == 'x' ? null : bit == '1',
      ], pattern: bits.contains('x'));
    }
    if (int.tryParse(token) case final int number) return _Int(number);
    if (token == 'TRUE' || token == 'FALSE') return _Bool(token == 'TRUE');
    if (!RegExp(r'^[A-Za-z_]').hasMatch(token)) return _fail();
    if (_next == '{') _skipBraces();
    if (_next == '(') {
      final List<List<String>> arguments = argumentsAt(_tokens, _at);
      _skipParentheses();
      if (token == 'UInt' && arguments.length == 1)
        return _unsigned(arguments.single);
      return null;
    }
    if (_environment.containsKey(token)) return _environment[token];
    final Field? field = _fields[token];
    if (field != null) return _Bits(field.bits);
    if (RegExp(r'^[A-Z][A-Za-z0-9]*_\w+$').hasMatch(token)) return _Enum(token);
    return null;
  }

  _Value? _unsigned(List<String> argument) {
    if (argument case [final String name]
        when !_environment.containsKey(name) && _fields.containsKey(name)) {
      final Field field = _fields[name]!;
      if (field.bits.contains(null)) return _FieldNumber(name, 0);
    }
    final _Value? value = _Expression(argument, _environment, _fields).value();
    if (value is! _Bits || value.pattern || value.bits.contains(null))
      return null;
    int number = 0;
    for (final bool? bit in value.bits) {
      number = number << 1 | (bit! ? 1 : 0);
    }
    return _Int(number);
  }

  void _skipBraces() {
    for (int depth = 0; _at < _tokens.length; _at++) {
      if (_tokens[_at] == '{') depth++;
      if (_tokens[_at] == '}' && --depth == 0) {
        _at++;
        return;
      }
    }
  }

  void _skipParentheses() {
    for (int depth = 0; _at < _tokens.length; _at++) {
      if (_tokens[_at] == '(') depth++;
      if (_tokens[_at] == ')' && --depth == 0) {
        _at++;
        return;
      }
    }
  }

  _Value? _fail() {
    _at = _tokens.length + 1;
    return null;
  }
}
