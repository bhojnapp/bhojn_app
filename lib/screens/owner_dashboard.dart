import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../notification_services.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/request_service.dart';

// ----------------------------------------------------------------------------
// 🚀 HELPER: Time to Meal Converter (FIXED: 4 PM onwards is Dinner)
// ----------------------------------------------------------------------------
String _getMealType(String timeStr) {
  try {
    DateTime parsed = DateFormat('hh:mm a').parse(timeStr);
    int hour = parsed.hour;
    if (hour >= 5 && hour < 11) return "Breakfast 🍳";
    if (hour >= 11 && hour < 16) return "Lunch 🍱"; // 16:00 (4 PM) tak lunch
    return "Dinner 🍽️"; // 4 PM ke baad sidha Dinner
  } catch (e) {
    return "Meal 🍛";
  }
}

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _currentIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;
  final AuthService _auth = AuthService();
  // 🚀 NAYA FUNCTION: Ye chup-chaap naya token layega aur save karega
  Future<void> saveNewFCMToken() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // Agar user logged in nahi hai, toh wapas jao

      // Google ke server se naya token mango
      String? token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        print("🔥 Naya Token Mil Gaya: $token"); // Terminal mein check karne ke liye

        // Database mein ghus ke update maar do
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print("✅ Token successfully database mein save ho gaya!");
      }
    } catch (e) {
      print("🚨 Token save karne mein error aa gaya bhai: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    saveNewFCMToken();

    if (user != null) {
      NotificationServices notificationServices = NotificationServices();

      // ✅ STEP 1: Initialize, ask permissions, save FCM Token
      notificationServices.initLocalNotifications().then((_) {
        print("Chowkidar Full Taiyar! ✅");
        notificationServices.requestNotificationPermission();
        notificationServices.saveDeviceToken(user!.uid, 'users');

        // ✅ STEP 2: FCM Foreground Listener Start
        // (Ab wo bhari bharkam Firestore snapshot listener yahan se hata diya hai)
        notificationServices.firebaseInit();
      });
    }
  }

  void _showMyQR() {
    // 🚀 MASTER KEY: Ye hamare poster ka HD screenshot nikalega
    final GlobalKey qrKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      backgroundColor: BhojnTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
          child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: BhojnTheme.accentRed)));
                var data = snapshot.data?.data() as Map<String, dynamic>?;
                String messName = data?['mess_name'] ?? "My Mess";
                String upiId = data?['upi_id'] ?? "No UPI ID";
                String upiUrl = "upi://pay?pa=$upiId&pn=${Uri.encodeComponent(messName)}&tr=${user!.uid}";

                return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 20),

                      // ========================================================
                      // 🖨️ THE HD PRINTABLE POSTER (Wrapped in RepaintBoundary)
                      // ========================================================
                      RepaintBoundary(
                          key: qrKey,
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                              decoration: BoxDecoration(
                                  color: Colors.white, // Pure white for crisp printing
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(color: BhojnTheme.accentRed, width: 4),
                                  boxShadow: [BoxShadow(color: BhojnTheme.accentRed.withOpacity(0.3), blurRadius: 15, spreadRadius: 5)]
                              ),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 🚀 Custom Header
                                    const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.qr_code_scanner_rounded, color: Colors.black87, size: 22),
                                          SizedBox(width: 8),
                                          Text("Scan For Payment/Attendance", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                                        ]
                                    ),
                                    const SizedBox(height: 10),
                                    Text(messName.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: BhojnTheme.accentRed, fontSize: 22, fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 20),

                                    // 🚀 QR Code
                                    upiId == "No UPI ID" || upiId.isEmpty
                                        ? const SizedBox(height: 220, child: Center(child: Text("Please update UPI ID in Profile", textAlign: TextAlign.center, style: TextStyle(color: Colors.black))))
                                        : QrImageView(data: upiUrl, version: QrVersions.auto, size: 220.0, backgroundColor: Colors.white, errorCorrectionLevel: QrErrorCorrectLevel.M),

                                    const SizedBox(height: 20),

                                    // 🚀 Branding (As requested: Small Black, Big Orange)
                                    const Text("Download", style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                                    const Text("BHOJN App", style: TextStyle(color: Colors.orange, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                  ]
                              )
                          )
                      ),
                      // ========================================================

                      const SizedBox(height: 30),

                      // 📥 DOWNLOAD & 📤 SHARE BUTTONS (Split UI)
                      Row(
                        children: [
                          // 📥 DOWNLOAD BUTTON (Direct Save to Gallery)
                          Expanded(
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: BhojnTheme.primaryOrange, // Mast Orange color
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                                  ),
                                  icon: const Icon(Icons.save_alt_rounded, color: Colors.white, size: 22),
                                  label: const Text("Save Image", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  onPressed: () async {
                                    try {
                                      // 🚀 NAYA LOGIC: Pehle Permission Check aur Request karo
                                      bool hasAccess = await Gal.hasAccess();
                                      if (!hasAccess) {
                                        hasAccess = await Gal.requestAccess();
                                      }

                                      // Agar user ne permission de di (ya pehle se di hui hai)
                                      if (hasAccess) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving HD Poster to Gallery... ⏳")));

                                        RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                        ui.Image image = await boundary.toImage(pixelRatio: 5.0);
                                        ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                        Uint8List pngBytes = byteData!.buffer.asUint8List();

                                        // Seedha Gallery me Save
                                        await Gal.putImageBytes(pngBytes, name: "Bhojn_Mess_QR");

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Poster Saved to Gallery! 🖼️✅"), backgroundColor: Colors.green));
                                        }
                                      } else {
                                        // Agar user ne "Deny" kar diya
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Storage Permission Denied! ❌"), backgroundColor: Colors.red));
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
                                    }
                                  }
                              )
                          ),

                          const SizedBox(width: 15), // Beech ka gap

                          // 📤 SHARE BUTTON (Open Share Menu)
                          Expanded(
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green, // Professional Green
                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                                  ),
                                  icon: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
                                  label: const Text("Share QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  onPressed: () async {
                                    try {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preparing HD Image... ⏳")));

                                      RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
                                      ui.Image image = await boundary.toImage(pixelRatio: 5.0);
                                      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                                      Uint8List pngBytes = byteData!.buffer.asUint8List();

                                      final tempDir = await getTemporaryDirectory();
                                      final file = await File('${tempDir.path}/Bhojn_Mess_QR.png').create();
                                      await file.writeAsBytes(pngBytes);

                                      // 🚀 Share Dialog Khulega
                                      await Share.shareXFiles([XFile(file.path)], text: 'Scan this QR to pay and mark attendance at $messName! 🍛');

                                    } catch (e) {
                                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
                                    }
                                  }
                              )
                          ),
                        ],
                      ),
                      const SizedBox(height: 20)
                    ]
                );
              }
          ),
        );
      },
    );
  }

  void _toggleMessStatus(bool currentStatus) async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'is_open': !currentStatus});
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Auth Error")));

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: BhojnTheme.accentRed)));
          var ownerData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          bool isMessOpen = ownerData['is_open'] ?? true; String firstName = user?.displayName?.split(' ')[0] ?? 'Malik';

          final List<Widget> tabs = [
            _HomeTab(uid: user!.uid, ownerData: ownerData),
            _StatusTab(uid: user!.uid, ownerData: ownerData),
            _AttendanceTab(uid: user!.uid, ownerData: ownerData), // 🚀 Yahan ownerData pass kar diya!
            _MessTab(auth: _auth, uid: user!.uid, ownerData: ownerData),
          ];

          return Scaffold(
            backgroundColor: BhojnTheme.darkBg,
            appBar: AppBar(
              backgroundColor: Colors.transparent, elevation: 0,
              title: Row(
                children: [
                  const Text('BHOJN', style: TextStyle(fontWeight: FontWeight.w900, color: BhojnTheme.accentRed, fontStyle: FontStyle.italic, fontSize: 24)), const SizedBox(width: 15),
                  GestureDetector(onTap: () => _toggleMessStatus(isMessOpen), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isMessOpen ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: isMessOpen ? Colors.green : Colors.red, width: 1)), child: Text(isMessOpen ? "OPEN" : "CLOSED", style: TextStyle(color: isMessOpen ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold)))),
                  const Spacer(), Text("Hello", style: const TextStyle(color: Colors.white, fontSize: 16)), const _WavingHand(),
                ],
              ),
            ),

            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_currentIndex),
                child: tabs[_currentIndex],
              ),
            ),

            floatingActionButton: FloatingActionButton(
                heroTag: "owner_qr_btn",
                onPressed: _showMyQR,
                backgroundColor: BhojnTheme.accentRed,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.qr_code_2, size: 30, color: Colors.white)
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              color: BhojnTheme.surfaceCard, shape: const CircularNotchedRectangle(), notchMargin: 8.0,
              child: SizedBox(height: 60, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildNavItem(icon: Icons.home_rounded, label: "HOME", index: 0), _buildNavItem(icon: Icons.dashboard_customize_rounded, label: "STATUS", index: 1), const SizedBox(width: 40), _buildNavItem(icon: Icons.checklist_rtl_rounded, label: "ATTEND", index: 2), _buildNavItem(icon: Icons.restaurant_menu_rounded, label: "MESS", index: 3)])),
            ),
          );
        }
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isSel = _currentIndex == index; Color color = isSel ? BhojnTheme.accentRed : Colors.grey;
    return InkWell(
        onTap: () => setState(() => _currentIndex = index),
        splashColor: Colors.transparent, highlightColor: Colors.transparent,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(scale: isSel ? 1.2 : 1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Icon(icon, color: color, size: 24)),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: color, fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal), child: Text(label))
                ]
            )
        )
    );
  }
}

