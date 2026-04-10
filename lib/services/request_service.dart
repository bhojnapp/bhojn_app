import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  // Firebase ka instance ek hi baar bana lo taaki baar baar na likhna pade
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================================
  // 🎓 STUDENT SIDE: Join Request Bhejna
  // ==========================================
  Future<void> sendJoinRequest({
    required String studentUid,
    required String studentName,
    required String messId,
    required String ownerUid,
    required int paidAmount,
    required int pendingDues,
    required int allocatedMeals,
  }) async {
    try {
      await _db.collection('join_requests').add({
        'student_id': studentUid,
        'student_name': studentName,
        'mess_id': messId,
        'owner_id': ownerUid, // Tere structure me messId hi ownerUid hai
        'paid_amount': paidAmount,
        'pending_dues': pendingDues,
        'total_allotted_meals': allocatedMeals,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),});
      print("✅ Request mast chali gayi inbox me!");
    } catch (e) {
      print("🚨 Request fail ho gayi bhai: $e");
    }
  }

  // ==========================================
  // 👑 OWNER SIDE: Request ACCEPT Karna
  // ==========================================
  Future<void> acceptRequest({
    required String requestId,
    required String studentId,
    required String studentName, // 🚀 NAYA: Student ka naam
    required String ownerId,
    required int totalMeals,
    required int pendingDues,
    required int paidAmount,     // 🚀 NAYA: Jo paisa diya hai
    required String timeStr,     // 🚀 NAYA: Time
  }) async {
    try {
      WriteBatch batch = _db.batch();

      // 1. Chitthi ko 'accepted' mark karo
      DocumentReference requestRef = _db.collection('join_requests').doc(requestId);
      batch.update(requestRef, {'status': 'accepted'});

      // 2. Student ki kundali me Mess ID add karo
      DocumentReference studentRef = _db.collection('users').doc(studentId);
      batch.update(studentRef, {
        'active_messes': FieldValue.arrayUnion([ownerId]),
        'mess_data.$ownerId': {
          'total_allotted_meals': totalMeals,
          'remaining_meals': totalMeals,
          'pending_dues': pendingDues,
        }
      });

      // 3. Owner ke register me student add karo
      DocumentReference enrolledRef = _db.collection('users').doc(ownerId).collection('enrolled_students').doc(studentId);
      batch.set(enrolledRef, {
        'student_id': studentId,
        'joined_at': FieldValue.serverTimestamp(),
        'status': 'active'
      });

      // 🚀 4. NAYA KAAM: Agar student ne paise diye hain, toh uski Raseed (Transaction) kaato!
      // Isse tere Analytics me turant paise dikhne lagenge.
      if (paidAmount > 0) {
        DocumentReference txnRef = _db.collection('users').doc(ownerId).collection('recent_transactions').doc();
        batch.set(txnRef, {
          'uid': studentId,
          'name': studentName,
          'amount': paidAmount,
          'type': 'Plan Join Payment',
          'time': timeStr,
          'isPending': false, // Kyunki owner ne khud accept kiya hai
          'timestamp': FieldValue.serverTimestamp()
        });
      }

      await batch.commit();
      print("✅ BOOM! Student add aur Raseed katt gayi!");

    } catch (e) {
      print("🚨 Accept karne me error: $e");
      throw e;
    }
  }

  // ==========================================
  // 👑 OWNER SIDE: Request REJECT Karna
  // ==========================================
  Future<void> rejectRequest(String requestId) async {
    try {
      await _db.collection('join_requests').doc(requestId).update(
          {'status': 'rejected'});
      print("❌ Request reject kar di gayi.");
    } catch (e) {
      print("🚨 Reject me error: $e");
    }
  }
}