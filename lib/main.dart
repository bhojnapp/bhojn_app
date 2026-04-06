import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
// ✅ NEW: FCM ka import
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/student_dashboard.dart';
import 'screens/owner_dashboard.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

// ✅ NEW: Background Notification Handler (Isko class ke bahar hi rakhna hai)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate ke liye Firebase initialize karna zaroori hai
  await Firebase.initializeApp();
  print("Background me chup chap notification aayi: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ NEW: Background handler ko activate kiya
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const BhojnApp());
}

class BhojnApp extends StatelessWidget {
  const BhojnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BHOJN',
      theme: BhojnTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();

    return StreamBuilder<User?>(
      stream: auth.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: BhojnTheme.darkBg, body: Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange)));
        }

        // Agar user logged in hai
        if (snapshot.hasData && snapshot.data != null) {
          User user = snapshot.data!;
          if (user.displayName == null || user.displayName!.isEmpty) {
            return _ProfileSyncScreen(user: user);
          }
          final String role = user.displayName ?? 'student';
          return role == 'owner' ? OwnerDashboard() : StudentDashboard();
        }

        // Agar logged in NAHI hai
        return RoleSelectionScreen();
      },
    );
  }
}

class _ProfileSyncScreen extends StatefulWidget {
  final User user;
  const _ProfileSyncScreen({required this.user});

  @override
  State<_ProfileSyncScreen> createState() => _ProfileSyncScreenState();
}

class _ProfileSyncScreenState extends State<_ProfileSyncScreen> {
  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  void _refreshUser() async {
    await Future.delayed(const Duration(seconds: 2));
    await widget.user.reload();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: BhojnTheme.primaryOrange),
            SizedBox(height: 20),
            Text("Finalizing your setup...", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Taking you to your dashboard shortly.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}