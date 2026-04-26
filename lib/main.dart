import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/student_dashboard.dart';
import 'screens/owner_dashboard.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background me chup chap notification aayi: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
  );
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

        if (snapshot.hasData && snapshot.data != null) {
          User user = snapshot.data!;

          // 🚀 THE ULTIMATE GATEKEEPER
          if (!user.emailVerified) {
            // 🚀 BUG FIXED HERE: Sahi screen ka naam aur user parameter pass kiya
            return VerifyEmailScreen(user: user);
          }

          if (user.displayName == null || user.displayName!.isEmpty) {
            return _ProfileSyncScreen(user: user);
          }
          final String role = user.displayName ?? 'student';
          return role == 'owner' ? const OwnerDashboard() : const StudentDashboard();
        }

        return const RoleSelectionScreen();
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

// ============================================================================
// 🚀 THE WAITING ROOM (VERIFY EMAIL SCREEN)
// ============================================================================
class VerifyEmailScreen extends StatefulWidget {
  final User user;
  const VerifyEmailScreen({super.key, required this.user});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isChecking = false;

  void _checkVerification() async {
    setState(() => isChecking = true);
    await widget.user.reload(); // Refresh data from Firebase
    User? refreshedUser = FirebaseAuth.instance.currentUser;
    setState(() => isChecking = false);

    if (refreshedUser != null && refreshedUser.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email Verified! Welcome to BHOJN 🎉"), backgroundColor: Colors.green));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Still not verified! Check your SPAM/Junk folder."), backgroundColor: Colors.orange));
    }
  }

  void _resendEmail() async {
    try {
      await widget.user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("New link sent! Please check your Inbox and SPAM folder."), backgroundColor: Colors.green));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().split('] ').last}"), backgroundColor: Colors.red));
    }
  }

  void _cancelAndLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Verification Required", style: TextStyle(color: BhojnTheme.primaryOrange)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: Colors.white, size: 80),
            const SizedBox(height: 20),
            const Text("Check Your Email", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "We have sent a verification link to:\n${widget.user.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.3))),
              child: const Text("⚠️ Note: If you don't see the email, please check your SPAM or JUNK folder.", textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isChecking ? null : _checkVerification,
                child: isChecking
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("I HAVE VERIFIED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: BhojnTheme.primaryOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _resendEmail,
                child: const Text("RESEND EMAIL", style: TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),

            TextButton(
              onPressed: _cancelAndLogout,
              child: const Text("Use a different account", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
            )
          ],
        ),
      ),
    );
  }
}