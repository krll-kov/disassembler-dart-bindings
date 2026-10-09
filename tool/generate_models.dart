import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:dart_style/dart_style.dart';

class NativeField {
  final String name;
  final NamedType type;
  final List<int> dimensions;

  NativeField(this.name, this.type, this.dimensions);
}

class NativeRecord {
  final String name;
  final bool union;
  final List<NativeField> fields;

  NativeRecord(this.name, this.union, this.fields);
}

String pascal(String value) => value
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
    .join();

String camel(String value) {
  final String result = pascal(value);
  if (result.isEmpty) throw StateError('Empty native name');
  if (int.tryParse(result[0]) != null) return 'mode$result';
  return '${result[0].toLowerCase()}${result.substring(1)}';
}

String nameOf(ClassDeclaration value) => value.namePart.typeName.lexeme;

NamedType elementOf(NamedType value) {
  final List<TypeAnnotation>? args = value.typeArguments?.arguments;
  if (args == null || args.length != 1 || args.single is! NamedType)
    throw StateError('Unsupported native element type: ${value.toSource()}');
  return args.single as NamedType;
}

List<int> dimensionsOf(FieldDeclaration field) {
  for (final Annotation annotation in field.metadata) {
    final String name = annotation.name.toSource().split('.').last;
    if (name != 'Array') continue;
    final List<Expression>? args = annotation.arguments?.arguments
        .map((argument) => argument.argumentExpression)
        .toList();
    if (args == null) throw StateError('Native array has no dimensions');
    final Iterable<AstNode> dimensions =
        args.length == 1 && args.single is ListLiteral
        ? (args.single as ListLiteral).elements
        : args;
    return dimensions.map((value) {
      if (value is! IntegerLiteral || value.value == null || value.value! < 1)
        throw StateError(
          'Unsupported native array dimension: ${value.toSource()}',
        );
      return value.value!;
    }).toList();
  }
  return const [];
}

Map<String, String> constantsOf(ClassDeclaration declaration) => {
  for (final FieldDeclaration member
      in declaration.body.members.whereType<FieldDeclaration>())
    if (member.isStatic && member.fields.isConst)
      for (final VariableDeclaration field in member.fields.variables)
        field.name.lexeme: field.initializer!.toSource(),
};

class ModelsGenerator {
  final Map<String, NativeRecord> records;
  final Map<String, String> names = {};
  final Set<String> reached = {};
  final Map<String, String> architectures;

  ModelsGenerator(this.records, this.architectures);

  void discover(String nativeName, String? owner) {
    if (reached.contains(nativeName)) return;
    final NativeRecord? record = records[nativeName];
    if (record == null) throw StateError('Missing native record $nativeName');
    reached.add(nativeName);
    names[nativeName] ??= nativeName.startsWith('Unnamed')
        ? owner ?? (throw StateError('Anonymous native record has no owner'))
        : pascal(nativeName);
    for (final NativeField field in record.fields) {
      NamedType type = field.type;
      while (type.name.lexeme == 'Array') type = elementOf(type);
      final String child = type.name.lexeme;
      if (!records.containsKey(child)) continue;
      final String suffix = field.name == 'unnamed'
          ? records[child]!.union
                ? 'Union'
                : 'Struct'
          : pascal(field.name);
      discover(child, '${names[nativeName]}$suffix');
    }
  }

  String dartType(NamedType type) {
    final String name = type.name.lexeme;
    if (name == 'Array') return 'List<${dartType(elementOf(type))}>';
    if (name == 'Pointer') return 'int';
    if (names.containsKey(name)) return names[name]!;
    if (const {'bool', 'Bool'}.contains(name)) return 'bool';
    if (const {'double', 'Double', 'Float'}.contains(name)) return 'double';
    if (const {
      'int',
      'Char',
      'SignedChar',
      'UnsignedChar',
      'Short',
      'UnsignedShort',
      'Int',
      'UnsignedInt',
      'Long',
      'UnsignedLong',
      'LongLong',
      'UnsignedLongLong',
      'Int8',
      'Uint8',
      'Int16',
      'Uint16',
      'Int32',
      'Uint32',
      'Int64',
      'Uint64',
      'IntPtr',
      'UintPtr',
      'Size',
      'WChar',
    }.contains(name))
      return 'int';
    throw StateError('Unsupported native field type: ${type.toSource()}');
  }

