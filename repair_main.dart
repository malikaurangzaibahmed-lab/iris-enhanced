import 'dart:io';

void main() {
  final content = File('lib/main.dart').readAsStringSync();
  final badStart = 'const MethodChannel _notificationChannel = MethodChannel(';
  final badEnd = 'class _AppRoot extends StatefulWidget {';
  
  final startIndex = content.indexOf(badStart);
  final endIndex = content.indexOf(badEnd);
  
  if (startIndex == -1 || endIndex == -1) {
    print('Could not find bad boundary');
    return;
  }
  
  final restoreContent = File('restore_main.dart').readAsStringSync();
  
  final replacement = '''
const MethodChannel _notificationChannel = MethodChannel('iris/notification_channel');

\

''';

  final newContent = content.substring(0, startIndex) + replacement + content.substring(endIndex);
  File('lib/main.dart').writeAsStringSync(newContent);
  print('Replaced broken section in main.dart!');
}
