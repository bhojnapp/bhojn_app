import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart'; // Ensure this path is correct

// Helper for Meal Type
String _getMealType(String timeStr) {
  try {
    DateTime parsed = DateFormat('hh:mm a').parse(timeStr);
    int hour = parsed.hour;
    if (hour >= 5 && hour < 11) return "Breakfast 🍳";
    if (hour >= 11 && hour < 16) return "Lunch 🍱";
    return "Dinner 🍽️";
  } catch (e) {
    return "Meal 🍛";
  }
}

// Payment Mode Enum (Naya Jugaad for 3 Options)
enum PaymentMode { thali, fifteenDays, monthly }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;

  // 🚀 NAYA JUGAAD: Apna khud ka state variable flashlight ke liye
  bool _isTorchOn = false;

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? "Unknown QR";
      _processScannedQR(code);
    }
  }

  void _processScannedQR(String code) async {
    setState(() => isScanning = false);
    cameraController.stop();

    try {
      Uri uri = Uri.parse(code);
      String messUid = uri.queryParameters['tr'] ?? "";
      String ownerUpi = uri.queryParameters['pa'] ?? "";
      if (messUid.isEmpty) messUid = code;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processing QR Code...", style: TextStyle(color: Colors.white)), duration: Duration(seconds: 1)),
      );

      // 🚀 TIMEOUT LAGA DIYA HAI TAANI APP ATKE NAHI (Bug #1 Fixed)
      var studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10), onTimeout: () => throw Exception("timeout"));

      var studentData = studentDoc.data() as Map<String, dynamic>? ?? {};
      String actualStudentName = studentData['name'] ?? "Student";
      List<dynamic> activeMesses = studentData['active_messes'] ?? [];
      String? joinedMessId = studentData['joined_mess_id'];

      // Agar enrolled hai, toh direct attendance mark karo
      if (activeMesses.contains(messUid) || joinedMessId == messUid) {
        _markDirectAttendance(messUid, user, actualStudentName);
        return;
      }

      // Agar naya student hai, toh Mess ki info laao
      var messDoc = await FirebaseFirestore.instance.collection('users').doc(messUid)
          .get()
          .timeout(const Duration(seconds: 10), onTimeout: () => throw Exception("timeout"));

      if (!messDoc.exists) {
        _resetScannerWithError("Invalid Mess QR Code! ❌");
        return;
      }

      var messData = messDoc.data() as Map<String, dynamic>;
      String messName = messData['mess_name'] ?? "Bhojn Mess";

      int priceThali = int.tryParse(messData['price_thali']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      int priceMonthly = int.tryParse(messData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

      // Fallback: Agar owner ne 15 days ka price set nahi kiya, toh exactly half pakad lega.
      int price15Days = int.tryParse(messData['price_15days']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? (priceMonthly ~/ 2);

      String finalUpi = messData['upi_id'] ?? ownerUpi;

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showLivePaymentSheet(messUid, messName, priceThali, price15Days, priceMonthly, finalUpi, actualStudentName);
      }
    } catch (e) {
      if (e.toString().contains("timeout")) {
        _resetScannerWithError("Internet connection is slow! 📶");
      } else {
        _resetScannerWithError("Unrecognized QR Format!");
      }
    }
  }

  void _markDirectAttendance(String messUid, User user, String actualStudentName) async {
    String timeStr = DateFormat('hh:mm a').format(DateTime.now());
    String mealType = _getMealType(timeStr);

    try {
      var messDoc = await FirebaseFirestore.instance.collection('users').doc(messUid).get().timeout(const Duration(seconds: 10));
      String messName = messDoc.data()?['mess_name'] ?? "Mess";

      // Mark Transactions
      await FirebaseFirestore.instance.collection('users').doc(messUid).collection('recent_transactions').add({
        'name': actualStudentName, 'uid': user.uid, 'amount': 0, 'type': 'Attendance: $mealType', 'time': timeStr, 'isPending': false, 'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('my_transactions').add({
        'mess_name': messName, 'mess_id': messUid, 'amount': 0, 'type': 'Attendance: $mealType', 'time': timeStr, 'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'remaining_meals': FieldValue.increment(-1),
        'mess_data': { messUid: { 'remaining_meals': FieldValue.increment(-1) } }
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ $mealType Attendance Marked! Enjoy.", style: const TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      _resetScannerWithError("Failed to mark attendance due to network. Try again!");
    }
  }

  void _resetScannerWithError(String errorMsg) {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      setState(() => isScanning = true);
      cameraController.start();
    }
  }

  void _showLivePaymentSheet(String messUid, String messName, int priceThali, int price15Days, int priceMonthly, String ownerUpi, String actualStudentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BhojnTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return _PaymentSheetContent(
            messUid: messUid, messName: messName, priceThali: priceThali,
            price15Days: price15Days, priceMonthly: priceMonthly,
            ownerUpi: ownerUpi, studentName: actualStudentName
        );
      },
    ).whenComplete(() {
      setState(() {
        isScanning = true;
        _isTorchOn = false; // Sheet band hone par torch UI reset
      });
      cameraController.start();
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                  border: Border.all(color: BhojnTheme.primaryOrange, width: 3),
                  borderRadius: BorderRadius.circular(20)),
              child: isScanning ? const SizedBox() : const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange)),
            ),
          ),
          Positioned(top: 50, left: 20, child: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context))),

          // 🚀 FLASHLIGHT BUTTON FIXED (ValueListenable Error Removed)
          Positioned(
            top: 50, right: 20,
            child: IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? BhojnTheme.primaryOrange : Colors.white,
                size: 30,
              ),
              onPressed: () {
                cameraController.toggleTorch();
                setState(() {
                  _isTorchOn = !_isTorchOn;
                });
              },
            ),
          ),

          const Positioned(top: 100, left: 0, right: 0, child: Text("Scan Owner's QR Code", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class _PaymentSheetContent extends StatefulWidget {
  final String messUid; final String messName; final int priceThali; final int price15Days; final int priceMonthly; final String ownerUpi; final String studentName;
  const _PaymentSheetContent({required this.messUid, required this.messName, required this.priceThali, required this.price15Days, required this.priceMonthly, required this.ownerUpi, required this.studentName});
  @override
  State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  PaymentMode _selectedMode = PaymentMode.thali;
  int thaliQty = 1;
  late TextEditingController _customAmountCtrl;

  @override
  void initState() {
    super.initState();
    _customAmountCtrl = TextEditingController(text: widget.priceMonthly.toString());
  }

  void _updateAmountField(PaymentMode mode) {
    setState(() {
      _selectedMode = mode;
      if (mode == PaymentMode.fifteenDays) {
        _customAmountCtrl.text = widget.price15Days.toString();
      } else if (mode == PaymentMode.monthly) {
        _customAmountCtrl.text = widget.priceMonthly.toString();
      }
    });
  }

  void _executePayment(int amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || amount <= 0) return;
    if (widget.ownerUpi.isEmpty || widget.ownerUpi == "No UPI ID") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Owner hasn't added UPI ID yet!")));
      return;
    }

    // 🚀🚀 NAYA FIX: SPAM BLOCKER (UPI App khulne se pehle check!) 🚀🚀
    if (_selectedMode != PaymentMode.thali) {
      try {
        var existingReq = await FirebaseFirestore.instance.collection('join_requests').doc(user.uid).get();
        if (existingReq.exists && existingReq.data()?['status'] == 'pending') {
          if (mounted) {
            Navigator.pop(context); // Payment sheet band kar do
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Hold on! ✋ You already have a pending request. Please wait for the owner's response.", style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ));
          }
          return; // 🛑 Yahan se aage code nahi jayega, UPI app open nahi hoga!
        }
      } catch (e) {
        print("Error checking pending requests: $e");
      }
    }

    String upiUrl = "upi://pay?pa=${widget.ownerUpi}&pn=${Uri.encodeComponent(widget.messName)}&tr=${widget.messUid}&am=$amount&cu=INR";
    Uri uri = Uri.parse(upiUrl);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
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

      if (_selectedMode != PaymentMode.thali) {
        // Handle 15 Days or Monthly
        int expectedTotal = _selectedMode == PaymentMode.fifteenDays ? widget.price15Days : widget.priceMonthly;
        int allottedMeals = _selectedMode == PaymentMode.fifteenDays ? 30 : 60;

        int pendingDue = expectedTotal - amount;
        if (pendingDue < 0) pendingDue = 0;

        Map<String, dynamic> requestPayload = {
          'owner_id': widget.messUid,
          'mess_id': widget.messUid,
          'student_id': user.uid,
          'student_uid': user.uid,
          'student_name': widget.studentName,
          'paid_amount': amount,
          'pending_dues': pendingDue,
          'total_allotted_meals': allottedMeals,
          'plan_type': _selectedMode == PaymentMode.fifteenDays ? '15 Days' : 'Monthly',
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp()
        };

        await FirebaseFirestore.instance.collection('join_requests').doc(user.uid).set(requestPayload);
        await FirebaseFirestore.instance.collection('users').doc(widget.messUid).collection('join_requests').doc(user.uid).set(requestPayload);

        await FirebaseFirestore.instance.collection('users').doc(widget.messUid).collection('recent_transactions').add({
          'name': widget.studentName, 'uid': user.uid, 'amount': amount, 'type': 'Join Request (${_selectedMode == PaymentMode.fifteenDays ? "15 Days" : "1 Month"})', 'time': timeStr, 'isPending': true, 'timestamp': FieldValue.serverTimestamp(),
        });

      } else {
        // Daily Thali Logic
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

  @override
  Widget build(BuildContext context) {
    int totalThaliPrice = widget.priceThali * thaliQty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 20, right: 20, top: 25),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),

          Row(children: [
            const CircleAvatar(backgroundColor: BhojnTheme.primaryOrange, child: Icon(Icons.restaurant, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Paying to", style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(widget.messName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))
            ]))
          ]),
          const SizedBox(height: 20),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModeButton("Daily Thali", PaymentMode.thali),
                const SizedBox(width: 10),
                _buildModeButton("15 Days", PaymentMode.fifteenDays),
                const SizedBox(width: 10),
                _buildModeButton("Monthly", PaymentMode.monthly),
              ],
            ),
          ),

          const SizedBox(height: 25),

          if (_selectedMode == PaymentMode.thali) ...[
            const Text("Thali Quantity", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                IconButton(onPressed: () { if (thaliQty > 1) setState(() => thaliQty--); }, icon: const Icon(Icons.remove_circle_outline, color: BhojnTheme.primaryOrange, size: 30)),
                Text(thaliQty.toString(), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => setState(() => thaliQty++), icon: const Icon(Icons.add_circle_outline, color: BhojnTheme.primaryOrange, size: 30))
              ]),
              Text("₹ $totalThaliPrice", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))
            ]),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () => _executePayment(totalThaliPrice), child: Text("PAY ₹$totalThaliPrice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          ] else ...[
            const Text("Enter Payment Amount", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 10),
            TextField(controller: _customAmountCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))),
            const SizedBox(height: 10),
            Text("Owner's ${_selectedMode == PaymentMode.fifteenDays ? "15-Day" : "Monthly"} Price is loaded by default. You can edit this amount if paying partial.", style: const TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { int customAmt = int.tryParse(_customAmountCtrl.text.trim()) ?? 0; _executePayment(customAmt); }, child: const Text("PAY & JOIN MESS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
          ]
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, PaymentMode mode) {
    bool isSelected = _selectedMode == mode;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? BhojnTheme.primaryOrange : Colors.white10,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 15)
      ),
      onPressed: () => _updateAmountField(mode),
      child: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
    );
  }
}