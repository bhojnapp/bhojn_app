import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationServices {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static bool _isLocalInitialized = false;
  static bool _isListenerActive = false;

  // 1. Local Initialization
  Future<void> initLocalNotifications() async {
    if (_isLocalInitialized) return;

    var androidSettings = const AndroidInitializationSettings('@mipmap/launcher_icon');
    var initSettings = InitializationSettings(android: androidSettings);

    try {
      // 🚀 ASLI FIX: Naye version mein parameter ka naam sirf 'settings' hai
      await _localNotificationsPlugin.initialize(
        settings: initSettings,
      );

      var androidChannel = const AndroidNotificationChannel(
        'bhojn_urgent_channel',
        'Bhojn Urgent Alerts',
        importance: Importance.max,
        playSound: true,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _isLocalInitialized = true;
    } catch (e) {
      print("Initialization error: $e");
    }

    print("Local Chowkidar Ready with VIP Channel! ✅");
  }

  // 2. FCM Foreground Listener
  void firebaseInit() {
    if (_isListenerActive) return;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 FCM Foreground Message Aaya: ${message.notification?.title}");

      if (message.notification != null) {
        showLocalNotification(
          message.notification!.title ?? "BHOJN Update",
          message.notification!.body ?? "Naya notification aaya hai!",
        );
      }
    });

    _isListenerActive = true;
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

    // 🚀 ASLI FIX: show() ke andar bhi sab kuch exact naam (id:, title:) ke sath dena padta hai
    await _localNotificationsPlugin.show(
      id: Random().nextInt(100000),
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  // 4. Permission maangna (Android 13+ Popup Fix)
  Future<void> requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true
    );

    // Android 13+ popup
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Bhai, Notification Permission mil gayi! 🎉');
    }
  }

  // 5. Token save karna
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