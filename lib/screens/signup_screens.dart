import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Location ke liye
import '../services/auth_service.dart';
import '../widgets/custom_widgets.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

// ============================================================================
// 🎓 STUDENT SIGNUP SCREEN
// ============================================================================
class StudentSignupScreen extends StatefulWidget {
  const StudentSignupScreen({super.key});
  @override
  State<StudentSignupScreen> createState() => _StudentSignupScreenState();
}

class _StudentSignupScreenState extends State<StudentSignupScreen> {
  final AuthService _auth = AuthService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool isLocating = false;
  bool isLoading = false;
  Position? studentLocation;

  Future<void> _fetchLocation() async {
    setState(() => isLocating = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        studentLocation = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Location Fetched Successfully!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to get location. You can skip it for now!")));
    }
    setState(() => isLocating = false);
  }

  void _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _nameCtrl.text.isEmpty || _mobileCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name, Mobile, Email, Password zaruri hain!")));
      return;
    }

    setState(() => isLoading = true);
    try {
      await _auth.register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          role: 'student',
          extraData: {
            'name': _nameCtrl.text.trim(),
            'mobile': _mobileCtrl.text.trim(),
            'alt_mobile': _altMobileCtrl.text.trim(),
            'college': _collegeCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            // 🚀 CTO HACK: Agar location null hai, toh dummy coordinate dal do
            'lat': studentLocation?.latitude ?? 18.5204, // Default Pune Lat
            'lng': studentLocation?.longitude ?? 73.8567, // Default Pune Lng
          }
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(title: const Text("Student Signup 🎓", style: TextStyle(color: BhojnTheme.primaryOrange)), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                const CircleAvatar(radius: 50, backgroundColor: Colors.white10, child: Icon(Icons.person, color: Colors.white54, size: 50)),
                CircleAvatar(radius: 18, backgroundColor: BhojnTheme.primaryOrange, child: IconButton(icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white), onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gallery aage connect karenge!")));
                }, padding: EdgeInsets.zero)),
              ],
            ),
            const SizedBox(height: 10),
            const Text("Add Profile Photo (Optional)", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),

            BhojnInput(controller: _nameCtrl, hint: "Full Name *", icon: Icons.person),
            const SizedBox(height: 15),
            BhojnInput(controller: _emailCtrl, hint: "Email Address *", icon: Icons.email),
            const SizedBox(height: 15),
            BhojnInput(controller: _passCtrl, hint: "Create Password *", icon: Icons.lock, isPassword: true),
            const SizedBox(height: 15),
            BhojnInput(controller: _mobileCtrl, hint: "Mobile No. *", icon: Icons.phone),
            const SizedBox(height: 15),
            BhojnInput(controller: _altMobileCtrl, hint: "Alternate Mobile (Optional)", icon: Icons.phone_android),
            const SizedBox(height: 15),
            BhojnInput(controller: _collegeCtrl, hint: "College/Profession (Optional)", icon: Icons.school),
            const SizedBox(height: 15),
            BhojnInput(controller: _addressCtrl, hint: "Local Address (Optional)", icon: Icons.home),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _fetchLocation,
              icon: isLocating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.location_on),
              label: Text(studentLocation == null ? "Detect My Location (Or Skip) 📍" : "Location Saved ✅"),
              style: ElevatedButton.styleFrom(backgroundColor: studentLocation == null ? Colors.blueGrey : Colors.green, minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 30),

            if (isLoading) const CircularProgressIndicator(color: BhojnTheme.primaryOrange)
            else BhojnButton(text: "CREATE STUDENT ACCOUNT", onPressed: _register, color: BhojnTheme.primaryOrange),

            const SizedBox(height: 10),
            TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen(role: 'student'))),
                child: const Text("Already have an account? Login", style: TextStyle(color: Colors.grey))
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 👑 OWNER SIGNUP SCREEN
// ============================================================================
class OwnerSignupScreen extends StatefulWidget {
  const OwnerSignupScreen({super.key});
  @override
  State<OwnerSignupScreen> createState() => _OwnerSignupScreenState();
}

class _OwnerSignupScreenState extends State<OwnerSignupScreen> {
  final AuthService _auth = AuthService();

  final _messNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  final _thaliCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();

  bool isLocating = false;
  bool isLoading = false;
  Position? messLocation;

