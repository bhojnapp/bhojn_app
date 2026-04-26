import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'scanner_screen.dart';
import '../notification_services.dart';
import '../services/request_service.dart';

// ----------------------------------------------------------------------------
// 🚀 HELPER: Time to Meal Converter
// ----------------------------------------------------------------------------
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

// ============================================================================
// MAIN DASHBOARD CLASS
// ============================================================================
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  bool _isInitialLoad = true;
  final User? user = FirebaseAuth.instance.currentUser;
  bool _hasShownJoke = false;

  String? _globalSelectedMessId;

  @override
  void initState() {
    super.initState();

    if (user != null) {
      NotificationServices notificationServices = NotificationServices();
      notificationServices.initLocalNotifications().then((_) {
        print("Student Chowkidar Ready! ✅");
        notificationServices.requestNotificationPermission();
        notificationServices.saveDeviceToken(user!.uid, 'users');
        notificationServices.firebaseInit();
      });
    }
  }

  void _showDailyChutkula() {
    final List<String> jokes = [
      "Hostel ka khana aur coding ka error... dono rulaate hain, par aadat pad jaati hai! 🤣",
      "Engineer ki life mein do hi problem hain: Ek 'Out of Syllabus' aur doosra 'Paneer ki sabzi mein Paneer kahan hai?' 🕵️‍♂️",
      "Mess wale bhaiya ka confidence dekho, paani daalke bolte hain 'Dal fry hai'! 😂",
      "Assignments aur Mess ka bill, hamesha due date ke baad hi yaad aate hain! ⏳",

      // 🔥 Naye Bachelor/Hostel Wale (29 Naye Bomb 💣)
      "Hostel ki 'Dal' aur ex ka 'Pyaar', dono kitne bhi pakka lo, patle hi rehte hain! 💔🍲",
      "Mahine ke shuru mein 'Bhai paneer mangwa', mahine ke aakhir mein 'Bhai Parle-G bacha hai kya?' 🍪📉",
      "Hostel mein alarm khud ke uthne ke liye nahi, roommates ki neend kharab karne ke liye lagaya jata hai! ⏰😂",
      "Kapde dhone ka bachelor rule: Jab tak almari ekdum khali na ho jaye, tab tak balti ko haath nahi lagana! 👕🛁",
      "Ghar ki yaad sabse zyada tab aati hai, jab thand mein subah apne jhoothe bartan dhone padte hain! 🥶🍽️",
      "Mess ki roti ko modna padta hai ya todna padta hai, aaj tak research chalu hai! 🥏🤔",
      "Sunday special ke naam pe wahi aalu-matar milte hain, bas usme aalu aur matar ka ratio thoda badh jata hai! 🥔🌿",
      "Bachelor life ka sach: Roommate ki Maggi hamesha apni Maggi se zyada tasty lagti hai! 🍜🤤",
      "Subah uth ke sabse bada decision: Aaj college jau, ya neend puri karu? 😴🎓",
      "Hostel mein shampoo aur toothpaste khatam hone ke baad bhi 3 din tak chalte hain, ye humara asli talent hai! 🧴💧",
      "Aadhi raat ko bhookh lagne par mess band hota hai, aur Zomato out of budget. Fir yaad aati hai maa ki rasoi! 😭🍔",
      "Mess wali aunty ka 'Beta aur kha lo' sunke lagta hai ghar aa gaye, phir roti chabate hi reality hit hoti hai! 🥲🏡",
      "Wi-Fi ki speed aur mess ki sabzi ka taste, dono hamesha expectations se kam hi hote hain! 📶📉",
      "Hostel mein 'Private' word ki koi value nahi, sab 'Open Source' (Sabka) hota hai! 🤝😅",
      "Room ki safai tabhi hoti hai jab ya toh mummy aane wali ho, ya phir room me chalne ki jagah na bachi ho! 🧹🗑️",
      "Bachelors ke pass hamesha 2 hi aasan raste hote hain: 'Bhai kal se pakka padhunga' aur 'Bhai aaj bahar khaate hain!' 🍕📚",
      "Mess ke chawal aur crush ka reply... dono hamesha thande hi aate hain! 🍚❄️",
      "Hostel fridge ka rule: Jo dikha, wo mera. Jisne rakha, wo dekhta reh gaya! 🥛👀",
      "Duniya mein sabse zyada wait aache din ka nahi, mess mein Sunday wale Chicken/Paneer ka hota hai! 🍗⏳",
      "Pura hafta sochne mein nikal jata hai ki 'Weekend pe kya karenge?', aur weekend sote-sote nikal jata hai! 🛌📆",
      "PG/Hostel ka sabse bada jhooth: 'Main uth gaya hu, bas 5 minute mein ready hoke aata hu!' ⏱️🏃‍♂️",
      "Month-end mein UPI PIN yaad rehta hai, par bank balance dekhne ki himmat nahi hoti! 💸🫣",
      "Mess ki paneer ki sabzi ek 'Treasure Hunt' hai, jisme paneer kisi ek lucky winner ko hi milta hai! 🏴‍☠️🧀",
      "Ghar walon ko lagta hai beta padhai kar raha hai, aur beta yahan soch raha hai raat ko Maggi kaun banayega! 🍜🧠",
      "Bhookh lagne pe 'Kuch bhi chalega' bolne wale dost hi sabse zyada nakhre karte hain mess me! 🤦‍♂️😂",
      "Exam se pehle wali raat aur mess ka raat ka khana, dono se bas bhagwan hi bacha sakta hai! 🙏🌙",
      "Hostel ki dosti ka ek hi test hai: 'Bhai tere hisse ka paneer/chicken mujhe dega kya?' 🤝🍲",
      "Ek bachelor ka bed sone se zyada laptop aur dhule hue kapde rakhne ke kaam aata hai! 💻🛏️",
      "Zindagi aur mess ki sabzi, dono mein 'namak' swaadanusaar kabhi nahi hota, ya toh zyada ya ekdum gayab! 🧂😬"
    ];
    String randomJoke = jokes[Random().nextInt(jokes.length)];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BhojnTheme.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Daily Chutkula 🤣", style: TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold)),
        content: Text(randomJoke, style: const TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Haha, OK! 😂", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  void _showSuccessAnimation() {
    showDialog(
        context: context,
        barrierColor: Colors.black87,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(const Duration(milliseconds: 3500), () {
            if (mounted && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Lottie.asset('assets/Thank you with confetti.json', width: 250, height: 250, repeat: false),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 1.5)
                  ),
                  child: const Text("Scan Successful! 🎉", style: TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Login kar bhai!")));

    return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(backgroundColor: BhojnTheme.darkBg, body: Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange)));
          }

          var studentData = studentSnapshot.data?.data() as Map<String, dynamic>? ?? {};

          List<String> activeMesses = [];
          if (studentData['joined_mess_id'] != null && studentData['joined_mess_id'].toString().isNotEmpty) {
            activeMesses.add(studentData['joined_mess_id'].toString());
          }
          if (studentData['active_messes'] != null) {
            for (var m in studentData['active_messes']) {
              if (!activeMesses.contains(m.toString())) activeMesses.add(m.toString());
            }
          }

          if (activeMesses.isNotEmpty && (_globalSelectedMessId == null || !activeMesses.contains(_globalSelectedMessId))) {
            _globalSelectedMessId = activeMesses.first;
          } else if (activeMesses.isEmpty) {
            _globalSelectedMessId = null;
          }

          if (_isInitialLoad) {
            _currentIndex = activeMesses.isNotEmpty ? 0 : 1;
            _isInitialLoad = false;
          }

          if ((studentData['is_chutkula_on'] ?? false) && !_hasShownJoke) {
            _hasShownJoke = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _showDailyChutkula());
          }

          // 🚀 REAL GPS LINK: Student ki location nikali yahan se
          double currentLat = double.tryParse(studentData['lat']?.toString() ?? '18.5204') ?? 18.5204;
          double currentLng = double.tryParse(studentData['lng']?.toString() ?? '73.8567') ?? 73.8567;

          final List<Widget> tabs = [
            _HomeTab(
              activeMesses: activeMesses,
              studentUid: user!.uid,
              studentData: studentData,
              selectedMessId: _globalSelectedMessId,
              onMessSwitched: (newId) {
                setState(() { _globalSelectedMessId = newId; });
              },
            ),
            _ExploreTab(studentLat: currentLat, studentLng: currentLng), // 🚀 And pass kardi Explore ko
            const _HostelsTab(),
            _MeTab(activeMesses: activeMesses, studentData: studentData, auth: AuthService(), uid: user!.uid)
          ];

          return Scaffold(
            backgroundColor: BhojnTheme.darkBg,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,

              // 🚀 THE IOS KILLER FIX: Ye lagate hi sab left me chipak jayega!
              centerTitle: false,
              titleSpacing: 20, // Edge se left spacing

              // 🔥 1. LEFT SIDE (Sirf BHOJN aur OPEN/CLOSED button)
              title: Row(
                  mainAxisSize: MainAxisSize.min, // Jitni zaroorat utni jagah lega
                  children: [
                    const Text('BHOJN', style: TextStyle(fontWeight: FontWeight.w900, color: BhojnTheme.primaryOrange, fontStyle: FontStyle.italic, fontSize: 24)),

                    if (_currentIndex == 0 && _globalSelectedMessId != null) ...[
                      const SizedBox(width: 8),
                      StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(_globalSelectedMessId).snapshots(),
                          builder: (context, messSnap) {
                            if (!messSnap.hasData || !messSnap.data!.exists) return const SizedBox();

                            // Safe Extraction jo humne pichle fix mein kiya tha
                            var messData = messSnap.data!.data() as Map<String, dynamic>?;
                            bool isOpen = true;
                            if (messData != null && messData.containsKey('is_open')) {
                              isOpen = messData['is_open'] == true;
                            }

                            return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                    color: isOpen ? Colors.green.withOpacity(0.15) : Colors.redAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isOpen ? Colors.green : Colors.redAccent, width: 1.5)
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isOpen ? Colors.green : Colors.redAccent)),
                                    const SizedBox(width: 4),
                                    Text(isOpen ? "OPEN" : "CLOSED", style: TextStyle(color: isOpen ? Colors.green : Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                )
                            );
                          }
                      )
                    ],
                  ]
              ),

              // 🔥 2. RIGHT SIDE (Hello Name aur 👋) - Ye automatically right me jayega
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130), // Laal patti aane se rokega
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            "Hello", // Yahan apna dynamic naam (user.displayName) daal dena
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const _WavingHand()
                      ],
                    ),
                  ),
                )
              ],
            ),
            body: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(key: ValueKey<int>(_currentIndex), child: tabs[_currentIndex])
            ),
            floatingActionButton: FloatingActionButton(
                heroTag: null,
                onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
                  if (result == true && mounted) {
                    _showSuccessAnimation();
                  }
                },
                backgroundColor: BhojnTheme.primaryOrange,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.white)
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              color: BhojnTheme.surfaceCard,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              child: SizedBox(
                height: 60,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNavItem(icon: Icons.home_rounded, label: "HOME", index: 0),
                      _buildNavItem(icon: Icons.explore_rounded, label: "EXPLORE", index: 1),
                      const SizedBox(width: 40),
                      _buildNavItem(icon: Icons.apartment_rounded, label: "HOSTELS", index: 2),
                      _buildNavItem(icon: Icons.person_rounded, label: "ME", index: 3)
                    ]
                ),
              ),
            ),
          );
        }
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    bool isSel = _currentIndex == index;
    Color color = isSel ? BhojnTheme.primaryOrange : Colors.grey;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(scale: isSel ? 1.2 : 1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack, child: Icon(icon, color: color, size: 24)),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 300), style: TextStyle(color: color, fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal), child: Text(label))
            ]
        ),
      ),
    );
  }
}

