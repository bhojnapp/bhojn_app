import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // AuthWrapper ke liye
import '../services/auth_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool isEmailVerified = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      // 🚀 MAGIC: Har 3 second mein Firebase ko check karega!
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkEmailVerified() async {
    User? user = FirebaseAuth.instance.currentUser;
    await user?.reload(); // Refresh user data from Firebase

    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      _timer?.cancel();
      // Verified hote hi sidha AuthWrapper me bhej do (jo ab Dashboard le jayega)
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A new verification link has been sent to your email.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Wait a few moments before resending.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread_outlined, size: 100, color: BhojnTheme.primaryOrange),
              const SizedBox(height: 30),
              const Text("Verify Your Email", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),
              Text(
                "We have sent a verification email to\n${FirebaseAuth.instance.currentUser?.email}\n\nPlease check your inbox and click on the link to activate your account. This page will automatically redirect once verified.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 40),

              const CircularProgressIndicator(color: BhojnTheme.primaryOrange),
              const SizedBox(height: 20),
              const Text("Waiting for verification...", style: TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold)),

              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: BhojnTheme.primaryOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: resendVerificationEmail,
                  child: const Text("RESEND EMAIL", style: TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () async {
                  _timer?.cancel();
                  await AuthService().logout();
                },
                child: const Text("Wrong email? Sign Out", style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)),
              )
            ],
          ),
        ),
      ),
    );
  }
}