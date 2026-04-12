import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// Helper for Meal Type
String _getMealType(String timeStr) {
  try {
    DateTime parsed = DateFormat('hh:mm a').parse(timeStr);
    int hour = parsed.hour;
    if (hour >= 5 && hour < 11) return "Breakfast 🍳";
    if (hour >= 11 && hour < 16) return "Lunch 🍱";
    return "Dinner 🍽️";
  } catch (e) { return "Meal 🍛"; }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? "Unknown QR";
      _processScannedQR(code);
    }
  }

  void _simulateScanForTesting() {
    if (!isScanning) return;
    // Dev Tool: Put specific owner UID here if testing on emulator
    _processScannedQR("upi://pay?pa=test@ybl&pn=Dummy&tr=OWNER_UID_HERE");
  }

  void _processScannedQR(String code) async {
    setState(() => isScanning = false); cameraController.stop();
    try {
      Uri uri = Uri.parse(code);
      String messUid = uri.queryParameters['tr'] ?? "";
      String ownerUpi = uri.queryParameters['pa'] ?? "";
      if (messUid.isEmpty) messUid = code;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing QR Code...", style: TextStyle(color: Colors.white))));

      var studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      var studentData = studentDoc.data() as Map<String, dynamic>? ?? {};

      // 🚀 ASLI NAAM NIKALA
      String actualStudentName = studentData['name'] ?? "Student";

      // MULTIPLE MESS CHECK
      List<dynamic> activeMesses = studentData['active_messes'] ?? [];
      String? joinedMessId = studentData['joined_mess_id'];

      // Agar enrolled hai, toh direct attendance mark karo
      if (activeMesses.contains(messUid) || joinedMessId == messUid) {
        _markDirectAttendance(messUid, user, actualStudentName);
        return;
      }

      // Agar naya student hai, toh Mess ki info laao aur Join Sheet kholo
      var messDoc = await FirebaseFirestore.instance.collection('users').doc(messUid).get();
      if (!messDoc.exists) { _resetScannerWithError("Invalid Mess QR Code! ❌"); return; }

      var messData = messDoc.data() as Map<String, dynamic>;
      String messName = messData['mess_name'] ?? "Bhojn Mess";
      int priceThali = int.tryParse(messData['price_thali']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      int priceMonthly = int.tryParse(messData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      String finalUpi = messData['upi_id'] ?? ownerUpi;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showLivePaymentSheet(messUid, messName, priceThali, priceMonthly, finalUpi, actualStudentName);
      }
    } catch (e) { _resetScannerWithError("Unrecognized QR Format!"); }
  }

  void _markDirectAttendance(String messUid, User user, String actualStudentName) async {
    String timeStr = DateFormat('hh:mm a').format(DateTime.now());
    String mealType = _getMealType(timeStr);

    var messDoc = await FirebaseFirestore.instance.collection('users').doc(messUid).get();
    String messName = messDoc.data()?['mess_name'] ?? "Mess";

    await FirebaseFirestore.instance.collection('users').doc(messUid).collection('recent_transactions').add({
      'name': actualStudentName, 'uid': user.uid, 'amount': 0, 'type': 'Attendance: $mealType', 'time': timeStr, 'isPending': false, 'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('my_transactions').add({
      'mess_name': messName, 'mess_id': messUid, 'amount': 0, 'type': 'Attendance: $mealType', 'time': timeStr, 'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'remaining_meals': FieldValue.increment(-1),
      'mess_data': {
        messUid: {
          'remaining_meals': FieldValue.increment(-1)
        }
      }
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ $mealType Attendance Marked! Enjoy.", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    }
  }

  void _resetScannerWithError(String errorMsg) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      setState(() => isScanning = true); cameraController.start();
    }
  }

  void _showLivePaymentSheet(String messUid, String messName, int priceThali, int priceMonthly, String ownerUpi, String actualStudentName) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: BhojnTheme.surfaceCard, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) { return _PaymentSheetContent(messUid: messUid, messName: messName, priceThali: priceThali, priceMonthly: priceMonthly, ownerUpi: ownerUpi, studentName: actualStudentName); },
    ).whenComplete(() { setState(() => isScanning = true); cameraController.start(); });
  }

  @override void dispose() { cameraController.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: Stack(children: [
      MobileScanner(controller: cameraController, onDetect: _onDetect),
      Center(child: Container(width: 250, height: 250, decoration: BoxDecoration(border: Border.all(color: BhojnTheme.primaryOrange, width: 3), borderRadius: BorderRadius.circular(20)), child: isScanning ? const SizedBox() : const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange)))),
      Positioned(top: 50, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context))),
      const Positioned(top: 100, left: 0, right: 0, child: Text("Scan Malik's QR Code", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
      Positioned(bottom: 50, left: 50, right: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: _simulateScanForTesting, child: const Text("Dev Hack: Simulate Scan 🚀", style: TextStyle(color: Colors.white))))
    ]));
  }
}

class _PaymentSheetContent extends StatefulWidget {
  final String messUid; final String messName; final int priceThali; final int priceMonthly; final String ownerUpi; final String studentName;
  const _PaymentSheetContent({required this.messUid, required this.messName, required this.priceThali, required this.priceMonthly, required this.ownerUpi, required this.studentName});
  @override State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  bool isJoinMode = false; int thaliQty = 1; late TextEditingController _customAmountCtrl;

  @override void initState() { super.initState(); _customAmountCtrl = TextEditingController(text: widget.priceMonthly.toString()); }