// ============================================================================
// 🏠 1. HOME TAB (Advanced Custom Dues & Anti-Spam)
// ============================================================================
class _HomeTab extends StatefulWidget {
  final List<String> activeMesses;
  final String studentUid;
  final Map<String, dynamic> studentData;
  final String? selectedMessId;
  final Function(String) onMessSwitched;

  const _HomeTab({
    required this.activeMesses,
    required this.studentUid,
    required this.studentData,
    required this.selectedMessId,
    required this.onMessSwitched
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic> _getMessSpecificData(String mId) {
    Map<String, dynamic> specificData = widget.studentData['mess_data']?[mId] ?? {};
    if (specificData.isNotEmpty) return specificData;

    if (widget.studentData['joined_mess_id'] == mId) {
      return {
        'total_allotted_meals': widget.studentData['total_allotted_meals'],
        'remaining_meals': widget.studentData['remaining_meals'],
        'pending_dues': widget.studentData['pending_dues']
      };
    }
    return { 'total_allotted_meals': 60, 'remaining_meals': 60, 'pending_dues': 0 };
  }

  void _handlePendingDues(BuildContext context, Map<String, dynamic> messData, String messUid, int totalAllottedMeals) {
    Map<String, dynamic> strictState = _getMessSpecificData(messUid);
    double pendingAmount = double.tryParse(strictState['pending_dues']?.toString() ?? '0') ?? 0;
    int priceMonthly = int.tryParse(messData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    int price15 = int.tryParse(messData['price_15days']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;

    int planPrice = (totalAllottedMeals <= 30) ? price15 : priceMonthly;
    if (planPrice == 0) planPrice = pendingAmount.toInt();

    double paidAmount = planPrice - pendingAmount;
    if (paidAmount < 0) paidAmount = 0;

    String ownerUpi = messData['upi_id'] ?? "";
    String messName = messData['mess_name'] ?? "Mess";

    TextEditingController payCtrl = TextEditingController(text: pendingAmount.toInt().toString());

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(messUid).collection('recent_transactions')
                      .where('uid', isEqualTo: widget.studentUid)
                      .where('isPending', isEqualTo: true)
                      .where('type', isEqualTo: 'Due Payment (Pending Verify)')
                      .snapshots(),
                  builder: (context, pendingSnap) {
                    bool hasPendingRequest = pendingSnap.hasData && pendingSnap.data!.docs.isNotEmpty;

                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                          left: 25, right: 25, top: 25
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 50),
                            const SizedBox(height: 15),
                            const Text("Billing & Dues", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),

                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Plan Total:", style: TextStyle(color: Colors.grey)), Text("₹$planPrice", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                                  const Divider(color: Colors.white10, height: 20),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Amount Paid:", style: TextStyle(color: Colors.grey)), Text("₹$paidAmount", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                                  const Divider(color: Colors.white10, height: 20),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Due:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("₹$pendingAmount", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18))]),
                                ],
                              ),
                            ),
                            const SizedBox(height: 25),

                            if (pendingAmount > 0) ...[
                              if (hasPendingRequest) ...[
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.withOpacity(0.5))
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.hourglass_top, color: Colors.orange),
                                      const SizedBox(width: 10),
                                      const Expanded(child: Text("⏳ Teri ek payment already verification ke liye pending hai. Owner ke approve karne tak thoda wait kar bhai!", style: TextStyle(color: Colors.orange, fontSize: 12, height: 1.5)))
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(width: double.infinity, height: 50, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)), onPressed: () => Navigator.pop(context), child: const Text("Close")))
                              ] else ...[
                                const Align(alignment: Alignment.centerLeft, child: Text("Enter Amount to Pay Now (₹)", style: TextStyle(color: Colors.white70, fontSize: 12))),
                                const SizedBox(height: 8),
                                TextField(
                                    controller: payCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    decoration: InputDecoration(
                                        prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70),
                                        filled: true,
                                        fillColor: Colors.white.withOpacity(0.05),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                                    )
                                ),
                                const SizedBox(height: 10),
                                const Text("Clear your dues to continue enjoying meals without interruption.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const SizedBox(height: 20),

                                SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () async {
                                          int payingAmt = int.tryParse(payCtrl.text) ?? 0;
                                          if(payingAmt <= 0) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bhai valid amount toh daal! 🤦‍♂️")));
                                            return;
                                          }
                                          if(payingAmt > pendingAmount) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pending dues se zyada amount kyu de raha hai bhai! 🛑")));
                                            return;
                                          }
                                          if(ownerUpi.isEmpty || ownerUpi == "No UPI ID") {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Owner UPI not available!")));
                                            return;
                                          }

                                          String upiUrl = "upi://pay?pa=$ownerUpi&pn=${Uri.encodeComponent(messName)}&tr=$messUid&am=$payingAmt&cu=INR";
                                          String timeStr = DateFormat('hh:mm a').format(DateTime.now());

                                          await FirebaseFirestore.instance.collection('users').doc(messUid).collection('recent_transactions').add({
                                            'name': widget.studentData['name'] ?? "Student",
                                            'uid': widget.studentUid,
                                            'amount': payingAmt,
                                            'type': 'Due Payment (Pending Verify)',
                                            'time': timeStr,
                                            'isPending': true,
                                            'timestamp': FieldValue.serverTimestamp()
                                          });

                                          try {
                                            await launchUrl(Uri.parse(upiUrl), mode: LaunchMode.externalApplication);
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open UPI app.")));
                                          }

                                          if(context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment request sent to Owner! ✅"), backgroundColor: Colors.green));
                                          }
                                        },
                                        child: const Text("PAY NOW VIA UPI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                    )
                                )
                              ]
                            ] else ...[
                              const Text("Awesome! You are fully paid.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24)),
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Go Back")
                                  )
                              )
                            ]
                          ]
                      ),
                    );
                  }
              );
            }
        )
    );
  }

  void _handleRateMess(BuildContext context, String messUid) {
    int _rating = 5;
    showModalBottomSheet(
        context: context,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Rate Your Experience", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) => IconButton(
                                icon: Icon(index < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 40),
                                onPressed: () => setModalState(() => _rating = index + 1)
                            ))
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                onPressed: () async {
                                  await FirebaseFirestore.instance.collection('users').doc(messUid).collection('ratings').doc(widget.studentUid).set({
                                    'rating': _rating,
                                    'timestamp': FieldValue.serverTimestamp()
                                  });
                                  if(context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanks for rating! 🌟"), backgroundColor: Colors.green));
                                  }
                                },
                                child: const Text("SUBMIT RATING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                        )
                      ]
                  )
              );
            }
        )
    );
  }

  void _handleReportMess(BuildContext context, String messUid) {
    TextEditingController complaintCtrl = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Report an Issue", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Your complaint will be sent directly to the owner anonymously.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 20),
                  TextField(
                      controller: complaintCtrl,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                          hintText: "What went wrong?",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                      )
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          onPressed: () async {
                            if(complaintCtrl.text.isEmpty) return;
                            await FirebaseFirestore.instance.collection('users').doc(messUid).collection('complaints').add({
                              'issue': complaintCtrl.text.trim(),
                              'timestamp': FieldValue.serverTimestamp()
                            });
                            if(context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue reported to owner! 🚨"), backgroundColor: Colors.orange));
                            }
                          },
                          child: const Text("SEND REPORT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      )
                  ),
                  const SizedBox(height: 20),
                ]
            )
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activeMesses.isEmpty || widget.selectedMessId == null) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.restaurant_menu, size: 100, color: Colors.white.withOpacity(0.1)), const SizedBox(height: 20),
            const Text("No Mess Joined Yet!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 10),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 40), child: Text("Go to Explore tab to find nearby messes, or tap the Scanner to join a mess directly.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
          ])
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.activeMesses.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 10, bottom: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.activeMesses.map((mId) {
                  int idx = widget.activeMesses.indexOf(mId) + 1;
                  bool isSel = mId == widget.selectedMessId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(label: Text("Pass $idx", style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)), selected: isSel, selectedColor: BhojnTheme.primaryOrange, backgroundColor: Colors.white.withOpacity(0.05), onSelected: (val) { if (val) widget.onMessSwitched(mId); }),
                  );
                }).toList(),
              ),
            ),
          ),

        Expanded(
          child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(widget.selectedMessId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange));
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();

                var messData = snapshot.data!.data() as Map<String, dynamic>;
                String messName = messData['mess_name'] ?? "My Mess";
                String todayMenu = messData['today_menu'] ?? "Menu not updated yet.";
                String menuTime = messData['menu_updated_at'] ?? "Recently";

                bool isVotingActive = messData['is_voting_active'] ?? false;
                List<dynamic> votingOptions = messData['voting_options'] ?? [];
                List<dynamic> votedBy = messData['voted_by'] ?? [];
                bool hasVoted = votedBy.contains(widget.studentUid);
                Map<String, dynamic> votingResults = messData['voting_results'] ?? {};
                int totalVotes = votingResults.values.fold(0, (sum, val) => sum + (val as int));

                Map<String, dynamic> strictState = _getMessSpecificData(widget.selectedMessId!);
                int totalAllotted = int.tryParse(strictState['total_allotted_meals']?.toString() ?? '60') ?? 60;
                int rawRemaining = int.tryParse(strictState['remaining_meals']?.toString() ?? totalAllotted.toString()) ?? totalAllotted;

                int remainingMeals = totalAllotted;
                int scansDone = 0;
                if (rawRemaining < 0) { scansDone = rawRemaining.abs(); remainingMeals = totalAllotted - scansDone; }
                else { remainingMeals = rawRemaining; scansDone = totalAllotted - remainingMeals; }
                if (remainingMeals < 0) remainingMeals = 0; if (remainingMeals > totalAllotted) remainingMeals = totalAllotted;
                if (scansDone < 0) scansDone = 0; if (scansDone > totalAllotted) scansDone = totalAllotted;
                double progress = totalAllotted > 0 ? (scansDone / totalAllotted).clamp(0.0, 1.0) : 0.0;
                num pendingDueAmt = num.tryParse(strictState['pending_dues']?.toString() ?? '0') ?? 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [BhojnTheme.primaryOrange, BhojnTheme.primaryOrange.withOpacity(0.7)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: BhojnTheme.primaryOrange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Digital Mess Pass", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), Text(messName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900))]), const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white))]), const SizedBox(height: 20),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Scans Done: $scansDone/$totalAllotted", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text("${(progress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]), const SizedBox(height: 8),
                            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.white24, color: Colors.white)), const SizedBox(height: 10),
                            Text("Remaining: $remainingMeals meals", style: const TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          _buildActionBtn(context, "Due: ₹$pendingDueAmt", Icons.account_balance_wallet, Colors.redAccent, () => _handlePendingDues(context, messData, widget.selectedMessId!, totalAllotted)), const SizedBox(width: 12),
                          _buildActionBtn(context, "Rate Mess", Icons.star_rounded, Colors.amber, () => _handleRateMess(context, widget.selectedMessId!)), const SizedBox(width: 12),
                          _buildActionBtn(context, "Report", Icons.campaign_rounded, Colors.orange, () => _handleReportMess(context, widget.selectedMessId!)),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Today's Menu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text("Updated: $menuTime", style: const TextStyle(color: Colors.grey, fontSize: 10)))]), const SizedBox(height: 12),
                      Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.restaurant, color: BhojnTheme.primaryOrange, size: 30), const SizedBox(height: 10), Text(todayMenu, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6))])),
                      const SizedBox(height: 30),
                      if (isVotingActive && votingOptions.isNotEmpty) ...[
                        const Text("Sunday Special Poll 🗳️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!hasVoted) ...[
                                const Text("Cast your vote below (1 Vote per Student):", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10),
                                ...votingOptions.map((option) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(widget.selectedMessId).update({'voting_results.$option': FieldValue.increment(1), 'voted_by': FieldValue.arrayUnion([widget.studentUid])}); if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Voted for $option! ✅"), backgroundColor: Colors.green)); }, child: Text(option.toString()))))).toList(),
                              ] else ...[
                                const Text("Live Results (You have voted!):", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
                                ...votingResults.entries.map((entry) { double votePercent = totalVotes > 0 ? entry.value / totalVotes : 0.0; return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(entry.key, style: const TextStyle(color: Colors.white)), Text("${entry.value} votes", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12))]), const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: votePercent, minHeight: 8, backgroundColor: Colors.white10, color: Colors.blueAccent))])); }).toList(), const SizedBox(height: 10), Text("Total Votes: $totalVotes (Poll auto-expires in 7 days)", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
          child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))]),
        ),
      ),
    );
  }
}

