// Copyright (c) 2026, swiftsoft
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_style/dart_style.dart';

import 'generate_models.dart';

Future<void> main(List<String> arguments) async {
  await generateExarmoModels(
    Platform.script.resolve('../'),
    check: arguments.contains('--check'),
  );
}

Future<void> generateExarmoModels(Uri root, {bool check = false}) async {
  final File source = File.fromUri(
    root.resolve('lib/src/third_party/exarmo.g.dart'),
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
      if (field.externalKeyword == null || field.isStatic) continue;
      final TypeAnnotation? type = field.fields.type;
      if (type is! NamedType)
        throw StateError('Unsupported exarmo field: ${field.toSource()}');
      for (final VariableDeclaration variable in field.fields.variables)
        fields.add(
          NativeField(variable.name.lexeme, type, dimensionsOf(field)),
        );
    }
    final String name = nameOf(declaration);
    records[name] = NativeRecord(name, superclass == 'Union', fields);
  }
  final ModelsGenerator generator = ModelsGenerator(records, const {});
  for (final String name in records.keys)
    if (!name.startsWith('Unnamed')) generator.discover(name, null);
  if (generator.names.values.toSet().length != generator.names.length)
    throw StateError('Exarmo model identifiers collide');
  final StringBuffer output = StringBuffer(
    '// Copyright 2026 Vector 35 Inc.\n'
    '// SPDX-License-Identifier: Apache-2.0\n'
    "import 'dart:ffi';\n\n"
    "import 'exarmo.g.dart' as native;\n",
  );
  for (final String name in generator.reached.toList()..sort()) {
    output.writeln();
    output.writeln(generator.recordSource(records[name]!));
  }
  final String generated = DartFormatter(
    languageVersion: DartFormatter.latestLanguageVersion,
  ).format(output.toString());
  final File destination = File.fromUri(
    root.resolve('lib/src/third_party/exarmo.models.g.dart'),
  );
  if (check) {
    if (!destination.existsSync() ||
        destination.readAsStringSync().replaceAll('\r\n', '\n') !=
            generated.replaceAll('\r\n', '\n'))
      throw StateError('Exarmo models differ from generated FFI');
  } else {
    destination.parent.createSync(recursive: true);
    destination.writeAsStringSync(generated);
  }
  stdout.writeln('${generator.reached.length} exarmo models');
}
