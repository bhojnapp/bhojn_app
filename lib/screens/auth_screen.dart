import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'signup_screens.dart';

// ===========================================================================
// 🎭 ROLE SELECTION SCREEN (Appears first after Splash)
// ===========================================================================
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String currentLang = "English";

  void _showLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BhojnTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose Language 🌐", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: BhojnTheme.primaryOrange)),
            const SizedBox(height: 20),
            _langTile("English"),
            _langTile("हिंदी (Hindi)"),
            _langTile("मराठी (Marathi)"),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _langTile(String lang) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () {
          setState(() => currentLang = lang);
          Navigator.pop(context);
        },
        title: Text(lang, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        trailing: currentLang == lang ? const Icon(Icons.check_circle, color: BhojnTheme.primaryOrange) : null,
        tileColor: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('BHOJN', style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: BhojnTheme.primaryOrange, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 10),
                      const Text("Pehle batao tum ho kaun? 🤔", style: TextStyle(fontSize: 18, color: Colors.grey)),
                      const SizedBox(height: 50),

                      _buildRoleCard(
                        context,
                        title: "Student (Bhojni)",
                        subtitle: "Khana khane wala",
                        icon: Icons.school,
                        color: BhojnTheme.primaryOrange,
                        role: 'student',
                      ),
                      const SizedBox(height: 20),

                      _buildRoleCard(
                        context,
                        title: "Mess Owner",
                        subtitle: "Mess Malik",
                        icon: Icons.restaurant,
                        color: BhojnTheme.accentRed,
                        role: 'owner',
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(15.0),
              child: TextButton.icon(
                onPressed: _showLanguageSheet,
                icon: const Icon(Icons.language, color: Colors.grey, size: 20),
                label: Text("Language: $currentLang", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required String role}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AuthScreen(role: role))),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// 🔐 AUTH SCREEN (Login) - Dynamic based on Role
// ===========================================================================
class AuthScreen extends StatefulWidget {
  final String role; // 'student' or 'owner'
  const AuthScreen({super.key, required this.role});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isLoading = false;

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email aur Password daalo Boss! 🤨")));
      return;
    }

    setState(() => isLoading = true);
    try {
      // 🚀 THE FIX: Yahan humne widget.role bhej diya Bouncer check ke liye!
      await _auth.login(_emailController.text.trim(), _passwordController.text.trim(), widget.role);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString().split('] ').last}")));
    }
    if(mounted) setState(() => isLoading = false);
  }

  void _goToSignup() {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => widget.role == 'student' ? const StudentSignupScreen() : const OwnerSignupScreen())
    );
  }

  void _showForgotPasswordSheet(Color themeColor) {
    TextEditingController resetEmailCtrl = TextEditingController(text: _emailController.text.trim());

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 30),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_reset, color: Colors.white, size: 40),
                  const SizedBox(height: 15),
                  const Text("Reset Password", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text("Enter the email address associated with your account. We will send you a secure link to reset your password.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 25),

                  TextField(
                    controller: resetEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Registered Email Address",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.email_outlined, color: themeColor),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: () async {
                        String email = resetEmailCtrl.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid email address.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                          return;
                        }

                        FocusScope.of(context).unfocus();

                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Success! A password reset link has been sent to your inbox.", style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 4),
                            ));
                          }
                        } catch (e) {
                          // 🚀 THE FIX: 'Exception: ' aur faltu brackets ko filter karke nikal diya
                          String cleanMessage = e.toString().replaceAll('Exception: ', '').split('] ').last.trim();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(cleanMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.redAccent, // Thoda premium red color
                              behavior: SnackBarBehavior.floating, // Niche se float hoke aayega
                            ));
                          }
                        }
                      },
                      child: const Text("SEND RESET LINK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 25),
                ]
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isStudent = widget.role == 'student';
    Color themeColor = isStudent ? BhojnTheme.primaryOrange : BhojnTheme.accentRed;

    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.grey), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Lottie.asset(
                isStudent
                    ? 'assets/animations/Couple eating.json' // Student ke liye
                    : 'assets/animations/Chef.json',         // 🚀 NAYA: Owner ke liye Chef!
                height: 180,
                fit: BoxFit.contain, // 'contain' better hota hai taaki animation ka koi part kate nahi
              ),
            ),
            const SizedBox(height: 30),

            Text(isStudent ? "STUDENT LOGIN 🎓" : "OWNER LOGIN 👑", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: themeColor)),
            const Text("Apne account mein login karein.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            BhojnInput(controller: _emailController, hint: "Email Address", icon: Icons.email_outlined),
            const SizedBox(height: 15),
            BhojnInput(controller: _passwordController, hint: "Password", icon: Icons.lock_outline, isPassword: true),

            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showForgotPasswordSheet(themeColor),
                  icon: Icon(Icons.lock_reset, color: themeColor, size: 18),
                  label: Text("Forgot Password?", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 15),

            if (isLoading)
              Center(child: CircularProgressIndicator(color: themeColor))
            else ...[
              BhojnButton(text: "LOGIN NOW 🚀", onPressed: _handleLogin, color: themeColor),
              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: themeColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _goToSignup,
                  child: Text("CREATE NEW ACCOUNT 📝", style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}