// ============================================================================
// 🌍 2. EXPLORE TAB
// ============================================================================
class _ExploreTab extends StatefulWidget {
  final double studentLat;
  final double studentLng;

  const _ExploreTab({required this.studentLat, required this.studentLng});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  String searchQuery = "";
  bool showOnlyOpen = false;
  bool showWithin3Km = false;
  bool showHighestRated = false;

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0 || lon1 == 0 || lat2 == 0 || lon2 == 0) return 0.0;
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p)/2 + c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a));
  }

  void _openJoinRequestForm(BuildContext context, Map<String, dynamic> messData, String messUid) {
    int priceMonthly = int.tryParse(messData['price_monthly']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    int price15Days = int.tryParse(messData['price_15days']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
    int selectedPlanPrice = priceMonthly;
    int allocatedMeals = 60;
    TextEditingController paidAmountCtrl = TextEditingController();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {
              int paidAmount = int.tryParse(paidAmountCtrl.text) ?? 0;
              int pendingDue = selectedPlanPrice - paidAmount;

              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Join Mess Request", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      const Text("Select a plan and enter the amount you have already paid offline/UPI.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 20),

                      const Text("Select Plan", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                          children: [
                            Expanded(
                                child: ChoiceChip(
                                    label: Text("15 Days (₹$price15Days)", style: const TextStyle(fontSize: 12)),
                                    selected: selectedPlanPrice == price15Days,
                                    onSelected: (val) { setModalState(() { selectedPlanPrice = price15Days; allocatedMeals = 30; }); },
                                    selectedColor: BhojnTheme.primaryOrange,
                                    backgroundColor: Colors.white10
                                )
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: ChoiceChip(
                                    label: Text("Monthly (₹$priceMonthly)", style: const TextStyle(fontSize: 12)),
                                    selected: selectedPlanPrice == priceMonthly,
                                    onSelected: (val) { setModalState(() { selectedPlanPrice = priceMonthly; allocatedMeals = 60; }); },
                                    selectedColor: BhojnTheme.primaryOrange,
                                    backgroundColor: Colors.white10
                                )
                            )
                          ]
                      ),
                      const SizedBox(height: 20),

                      const Text("Amount You Paid (₹)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 5),
                      TextField(
                          controller: paidAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          onChanged: (val) => setModalState((){}),
                          decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.currency_rupee, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                          )
                      ),
                      const SizedBox(height: 15),

                      Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: pendingDue > 0 ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Auto-Calculated Dues:", style: TextStyle(color: pendingDue > 0 ? Colors.redAccent : Colors.green, fontWeight: FontWeight.bold)),
                                Text("₹ $pendingDue", style: TextStyle(color: pendingDue > 0 ? Colors.redAccent : Colors.green, fontSize: 18, fontWeight: FontWeight.w900))
                              ]
                          )
                      ),
                      const SizedBox(height: 25),

                      SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if(user != null) {
                                  try {
                                    // 🚀 SPAM BLOCKER
                                    var existingReq = await FirebaseFirestore.instance.collection('join_requests').doc(user.uid).get();

                                    if (existingReq.exists && existingReq.data()?['status'] == 'pending') {
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text("Hold on! ✋ You already have a pending request. Please wait for the owner's response.", style: TextStyle(color: Colors.white)),
                                          backgroundColor: Colors.orange,
                                        ));
                                      }
                                      return;
                                    }

                                    var studentDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                                    String actualStudentName = studentDoc.data()?['name'] ?? user.displayName ?? 'Student';

                                    // 🚀🚀 THE BRAHMASTRA FIX: Direct Firestore instead of RequestService! 🚀🚀
                                    String timeStr = DateFormat('hh:mm a').format(DateTime.now());

                                    Map<String, dynamic> requestPayload = {
                                      'owner_id': messUid,
                                      'mess_id': messUid,
                                      'student_id': user.uid,
                                      'student_uid': user.uid,
                                      'student_name': actualStudentName,
                                      'paid_amount': paidAmount,
                                      'pending_dues': pendingDue,
                                      'total_allotted_meals': allocatedMeals,
                                      'plan_type': allocatedMeals == 30 ? '15 Days' : 'Monthly',
                                      'status': 'pending',
                                      'timestamp': FieldValue.serverTimestamp()
                                    };

                                    // 1. Global Requests DB (Owner Dashboard yahan se padhta hai)
                                    await FirebaseFirestore.instance.collection('join_requests').doc(user.uid).set(requestPayload);

                                    // 2. Sub-collection (Backup)
                                    await FirebaseFirestore.instance.collection('users').doc(messUid).collection('join_requests').doc(user.uid).set(requestPayload);

                                    // 3. Owner's Notification History
                                    await FirebaseFirestore.instance.collection('users').doc(messUid).collection('recent_transactions').add({
                                      'name': actualStudentName,
                                      'uid': user.uid,
                                      'amount': paidAmount,
                                      'type': 'Join Request (${allocatedMeals == 30 ? "15 Days" : "1 Month"})',
                                      'time': timeStr,
                                      'isPending': true,
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });

                                    if (context.mounted) {
                                      Navigator.pop(context); // Request form band
                                      Navigator.pop(context); // View info panel band
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent to Owner! 🚀✅"), backgroundColor: Colors.green));
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
                                    }
                                  }
                                }
                              },
                              child: const Text("SEND REQUEST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          )
                      ),
                      const SizedBox(height: 20),
                    ]
                ),
              );
            }
        )
    );
  }

  void _showMessFullDetails(BuildContext context, Map<String, dynamic> messData, String messUid) {
    String messName = messData['mess_name'] ?? "Bhojn Mess";
    String todayMenu = messData['today_menu'] ?? "Menu not updated for today.";
    String menuTime = messData['menu_updated_at'] ?? "Recently";
    String holiday = messData['weekly_holiday'] ?? "None";
    String contact = messData['mobile'] ?? "Not available";
    String address = messData['address'] ?? "Address not provided";
    List<dynamic> photos = messData['photos'] ?? [];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),

                  Row(
                      children: [
                        const CircleAvatar(radius: 30, backgroundColor: Colors.white10, child: Icon(Icons.restaurant, color: BhojnTheme.primaryOrange, size: 30)),
                        const SizedBox(width: 15),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(messName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                  Text("Weekly Holiday: $holiday", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600))
                                ]
                            )
                        )
                      ]
                  ),
                  const SizedBox(height: 25),

                  const Text("Mess Photos 📸", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  if (photos.isNotEmpty)
                    SizedBox(
                        height: 120,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: const EdgeInsets.all(10),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: InteractiveViewer(child: Image.network(photos[index], fit: BoxFit.contain)),
                                        ),
                                      )
                                  );
                                },
                                child: Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    width: 160,
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(15),
                                        image: DecorationImage(image: NetworkImage(photos[index]), fit: BoxFit.cover)
                                    )
                                ),
                              );
                            }
                        )
                    )
                  else
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: const Center(
                            child: Text("Owner hasn't uploaded any photos yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))
                        )
                    ),
                  const SizedBox(height: 25),

                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Today's Menu 🍲", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Updated: $menuTime", style: const TextStyle(color: Colors.grey, fontSize: 10))
                      ]
                  ),
                  const SizedBox(height: 10),

                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.green.withOpacity(0.3))
                      ),
                      child: Text(todayMenu, style: const TextStyle(color: Colors.green, fontSize: 14))
                  ),
                  const SizedBox(height: 20),

                  const Text("Contact Info", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.phone, color: Colors.grey), title: Text("+91 $contact", style: const TextStyle(color: Colors.white70))),
                  ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on, color: Colors.grey), title: Text(address, style: const TextStyle(color: Colors.white70))),
                  const SizedBox(height: 30),

                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: BhojnTheme.primaryOrange,
                              side: const BorderSide(color: BhojnTheme.primaryOrange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          icon: const Icon(Icons.person_add, color: BhojnTheme.primaryOrange),
                          label: const Text("Request to Join Mess", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: () => _openJoinRequestForm(context, messData, messUid)
                      )
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
              padding: EdgeInsets.only(left: 20, top: 10, bottom: 5),
              child: Text("Explore Messes 🌍", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
          ),

          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                  onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                      hintText: "Search by mess name...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: BhojnTheme.primaryOrange),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0)
                  )
              )
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              children: [
                FilterChip(
                    label: const Text("Open Now", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: showOnlyOpen,
                    selectedColor: Colors.green.withOpacity(0.3),
                    checkmarkColor: Colors.green,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(color: showOnlyOpen ? Colors.green : Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                    onSelected: (bool value) { setState(() { showOnlyOpen = value; }); }
                ),
                const SizedBox(width: 10),
                FilterChip(
                    label: const Text("Within 3 KM", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: showWithin3Km,
                    selectedColor: BhojnTheme.primaryOrange.withOpacity(0.3),
                    checkmarkColor: BhojnTheme.primaryOrange,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(color: showWithin3Km ? BhojnTheme.primaryOrange : Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                    onSelected: (bool value) { setState(() { showWithin3Km = value; }); }
                ),
                const SizedBox(width: 10),
                FilterChip(
                    label: const Text("Top Rated 🌟", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    selected: showHighestRated,
                    selectedColor: Colors.amber.withOpacity(0.3),
                    checkmarkColor: Colors.amber,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: TextStyle(color: showHighestRated ? Colors.amber : Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: BorderSide.none,
                    onSelected: (bool value) { setState(() { showHighestRated = value; }); }
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'owner').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No mess found nearby! 😢", style: TextStyle(color: Colors.grey)));

                var messes = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['is_visible'] == false) return false;

                  bool isOpen = data['is_open'] ?? true;
                  if (showOnlyOpen && !isOpen) return false;

                  double lat = double.tryParse(data['lat']?.toString() ?? '0') ?? 0.0;
                  double lng = double.tryParse(data['lng']?.toString() ?? '0') ?? 0.0;
                  double distance = _calculateDistance(widget.studentLat, widget.studentLng, lat, lng);

                  if (showWithin3Km && (distance > 3.0 || distance == 0.0)) return false;

                  var name = (data['mess_name'] ?? "").toString().toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (messes.isEmpty) return const Center(child: Text("No matches found based on your filters.", style: TextStyle(color: Colors.grey)));

                messes.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;

                  if (showHighestRated) {
                    double ratingA = double.tryParse(dataA['avg_rating']?.toString() ?? '0') ?? 0.0;
                    double ratingB = double.tryParse(dataB['avg_rating']?.toString() ?? '0') ?? 0.0;
                    return ratingB.compareTo(ratingA); // Descending (High to Low)
                  } else {
                    double latA = double.tryParse(dataA['lat']?.toString() ?? '0') ?? 0.0;
                    double lngA = double.tryParse(dataA['lng']?.toString() ?? '0') ?? 0.0;
                    double distA = _calculateDistance(widget.studentLat, widget.studentLng, latA, lngA);

                    double latB = double.tryParse(dataB['lat']?.toString() ?? '0') ?? 0.0;
                    double lngB = double.tryParse(dataB['lng']?.toString() ?? '0') ?? 0.0;
                    double distB = _calculateDistance(widget.studentLat, widget.studentLng, latB, lngB);

                    return distA.compareTo(distB); // Ascending (Nearest First)
                  }
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: messes.length,
                  itemBuilder: (context, index) {
                    var messDoc = messes[index];
                    var messData = messDoc.data() as Map<String, dynamic>;
                    String messName = messData['mess_name'] ?? "Bhojn Mess";
                    String priceThali = messData['price_thali'] ?? "N/A";
                    String priceMonthly = messData['price_monthly'] ?? "N/A";
                    bool isOpen = messData['is_open'] ?? true;

                    double lat = double.tryParse(messData['lat']?.toString() ?? '0') ?? 0.0;
                    double lng = double.tryParse(messData['lng']?.toString() ?? '0') ?? 0.0;
                    double dist = _calculateDistance(widget.studentLat, widget.studentLng, lat, lng);
                    String distanceStr = dist > 0 ? "${dist.toStringAsFixed(1)} KM" : "Distance Unknown";

                    return Card(
                        color: Colors.white.withOpacity(0.05),
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                              iconColor: BhojnTheme.primaryOrange,
                              collapsedIconColor: Colors.grey,
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(messName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
                                  Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                          children: [
                                            const Icon(Icons.near_me, size: 10, color: BhojnTheme.primaryOrange),
                                            const SizedBox(width: 4),
                                            Text(distanceStr, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))
                                          ]
                                      )
                                  )
                                ],
                              ),
                              subtitle: Text(isOpen ? "Status: OPEN" : "Status: CLOSED", style: TextStyle(color: isOpen ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(left: 15, right: 15, bottom: 15),
                                    child: Column(
                                        children: [
                                          Row(
                                              children: [
                                                const Icon(Icons.location_on, color: Colors.grey, size: 16),
                                                const SizedBox(width: 5),
                                                Expanded(child: Text("Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}", style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                                IconButton(
                                                    icon: const Icon(Icons.copy, color: BhojnTheme.primaryOrange, size: 16),
                                                    tooltip: "Copy Coordinates",
                                                    onPressed: () {
                                                      Clipboard.setData(ClipboardData(text: "$lat, $lng"));
                                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Coordinates Copied! 📋"), backgroundColor: Colors.green));
                                                    }
                                                )
                                              ]
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                _rateBox("Thali", "₹$priceThali"),
                                                _rateBox("Monthly", "₹$priceMonthly")
                                              ]
                                          ),
                                          const SizedBox(height: 15),
                                          SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange.withOpacity(0.2), foregroundColor: BhojnTheme.primaryOrange, elevation: 0),
                                                  onPressed: () => _showMessFullDetails(context, messData, messDoc.id),
                                                  child: const Text("View More Info")
                                              )
                                          )
                                        ]
                                    )
                                )
                              ]
                          ),
                        )
                    );
                  },
                );
              },
            ),
          ),
        ]
    );
  }

  Widget _rateBox(String title, String price) {
    return Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(price, style: const TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold))
        ]
    );
  }
}