// ============================================================================
// 🏠 1. HOME TAB (🔥 Strict Newest-First Sorting & Real Name Fix)
// ============================================================================
class _HomeTab extends StatelessWidget {
  final String uid; final Map<String, dynamic> ownerData;
  const _HomeTab({required this.uid, required this.ownerData});

  @override Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime startOfToday = DateTime(now.year, now.month, now.day);
    DateTime startOfMonth = DateTime(now.year, now.month, 1);

    int priceMonthly = int.tryParse(ownerData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    int avgThaliRate = priceMonthly > 0 ? (priceMonthly / 60).round() : 0;

    String currentSessionName = _getMealType(DateFormat('hh:mm a').format(now));

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('active_messes', arrayContains: uid).snapshots(),
        builder: (context, studentsSnap) {
          int totalAdmitted = studentsSnap.data?.docs.length ?? 0;

          // Directory for Real Names
          Map<String, String> studentDirectory = {};
          if (studentsSnap.hasData) {
            for (var doc in studentsSnap.data!.docs) {
              var sData = doc.data() as Map<String, dynamic>;
              studentDirectory[doc.id] = sData['name'] ?? 'Student';
            }
          }

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('recent_transactions').orderBy('timestamp', descending: true).limit(500).snapshots(),
              builder: (context, recentSnap) {
                var allRecentTxns = recentSnap.data?.docs ?? [];

                int smartTodayIncome = 0;
                int currentSessionIncome = 0;
                int totalServedToday = 0;
                Set<String> uniqueStudentsCurrentSession = {};

                Map<String, List<DocumentSnapshot>> sessionGroups = {
                  "Breakfast 🍳": [], "Lunch 🍱": [], "Dinner 🍽️": [], "Meal 🍛": [],
                };
                Map<String, int> sessionScanCounts = {
                  "Breakfast 🍳": 0, "Lunch 🍱": 0, "Dinner 🍽️": 0, "Meal 🍛": 0,
                };

                for(var doc in allRecentTxns) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['isPending'] == true) continue;

                  DateTime dt = data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : DateTime.now();

                  var rawAmt = data['amount'];
                  int amt = (rawAmt is int) ? rawAmt : (int.tryParse(rawAmt?.toString() ?? '0') ?? 0);
                  bool isScan = (amt == 0);
                  int valueToAdd = isScan ? avgThaliRate : amt;

                  if (!dt.isBefore(startOfToday)) {
                    smartTodayIncome += valueToAdd;

                    String timeStr = data['time'] ?? '--:--';
                    String session = _getMealType(timeStr);

                    if (sessionGroups.containsKey(session)) {
                      sessionGroups[session]!.add(doc);
                    } else {
                      sessionGroups[session] = [doc];
                    }

                    if (isScan) {
                      totalServedToday++;
                      sessionScanCounts[session] = (sessionScanCounts[session] ?? 0) + 1;

                      if (session == currentSessionName && data['uid'] != null) {
                        uniqueStudentsCurrentSession.add(data['uid']);
                      }
                    }

                    if (session == currentSessionName) {
                      currentSessionIncome += valueToAdd;
                    }
                  }
                }

                int presentInCurrentSession = uniqueStudentsCurrentSession.length;
                double progress = totalAdmitted > 0 ? presentInCurrentSession / totalAdmitted : 0.0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // ==========================================
                    // 📊 1. LIVE ANALYTICS CARD
                    // ==========================================
                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [BhojnTheme.accentRed.withOpacity(0.8), BhojnTheme.accentRed.withOpacity(0.4)]), borderRadius: BorderRadius.circular(20)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Live Session Analytics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text("Live: $currentSessionName", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: Colors.white24, color: Colors.white)),
                              const SizedBox(height: 10),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_statText("Present Now: $presentInCurrentSession", Colors.white), _statText("Admitted: $totalAdmitted", Colors.white70)]),

                              const Divider(color: Colors.white24, height: 30),

                              Text("Total for $currentSessionName", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text("₹ $currentSessionIncome", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                              const SizedBox(height: 10),

                              Row(
                                  children: [
                                    Text("Today's Income: ₹$smartTodayIncome", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                                    Container(margin: const EdgeInsets.symmetric(horizontal: 10), width: 1, height: 12, color: Colors.white38),
                                    Text("Today's Served: $totalServedToday", style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))
                                  ]
                              )
                            ]
                        )
                    ),
                    const SizedBox(height: 30),

                    const Text("Today's History 🕒", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),

                    // ==========================================
                    // 📜 2. SESSION-WISE GROUPED SCANS
                    // ==========================================
                    if (totalServedToday == 0 && smartTodayIncome == 0)
                      const Center(child: Padding(padding: EdgeInsets.all(20.0), child: Text("No scans yet today.", style: TextStyle(color: Colors.grey))))
                    else
                    // 🚀 THE FIX: Order reversed. Latest session of the day shows on TOP.
                      ...['Dinner 🍽️', 'Lunch 🍱', 'Breakfast 🍳', 'Meal 🍛'].map((sessionKey) {
                        var items = sessionGroups[sessionKey] ?? [];
                        if (items.isEmpty) return const SizedBox();

                        // 🚀 MEGA FIX: Explicitly sorting scans so the newest is ALWAYS at index 0 (Top)
                        items.sort((a, b) {
                          var dataA = a.data() as Map<String, dynamic>;
                          var dataB = b.data() as Map<String, dynamic>;
                          DateTime timeA = dataA['timestamp'] != null ? (dataA['timestamp'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                          DateTime timeB = dataB['timestamp'] != null ? (dataB['timestamp'] as Timestamp).toDate() : DateTime.fromMillisecondsSinceEpoch(0);
                          return timeB.compareTo(timeA); // Descending order
                        });

                        int sessionScans = sessionScanCounts[sessionKey] ?? 0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(sessionKey, style: const TextStyle(color: BhojnTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text("Scanned: $sessionScans", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 20),

                            ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  var student = items[index].data() as Map<String, dynamic>;
                                  String time = student['time'] ?? '--:--';

                                  String type = student['type'] ?? "Scan";
                                  if (type.contains("Attendance")) {
                                    type = "Scanned";
                                  }

                                  String sUid = student['uid'] ?? '';
                                  String dbName = student['name'] ?? '';
                                  String dirName = studentDirectory[sUid] ?? '';

                                  String sName = "Unknown Student";

                                  if (dirName.isNotEmpty && dirName.toLowerCase() != 'student') {
                                    sName = dirName;
                                  } else if (dbName.isNotEmpty && dbName.toLowerCase() != 'student') {
                                    sName = dbName;
                                  } else {
                                    sName = "Student (Profile Not Updated)";
                                  }

                                  String amt = student['amount']?.toString() ?? "0";

                                  DateTime dt = student['timestamp'] != null ? (student['timestamp'] as Timestamp).toDate() : DateTime.now();
                                  String dateStamp = DateFormat('dd MMM yyyy').format(dt);

                                  return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                                      child: ListTile(
                                          leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.2), child: const Icon(Icons.check, color: Colors.green)),
                                          title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                          subtitle: Text("$dateStamp • $time", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(amt == "0" ? "Present" : "+ ₹$amt", style: TextStyle(color: amt == "0" ? Colors.blue : Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                                                Text(type, style: const TextStyle(color: Colors.grey, fontSize: 10))
                                              ]
                                          )
                                      )
                                  );
                                }
                            ),
                            const SizedBox(height: 25),
                          ],
                        );
                      }),
                  ]),
                );
              }
          );
        }
    );
  }
  Widget _statText(String text, color) => Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold));
}

