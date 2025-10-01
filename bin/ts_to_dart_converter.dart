#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';

/// Automated TypeScript to Dart converter
/// Usage: dart run bin/ts_to_dart_converter.dart -i input.ts -o output.dart [--interop]
void main(List<String> args) {
  final parser = ArgParser()
    ..addOption('input', abbr: 'i', help: 'Input TypeScript file path', mandatory: true)
    ..addOption('output', abbr: 'o', help: 'Output Dart file path', mandatory: true)
    ..addFlag('interop', help: 'Generate JavaScript interop code')
    ..addFlag('help', abbr: 'h', help: 'Show usage information');

  try {
    final results = parser.parse(args);

    if (results['help'] as bool) {
      print(parser.usage);
      exit(0);
    }

    final inputPath = results['input'] as String;
    final outputPath = results['output'] as String;
    final generateInterop = results['interop'] as bool;

    final converter = TypeScriptToDartConverter();
    final tsCode = File(inputPath).readAsStringSync();
    final dartCode = converter.convert(tsCode, generateInterop: generateInterop);

    File(outputPath).writeAsStringSync(dartCode);
    print('✅ Conversion complete: $inputPath -> $outputPath');

  } catch (e) {
    print('❌ Error: $e');
    print(parser.usage);
    exit(1);
  }
}

class TypeScriptToDartConverter {
  String convert(String typescriptCode, {bool generateInterop = false}) {
    var dartCode = typescriptCode;

    // Basic type conversions
    dartCode = _convertBasicTypes(dartCode);
    dartCode = _convertInterfaces(dartCode);
    dartCode = _convertClasses(dartCode);
    dartCode = _convertFunctions(dartCode);
    dartCode = _convertModules(dartCode);

    if (generateInterop) {
      dartCode = _addJsInteropAnnotations(dartCode);
    }

    return _formatCode(dartCode);
  }

  String _convertBasicTypes(String code) {
    return code
        .replaceAll('string', 'String')
        .replaceAll('number', 'num')
        .replaceAll('boolean', 'bool')
        .replaceAll('any', 'dynamic')
        .replaceAll('void', 'void')
        .replaceAll('Array<', 'List<')
        .replaceAll('Promise<', 'Future<')
        .replaceAll(': string', ': String')
        .replaceAll(': number', ': num')
        .replaceAll(': boolean', ': bool')
        .replaceAll(': any', ': dynamic')
        .replaceAll(': void', ': void');
  }

  String _convertInterfaces(String code) {
    // Convert TypeScript interfaces to Dart abstract classes
    final interfaceRegex = RegExp(r'interface\s+(\w+)(?:\s+extends\s+([^}]+))?\s*\{([^}]*)\}', multiLine: true);

    return code.replaceAllMapped(interfaceRegex, (match) {
      final name = match.group(1)!;
      final extendsClause = match.group(2);
      final body = match.group(3)!;

      var extendsStr = '';
      if (extendsClause != null && extendsClause.isNotEmpty) {
        extendsStr = ' implements $extendsClause';
      }

      // Convert interface body
      var dartBody = body
          .replaceAll('?', '') // Remove optional markers
          .replaceAll(';', '') // Remove semicolons
          .replaceAllMapped(RegExp(r'(\w+)\s*\(\s*([^)]*)\s*\)\s*:\s*([^;\n]+);'), (funcMatch) {
            final funcName = funcMatch.group(1)!;
            final params = funcMatch.group(2)!;
            final returnType = funcMatch.group(3)!;
            return '$returnType $funcName($params);';
          });

      return 'abstract class $name$extendsStr {\n  $dartBody\n}';
    });
  }

  String _convertClasses(String code) {
    // Convert TypeScript classes to Dart classes
    final classRegex = RegExp(r'class\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}', multiLine: true);

    return code.replaceAllMapped(classRegex, (match) {
      final name = match.group(1);
      final extendsClause = match.group(2);
      final body = match.group(3);

      var extendsStr = '';
      if (extendsClause != null && extendsClause.isNotEmpty) {
        extendsStr = ' extends $extendsClause';
      }

      // Convert class body
      var dartBody = body
          .replaceAll('constructor(', '$name(') // Convert constructor
          .replaceAll('this.', '') // Remove this. references (Dart doesn't need them for field access)
          .replaceAllMapped(RegExp(r'(\w+)\s*\(\s*([^)]*)\s*\)\s*:\s*([^;{]+)'), (methodMatch) {
            // Convert method signatures
            final methodName = methodMatch.group(1);
            final params = methodMatch.group(2);
            final returnType = methodMatch.group(3);
            return '$returnType $methodName($params)';
          });

      return 'class $name$extendsStr {\n  $dartBody\n}';
    });
  }

  String _convertFunctions(String code) {
    // Convert function declarations
    final functionRegex = RegExp(r'function\s+(\w+)\s*\(\s*([^)]*)\s*\)\s*:\s*([^;{]+)', multiLine: true);

    return code.replaceAllMapped(functionRegex, (match) {
      final name = match.group(1);
      final params = match.group(2);
      final returnType = match.group(3);
      return '$returnType $name($params)';
    });
  }

  String _convertModules(String code) {
    // Convert module imports/exports
    var dartCode = code
        .replaceAll('export ', '') // Remove export keywords
        .replaceAll('import {', "import '")
        .replaceAll('} from', ".dart' show")
        .replaceAll('from', "import 'package:")
        .replaceAll("';", ".dart';");

    return dartCode;
  }

  String _addJsInteropAnnotations(String code) {
    var dartCode = code;

    // Add JS interop imports
    const interopImports = '''
import 'package:js/js.dart';
import 'dart:js' as js;

''';

    // Add library annotation and external modifiers
    if (dartCode.contains('class ')) {
      dartCode = '@JS()\nlibrary ts_interop;\n\n' + interopImports + dartCode;

      // Make methods external for JS interop
      dartCode = dartCode.replaceAllMapped(RegExp(r'(\w+)\s+(\w+)\s*\([^)]*\)\s*\{'), (match) {
        final returnType = match.group(1);
        final methodName = match.group(2);
        return 'external $returnType $methodName(';
      });

      // Add @JS annotations to classes
      dartCode = dartCode.replaceAllMapped(RegExp(r'class\s+(\w+)'), (match) {
        final className = match.group(1);
        return '@JS()\nclass $className';
      });
    }

    return dartCode;
  }

  String _formatCode(String code) {
    // Basic code formatting
    return code
        .replaceAll(';;', ';') // Remove double semicolons
        .replaceAll('\n\n\n', '\n\n') // Remove excessive newlines
        .trim();
  }
}