  void _executePayment(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || amount <= 0) return;
    if (widget.ownerUpi.isEmpty || widget.ownerUpi == "No UPI ID") { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Owner hasn't added UPI ID yet!"))); return; }

    String upiUrl = "upi://pay?pa=${widget.ownerUpi}&pn=${Uri.encodeComponent(widget.messName)}&tr=${widget.messUid}&am=$amount&cu=INR";
    Uri uri = Uri.parse(upiUrl);

    try { await launchUrl(uri, mode: LaunchMode.externalApplication); } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open UPI app. Please install GPay/PhonePe.")));
    }

    if (mounted) {
      bool? didPay = await showDialog<bool>(
          context: context, barrierDismissible: false,
          builder: (context) => AlertDialog(
              backgroundColor: BhojnTheme.surfaceCard, title: const Text("Confirm Payment", style: TextStyle(color: Colors.white)),
              content: const Text("Did your payment complete successfully in your UPI App?", style: TextStyle(color: Colors.grey)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No, Cancel", style: TextStyle(color: Colors.redAccent))),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange), onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Paid ✅")),
              ]
          )
      );

      if (didPay != true) return;

      String timeStr = DateFormat('hh:mm a').format(DateTime.now());

      if (isJoinMode) {
        int pendingDue = widget.priceMonthly - amount;
        if (pendingDue < 0) pendingDue = 0;

        // 🚀 ULTIMATE BRAHMASTRA DATA PAYLOAD: Ye saari keys cover kar lega!
        Map<String, dynamic> requestPayload = {
          'owner_id': widget.messUid,
          'mess_id': widget.messUid,        // Extra safety
          'student_id': user.uid,           // Functions aur nayi UI ke liye
          'student_uid': user.uid,          // Purani UI ke liye
          'student_name': widget.studentName,
          'paid_amount': amount,
          'pending_dues': pendingDue,
          'total_allotted_meals': 60,
          'status': 'pending',              // ⚠️ Bada 'P', kyunki Explore yahi use karta hai
          'timestamp': FieldValue.serverTimestamp()
        };

        // 1. GLOBAL Collection mein bhej diya (Cloud functions aur naye raste ke liye)
        // Doc ID 'user.uid' rakhi hai taaki Owner UI direct id pakad sake.
        await FirebaseFirestore.instance.collection('join_requests').doc(user.uid).set(requestPayload);

        // 2. SUB-COLLECTION mein bhi bhej diya (Agar Owner ka Dashboard abhi bhi purana rasta use kar raha hai toh)
        await FirebaseFirestore.instance.collection('users').doc(widget.messUid).collection('join_requests').doc(user.uid).set(requestPayload);

        // 3. Owner ko notification/history mein dikhane ke liye
        await FirebaseFirestore.instance.collection('users').doc(widget.messUid).collection('recent_transactions').add({
          'name': widget.studentName, 'uid': user.uid, 'amount': amount, 'type': 'Join Request (Pending)', 'time': timeStr, 'isPending': true, 'timestamp': FieldValue.serverTimestamp(),
        });

      } else {
        // Normal Daily Thali Code
        String type = "Thali x$thaliQty (Pending)";
        await FirebaseFirestore.instance.collection('users').doc(widget.messUid).collection('recent_transactions').add({
          'name': widget.studentName, 'uid': user.uid, 'amount': amount, 'type': type, 'time': timeStr, 'isPending': true, 'timestamp': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('my_transactions').add({
          'mess_name': widget.messName, 'mess_id': widget.messUid, 'amount': amount, 'type': type, 'time': timeStr, 'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context); Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⏳ Request Sent! Waiting for Owner Approval.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.orange));
      }
    }
  }

  @override Widget build(BuildContext context) {
    int totalThaliPrice = widget.priceThali * thaliQty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20),
        Row(children: [const CircleAvatar(backgroundColor: BhojnTheme.primaryOrange, child: Icon(Icons.restaurant, color: Colors.white)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Paying to", style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(widget.messName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]))]), const SizedBox(height: 25),
        Row(children: [Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: !isJoinMode ? BhojnTheme.primaryOrange : Colors.white10, elevation: 0), onPressed: () => setState(() => isJoinMode = false), child: Text("Daily Thali", style: TextStyle(color: !isJoinMode ? Colors.white : Colors.grey)))), const SizedBox(width: 10), Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isJoinMode ? BhojnTheme.primaryOrange : Colors.white10, elevation: 0), onPressed: () => setState(() => isJoinMode = true), child: Text("Join Mess", style: TextStyle(color: isJoinMode ? Colors.white : Colors.grey))))]), const SizedBox(height: 25),
        if (!isJoinMode) ...[
          const Text("Thali Quantity", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [IconButton(onPressed: () { if (thaliQty > 1) setState(() => thaliQty--); }, icon: const Icon(Icons.remove_circle_outline, color: BhojnTheme.primaryOrange, size: 30)), Text(thaliQty.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), IconButton(onPressed: () => setState(() => thaliQty++), icon: const Icon(Icons.add_circle_outline, color: BhojnTheme.primaryOrange, size: 30))]), Text("₹ $totalThaliPrice", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))]), const SizedBox(height: 30),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () => _executePayment(totalThaliPrice), child: Text("PAY ₹$totalThaliPrice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ] else ...[
          const Text("Enter Payment Amount", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 10),
          TextField(controller: _customAmountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))), const SizedBox(height: 10), const Text("Owner's Monthly Price is loaded by default. You can edit this amount.", style: TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 30),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { int customAmt = int.tryParse(_customAmountCtrl.text.trim()) ?? 0; _executePayment(customAmt); }, child: const Text("PAY & JOIN MESS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ]
      ]),
    );
  }
}