// ============================================================================
// 🏢 3. HOSTELS TAB
// ============================================================================
class _HostelsTab extends StatelessWidget {
  const _HostelsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Coming Soon", style: TextStyle(color: Colors.grey)));
  }
}

// ============================================================================
// 👤 4. ME TAB
// ============================================================================
class _MeTab extends StatefulWidget {
  final List<String> activeMesses;
  final Map<String, dynamic> studentData;
  final AuthService auth;
  final String uid;

  const _MeTab({
    required this.activeMesses,
    required this.studentData,
    required this.auth,
    required this.uid
  });

  @override
  State<_MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<_MeTab> {
  String? selectedHistoryMessId;

  @override
  void initState() {
    super.initState();
    if (widget.activeMesses.isNotEmpty) {
      selectedHistoryMessId = widget.activeMesses.first;
    }
  }

  // 🚀 NAYA FUNCTION: Help & Feedback Bottom Sheet
  void _showHelpBottomSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Help & Support 🎧", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("App me koi dikkat aa rahi hai? Humse direct connect karo!", style: TextStyle(color: Colors.grey, fontSize: 14), textAlign: TextAlign.center),
                const SizedBox(height: 25),

                // WhatsApp Button
                ListTile(
                  onTap: () async {
                    final Uri url = Uri.parse('https://wa.me/919011082875?text=Hello%20BHOJN%20Support,%20I%20need%20help');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("WhatsApp open nahi ho paya!")));
                    }
                  },
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: const Icon(Icons.chat, color: Colors.greenAccent),
                  title: const Text("Message on WhatsApp", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("+91 9011082875", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 16),
                ),
                const SizedBox(height: 15),

                // Email Button
                ListTile(
                  onTap: () async {
                    final Uri url = Uri.parse('mailto:bhojn.support@gmail.com?subject=BHOJN App Support Needed');
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email app open nahi ho paya!")));
                    }
                  },
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: const Icon(Icons.email, color: BhojnTheme.primaryOrange),
                  title: const Text("Send an Email", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("bhojn.support@gmail.com", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 16),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        }
    );
  }

  void _showAttendanceHistory(BuildContext context) {
    String validMessId = selectedHistoryMessId ?? "unknown";

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: BhojnTheme.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return DraggableScrollableSheet(
                    initialChildSize: 0.8,
                    minChildSize: 0.5,
                    maxChildSize: 0.95,
                    expand: false,
                    builder: (_, controller) {
                      return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(validMessId).snapshots(),
                          builder: (context, messSnap) {
                            String mName = "Loading...";
                            if (messSnap.hasData && messSnap.data != null && messSnap.data!.exists) {
                              var mData = messSnap.data!.data() as Map<String, dynamic>?;
                              mName = mData?['mess_name'] ?? "Mess";
                            }

                            return Column(
                                children: [
                                  const SizedBox(height: 15),
                                  Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                                  const SizedBox(height: 20),

                                  Text("Attendance: $mName 🍛", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),

                                  if (widget.activeMesses.length > 1)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                                children: widget.activeMesses.map((mId) {
                                                  int idx = widget.activeMesses.indexOf(mId) + 1;
                                                  bool isSel = mId == selectedHistoryMessId;
                                                  return Padding(
                                                      padding: const EdgeInsets.only(right: 10),
                                                      child: ChoiceChip(
                                                          label: Text("Pass $idx", style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontWeight: FontWeight.bold)),
                                                          selected: isSel,
                                                          selectedColor: BhojnTheme.primaryOrange,
                                                          backgroundColor: Colors.white.withOpacity(0.05),
                                                          onSelected: (val) {
                                                            if (val) setModalState(() { selectedHistoryMessId = mId; validMessId = mId; });
                                                          }
                                                      )
                                                  );
                                                }).toList()
                                            )
                                        )
                                    ),

                                  const SizedBox(height: 10),

                                  Expanded(
                                    child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).collection('my_transactions').orderBy('timestamp', descending: true).snapshots(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange));
                                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No meal history found.", style: TextStyle(color: Colors.grey)));

                                          var docs = snapshot.data!.docs.where((doc) {
                                            var data = doc.data() as Map<String, dynamic>;
                                            return data['mess_name'] == mName || data['mess_id'] == selectedHistoryMessId;
                                          }).toList();

                                          if (docs.isEmpty) return const Center(child: Text("No history for this mess.", style: TextStyle(color: Colors.grey)));

                                          Map<String, List<Map<String, dynamic>>> groupedData = {};
                                          for(var d in docs) {
                                            var map = d.data() as Map<String, dynamic>;
                                            DateTime dt = map['timestamp'] != null ? (map['timestamp'] as Timestamp).toDate() : DateTime.now();
                                            String dateKey = DateFormat('dd MMM yyyy').format(dt);
                                            if(!groupedData.containsKey(dateKey)) groupedData[dateKey] = [];
                                            groupedData[dateKey]!.add(map);
                                          }

                                          return ListView.builder(
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
                                                      padding: const EdgeInsets.only(top: 25, bottom: 15),
                                                      child: Row(
                                                          children: [
                                                            Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                                decoration: BoxDecoration(color: BhojnTheme.primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: BhojnTheme.primaryOrange.withOpacity(0.3))),
                                                                child: Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      const Icon(Icons.calendar_month, size: 14, color: BhojnTheme.primaryOrange),
                                                                      const SizedBox(width: 8),
                                                                      Text(dateKey, style: const TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 13))
                                                                    ]
                                                                )
                                                            ),
                                                            const Expanded(child: Divider(color: Colors.white10, indent: 15))
                                                          ]
                                                      )
                                                  ),

                                                  ...items.map((doc) {
                                                    String type = doc['type'] ?? "Attendance";
                                                    String time = doc['time'] ?? "--:--";
                                                    int amt = doc['amount'] ?? 0;
                                                    bool isPending = doc['isPending'] ?? false;
                                                    String statusStr = isPending ? "(Pending Verify)" : "Confirmed";

                                                    if (type.contains("Join") && widget.activeMesses.contains(selectedHistoryMessId)) {
                                                      isPending = false;
                                                      statusStr = "Confirmed ✅";
                                                    }

                                                    return Container(
                                                        margin: const EdgeInsets.only(bottom: 10),
                                                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                                                        child: ListTile(
                                                            leading: CircleAvatar(
                                                                backgroundColor: isPending ? Colors.orange.withOpacity(0.2) : (amt > 0 ? Colors.blue.withOpacity(0.2) : Colors.green.withOpacity(0.2)),
                                                                child: Icon(isPending ? Icons.access_time : (amt > 0 ? Icons.payment : Icons.check), color: isPending ? Colors.orange : (amt > 0 ? Colors.blue : Colors.green))
                                                            ),
                                                            title: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                            subtitle: Text("$mName • $time\nStatus: $statusStr", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                                            trailing: amt > 0 ? Text("₹$amt", style: const TextStyle(color: BhojnTheme.primaryOrange, fontWeight: FontWeight.bold, fontSize: 16)) : const Text("Scanned", style: TextStyle(color: Colors.green, fontSize: 12))
                                                        )
                                                    );
                                                  })
                                                ],
                                              );
                                            },
                                          );
                                        }
                                    ),
                                  )
                                ]
                            );
                          }
                      );
                    }
                );
              }
          );
        }
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            backgroundColor: BhojnTheme.surfaceCard,
            title: const Text("Logout?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: const Text("Are you sure you want to logout of your account?", style: TextStyle(color: Colors.grey)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: BhojnTheme.primaryOrange),
                  onPressed: () { Navigator.pop(context); widget.auth.logout(); },
                  child: const Text("Yes, Logout", style: TextStyle(color: Colors.white))
              )
            ]
        )
    );
  }

  void _confirmDeleteProfile(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: BhojnTheme.surfaceCard,
          title: const Text("Delete Profile? ⚠️", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: const Text("For security reasons, only authenticated owners of this account can delete it. This will permanently erase your history and passes from our secure cloud.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  Navigator.pop(context);
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Security Check: Session expired. Please log out and log in again to verify your identity before deleting! 🔒"), backgroundColor: Colors.orange, duration: Duration(seconds: 4)));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
                    }
                  } catch(e) {
                    if (context.mounted) Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred while deleting.")));
                  }
                },
                child: const Text("Verify & Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    String fullName = widget.studentData['name'] ?? "Bhojni Student";
    String email = widget.studentData['email'] ?? "No Email";
    String mobile = widget.studentData['mobile'] ?? "No Mobile";

    // 🚀 THE FIX: Yahan '?? true' ko '?? false' kar diya. Ab default OFF rahega!
    bool chutkuleOn = widget.studentData['is_chutkula_on'] ?? false;

    return SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 80),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                  children: [
                    const CircleAvatar(radius: 40, backgroundColor: Colors.white10, child: Icon(Icons.person, size: 40, color: Colors.white)),
                    const SizedBox(width: 20),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 5),
                              Text(email, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              Text("+91 $mobile", style: const TextStyle(color: BhojnTheme.primaryOrange, fontSize: 12))
                            ]
                        )
                    )
                  ]
              ),
              const SizedBox(height: 30),

              const Text("My Food Journey 🍛", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),

              ListTile(
                  onTap: () => _showAttendanceHistory(context),
                  tileColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  leading: const Icon(Icons.history, color: BhojnTheme.primaryOrange),
                  title: const Text("Full Attendance History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text("View daily scans and payments", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
              ),
              const SizedBox(height: 30),

              const Text("Settings ⚙️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 15),

              Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                  child: Column(
                      children: [
                        SwitchListTile(
                            activeColor: BhojnTheme.primaryOrange,
                            title: const Text("Daily Chutkule 🤣", style: TextStyle(color: Colors.white)),
                            subtitle: const Text("Funny tone and jokes popups", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            value: chutkuleOn,
                            onChanged: (val) {
                              FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'is_chutkula_on': val});
                            }
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: const Icon(Icons.help_outline, color: Colors.white70),
                          title: const Text("Help & Feedback", style: TextStyle(color: Colors.white)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          // 🚀 THE FIX: Bottom sheet function connect kar diya!
                          onTap: () => _showHelpBottomSheet(context),
                        )
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
                            onTap: () => _confirmLogout(context),
                            leading: const Icon(Icons.logout, color: Colors.white),
                            title: const Text("Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                            onTap: () => _confirmDeleteProfile(context),
                            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                            title: const Text("Delete Profile", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                        )
                      ]
                  )
              )
            ]
        )
    );
  }
}

// ============================================================================
// 👋 HELPER: WAVING HAND ANIMATION
// ============================================================================
class _WavingHand extends StatefulWidget {
  const _WavingHand({super.key});

  @override
  State<_WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<_WavingHand> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _animation = Tween<double>(begin: -0.05, end: 0.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
        turns: _animation,
        child: const Text("👋", style: TextStyle(fontSize: 18))
    );
  }
}
