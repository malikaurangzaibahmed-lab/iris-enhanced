import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

class SystemBroadcastService {
  static final SystemBroadcastService _instance = SystemBroadcastService._internal();
  factory SystemBroadcastService() => _instance;
  SystemBroadcastService._internal();

  final _broadcastController = StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream of incoming push notifications and system broadcasts
  Stream<Map<String, dynamic>> get stream => _broadcastController.stream;

  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true, 
      announcement: true,
      badge: true, 
      sound: true
    );

    // Free Push Notification Bridge
    // Automatically forwards FCM payloads to the Smart Pill UI
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _broadcastController.add({
          'title': message.notification!.title ?? 'System Announcement',
          'body': message.notification!.body ?? '',
          'isUrgent': message.data['urgent'] == 'true',
        });
      }
    });
  }

  /// Manually trigger a UI banner (Useful if an admin publishes a local change)
  void triggerLocalOverride(
    String title, 
    String body, {
    bool isUrgent = false, 
    bool isPersistent = false, 
    bool dismiss = false,
    Duration? duration,
  }) {
    _broadcastController.add({
      'title': title,
      'body': body,
      'isUrgent': isUrgent,
      'isPersistent': isPersistent,
      'dismiss': dismiss,
      'durationMs': duration?.inMilliseconds,
    });
  }

  /// Admins call this to bypass Firebase rules and hit the 0-cost Cloudflare Worker
  Future<bool> publishGlobalNetworkOverride(String title, String body, {bool isUrgent = false}) async {
    try {
      // NOTE: Replace this purely with the actual assigned Cloudflare URL when deployed
      const workerUrl = 'https://iris.malikaurangzaibahmed.workers.dev';
      
      final response = await http.post(
        Uri.parse(workerUrl),
         headers: {
           'Content-Type': 'application/json',
           'Authorization': 'Bearer SUPER_SECRET_ADMIN_OMNIFLOW_KEY'
         },
         body: jsonEncode({
           'title': isUrgent ? '⚠️ CRITICAL: $title' : title,
           'body': body,
           'topic': 'all_students'
         })
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
