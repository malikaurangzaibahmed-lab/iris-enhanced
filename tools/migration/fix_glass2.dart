import 'dart:io';

void main() {
  final file = File('d:/IRIS/lib/main.dart');
  String c = file.readAsStringSync();
  int count = 0;

  // 1. NavBar / ClipRRect children with _bottomNavIndex (two identical occurrences)
  c = c.replaceAll(
    '              child: BackdropFilter(\n                filter: ImageFilter.blur(\n                  sigmaX: IrisMotion.reduceBlur\n                      ? 6\n                      : (_bottomNavIndex == 0 ? 16 : 20),\n                  sigmaY: IrisMotion.reduceBlur\n                      ? 6\n                      : (_bottomNavIndex == 0 ? 16 : 20),\n                ),',
    '              child: NativeLiquidGlass(\n                radius: radius,\n                blurRadius: IrisMotion.reduceBlur ? 6.0 : (_bottomNavIndex == 0 ? 16.0 : 20.0),',
  );

  // 2. safeSelected navBar variant
  c = c.replaceAll(
    '          child: BackdropFilter(\n            filter: ImageFilter.blur(\n              sigmaX: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),\n              sigmaY: IrisMotion.reduceBlur ? 6 : (safeSelected == 0 ? 16 : 20),\n            ),',
    '          child: NativeLiquidGlass(\n            radius: radius,\n            blurRadius: IrisMotion.reduceBlur ? 6.0 : (safeSelected == 0 ? 16.0 : 20.0),',
  );

  // 3. GlassCard with explicit blurSigma variable
  c = c.replaceAll(
    '          child: BackdropFilter(\n            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),',
    '          child: NativeLiquidGlass(\n            radius: effectiveRadius,\n            blurRadius: blurSigma,',
  );

  // 4. Dialog builder (3x: showDayFilter, showSortOptions, confirm dialog)
  c = c.replaceAll(
    'builder: (ctx) => BackdropFilter(\n        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),',
    'builder: (ctx) => NativeLiquidGlass(\n        radius: 16.0,\n        blurRadius: 10.0,',
  );

  // Count remaining
  final remaining = RegExp(r'BackdropFilter').allMatches(c).length;
  print('Remaining BackdropFilter instances: $remaining');

  // Only add NativeLiquidGlass import if it got used and isn't already there
  if (!c.contains("import './widgets/native_liquid_glass.dart'")) {
    c = c.replaceFirst("import 'dart:async';", "import './widgets/native_liquid_glass.dart';\nimport 'dart:async';");
    print('Import injected.');
  }

  file.writeAsStringSync(c);
  print('Done.');
}