  String copyValue(
    NamedType type,
    String access,
    List<int> dimensions, [
    int level = 0,
  ]) {
    final String name = type.name.lexeme;
    if (name == 'Array') {
      if (level >= dimensions.length)
        throw StateError('Native array lacks capacity: $access');
      final NamedType element = elementOf(type);
      final String iterator = 'i$level';
      return '<${dartType(element)}>[for (int $iterator = 0; $iterator < '
          '${dimensions[level]}; $iterator++) '
          '${copyValue(element, '$access[$iterator]', dimensions, level + 1)}]';
    }
    if (level != dimensions.length)
      throw StateError(
        'Native array dimensions differ from field type: $access',
      );
    if (name == 'Pointer') return '$access.address';
    if (names.containsKey(name)) return '${names[name]}.copy($access)';
    dartType(type);
    return access;
  }

  String freeze(NamedType type, String access, [int level = 0]) {
    if (type.name.lexeme != 'Array') return access;
    final NamedType element = elementOf(type);
    final String body = element.name.lexeme == 'Array'
        ? '[for (final value$level in $access) '
              '${freeze(element, 'value$level', level + 1)}]'
        : access;
    return 'List<${dartType(element)}>.unmodifiable($body)';
  }

  String recordSource(NativeRecord record) {
    final String name = names[record.name]!;
    final bool architecture = architectures.containsValue(record.name);
    final StringBuffer result = StringBuffer();
    result.writeln(
      'final class $name${architecture ? ' extends ArchitectureDetails' : ''} {',
    );
    for (final NativeField field in record.fields)
      result.writeln('  final ${dartType(field.type)} ${field.name};');
    result.writeln();
    final bool arrays = record.fields.any(
      (field) => field.dimensions.isNotEmpty,
    );
    result.writeln('  ${arrays ? '' : 'const '}$name({');
    for (final NativeField field in record.fields)
      result.writeln(
        field.dimensions.isEmpty
            ? '    required this.${field.name},'
            : '    required ${dartType(field.type)} ${field.name},',
      );
    final List<String> initializers = [
      for (final NativeField field in record.fields)
        if (field.dimensions.isNotEmpty)
          '${field.name} = ${freeze(field.type, field.name)}',
    ];
    result.writeln(
      '  })${initializers.isEmpty ? '' : ' : ${initializers.join(',\n       ')}'};',
    );
    result.writeln();
    result.writeln(
      '  factory $name.copy(native.${record.name} value) => $name(',
    );
    for (final NativeField field in record.fields)
      result.writeln(
        '    ${field.name}: ${copyValue(field.type, 'value.${field.name}', field.dimensions)},',
      );
    result.writeln('  );');
    result.writeln('}');
    return result.toString();
  }
}

Future<void> main(List<String> arguments) async {
  final Uri root = Platform.script.resolve('../');
  final String? metadata = arguments
      .where((value) => value.startsWith('--metadata='))
      .firstOrNull;
  await generateModels(
    root,
    check: arguments.contains('--check'),
    metadata: metadata == null
        ? null
        : File(metadata.substring('--metadata='.length)).absolute.uri,
  );
}