// ============================================================================
// 📋 2. STATUS TAB (🔥 Excel/Notepad Style Menu Bar)
// ============================================================================
class _StatusTab extends StatefulWidget {
  final String uid; final Map<String, dynamic> ownerData;
  const _StatusTab({required this.uid, required this.ownerData});
  @override State<_StatusTab> createState() => _StatusTabState();
}
class _StatusTabState extends State<_StatusTab> {
  final TextEditingController _menuCtrl = TextEditingController();
  final TextEditingController _thaliCtrl = TextEditingController();
  final TextEditingController _fifteenCtrl = TextEditingController();
  final TextEditingController _monthlyCtrl = TextEditingController();
  final TextEditingController _pollOptionCtrl = TextEditingController();
  List<String> pollOptions = [];

  void _pushMenu() async {
    if (_menuCtrl.text.isEmpty) return;
    String timeStr = DateFormat('dd MMM, hh:mm a').format(DateTime.now());
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'today_menu': _menuCtrl.text.trim(), 'menu_updated_at': timeStr});
    _menuCtrl.clear();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menu Live! 🍲"), backgroundColor: Colors.green));
  }

  void _savePricing() async {
    if(_thaliCtrl.text.isNotEmpty) await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'price_thali': _thaliCtrl.text.trim()});
    if(_fifteenCtrl.text.isNotEmpty) await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'price_15days': _fifteenCtrl.text.trim()});
    if(_monthlyCtrl.text.isNotEmpty) await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'price_monthly': _monthlyCtrl.text.trim()});
    _thaliCtrl.clear(); _fifteenCtrl.clear(); _monthlyCtrl.clear();
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pricing Updated! 💰"), backgroundColor: Colors.green));
  }

  void _startVoting() async {
    if (pollOptions.length < 2) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least 2 options required!"))); return; }
    Map<String, int> initialResults = { for (var option in pollOptions) option : 0 };
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'is_voting_active': true, 'voting_options': pollOptions, 'voting_results': initialResults, 'voted_by': []});
  }

  void _stopVoting() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'is_voting_active': false});
    setState(() => pollOptions.clear());
  }

  // 🚀 NEW: Excel/Notepad Style Menu Builder
  Widget _buildExcelStyleMenu(String menuText) {
    // Nayi line ke hisaab se items alag karo
    List<String> items = menuText.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (items.isEmpty) items = ["No menu updated yet."];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10), // Outer table border
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: items.asMap().entries.map((entry) {
            int index = entry.key + 1;
            String item = entry.value;
            return Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white10, width: 1)), // Row line
              ),
              child: Row(
                children: [
                  // Excel Numbering Column (Grey Background)
                  Container(
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.black26,
                      border: Border(right: BorderSide(color: Colors.white10, width: 1)), // Column line
                    ),
                    child: Center(child: Text("$index", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                  // Menu Item Text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      child: Text(item, style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    bool isMessOpen = widget.ownerData['is_open'] ?? true;
    String currentMenu = widget.ownerData['today_menu'] ?? "No menu updated yet.";
    String curThali = widget.ownerData['price_thali']?.toString() ?? "N/A";
    String cur15 = widget.ownerData['price_15days']?.toString() ?? "N/A";
    String curMonthly = widget.ownerData['price_monthly']?.toString() ?? "N/A";
    bool isVotingActive = widget.ownerData['is_voting_active'] ?? false;
    Map<String, dynamic> results = widget.ownerData['voting_results'] ?? {};
    int totalVotes = results.values.fold(0, (sum, val) => sum + ((val as num).toInt()));

    return SingleChildScrollView(padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), tileColor: Colors.white.withOpacity(0.05), title: const Text("Mess Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), subtitle: Text(isMessOpen ? "Receiving students" : "Closed for now", style: const TextStyle(color: Colors.grey, fontSize: 12)), trailing: Switch(value: isMessOpen, activeColor: Colors.green, inactiveThumbColor: Colors.red, onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'is_open': val}))), const SizedBox(height: 25),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Update Menu", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), Text("Current: Live ✅", style: TextStyle(color: Colors.green.shade300, fontSize: 12))]), const SizedBox(height: 5),

      // 🚀 The Excel Style Widget Injection
      _buildExcelStyleMenu(currentMenu),
      const SizedBox(height: 15),

      // 🚀 TextField updated to act like a multi-line notepad
      TextField(controller: _menuCtrl, minLines: 3, maxLines: 5, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: "Type menu line-by-line (Press Enter for new line)...", filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none))), const SizedBox(height: 10),

      Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: _pushMenu, style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.accentRed), child: const Text("Push New Menu"))), const SizedBox(height: 25),
      const Text("Pricing Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Thali (₹$curThali)", style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height:5), _priceField(_thaliCtrl, "New ₹")])), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("15 Days (₹$cur15)", style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height:5), _priceField(_fifteenCtrl, "New ₹")])), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Monthly (₹$curMonthly)", style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height:5), _priceField(_monthlyCtrl, "New ₹")]))
      ]), const SizedBox(height: 10),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _savePricing, child: const Text("Save Prices", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))), const SizedBox(height: 25),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: BhojnTheme.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: BhojnTheme.primaryOrange.withOpacity(0.5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.how_to_vote, color: BhojnTheme.primaryOrange), const SizedBox(width: 10), const Text("Sunday Special Voting", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), if (isVotingActive) InkWell(onTap: _stopVoting, child: const Icon(Icons.cancel, color: Colors.red))]), const SizedBox(height: 15), if (isVotingActive) ...[const Text("Live Results:", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), const SizedBox(height: 10), ...results.entries.map((entry) { double percentage = totalVotes > 0 ? entry.value / totalVotes : 0.0; return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(entry.key, style: const TextStyle(color: Colors.white)), Text("${entry.value} votes", style: const TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12))]), const SizedBox(height: 5), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: percentage, minHeight: 8, backgroundColor: Colors.white10, color: BhojnTheme.primaryOrange))])); }), const SizedBox(height: 10), Text("Total Votes: $totalVotes", style: const TextStyle(color: Colors.grey, fontSize: 11)), ] else ...[Row(children: [Expanded(child: TextField(controller: _pollOptionCtrl, style: const TextStyle(color: Colors.white, fontSize: 14), decoration: InputDecoration(hintText: "Add Dish Option", filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10)))), const SizedBox(width: 10), IconButton(icon: const Icon(Icons.add_circle, color: BhojnTheme.primaryOrange, size: 30), onPressed: () { if (_pollOptionCtrl.text.isNotEmpty) { setState(() { pollOptions.add(_pollOptionCtrl.text.trim()); _pollOptionCtrl.clear(); }); } })]), const SizedBox(height: 10), Wrap(spacing: 8, children: pollOptions.map((opt) => Chip(label: Text(opt, style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: Colors.white10, deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey), onDeleted: () => setState(() => pollOptions.remove(opt)))).toList()), const SizedBox(height: 15), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _startVoting, style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange), child: const Text("Push Voting Notification"))), ] ]))
    ]));
  }
  Widget _priceField(TextEditingController ctrl, String hint) => TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontSize: 14), keyboardType: TextInputType.number, decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)));
}

