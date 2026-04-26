import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream to listen to auth state changes
  Stream<User?> get userStream => _auth.authStateChanges();

  // ==========================================
  // 🔔 FCM TOKEN MANAGER
  // ==========================================
  Future<void> _updateFCMToken(String uid, {bool isLogout = false}) async {
    try {
      if (isLogout) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': FieldValue.delete(),
        });
        print("🗑️ FCM Token Deleted from Firestore for user: $uid");
        await FirebaseMessaging.instance.deleteToken();
        print("💥 Device FCM Token Nuked!");
      } else {
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
  // 🔑 LOGIN FUNCTION (VIP BOUNCER ADDED)
  // ==========================================
  // 🚀 NAYA: expectedRole parameter add kiya hai!
  Future<UserCredential> login(String email, String password, String expectedRole) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

      // 🕵️‍♂️ THE VIP BOUNCER: Check Role
      // Pehle displayName se check karte hain (Kyunki humne signup ke time yahi save kiya tha)
      String? actualRole = cred.user!.displayName;

      // Agar kisi purane user ka displayName null hai, toh Firestore database se backup check karo
      if (actualRole == null || actualRole.isEmpty) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(cred.user!.uid).get();
        if (doc.exists && doc.data() != null) {
          actualRole = (doc.data() as Map<String, dynamic>)['role'];
          // Future ke liye displayName update maar do
          if (actualRole != null) {
            await cred.user!.updateDisplayName(actualRole);
          }
        }
      }

      // 🛑 STRICT FILTER: Role Match Check
      if (actualRole != expectedRole) {
        // Bhai pakda gaya! Isko turant bahar phek do
        await FirebaseAuth.instance.signOut();
        // Error message throw karo jo UI pe dikhega
        throw Exception('Aap $actualRole hai, $expectedRole ke login me kya kar rahe ho? Sahi option chuno! 😂');
      }

      // Agar verify ho chuka hai aur role sahi hai, tabhi notification token save karo
      if (cred.user!.emailVerified) {
        await _updateFCMToken(cred.user!.uid);
      }
      return cred;
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // ==========================================
  // 📝 REGISTER FUNCTION (SMART INTERCEPT LOGIC)
  // ==========================================
  Future<UserCredential> register({
    required String email,
    required String password,
    required String role,
    required Map<String, dynamic> extraData,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _setupUserInFirestore(cred, role, extraData, email);
      return cred;

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          UserCredential cred = await _auth.signInWithEmailAndPassword(email: email, password: password);

          if (!cred.user!.emailVerified) {
            print("🔄 Recovering unverified zombie account...");
            await _setupUserInFirestore(cred, role, extraData, email, isUpdate: true);
            return cred;
          } else {
            throw Exception('Ye email pehle se verified aur registered hai. Seedha Login karo!');
          }
        } catch (loginError) {
          throw Exception('Ye account pehle se bana hua hai! Agar password yaad nahi toh Login page pe jaake "Forgot Password" karo.');
        }
      }
      throw Exception(_handleAuthError(e));
    } catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  // 🛠️ Helper Function
  Future<void> _setupUserInFirestore(UserCredential cred, String role, Map<String, dynamic> extraData, String email, {bool isUpdate = false}) async {
    await cred.user!.updateDisplayName(role);

    Map<String, dynamic> userData = {
      'email': email,
      'role': role,
    };

    if (!isUpdate) {
      userData['createdAt'] = FieldValue.serverTimestamp();
    }

    userData.addAll(extraData);

    await _firestore.collection('users').doc(cred.user!.uid).set(userData, SetOptions(merge: true));

    if (!cred.user!.emailVerified) {
      // 🚀 THE FIX: Firebase ko 1 second (1000ms) ka aaram do taaki backend me data set ho jaye
      await Future.delayed(const Duration(seconds: 1));
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      print("✅ Automatic Verification Email Sent Successfully!");
    }
  }

  // ==========================================
  // 🚪 SIMPLE FIREBASE LOGOUT
  // ==========================================
  Future<void> logout() async {
    try {
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _updateFCMToken(uid, isLogout: true);
      }
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
        case 'email-not-verified': return e.message ?? 'Email verify karna padega.';
        default: return e.message ?? 'Kuch toh gadbad hai.';
      }
    }
    return e.toString();
  }
}