  Future<void> _fetchLocation() async {
    setState(() => isLocating = true);
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        messLocation = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Mess Location Locked!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location zaruri hai, but testing ke liye skip kar sakte ho!")));
    }
    setState(() => isLocating = false);
  }

  void _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _messNameCtrl.text.isEmpty || _mobileCtrl.text.isEmpty || _upiCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required (*) fields!")));
      return;
    }

    // 🚀 CTO HACK: Location check temporarily disabled for testing!
    // if (messLocation == null) {
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please detect mess location first! 📍")));
    //   return;
    // }

    setState(() => isLoading = true);
    try {
      await _auth.register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
          role: 'owner',
          extraData: {
            'mess_name': _messNameCtrl.text.trim(),
            'mobile': _mobileCtrl.text.trim(),
            'alt_mobile': _altMobileCtrl.text.trim(),
            'address': _addressCtrl.text.trim(),
            'upi_id': _upiCtrl.text.trim(),
            // 🚀 CTO HACK: Agar location null hai, toh dummy coordinate dal do
            'lat': messLocation?.latitude ?? 18.5204, // Default Lat
            'lng': messLocation?.longitude ?? 73.8567, // Default Lng
            'price_thali': _thaliCtrl.text.isNotEmpty ? _thaliCtrl.text : "N/A",
            'price_monthly': _monthlyCtrl.text.isNotEmpty ? _monthlyCtrl.text : "N/A",
          }
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(title: const Text("Malik Signup 👑", style: TextStyle(color: BhojnTheme.accentRed)), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upto 5 images selection aage connect karenge!")));
              },
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: BhojnTheme.accentRed.withOpacity(0.5), width: 2, style: BorderStyle.solid)),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: BhojnTheme.accentRed, size: 40),
                    SizedBox(height: 5),
                    Text("Select up to 5 Mess Photos", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text("(Menu, Dining area, Kitchen)", style: TextStyle(color: Colors.grey, fontSize: 11))
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            BhojnInput(controller: _messNameCtrl, hint: "Mess Name *", icon: Icons.restaurant),
            const SizedBox(height: 15),
            BhojnInput(controller: _emailCtrl, hint: "Email Address *", icon: Icons.email),
            const SizedBox(height: 15),
            BhojnInput(controller: _passCtrl, hint: "Create Password *", icon: Icons.lock, isPassword: true),
            const SizedBox(height: 15),
            BhojnInput(controller: _mobileCtrl, hint: "Mobile No. *", icon: Icons.phone),
            const SizedBox(height: 15),
            BhojnInput(controller: _altMobileCtrl, hint: "Alternate Mobile (Optional)", icon: Icons.phone_android),
            const SizedBox(height: 15),
            BhojnInput(controller: _addressCtrl, hint: "Full Address text (Optional)", icon: Icons.map),
            const SizedBox(height: 15),
            BhojnInput(controller: _upiCtrl, hint: "UPI ID (For Payments) *", icon: Icons.qr_code),

            const SizedBox(height: 25),
            const Align(alignment: Alignment.centerLeft, child: Text("Pricing (Optional - Edit Later)", style: TextStyle(color: BhojnTheme.accentRed, fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: BhojnInput(controller: _thaliCtrl, hint: "1 Thali ₹", icon: Icons.currency_rupee)),
                const SizedBox(width: 10),
                Expanded(child: BhojnInput(controller: _monthlyCtrl, hint: "Monthly ₹", icon: Icons.calendar_month)),
              ],
            ),
            const SizedBox(height: 25),

            ElevatedButton.icon(
              onPressed: _fetchLocation,
              icon: isLocating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
              label: Text(messLocation == null ? "Detect Location (Or Skip for Test) 📍" : "Location Saved ✅"),
              style: ElevatedButton.styleFrom(backgroundColor: messLocation == null ? BhojnTheme.accentRed : Colors.green, minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 30),

            if (isLoading) const CircularProgressIndicator(color: BhojnTheme.accentRed)
            else BhojnButton(text: "CREATE MESS ACCOUNT", onPressed: _register, color: BhojnTheme.accentRed),

            const SizedBox(height: 10),
            TextButton(
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AuthScreen(role: 'owner'))),
                child: const Text("Already have an account? Login", style: TextStyle(color: Colors.grey))
            )
          ],
        ),
      ),
    );
  }
}