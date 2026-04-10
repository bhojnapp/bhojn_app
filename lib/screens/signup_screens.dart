import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  Position? studentLocation; // Real GPS Location

  // 🚀 NAYA FEATURE: Real GPS Location Fetcher (Strict)
  Future<void> _fetchLocation() async {
    setState(() => isLocating = true);

    bool serviceEnabled;
    LocationPermission permission;

    // Check if GPS is ON
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bhai pehle phone ka GPS (Location) ON kar le! 🗺️"), backgroundColor: Colors.orange));
      setState(() => isLocating = false);
      return;
    }

    // Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied! Nearby mess nahi dikhenge. 🛑"), backgroundColor: Colors.red));
        setState(() => isLocating = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission permanently denied. Settings se allow kar! ⚙️"), backgroundColor: Colors.red));
      setState(() => isLocating = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        studentLocation = position;
        isLocating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Real Location Captured Successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    }
  }

  void _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _nameCtrl.text.isEmpty || _mobileCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name, Mobile, Email, Password zaruri hain!")));
      return;
    }

    // 🚀 STRICT CHECK: Location mandatory for good Explore experience
    if (studentLocation == null) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: BhojnTheme.surfaceCard,
            title: const Text("Location Missing 📍", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: const Text("Bhai, 'Detect My Location' pe click karke real GPS location de, taaki hum tujhe tere aas-paas ki nearest messes dikha sakein!"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: BhojnTheme.primaryOrange)))
            ],
          )
      );
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
            // 🚀 REAL DATA: Ab dummy data ki jagah exact GPS value cloud pe jayegi
            'lat': studentLocation!.latitude,
            'lng': studentLocation!.longitude,
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
              icon: isLocating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
              label: Text(studentLocation == null ? "Detect My Live Location 📍" : "Location Locked ✅"),
              style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: studentLocation == null ? BhojnTheme.primaryOrange.withOpacity(0.5) : Colors.green,
                  minimumSize: const Size(double.infinity, 50)
              ),
            ),
            if (studentLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Lat: ${studentLocation!.latitude.toStringAsFixed(4)}, Lng: ${studentLocation!.longitude.toStringAsFixed(4)}", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
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
  Position? messLocation; // Real GPS Location

  // 🚀 NAYA FEATURE: Real GPS Location Fetcher for Owner
  Future<void> _fetchLocation() async {
    setState(() => isLocating = true);

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bhai pehle phone ka GPS (Location) ON kar le! 🗺️"), backgroundColor: Colors.orange));
      setState(() => isLocating = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied! Mess map pe nahi dikhegi. 🛑"), backgroundColor: Colors.red));
        setState(() => isLocating = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission permanently denied. Settings se allow kar! ⚙️"), backgroundColor: Colors.red));
      setState(() => isLocating = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        messLocation = position;
        isLocating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Real Mess Location Locked Successfully!"), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => isLocating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    }
  }

  void _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty || _messNameCtrl.text.isEmpty || _mobileCtrl.text.isEmpty || _upiCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required (*) fields!")));
      return;
    }

    // 🚀 STRICT CHECK: Location mandatory for Owner so it shows in distance calculations
    if (messLocation == null) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: BhojnTheme.surfaceCard,
            title: const Text("Mess Location Missing 📍", style: TextStyle(color: BhojnTheme.accentRed, fontWeight: FontWeight.bold)),
            content: const Text("Malik, 'Detect Live Mess Location' pe click karke apne mess ki real GPS location set karo, taaki students ko tumhari mess nearby mein dikhe!"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: BhojnTheme.accentRed)))
            ],
          )
      );
      return;
    }

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
            // 🚀 REAL DATA: Exact GPS value of the Mess
            'lat': messLocation!.latitude,
            'lng': messLocation!.longitude,
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
              label: Text(messLocation == null ? "Detect Live Mess Location 📍" : "Mess Location Locked ✅"),
              style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: messLocation == null ? BhojnTheme.accentRed.withOpacity(0.5) : Colors.green,
                  minimumSize: const Size(double.infinity, 50)
              ),
            ),
            if (messLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Lat: ${messLocation!.latitude.toStringAsFixed(4)}, Lng: ${messLocation!.longitude.toStringAsFixed(4)}", style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
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