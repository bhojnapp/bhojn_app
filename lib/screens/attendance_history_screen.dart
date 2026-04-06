import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: BhojnTheme.darkBg,
      appBar: AppBar(
        title: const Text("Mera Hisaab 📋", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🔥 Logic: Student ke 'Dates' collection se saara data uthao
        stream: FirebaseFirestore.instance
            .collection('Attendance')
            .doc(user!.uid)
            .collection('Dates')
            .orderBy('timestamp', descending: true) // Latest date sabse upar
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: BhojnTheme.primaryOrange));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 15),
                  const Text("Abhi tak koi attendance nahi hai!", style: TextStyle(color: Colors.grey)),
                  const Text("Khana khao, scan karo! 🍽️", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              String dateStr = snapshot.data!.docs[index].id; // Document ID hi date hai

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.check, color: Colors.white),
                  ),
                  title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  subtitle: const Text("Status: Khana Kha Liya 🥗", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                ),
              );
            },
          );
        },
      ),
    );
  }
}