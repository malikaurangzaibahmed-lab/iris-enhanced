import 'dart:io';

void main() async {
  final materialImport = "import 'package:flutter/material.dart';";
  final liquidImport = "import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';";
  
  void ensureImport(String file, String code) {
    var content = File(file).readAsStringSync();
    if (!content.contains(code.trim())) {
      final lines = content.split('\n');
      int importIndex = lines.indexWhere((l) => l.startsWith('import '));
      if (importIndex == -1) importIndex = 0;
      lines.insert(importIndex, code.trim());
      File(file).writeAsStringSync(lines.join('\n'));
      print('Added import to ' + file);
    }
  }

  ensureImport('lib/main.dart', materialImport);
  ensureImport('lib/screens/dashboard_screen.dart', liquidImport);
}
