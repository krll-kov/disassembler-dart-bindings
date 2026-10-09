import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';

import 'generate_models.dart';

final class ZydisModelsGenerator extends ModelsGenerator {
  ZydisModelsGenerator(Map<String, NativeRecord> records)
    : super(records, const {});

  @override
  void discover(String nativeName, String? owner) {
    if (!nativeName.startsWith('Unnamed')) names[nativeName] = nativeName;
    super.discover(nativeName, owner);
  }

  @override
  String dartType(NamedType type) {
    if (type.name.lexeme == 'Pointer') {
      final String child = elementOf(type).name.lexeme;
      if (names.containsKey(child)) return '${names[child]}?';
    }
    return super.dartType(type);
  }

  @override
  String copyValue(
    NamedType type,
    String access,
    List<int> dimensions, [
    int level = 0,
  ]) {
    if (type.name.lexeme == 'Pointer') {
      final String child = elementOf(type).name.lexeme;
      if (names.containsKey(child)) {
        return '$access.address == 0 ? null : ${names[child]}.copy($access.ref)';
      }
    }
    return super.copyValue(type, access, dimensions, level);
  }
}

Future<void> generateZydisModels(Uri root) async {
  final File source = File.fromUri(
    root.resolve('lib/src/third_party/zydis.g.dart'),
  );
  final CompilationUnit unit = parseString(
    content: source.readAsStringSync(),
    path: source.path,
    throwIfDiagnostics: true,
  ).unit;
  final Map<String, NativeRecord> records = {};
  for (final ClassDeclaration declaration
      in unit.declarations.whereType<ClassDeclaration>()) {
    final String? superclass =
        declaration.extendsClause?.superclass.name.lexeme;
    if (superclass != 'Struct' && superclass != 'Union') continue;
    final List<NativeField> fields = [];
    for (final FieldDeclaration field
        in declaration.body.members.whereType<FieldDeclaration>()) {
      if (field.isStatic || field.fields.type is! NamedType) continue;
      for (final VariableDeclaration variable in field.fields.variables) {
        fields.add(
          NativeField(
            variable.name.lexeme,
            field.fields.type! as NamedType,
            dimensionsOf(field),
          ),
        );
      }
    }
    records[nameOf(declaration)] = NativeRecord(
      nameOf(declaration),
      superclass == 'Union',
      fields,
    );
  }
  final generator = ZydisModelsGenerator(records);
  for (final String nativeName in [
    'ZydisDecodedInstruction',
    'ZydisDecodedOperand',
    'ZydisAccessedFlags',
  ]) {
    generator.discover(nativeName, null);
  }
  final StringBuffer output = StringBuffer(
    "import 'dart:ffi';\n\nimport 'zydis.g.dart' as native;\n\n",
  );
  for (final String name in generator.reached.toList()..sort()) {
    output.writeln(generator.recordSource(records[name]!));
  }
  final formatter = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  );
  await File.fromUri(root.resolve('lib/src/third_party/zydis.models.g.dart'))
      .writeAsString(formatter.format(output.toString()));
  final List<String> constants = [
    for (final ClassDeclaration declaration
        in unit.declarations.whereType<ClassDeclaration>())
      if (!records.containsKey(nameOf(declaration)) &&
          constantsOf(declaration).isNotEmpty)
        nameOf(declaration),
    for (final TopLevelVariableDeclaration declaration
        in unit.declarations.whereType<TopLevelVariableDeclaration>())
      if (declaration.variables.isConst)
        for (final VariableDeclaration field in declaration.variables.variables)
          field.name.lexeme,
  ]..sort();
  await File.fromUri(
    root.resolve('lib/src/third_party/zydis.constants.g.dart'),
  ).writeAsString(
    formatter.format("export 'zydis.g.dart' show ${constants.join(', ')};\n"),
  );
}
