import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  // ==========================================
  // 🔑 LOGIN FUNCTION
  // ==========================================
  Future<UserCredential> login(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
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

      // 2. Update Display Name with Role (taaki AuthWrapper samajh sake owner hai ya student)
      await cred.user!.updateDisplayName(role);

      // 3. Prepare data for Firestore
      Map<String, dynamic> userData = {
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Merge extraData (Location, Name, Mobile, etc.)
      userData.addAll(extraData);

      // 4. Save to Firestore
      await _firestore.collection('users').doc(cred.user!.uid).set(userData);

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
      // Sirf Firebase se logout (Kyunki Email/Password use ho raha hai)
      await FirebaseAuth.instance.signOut();
      print("✅ Successfully Logged Out from Firebase!");
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