Future<void> generateModels(
  Uri root, {
  bool check = false,
  Uri? metadata,
}) async {
  final File source = File.fromUri(
    root.resolve('lib/src/third_party/capstone.g.dart'),
  );
  final File destination = File.fromUri(
    root.resolve('lib/src/generated/models.g.dart'),
  );
  final CompilationUnit unit = parseString(
    content: source.readAsStringSync(),
    path: source.path,
    throwIfDiagnostics: true,
  ).unit;
  final Map<String, ClassDeclaration> declarations = {
    for (final ClassDeclaration declaration
        in unit.declarations.whereType<ClassDeclaration>())
      nameOf(declaration): declaration,
  };
  final Map<String, NativeRecord> records = {};
  for (final MapEntry<String, ClassDeclaration> entry in declarations.entries) {
    final String? superclass =
        entry.value.extendsClause?.superclass.name.lexeme;
    if (superclass != 'Struct' && superclass != 'Union') continue;
    final List<NativeField> fields = [];
    for (final FieldDeclaration field
        in entry.value.body.members.whereType<FieldDeclaration>()) {
      if (field.externalKeyword == null || field.isStatic) continue;
      final TypeAnnotation? type = field.fields.type;
      if (type is! NamedType)
        throw StateError(
          'Unsupported native field declaration: ${field.toSource()}',
        );
      for (final VariableDeclaration variable in field.fields.variables)
        fields.add(
          NativeField(variable.name.lexeme, type, dimensionsOf(field)),
        );
    }
    records[entry.key] = NativeRecord(entry.key, superclass == 'Union', fields);
  }
  final NativeRecord detail =
      records['cs_detail'] ?? (throw StateError('FFI output lacks cs_detail'));
  final NativeField unionField = detail.fields.singleWhere(
    (field) => records[field.type.name.lexeme]?.union == true,
  );
  final NativeRecord union = records[unionField.type.name.lexeme]!;
  final Map<String, String> architectures = {
    for (final NativeField field in union.fields)
      field.name: field.type.name.lexeme,
  };
  final Map<String, String> archConstants = constantsOf(
    declarations['cs_arch']!,
  );
  final Map<String, String> modeConstants = constantsOf(
    declarations['cs_mode']!,
  );
  final Map<String, String> optionConstants = constantsOf(
    declarations['cs_opt_value']!,
  );
  final ModelsGenerator generator = ModelsGenerator(records, architectures);
  for (final MapEntry<String, String> architecture in architectures.entries) {
    generator.names[architecture.value] = '${pascal(architecture.key)}Details';
    generator.discover(architecture.value, null);
  }
  if (generator.names.values.toSet().length != generator.names.length)
    throw StateError('Generated model names collide');
  final StringBuffer output = StringBuffer();
  output.writeln("import 'dart:ffi';");
  output.writeln();
  output.writeln("import '../third_party/capstone.g.dart' as native;");
  output.writeln();
  output.writeln('enum Architecture {');
  final List<String> nativeArchitectures = archConstants.keys
      .where(
        (constant) =>
            constant.startsWith('CS_ARCH_') &&
            constant != 'CS_ARCH_MAX' &&
            constant != 'CS_ARCH_ALL',
      )
      .toList();
  if (nativeArchitectures.length != architectures.length)
    throw StateError('cs_arch constants and cs_detail branches differ');
  for (final String constant in nativeArchitectures) {
    final String key = constant.substring(8).toLowerCase();
    if (!architectures.containsKey(key))
      throw StateError('Architecture has no cs_detail branch: $constant');
    output.writeln('  ${camel(key)}(native.cs_arch.$constant),');
  }
  output.writeln(
    '  ;\n\n  final int value;\n\n  const Architecture(this.value);\n}',
  );
  output.writeln();
  output.writeln('final class Mode {');
  for (final String constant in modeConstants.keys) {
    if (!constant.startsWith('CS_MODE_')) continue;
    output.writeln(
      '  static const ${camel(constant.substring(8))} = native.cs_mode.$constant;',
    );
  }
  output.writeln('}');
  output.writeln();
  output.writeln('enum Syntax {');
  for (final String constant in optionConstants.keys) {
    if (!constant.startsWith('CS_OPT_SYNTAX_')) continue;
    String name = camel(constant.substring(14));
    if (name == 'default') name = 'defaultSyntax';
    output.writeln('  $name(native.cs_opt_value.$constant),');
  }
  output.writeln('  ;\n\n  final int value;\n\n  const Syntax(this.value);\n}');
  output.writeln();
  output.writeln(
    'sealed class ArchitectureDetails {\n  const ArchitectureDetails();\n}',
  );
  output.writeln();
  output.writeln(
    'ArchitectureDetails copyArchitectureDetails(native.cs_detail detail, int architecture) => switch (architecture) {',
  );
  for (final MapEntry<String, String> architecture in architectures.entries)
    output.writeln(
      '  native.cs_arch.CS_ARCH_${architecture.key.toUpperCase()} => '
      '${generator.names[architecture.value]}.copy(detail.${unionField.name}.${architecture.key}),',
    );
  output.writeln(
    "  _ => throw UnsupportedError('Capstone architecture detail: \$architecture'),\n};",
  );
  for (final String name in generator.reached.toList()..sort()) {
    output.writeln();
    output.writeln(generator.recordSource(records[name]!));
  }
  final DartFormatter formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  final String generated = formatter.format(output.toString());
  if (metadata != null) {
    File.fromUri(metadata).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'architectures': architectures,
        'records': {
          for (final String name in generator.reached.toList()..sort())
            name: {
              'model': generator.names[name],
              'union': records[name]!.union,
              'fields': [
                for (final NativeField field in records[name]!.fields)
                  {
                    'name': field.name,
                    'type': field.type.toSource(),
                    'dimensions': field.dimensions,
                  },
              ],
            },
        },
      }),
    );
  }
  final List<String> constants = [
    for (final MapEntry<String, ClassDeclaration> declaration
        in declarations.entries)
      if (!records.containsKey(declaration.key) &&
          constantsOf(declaration.value).isNotEmpty)
        declaration.key,
    for (final TopLevelVariableDeclaration declaration
        in unit.declarations.whereType<TopLevelVariableDeclaration>())
      if (declaration.variables.isConst)
        for (final VariableDeclaration field in declaration.variables.variables)
          field.name.lexeme,
  ]..sort();
  final String exports = formatter.format(
    "export 'src/third_party/capstone.g.dart' show\n    "
    '${constants.join(',\n    ')};\n',
  );
  final File constantDestination = File.fromUri(
    root.resolve('lib/constants.dart'),
  );
  final File nativeDestination = File.fromUri(root.resolve('lib/native.dart'));
  String nativePreamble = '';
  if (nativeDestination.existsSync()) {
    final String content = nativeDestination.readAsStringSync();
    final CompilationUnit nativeUnit = parseString(content: content).unit;
    if (nativeUnit.directives.isNotEmpty)
      nativePreamble = content.substring(0, nativeUnit.directives.first.offset);
  }
  final List<String> helpers = [
    for (final FunctionDeclaration function
        in unit.declarations.whereType<FunctionDeclaration>())
      if (function.name.lexeme.startsWith('capstone_')) function.name.lexeme,
  ]..sort();
  final String nativeExports = formatter.format(
    "$nativePreamble"
    "export 'src/third_party/capstone.g.dart'"
    "${helpers.isEmpty ? '' : ' hide ${helpers.join(', ')}'};\n",
  );
  if (check) {
    if (!destination.existsSync() ||
        destination.readAsStringSync() != generated)
      throw StateError('Generated architecture models differ from FFI output');
    if (!constantDestination.existsSync() ||
        constantDestination.readAsStringSync() != exports)
      throw StateError('Generated constants differ from FFI output');
    if (!nativeDestination.existsSync() ||
        nativeDestination.readAsStringSync() != nativeExports)
      throw StateError('Generated native exports differ from FFI output');
  } else {
    destination.parent.createSync(recursive: true);
    destination.writeAsStringSync(generated);
    constantDestination.writeAsStringSync(exports);
    nativeDestination.writeAsStringSync(nativeExports);
  }
  final int fields = generator.reached.fold(
    0,
    (sum, name) => sum + records[name]!.fields.length,
  );
  stdout.writeln(
    '${architectures.length} architecture details, '
    '${generator.reached.length} models, $fields fields',
  );
}
