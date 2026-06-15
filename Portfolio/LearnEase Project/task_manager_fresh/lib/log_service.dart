// log_service.dart
import 'dart:io';

class LogService {
  static Future<void> log(String message) async {
    final logFile = File('log.txt'); // Adjust the path as needed
    final currentTime = DateTime.now().toIso8601String();
    final logMessage = '$currentTime: $message\n';
    await logFile.writeAsString(logMessage, mode: FileMode.append);
  }
}
