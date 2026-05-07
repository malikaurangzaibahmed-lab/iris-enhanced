import 'dart:io';

void main() {
  final dir = Directory('d:/IRIS/lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  
  final regex = RegExp(r'BackdropFilter\s*\(\s*filter:\s*ImageFilter\.blur\(\s*sigmaX:\s*([0-9.]+)\s*,\s*sigmaY:\s*([0-9.]+)\s*\)\s*,');
  
  for (final file in files) {
    if (file.path.contains('native_liquid_glass.dart')) continue;
    
    String content = file.readAsStringSync();
    if (!content.contains('BackdropFilter')) continue;

    bool changed = false;
    content = content.replaceAllMapped(regex, (match) {
      changed = true;
      return 'NativeLiquidGlass(radius: 0.0, blurRadius: ${match.group(1)},';
    });

    if (changed) {
      if (!content.contains('native_liquid_glass.dart')) {
        // Calculate relative path to widgets folder
        final pathParts = file.path.replaceAll('\\', '/').split('/lib/');
        if (pathParts.length > 1) {
          final depth = pathParts[1].split('/').length - 1;
          final prefix = depth == 0 ? './widgets/' : '../' * depth + 'widgets/';
          content = "import '${prefix}native_liquid_glass.dart';\n" + content;
        }
      }
      file.writeAsStringSync(content);
      print("Updated \${file.path}");
    }
  }
}
