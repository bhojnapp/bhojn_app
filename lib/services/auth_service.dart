import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  // ==========================================
  // 🔔 FCM TOKEN MANAGER (BUG FIXED)
  // ==========================================
  Future<void> _updateFCMToken(String uid, {bool isLogout = false}) async {
    try {
      if (isLogout) {
        // 1. Database se purana token uda do
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
        print("🗑️ FCM Token Deleted from Firestore for user: $uid");

        // 2. 🚀 THE BRAHMASTRA: Phone/App se hi token hamesha ke liye Nuke kar do!
        // Isse agle user ko kisi aur ka message nahi aayega.
        await FirebaseMessaging.instance.deleteToken();
        print("💥 Device FCM Token Nuked!");

      } else {
        // Login/Register ke time ekdum NAYA token generate karke save karo
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).update({
            'fcmToken': token,
          });
          print("✅ New FCM Token Saved: $token");
        }
      }
    } catch (e) {
      print("🚨 FCM Token Error: $e");
    }
  }

  // ==========================================
  // 🔑 LOGIN FUNCTION
  // ==========================================
  Future<UserCredential> login(String email, String password) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      // 🚀 Naya Token Save Karo
      await _updateFCMToken(cred.user!.uid);

      return cred;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ==========================================
  // 📝 REGISTER FUNCTION
  // ==========================================
  Future<UserCredential> register({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> extraData,
  }) async {
    try {
      // 1. Create User in Firebase Auth
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);

      // 2. Update Display Name with Role
      await cred.user!.updateDisplayName(role);

      // 3. Prepare data for Firestore
      Map<String, dynamic> userData = {
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Merge extraData
      userData.addAll(extraData);

      // 4. Save to Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set(userData);

      // 🚀 Naya User bante hi uska pehla Token Save Karo
      await _updateFCMToken(cred.user!.uid);

      return cred;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ==========================================
  // 🚪 SIMPLE FIREBASE LOGOUT
  // ==========================================
  Future<void> logout() async {
    try {
      // 🚀 STEP 1: Firebase se bahar nikalne se PEHLE token destroy karna zaroori hai
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _updateFCMToken(uid, isLogout: true);
      }

      // 🚀 STEP 2: Ab aaram se sign out karo
      await FirebaseAuth.instance.signOut();
      print("✅ Successfully Logged Out from Firebase & Session Cleared!");
    } catch (e) {
      print("🚨 Logout Error: $e");
    }
  }

  // ==========================================
  // 🛡️ ERROR HANDLER
  // ==========================================
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found': return 'Koi account nahi mila is email se.';
        case 'wrong-password': return 'Password galat hai Boss!';
        case 'email-already-in-use': return 'Ye email pehle se registered hai.';
        case 'weak-password': return 'Password thoda strong rakho (min 6 chars).';
        default: return e.message ?? 'Kuch toh gadbad hai.';
      }
    }
    return e.toString();
  }
}