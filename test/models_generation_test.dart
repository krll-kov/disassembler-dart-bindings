import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

import '../tool/generate_models.dart';

Iterable<T> _nodes<T extends AstNode>(AstNode root) sync* {
  if (root is T) yield root;
  for (final AstNode child in root.childEntities.whereType<AstNode>())
    yield* _nodes<T>(child);
}

Map<String, ClassDeclaration> _classes(String source) => {
  for (final ClassDeclaration value in parseString(
    content: source,
    throwIfDiagnostics: true,
  ).unit.declarations.whereType<ClassDeclaration>())
    value.namePart.typeName.lexeme: value,
};

Map<String, FieldDeclaration> _fields(ClassDeclaration type, bool native) => {
  for (final FieldDeclaration field
      in type.body.members.whereType<FieldDeclaration>())
    if (!field.isStatic && (!native || field.externalKeyword != null))
      for (final VariableDeclaration value in field.fields.variables)
        value.name.lexeme: field,
};

void main() {
  final Uri root = Directory.current.absolute.uri;

  test(
    'Generated models and exports match current native declarations',
    () async {
      await generateModels(root, check: true);
    },
  );

  test('Detail dependency fields retain types and native copy sources', () {
    final Map<String, ClassDeclaration> native = _classes(
      File.fromUri(root.resolve('lib/src/third_party/capstone.g.dart'))
          .readAsStringSync(),
    );
    final Map<String, ClassDeclaration> model = _classes(
      File.fromUri(root.resolve('lib/src/generated/models.g.dart'))
          .readAsStringSync(),
    );
    final Map<String, (ClassDeclaration, ConstructorDeclaration)> factories =
        {};
    for (final ClassDeclaration type in model.values) {
      for (final ConstructorDeclaration factory
          in type.body.members.whereType<ConstructorDeclaration>()) {
        if (factory.factoryKeyword == null || factory.name?.lexeme != 'copy')
          continue;
        final String nativeType = _nodes<NamedType>(factory.parameters)
            .singleWhere((value) => value.toSource().startsWith('native.'))
            .name
            .lexeme;
        expect(factories.containsKey(nativeType), isFalse);
        factories[nativeType] = (type, factory);
      }
    }
    String expectedType(NamedType type) {
      final String name = type.name.lexeme;
      if (name == 'Pointer') return 'int';
      if (name == 'Array')
        return 'List<${expectedType(type.typeArguments!.arguments.single as NamedType)}>';
      if (factories.containsKey(name))
        return factories[name]!.$1.namePart.typeName.lexeme;
      if (const {'double', 'Float', 'Double'}.contains(name)) return 'double';
      if (const {'bool', 'Bool'}.contains(name)) return 'bool';
      return 'int';
    }

    final Set<String> nativeRecords = {
      for (final MapEntry<String, ClassDeclaration> type in native.entries)
        if (const {
          'Struct',
          'Union',
        }.contains(type.value.extendsClause?.superclass.name.lexeme))
          type.key,
    };
    final Set<String> reachable = {};
    void visitRecord(String name) {
      if (!reachable.add(name)) return;
      for (final FieldDeclaration field in _fields(
        native[name]!,
        true,
      ).values) {
        NamedType type = field.fields.type as NamedType;
        while (type.name.lexeme == 'Array')
          type = type.typeArguments!.arguments.single as NamedType;
        if (nativeRecords.contains(type.name.lexeme))
          visitRecord(type.name.lexeme);
      }
    }

    final NamedType union = _fields(native['cs_detail']!, true).values
        .map((field) => field.fields.type as NamedType)
        .singleWhere(
          (type) =>
              native[type.name.lexeme]?.extendsClause?.superclass.name.lexeme ==
              'Union',
        );
    for (final FieldDeclaration field in _fields(
      native[union.name.lexeme]!,
      true,
    ).values)
      visitRecord((field.fields.type as NamedType).name.lexeme);
    expect(factories.keys, unorderedEquals(reachable));

    for (final String name in reachable) {
      final (ClassDeclaration copied, ConstructorDeclaration factory) =
          factories[name]!;
      final Map<String, FieldDeclaration> before = _fields(native[name]!, true);
      final Map<String, FieldDeclaration> after = _fields(copied, false);
      expect(after.keys, unorderedEquals(before.keys), reason: name);
      final Map<String, NamedArgument> arguments = {
        for (final NamedArgument arg in _nodes<NamedArgument>(factory.body))
          arg.name.lexeme: arg,
      };
      expect(arguments.keys, unorderedEquals(before.keys), reason: name);
      for (final MapEntry<String, FieldDeclaration> field in before.entries) {
        final String key = field.key;
        final FieldDeclaration target = after[key]!;
        expect(target.fields.isFinal, isTrue, reason: '$name.$key');
        expect(
          target.fields.type!.toSource(),
          expectedType(field.value.fields.type as NamedType),
          reason: '$name.$key',
        );
        final Set<String> referenced = {
          for (final PrefixedIdentifier value in _nodes<PrefixedIdentifier>(
            arguments[key]!,
          ))
            if (value.prefix.name == 'value') value.identifier.name,
          for (final PropertyAccess value in _nodes<PropertyAccess>(
            arguments[key]!,
          ))
            if (value.target is SimpleIdentifier &&
                (value.target as SimpleIdentifier).name == 'value')
              value.propertyName.name,
        };
        expect(referenced, {key}, reason: '$name.$key');
      }
    }
  });
}
