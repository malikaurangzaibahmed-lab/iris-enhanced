import 'dart:io';

void main() {
  final file = File('d:/IRIS/lib/main.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll(RegExp(r'BackdropFilter\(\s*filter:\s*ImageFilter\.blur\(sigmaX:\s*10,\s*sigmaY:\s*10\),'), 
                               'NativeLiquidGlass(radius: 0.0, blurRadius: 10.0,');
                               
  content = content.replaceAll(RegExp(r'BackdropFilter\(\s*filter:\s*ImageFilter\.blur\(sigmaX:\s*blurSigma,\s*sigmaY:\s*blurSigma\),'), 
                               'NativeLiquidGlass(radius: effectiveRadius, blurRadius: blurSigma,');                               

  content = content.replaceAll(RegExp(r'BackdropFilter\(\s*filter:\s*ImageFilter\.blur\(\s*sigmaX:\s*IrisMotion\.reduceBlur\s*\?\s*6\s*:\s*\(_bottomNavIndex\s*==\s*0\s*\?\s*16\s*:\s*20\),\s*sigmaY:\s*IrisMotion\.reduceBlur\s*\?\s*6\s*:\s*\(_bottomNavIndex\s*==\s*0\s*\?\s*16\s*:\s*20\),\s*\),'), 
                               'NativeLiquidGlass(radius: radius, blurRadius: IrisMotion.reduceBlur ? 6.0 : (_bottomNavIndex == 0 ? 16.0 : 20.0),');

  content = content.replaceAll(RegExp(r'BackdropFilter\(\s*filter:\s*ImageFilter\.blur\(\s*sigmaX:\s*IrisMotion\.reduceBlur\s*\?\s*6\s*:\s*\(safeSelected\s*==\s*0\s*\?\s*16\s*:\s*20\),\s*sigmaY:\s*IrisMotion\.reduceBlur\s*\?\s*6\s*:\s*\(safeSelected\s*==\s*0\s*\?\s*16\s*:\s*20\),\s*\),'), 
                               'NativeLiquidGlass(radius: radius, blurRadius: IrisMotion.reduceBlur ? 6.0 : (safeSelected == 0 ? 16.0 : 20.0),');
                               
  file.writeAsStringSync(content);
  print('Done parsing main.dart');
}
