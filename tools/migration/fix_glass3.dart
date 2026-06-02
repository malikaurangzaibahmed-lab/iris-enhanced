import 'dart:io';

void main() {
  final file = File('d:/IRIS/lib/main.dart');
  // Read raw bytes and normalise line endings to LF for safe matching
  final raw = file.readAsBytesSync();
  String c = String.fromCharCodes(raw).replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  int before = RegExp(r'BackdropFilter').allMatches(c).length;
  print('BackdropFilter count BEFORE: $before');

  // 1. NavBar / ClipRRect children with _bottomNavIndex
  c = c.replaceAll(
    '              child: BackdropFilter(\n                filter: ImageFilter.blur(\n                  sigmaX: IrisMotion.reduceBlur\n                      ? 6\n                      : (_bottomNavIndex == 0 ? 16 : 20),\n                  sigmaY: IrisMotion.reduceBlur\n                      ? 6\n                      : (_bottomNavIndex == 0 ? 16 : 20),\n                ),',
    '              child: NativeLiquidGlass(\n                radius: radius,\n                blurRadius: IrisMotion.reduceBlur ? 6.0 : (_bottomNavIndex == 0 ? 16.0 : 20.0),',
  );

  // 2. safeSelected navBar variant
  c = c.replaceAll(
    '          child: BackdropFilter(\n            filter: ImageFilter.blur(\n              sigmaX: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),\n              sigmaY: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),\n            ),',
    '          child: NativeLiquidGlass(\n            radius: radius,\n            blurRadius: IrisMotion.reduceBlur ? 6.0 : (safeSelected == 0 ? 16.0 : 20.0),',
  );

  // 3. GlassCard blurSigma
  c = c.replaceAll(
    '          child: BackdropFilter(\n            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),',
    '          child: NativeLiquidGlass(\n            radius: effectiveRadius,\n            blurRadius: blurSigma,',
  );

  // 4. Dialog builders (sigmaX: 10, sigmaY: 10) - three instances
  c = c.replaceAll(
    'builder: (ctx) => BackdropFilter(\n        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),',
    'builder: (ctx) => NativeLiquidGlass(\n        radius: 16.0,\n        blurRadius: 10.0,',
  );

  int after = RegExp(r'BackdropFilter').allMatches(c).length;
  int replaced = RegExp(r'NativeLiquidGlass').allMatches(c).length;
  print('BackdropFilter count AFTER:  $after');
  print('NativeLiquidGlass instances: $replaced');

  // Ensure import is present
  if (!c.contains("import './widgets/native_liquid_glass.dart'")) {
    c = c.replaceFirst("import 'dart:async';", "import './widgets/native_liquid_glass.dart';\nimport 'dart:async';");
    print('Import injected.');
  }

  // Write back with CRLF to stay consistent with existing file
  file.writeAsStringSync(c.replaceAll('\n', '\r\n'));
  print('File written.');
}
