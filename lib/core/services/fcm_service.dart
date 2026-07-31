import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    if (kIsWeb) {
      // FCM web setup requires a service worker which might not be configured yet.
      return;
    }

    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await _messaging.getToken();
        if (token != null) {
          await _saveTokenToDatabase(token);
        }

        _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          // In a real app, use flutter_local_notifications to display a heads-up alert
          if (kDebugMode) {
            debugPrint('Got a message whilst in the foreground!');
            debugPrint('Message data: ${message.data}');
            if (message.notification != null) {
              debugPrint('Message also contained a notification: ${message.notification}');
            }
          }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('FCM Init Error: $e');
    }
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      // Ignore if user document doesn't exist yet
    }
  }
}