// ============================================================================
// 👥 3. ATTENDANCE TAB (🔥 Advanced UI, Custom Payments & Smart Filters)
// ============================================================================
class _AttendanceTab extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> ownerData;
  const _AttendanceTab({required this.uid, required this.ownerData});
  @override State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  String _currentFilter = 'All';
  final List<String> _filters = ['All', 'Present', 'Absent', 'Pending Dues', 'Full Paid'];

  // 🚀 PRO JOIN CONFIRMATION (Using Batch Write Service)
  void _acceptStudent(String requestDocId, String studentUid, String studentName, num dues, int totalMeals, num paidAmt) async { // 👈 Yahan paidAmt add kar diya
    try {
      final requestService = RequestService();
      String timeStr = DateFormat('hh:mm a').format(DateTime.now()); // 👈 Yahan timeStr nikal liya

      await requestService.acceptRequest(
        requestId: requestDocId,
        studentId: studentUid,
        studentName: studentName,
        ownerId: widget.uid,
        totalMeals: totalMeals,
        pendingDues: dues.toInt(),
        paidAmount: paidAmt.toInt(),
        timeStr: timeStr,
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$studentName Accepted! 🎉✅"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e ❌"), backgroundColor: Colors.red));
    }
  }

  // 🚀 PRO DECLINE (Using Request Service)
  void _declineStudent(String requestDocId) async {
    try {
      final requestService = RequestService();
      await requestService.rejectRequest(requestDocId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Declined! ❌"), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // 🚀 MEGA FIX: CUSTOM DUE PAYMENT CALCULATOR (Partial or Full)
  void _verifyPayment(String txnId, String studentUid, int amtPaid) async {
    try {
      // 1. Transaction Verify kar do
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').doc(txnId).update({'isPending': false});

      // 2. Student ka current due nikalo aur usme se Custom Amount minus karo
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(studentUid).get();
      if(userDoc.exists) {
        var data = userDoc.data()!;
        var messData = data['mess_data'] ?? {};
        var myMess = messData[widget.uid] ?? {};

        num currentDues = num.tryParse(myMess['pending_dues']?.toString() ?? '0') ?? 0;
        num newDues = currentDues - amtPaid;
        if (newDues < 0) newDues = 0; // Negative na ho jaye isliye safety lock

        await FirebaseFirestore.instance.collection('users').doc(studentUid).set({
          'mess_data': {
            widget.uid: {
              'pending_dues': newDues
            }
          }
        }, SetOptions(merge: true));
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Verified & Dues Updated! ✅"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()} ❌"), backgroundColor: Colors.red));
    }
  }

  void _rejectPayment(String txnId) async {
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').doc(txnId).delete();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Claim Rejected! ❌"), backgroundColor: Colors.red));
  }

  void _showStudentProfileAndHistory(BuildContext context, Map<String, dynamic> studentData, String studentUid) {
    String name = studentData['name'] ?? "Unknown Student";
    String email = studentData['email'] ?? "No Email provided";
    String mobile = studentData['mobile'] ?? "No Contact info";
    String college = studentData['college'] ?? "No College info";

    Map<String, dynamic> specData = studentData['mess_data']?[widget.uid] ?? {};
    num dues = num.tryParse(specData['pending_dues']?.toString() ?? studentData['pending_dues']?.toString() ?? '0') ?? 0;
    int totalMeals = int.tryParse(specData['total_allotted_meals']?.toString() ?? '60') ?? 60;

    showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: BhojnTheme.surfaceCard, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return DraggableScrollableSheet(
              initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
              builder: (_, controller) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15), Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 35, backgroundColor: Colors.white10, child: Icon(Icons.person, size: 35, color: Colors.white)), const SizedBox(width: 15),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(college, style: const TextStyle(color: BhojnTheme.primaryOrange, fontSize: 14)), Text("+91 $mobile  •  $email", style: const TextStyle(color: Colors.grey, fontSize: 12))])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🚀 SMART MATHEMATICS: Extract Actual Paid Amount
                    FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(widget.uid).get(),
                        builder: (context, ownerSnap) {
                          int planPrice = 0;
                          if (ownerSnap.hasData && ownerSnap.data!.exists) {
                            var ownerData = ownerSnap.data!.data() as Map<String, dynamic>;
                            int priceMonthly = int.tryParse(ownerData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
                            int price15 = int.tryParse(ownerData['price_15days']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

                            planPrice = totalMeals <= 30 ? price15 : priceMonthly;
                          }

                          num totalPaid = planPrice > 0 ? (planPrice - dues) : 0;
                          if (totalPaid < 0) totalPaid = 0;

                          return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                              child: Row(
                                  children: [
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.3))),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text("Total Paid", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 2),
                                                  Text("₹$totalPaid", style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.w900)),
                                                ]
                                            )
                                        )
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(color: dues > 0 ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: dues > 0 ? Colors.red.withOpacity(0.3) : Colors.blue.withOpacity(0.3))),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(dues > 0 ? "Pending Due" : "Status", style: TextStyle(color: dues > 0 ? Colors.redAccent : Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 2),
                                                  Text(dues > 0 ? "₹$dues" : "Fully Paid ✅", style: TextStyle(color: dues > 0 ? Colors.redAccent : Colors.blue, fontSize: 16, fontWeight: FontWeight.w900)),
                                                ]
                                            )
                                        )
                                    ),
                                  ]
                              )
                          );
                        }
                    ),

                    const Padding(padding: EdgeInsets.only(left: 20, top: 15), child: Text("Complete Attendance History 🍛", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 10),

                    // 🚀 FIXED: Galti se yahan join_requests aa gaya tha, isko wapas recent_transactions kar diya
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').orderBy('timestamp', descending: true).limit(1000).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.accentRed));

                            Map<String, List<Map<String, dynamic>>> groupedData = {};

                            if (snapshot.hasData) {
                              for (var docSnap in snapshot.data!.docs) {
                                var doc = docSnap.data() as Map<String, dynamic>;
                                if (doc['uid'] != studentUid) continue;

                                DateTime dt = doc['timestamp'] != null ? (doc['timestamp'] as Timestamp).toDate() : DateTime.now();
                                String dateKey = DateFormat('dd MMM yyyy').format(dt);
                                if (!groupedData.containsKey(dateKey)) groupedData[dateKey] = [];
                                groupedData[dateKey]!.add(doc);
                              }
                            }

                            return groupedData.isEmpty
                                ? const Center(child: Text("No attendance scans found.", style: TextStyle(color: Colors.grey)))
                                : ListView.builder(
                              controller: controller,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: groupedData.length,
                              itemBuilder: (context, index) {
                                String dateKey = groupedData.keys.elementAt(index);
                                List<Map<String, dynamic>> items = groupedData[dateKey]!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20, bottom: 15),
                                      child: Row(
                                        children: [
                                          Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                  color: BhojnTheme.primaryOrange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: BhojnTheme.primaryOrange.withOpacity(0.3))
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.calendar_month, size: 14, color: BhojnTheme.primaryOrange),
                                                  const SizedBox(width: 8),
                                                  Text(dateKey, style: const TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13)),
                                                ],
                                              )
                                          ),
                                          const Expanded(child: Divider(color: Colors.white10, indent: 15)),
                                        ],
                                      ),
                                    ),

                                    ...items.map((item) {
                                      String time = item['time'] ?? '--:--';
                                      String type = item['type'] ?? "Scan";
                                      if (type.contains("Attendance")) type = "Scanned";

                                      int amt = (item['amount'] is int) ? item['amount'] : (int.tryParse(item['amount']?.toString() ?? '0') ?? 0);
                                      bool isPending = item['isPending'] ?? false;
                                      String mealType = _getMealType(time);

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                              backgroundColor: isPending ? Colors.orange.withOpacity(0.2) : (amt > 0 ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
                                              child: Icon(isPending ? Icons.access_time : (amt > 0 ? Icons.payment : Icons.check), color: isPending ? Colors.orange : (amt > 0 ? Colors.blue : Colors.green))
                                          ),
                                          title: Text(amt > 0 ? type : mealType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          subtitle: Text(amt > 0 ? "Received at $time" : "Scanned at $time", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          trailing: Text(amt > 0 ? (isPending ? "Pending Verify" : "+ ₹$amt") : "Attended", style: TextStyle(color: isPending ? Colors.orange : Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                      );
                                    })
                                  ],
                                );
                              },
                            );
                          }
                      ),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildMealDot(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.redAccent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 1)
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold))
      ],
    );
  }

  @override Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 🚀 SMART HIDING: PENDING JOIN REQUESTS (PRO FIX APPLIED)
          StreamBuilder<QuerySnapshot>(
            // 🚀 NAYA STREAM: Ab yeh Global postbox 'join_requests' mein check karega!
              stream: FirebaseFirestore.instance.collection('join_requests').where('owner_id', isEqualTo: widget.uid).where('status', isEqualTo: 'pending').snapshots(),
              builder: (context, requestSnap) {
                if (!requestSnap.hasData || requestSnap.data!.docs.isEmpty) {
                  return const SizedBox.shrink(); // Ekdum gayab ho jayega agar khali hai!
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
                      child: Text("Pending Join Requests 📨", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: requestSnap.data!.docs.length,
                        itemBuilder: (context, index) {
                          var req = requestSnap.data!.docs[index].data() as Map<String, dynamic>;

                          // 🚀 NAYA: Request ki ID aur Student ki ID dono alag alag nikaali
                          String requestDocId = requestSnap.data!.docs[index].id;
                          String sUid = req['student_id'] ?? '';
                          String sName = req['student_name'] ?? 'Student';

                          num paidAmt = num.tryParse(req['paid_amount']?.toString() ?? '0') ?? 0;
                          num dues = num.tryParse(req['pending_dues']?.toString() ?? '0') ?? 0;
                          int meals = int.tryParse(req['total_allotted_meals']?.toString() ?? '60') ?? 60;

                          return Container(
                            width: 270, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(sName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("Paid: ₹$paidAmt", style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text("Due: ₹$dues", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text("Requested Plan: $meals Meals", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                        onTap: () => _declineStudent(requestDocId), // 🚀 requestDocId bhej diya
                                        child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.red, size: 16))
                                    ),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        // 🚀 YAHAN paidAmt PASS KAR DIYA
                                        onPressed: () => _acceptStudent(requestDocId, sUid, sName, dues, meals, paidAmt),
                                        child: const Text("ACCEPT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 40, thickness: 1),
                  ],
                );
              }
          ),

          // 🚀 SMART HIDING: PENDING DUE PAYMENTS
          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').where('isPending', isEqualTo: true).snapshots(),
              builder: (context, pendingTxnSnap) {
                if (!pendingTxnSnap.hasData || pendingTxnSnap.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                var duePayments = pendingTxnSnap.data!.docs.where((doc) {
                  var map = doc.data() as Map<String, dynamic>;
                  return map['type'].toString().contains('Payment');
                }).toList();

                if (duePayments.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 20, bottom: 10, top: 10),
                      child: Text("Pending Due Payments 💸", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: duePayments.length,
                        itemBuilder: (context, index) {
                          var txn = duePayments[index].data() as Map<String, dynamic>;
                          String txnId = duePayments[index].id;
                          String sName = txn['name'] ?? 'Student';
                          String sUid = txn['uid'] ?? '';
                          String time = txn['time'] ?? '';
                          int amt = txn['amount'] ?? 0;

                          return Container(
                            width: 270, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withOpacity(0.5))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(sName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                    Text("₹$amt", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text("Received at $time", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                        onTap: () => _rejectPayment(txnId),
                                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Text("REJECT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)))
                                    ),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () => _verifyPayment(txnId, sUid, amt),
                                        child: const Text("VERIFY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 40, thickness: 1),
                  ],
                );
              }
          ),

          StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('active_messes', arrayContains: widget.uid).snapshots(),
              builder: (context, allStudentsSnap) {
                if (allStudentsSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.accentRed));

                var allStudents = allStudentsSnap.data?.docs ?? [];

                DateTime now = DateTime.now();
                DateTime startOfToday = DateTime(now.year, now.month, now.day);

                return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').orderBy('timestamp', descending: true).limit(1000).snapshots(),
                    builder: (context, todayTxnsSnap) {

                      Map<String, Map<String, dynamic>> studentTodayStats = {};
                      List<String> presentUids = [];

                      if (todayTxnsSnap.hasData) {
                        for (var doc in todayTxnsSnap.data!.docs) {
                          var data = doc.data() as Map<String, dynamic>;
                          if (data['isPending'] == true || data['timestamp'] == null) continue;

                          DateTime dt = (data['timestamp'] as Timestamp).toDate();
                          if (dt.isBefore(startOfToday)) continue;

                          var rawAmt = data['amount'];
                          int amt = (rawAmt is int) ? rawAmt : (int.tryParse(rawAmt?.toString() ?? '0') ?? 0);
                          if (amt > 0) continue;

                          String sUid = data['uid'] ?? "";
                          if(sUid.isEmpty) continue;

                          if (!presentUids.contains(sUid)) presentUids.add(sUid);

                          if(!studentTodayStats.containsKey(sUid)) {
                            studentTodayStats[sUid] = {'BF': false, 'L': false, 'D': false, 'count': 0};
                          }

                          studentTodayStats[sUid]!['count'] += 1;

                          int hour = dt.hour;
                          if (hour >= 1 && hour < 11) studentTodayStats[sUid]!['BF'] = true;
                          else if (hour >= 11 && hour < 17) studentTodayStats[sUid]!['L'] = true;
                          else studentTodayStats[sUid]!['D'] = true;
                        }
                      }

                      var filteredStudents = allStudents.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        bool isPresent = presentUids.contains(doc.id);

                        Map<String, dynamic> specData = data['mess_data']?[widget.uid] ?? {};
                        num pending = num.tryParse(specData['pending_dues']?.toString() ?? data['pending_dues']?.toString() ?? '0') ?? 0;

                        if (_currentFilter == 'Present') return isPresent;
                        if (_currentFilter == 'Absent') return !isPresent;
                        if (_currentFilter == 'Pending Dues') return pending > 0;
                        if (_currentFilter == 'Full Paid') return pending <= 0;
                        return true;
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _filters.map((filterName) => Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: ChoiceChip(
                                    label: Text(filterName, style: TextStyle(color: _currentFilter == filterName ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                                    selected: _currentFilter == filterName,
                                    selectedColor: BhojnTheme.accentRed,
                                    backgroundColor: Colors.white.withOpacity(0.05),
                                    onSelected: (bool selected) { if (selected) setState(() => _currentFilter = filterName); },
                                  ),
                                )).toList(),
                              ),
                            ),
                          ),

                          // 🚀 NEW: REMIND DEFAULTERS BUTTON
                          if (_currentFilter == 'Pending Dues' && filteredStudents.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                    icon: const Icon(Icons.notifications_active, color: Colors.white),
                                    label: const Text("Remind All Defaulters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    onPressed: () async {
                                      try {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sending Reminders... ⏳")));

                                        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('remindDefaulters');
                                        final result = await callable.call(<String, dynamic>{
                                          'messName': widget.ownerData['mess_name'] ?? 'Your Mess',
                                        });

                                        if (result.data['success'] == true) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message']), backgroundColor: Colors.green));
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to send reminders: $e"), backgroundColor: Colors.red));
                                      }
                                    }
                                ),
                              ),
                            ),

                          const SizedBox(height: 10),
                          ListView.builder(
                              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: filteredStudents.length,
                              itemBuilder: (context, index) {
                                var studentDoc = filteredStudents[index];
                                var student = studentDoc.data() as Map<String, dynamic>;
                                String sUid = studentDoc.id;

                                Map<String, dynamic> specData = student['mess_data']?[widget.uid] ?? {};
                                num stuPending = num.tryParse(specData['pending_dues']?.toString() ?? student['pending_dues']?.toString() ?? '0') ?? 0;

                                var stats = studentTodayStats[sUid];
                                bool hasScannedToday = presentUids.contains(sUid);
                                bool hasBF = stats?['BF'] ?? false;
                                bool hasL = stats?['L'] ?? false;
                                bool hasD = stats?['D'] ?? false;
                                int scanCount = stats?['count'] ?? 0;

                                return Container(
                                    margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                                    child: ListTile(
                                        onTap: () => _showStudentProfileAndHistory(context, student, sUid),
                                        leading: CircleAvatar(backgroundColor: Colors.white10, child: Icon(Icons.person, color: hasScannedToday ? Colors.green : Colors.white)),
                                        title: Text(student['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(student['mobile'] ?? "No mobile", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                            if (stuPending > 0) Text("Pending Due: ₹$stuPending", style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold))
                                          ],
                                        ),

                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _buildMealDot("B", hasBF),
                                                const SizedBox(width: 8),
                                                _buildMealDot("L", hasL),
                                                const SizedBox(width: 8),
                                                _buildMealDot("D", hasD),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            if (scanCount > 0) Text("Scans: $scanCount", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold))
                                          ],
                                        )
                                    )
                                );
                              }
                          )
                        ],
                      );
                    }
                );
              }
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ============================================================================
// 🍽️ 4. MESS TAB (🔥 Photo Upload, Analytics & Complaints Inbox)
// ============================================================================
class _MessTab extends StatefulWidget {
  final AuthService auth;
  final String uid;
  final Map<String, dynamic> ownerData;

