import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _nameController = TextEditingController();
  final _upiController = TextEditingController(); // ✅ Added for UPI
  final _messNameController = TextEditingController(); // ✅ Mess Name
  bool isLoading = false;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    setState(() => isLoading = true);
    try {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        setState(() {
          _nameController.text = doc.get('name') ?? "";
          _upiController.text = doc.get('upi_id') ?? "";
          _messNameController.text = doc.get('mess_name') ?? "";
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
    }
    setState(() => isLoading = false);
  }

  void _saveProfile() async {
    if (_nameController.text.isEmpty || _upiController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Naam aur UPI ID zaruri hai Boss! 🤨")));
      return;
    }

    setState(() => isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameController.text.trim(),
        'upi_id': _upiController.text.trim(),
        'mess_name': _messNameController.text.trim(),
        'email': user!.email,
        'role': user!.displayName, // Store role for easy access
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile & Payment Info Saved! 💰"), backgroundColor: Colors.green)
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(title: const Text("Profile & Setup ⚙️"), elevation: 0, backgroundColor: Colors.transparent),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, backgroundColor: BhojnTheme.primaryOrange, child: Icon(Icons.person, size: 50, color: Colors.black)),
            const SizedBox(height: 35),

            _buildLabel("Full Name"),
            BhojnInput(controller: _nameController, hint: "Shri...", icon: Icons.person_outline),

            const SizedBox(height: 20),
            _buildLabel("Mess Name (If Owner)"),
            BhojnInput(controller: _messNameController, hint: "E.g. Royal Mess", icon: Icons.restaurant),

            const SizedBox(height: 20),
            _buildLabel("UPI ID for Payments (VPA)"),
            BhojnInput(controller: _upiController, hint: "example@okaxis", icon: Icons.payments_outlined),

            const SizedBox(height: 40),
            if (isSaving)
              const CircularProgressIndicator(color: BhojnTheme.primaryOrange)
            else
              BhojnButton(text: "SAVE SETTINGS ✅", onPressed: _saveProfile, color: BhojnTheme.primaryOrange),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(bottom: 8, left: 5), child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)));
}