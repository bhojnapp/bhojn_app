import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final dynamic _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 🚀 MEGA FIX: Static flags taaki double initialization na ho
  static bool _isLocalInitialized = false;
  static bool _isListenerActive = false;

  // 1. Local Initialization
  Future<void> initLocalNotifications() async {
    // ✅ FIX: Agar pehle se setup hai, toh dubara mat karo
    if (_isLocalInitialized) return;

    var androidSettings = const AndroidInitializationSettings('@mipmap/launcher_icon');
    var initSettings = InitializationSettings(android: androidSettings);

    try {
      await _localNotificationsPlugin.initialize(
        initSettings, // Pehla positional
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          print("Notification clicked: ${response.payload}");
        },
      );
      _isLocalInitialized = true; // Mark as done
    } catch (e) {
      print("Initialization error, trying backup: $e");
      await _localNotificationsPlugin.initialize(initSettings);
      _isLocalInitialized = true;
    }

    print("Local Chowkidar Ready! ✅");
  }

  // 2. FCM Foreground Listener (Ye active app me notification bajayega)
  void firebaseInit() {
    // ✅ MEGA FIX: Agar listener pehle se lag chuka hai, toh doosra mat banao! (Prevents Double Notification)
    if (_isListenerActive) {
      print("🔔 Listener pehle se active hai, skipping duplicate...");
      return;
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 FCM Foreground Message Aaya: ${message.notification?.title}");

      if (message.notification != null) {
        showLocalNotification(
          message.notification!.title ?? "BHOJN Update",
          message.notification!.body ?? "Naya notification aaya hai!",
        );
      }
    });

    _isListenerActive = true; // Mark as active
  }

  // 3. Show Notification (Local)
  Future<void> showLocalNotification(String title, String body) async {
    var androidDetails = const AndroidNotificationDetails(
      'bhojn_urgent_channel',
      'Bhojn Urgent Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/launcher_icon',
    );

    var details = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      Random().nextInt(100000),
      title,
      body,
      details,
    );
  }

  // 4. Permission maangna
  void requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Bhai, Notification Permission mil gayi! 🎉');
    }
  }

  // 5. Token save karna (Ab ye properly FCM server ko token dega)
  Future<void> saveDeviceToken(String userId, String userType) async {
    try {
      String? token = await messaging.getToken();
      if (token != null) {
        print("FCM Token Generated: $token");
        await FirebaseFirestore.instance
            .collection(userType)
            .doc(userId)
            .set({'fcmToken': token}, SetOptions(merge: true));
      }
    } catch (e) {
      print("Token error: $e");
    }
  }
}