  const _MessTab({required this.auth, required this.uid, required this.ownerData});

  @override
  State<_MessTab> createState() => _MessTabState();
}

class _MessTabState extends State<_MessTab> {

  Future<void> _updateLiveLocation(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fetching exact GPS location... ⏳")));

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS OFF hai! Pehle location on kar. 🗺️"), backgroundColor: Colors.orange));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission denied! 🛑"), backgroundColor: Colors.red));
        return;
      }
    }

    try {
      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'lat': pos.latitude,
        'lng': pos.longitude,
      });
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location Updated! 📍✅"), backgroundColor: Colors.green));
    } catch(e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // 📸 BULLETPROOF PHOTO UPLOAD
  Future<void> _uploadPhoto(BuildContext context, List<dynamic> currentPhotos) async {
    if (currentPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Max 5 photos allowed! Purani delete kar. 🛑"), backgroundColor: Colors.orange));
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);

      if (image != null) {
        if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading photo... Please wait ⏳")));

        File file = File(image.path);
        print("🔥 1. FILE PATH MIL GAYA: ${file.path}");

        String fileName = 'mess_photos/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        var ref = FirebaseStorage.instance.ref().child(fileName);

        print("🔥 2. UPLOADING TO FIREBASE STORAGE...");
        UploadTask uploadTask = ref.putFile(file);

        TaskSnapshot snapshot = await uploadTask.whenComplete(() {
          print("🔥 3. UPLOAD TASK 100% FINISHED!");
        });

        print("🔥 4. FETCHING DOWNLOAD URL...");
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print("🔥 5. URL MIL GAYA: $downloadUrl");

        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'photos': FieldValue.arrayUnion([downloadUrl])
        });

        if(context.mounted) {
          Navigator.pop(context); // Sheet close
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Uploaded & Live! 📸✅"), backgroundColor: Colors.green));
        }
      }
    } catch(e) {
      print("🚨 MEGA ERROR DURING UPLOAD: $e");
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red));
    }
  }

  // 🗑️ DELETE PHOTO
  Future<void> _deletePhoto(String photoUrl) async {
    try {
      Reference photoRef = FirebaseStorage.instance.refFromURL(photoUrl);
      await photoRef.delete();
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'photos': FieldValue.arrayRemove([photoUrl])
      });
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Deleted! 🗑️"), backgroundColor: Colors.green));
    } catch(e) {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'photos': FieldValue.arrayRemove([photoUrl])
      });
    }
  }

  // 🖼️ ADVANCED PHOTO MANAGER
  void _managePhotos(BuildContext context, List<dynamic> photos) {
    showModalBottomSheet(
        context: context,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),

                    const Text("Mess Photos (Max 5) 📸", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    if (photos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text("No photos added yet. Upload to attract students!", style: TextStyle(color: Colors.grey)),
                      )
                    else
                      SizedBox(
                          height: 140,
                          child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: photos.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                    children: [
                                      Container(
                                          margin: const EdgeInsets.only(right: 15, top: 10),
                                          width: 140,
                                          decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              border: Border.all(color: Colors.white10),
                                              image: DecorationImage(image: NetworkImage(photos[index]), fit: BoxFit.cover)
                                          )
                                      ),
                                      Positioned(
                                          top: 0, right: 5,
                                          child: InkWell(
                                            onTap: () async {
                                              Navigator.pop(context);
                                              await _deletePhoto(photos[index]);
                                            },
                                            child: const CircleAvatar(radius: 14, backgroundColor: Colors.red, child: Icon(Icons.delete, size: 16, color: Colors.white)),
                                          )
                                      )
                                    ]
                                );
                              }
                          )
                      ),

                    const SizedBox(height: 25),
                    SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: photos.length >= 5 ? null : () => _uploadPhoto(context, photos),
                            icon: const Icon(Icons.add_a_photo, color: Colors.white),
                            label: const Text("Upload New Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                    )
                  ]
              )
          );
        }
    );
  }

  void _editProfile(BuildContext context) {
    TextEditingController nameCtrl = TextEditingController(text: widget.ownerData['mess_name']);
    TextEditingController mobileCtrl = TextEditingController(text: widget.ownerData['mobile']);
    TextEditingController addressCtrl = TextEditingController(text: widget.ownerData['address']);
    TextEditingController upiCtrl = TextEditingController(text: widget.ownerData['upi_id'] ?? "");

    showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: BhojnTheme.surfaceCard, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
            child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Edit Mess Details", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 25),
                  TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Mess Name", labelStyle: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                  TextField(controller: mobileCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Contact Mobile", labelStyle: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                  TextField(controller: addressCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Full Address", labelStyle: TextStyle(color: Colors.grey))),
                  const SizedBox(height: 15),
                  TextField(controller: upiCtrl, style: const TextStyle(color: BhojnTheme.accentRed, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: "UPI ID (Very Important)", labelStyle: TextStyle(color: BhojnTheme.accentRed), hintText: "example@okbank", hintStyle: TextStyle(color: Colors.white24))),
                  const SizedBox(height: 30),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () async {
                            String enteredUpi = upiCtrl.text.trim();
                            bool isValidUpi = RegExp(r"^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$").hasMatch(enteredUpi);
                            if (!isValidUpi && enteredUpi.isNotEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Invalid UPI Format! Must be like name@bank"), backgroundColor: Colors.red)); return; }

                            await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'mess_name': nameCtrl.text.trim(), 'mobile': mobileCtrl.text.trim(), 'address': addressCtrl.text.trim(), 'upi_id': enteredUpi,});
                            if(context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully! ✅"), backgroundColor: Colors.green)); }
                          },
                          child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      )
                  ),
                  const SizedBox(height: 20),
                ]
            )
        )
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: BhojnTheme.surfaceCard,
          title: const Text("Logout?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to logout of your account?", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.accentRed),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.auth.logout();
                },
                child: const Text("Yes, Logout", style: TextStyle(color: Colors.white))
            )
          ],
        )
    );
  }

  void _confirmDeleteProfile(BuildContext context) {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: BhojnTheme.surfaceCard,
          title: const Text("Delete Profile? ⚠️", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text("This is a permanent action! Your mess profile, active students, and all transaction history will be wiped out from the servers immediately. Are you sure?", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)));

                  try {
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      String uid = user.uid;
                      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
                      await user.delete();
                      await widget.auth.logout();
                      if (context.mounted) Navigator.pop(context);
                    }
                  } on FirebaseAuthException catch(e) {
                    if (context.mounted) Navigator.pop(context);
                    if (e.code == 'requires-recent-login') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Security Check: Session expired. Log out and log in again to verify identity before deleting! 🔒"), backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
                    }
                  } catch(e) {
                    if (context.mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete account. Contact support.")));
                  }
                },
                child: const Text("Permanently Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  void _manageHolidays(BuildContext context, String currentHolidaysStr) {
    List<String> allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    List<String> selectedDays = currentHolidaysStr == "None" ? [] : currentHolidaysStr.split(', ');

    showModalBottomSheet(
        context: context,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetContext) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Select Weekly Holidays", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        const Text("Select multiple days if your mess is closed on specific days.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: allDays.map((day) {
                            bool isSelected = selectedDays.contains(day);
                            return FilterChip(
                              label: Text(day, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12)),
                              selected: isSelected,
                              selectedColor: BhojnTheme.accentRed,
                              backgroundColor: Colors.white10,
                              checkmarkColor: Colors.white,
                              onSelected: (val) {
                                setSheetState(() {
                                  if (val) {
                                    selectedDays.add(day);
                                  } else {
                                    selectedDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.accentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: () async {
                                  String newHolidayStr = selectedDays.isEmpty ? "None" : selectedDays.join(', ');
                                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'weekly_holiday': newHolidayStr});
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Holidays Updated! 📅"), backgroundColor: Colors.green));
                                  }
                                },
                                child: const Text("Save Holidays", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                        )
                      ],
                    )
                );
              }
          );
        }
    );
  }

  // 🚀 NAYA FUNCTION: COMPLAINT INBOX WAPAS LAA DIYA
  void _showComplaints(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BhojnTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(top: 25, left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              const Row(
                children: [
                  Icon(Icons.report_problem, color: Colors.orangeAccent),
                  SizedBox(width: 10),
                  Text("Student Complaints", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('complaints').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange));
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No complaints yet! You're doing great! 🎉", style: TextStyle(color: Colors.grey)));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;
                        String studentName = data['student_name'] ?? "Unknown Student";
                        String issue = data['issue'] ?? "No details provided";
                        Timestamp? ts = data['timestamp'];
                        String dateStr = ts != null ? DateFormat('dd MMM, hh:mm a').format(ts.toDate()) : "Just now";

                        return Card(
                          color: Colors.white10,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(studentName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 5),
                                Text(issue, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 5),
                                Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              onPressed: () async {
                                await doc.reference.delete();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Complaint marked as resolved! ✅"), backgroundColor: Colors.green));
                                }
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override Widget build(BuildContext context) {
    String messName = widget.ownerData['mess_name'] ?? "My Mess Profile";
    String contactInfo = widget.ownerData['mobile'] ?? "No Contact Added";
    String address = widget.ownerData['address'] ?? "Address not provided";
    bool isVisible = widget.ownerData['is_visible'] ?? true;
    String holiday = widget.ownerData['weekly_holiday'] ?? "None";
    bool wantsScanNotifications = widget.ownerData['notify_on_scan'] ?? true;
    List<dynamic> photos = widget.ownerData['photos'] ?? [];

    double lat = double.tryParse(widget.ownerData['lat']?.toString() ?? '0') ?? 0.0;
    double lng = double.tryParse(widget.ownerData['lng']?.toString() ?? '0') ?? 0.0;
    String coordStr = (lat != 0 && lng != 0) ? "${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}" : "Not Set";

    DateTime now = DateTime.now();

    int priceMonthly = int.tryParse(widget.ownerData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    int avgThaliRate = priceMonthly > 0 ? (priceMonthly / 60).round() : 0;

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('active_messes', arrayContains: widget.uid).snapshots(),
        builder: (context, studentSnap) {

          int totalPendingDues = 0;
          if (studentSnap.hasData) {
            for (var doc in studentSnap.data!.docs) {
              var sData = doc.data() as Map<String, dynamic>;
              Map<String, dynamic> specData = sData['mess_data']?[widget.uid] ?? {};
              totalPendingDues += (num.tryParse(specData['pending_dues']?.toString() ?? sData['pending_dues']?.toString() ?? '0') ?? 0).toInt();
            }
          }

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('recent_transactions').orderBy('timestamp', descending: true).limit(3000).snapshots(),
              builder: (context, recentSnap) {

                int cashToday = 0, cashMonthly = 0, cashYearly = 0;
                int foodValueToday = 0, foodValueMonthly = 0, foodValueYearly = 0;

                if(recentSnap.hasData) {
                  for(var doc in recentSnap.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if(data['isPending'] == true || data['timestamp'] == null) continue;

                    DateTime dt = (data['timestamp'] as Timestamp).toDate();

                    int amt = (data['amount'] is int) ? data['amount'] : (int.tryParse(data['amount']?.toString() ?? '0') ?? 0);
                    bool isScan = (amt == 0);
                    int valueToAdd = isScan ? avgThaliRate : amt;

                    if (dt.year == now.year) {
                      if (amt > 0) cashYearly += amt;
                      if (isScan) foodValueYearly += valueToAdd;

                      if (dt.month == now.month) {
                        if (amt > 0) cashMonthly += amt;
                        if (isScan) foodValueMonthly += valueToAdd;

                        if (dt.day == now.day) {
                          if (amt > 0) cashToday += amt;
                          if (isScan) foodValueToday += valueToAdd;
                        }
                      }
                    }
                  }
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                        child: Column(
                            children: [
                              Row(
                                  children: [
                                    const CircleAvatar(radius: 40, backgroundColor: Colors.white10, child: Icon(Icons.restaurant, size: 40, color: BhojnTheme.accentRed)),
                                    const SizedBox(width: 20),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(messName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                              const SizedBox(height: 5),
                                              Text("+91 $contactInfo", style: const TextStyle(color: Colors.white70, fontSize: 14))
                                            ]
                                        )
                                    ),
                                    IconButton(onPressed: () => _editProfile(context), icon: const Icon(Icons.edit, color: BhojnTheme.accentRed))
                                  ]
                              ),
                              const Divider(color: Colors.white10, height: 30),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.grey, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(address, style: const TextStyle(color: Colors.grey, fontSize: 13)))
                                  ]
                              )
                            ]
                        )
                    ),
                    const SizedBox(height: 25),

                    const Text("Income Analytics 📈", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),

                    Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Avg. Thali Rate:", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text("₹$avgThaliRate / meal", style: const TextStyle(color: BhojnTheme.primaryOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 15),

                              const Text("💰 Actual Cash Received", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 5),
                              _incomeRow("Today", "₹ $cashToday"),
                              _incomeRow("This Month", "₹ $cashMonthly"),
                              _incomeRow("This Year", "₹ $cashYearly"),

                              const Divider(color: Colors.white10, height: 30),

                              const Text("🍛 Value of Food Served", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 5),
                              _incomeRow("Today", "₹ $foodValueToday"),
                              _incomeRow("This Month", "₹ $foodValueMonthly"),
                              _incomeRow("This Year", "₹ $foodValueYearly"),

                              const Divider(color: Colors.white10, height: 30),

                              _incomeRow("Total Pending Dues", "₹ $totalPendingDues", color: Colors.redAccent),
                            ]
                        )
                    ),
                    const SizedBox(height: 25),

                    // 🚀 NAYA SECTION: INBOX & FEEDBACK
                    const Text("Inbox & Support 📥", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),
                    Container(
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: const Icon(Icons.report_problem, color: Colors.orangeAccent),
                        title: const Text("Student Complaints Inbox", style: TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: const Text("Tap to view issues reported by students", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () => _showComplaints(context),
                      ),
                    ),
                    const SizedBox(height: 25),

                    const Text("Settings & Controls ⚙️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),

                    Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                            children: [
                              ListTile(
                                  leading: const Icon(Icons.collections, color: BhojnTheme.primaryOrange),
                                  title: const Text("Manage Mess Photos", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text("${photos.length}/5 Photos Uploaded", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  onTap: () => _managePhotos(context, photos)
                              ),
                              const Divider(color: Colors.white10, height: 1),

                              ListTile(
                                  leading: const Icon(Icons.my_location, color: Colors.blueAccent),
                                  title: const Text("Update Live Location", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text("GPS: $coordStr", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  trailing: const Icon(Icons.refresh, size: 18, color: Colors.blueAccent),
                                  onTap: () => _updateLiveLocation(context)
                              ),
                              const Divider(color: Colors.white10, height: 1),

                              SwitchListTile(
                                  activeColor: BhojnTheme.accentRed,
                                  title: const Text("Visibility for Nearby Students", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text(isVisible ? "Students can see you in Explore" : "You are hidden from searches", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  value: isVisible,
                                  onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'is_visible': val})
                              ),
                              const Divider(color: Colors.white10, height: 1),

                              SwitchListTile(
                                  activeColor: BhojnTheme.accentRed,
                                  title: const Text("Attendance Push Notifications", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text(wantsScanNotifications ? "You get notified on every student scan" : "Silent mode. No scan alerts.", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  value: wantsScanNotifications,
                                  onChanged: (val) => FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'notify_on_scan': val})
                              ),
                              const Divider(color: Colors.white10, height: 1),

                              ListTile(
                                  leading: const Icon(Icons.event_busy, color: Colors.white70),
                                  title: const Text("Set Weekly Holiday(s)", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  subtitle: Text("Closed on: $holiday", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                  trailing: const Icon(Icons.edit, size: 14, color: Colors.grey),
                                  onTap: () => _manageHolidays(context, holiday)
                              ),
                            ]
                        )
                    ),
                    const SizedBox(height: 30),

                    const Text("Danger Zone ⚠️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BhojnTheme.accentRed)),
                    const SizedBox(height: 15),

                    Container(
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                            children: [
                              ListTile(
                                  leading: const Icon(Icons.logout, color: Colors.white70),
                                  title: const Text("Logout", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  onTap: () => _confirmLogout(context)
                              ),
                              const Divider(color: Colors.white10, height: 1),
                              ListTile(
                                  leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                  title: const Text("Delete Account Permanently", style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                                  onTap: () => _confirmDeleteProfile(context)
                              ),
                            ]
                        )
                    ),
                    const SizedBox(height: 100),
                  ]),
                );
              }
          );
        }
    );
  }

  Widget _incomeRow(String title, String amount, {Color color = Colors.white}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(amount, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold))
          ]
      )
  );
}

// Ye sabse last mein daal de bhai
class _WavingHand extends StatefulWidget { const _WavingHand({super.key}); @override State<_WavingHand> createState() => _WavingHandState(); }
class _WavingHandState extends State<_WavingHand> with SingleTickerProviderStateMixin { late AnimationController _controller; late Animation<double> _animation; @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); _animation = Tween<double>(begin: -0.05, end: 0.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)); } @override void dispose() { _controller.dispose(); super.dispose(); } @override Widget build(BuildContext context) => RotationTransition(turns: _animation, child: const Text("👋", style: TextStyle(fontSize: 18))); }
