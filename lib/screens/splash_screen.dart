import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart'; // AuthWrapper ke liye

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 🔥 CTO ANIMATION LOGIC: Smooth fade-in aur thoda "pop-out" (Scale) effect
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward(); // Animation start karo
    _startApp(); // Timer start karo
  }

  void _startApp() async {
    // 2.5 seconds ka wait, uske baad seedha Entry Gate pe
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthWrapper()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Welcome To', style: TextStyle(fontSize: 22, color: Colors.grey, letterSpacing: 2.5)),
                SizedBox(height: 5),
                Text('BHOJN', style: TextStyle(fontSize: 65, fontWeight: FontWeight.w900, color: BhojnTheme.primaryOrange, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}