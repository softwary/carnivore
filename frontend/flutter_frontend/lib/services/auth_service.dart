// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  Future<void> loginAnonymously() async {
    print('trying to login anonly');
    try {
      await FirebaseAuth.instance.signInAnonymously();
      print('Logged in anonymously');
    } catch (e) {
      print('Failed to login anonymously: $e');
    }
  }

Future<void> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
          clientId: '133326456900-lr78e4hjq0tg6c33fbapaueqi19vltff.apps.googleusercontent.com',
          ); // Use GoogleSignIn for web
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      print('Logged in with Google');
    } catch (e) {
      print('Failed to login with Google: $e');
    }
  }
  // Add the logout method
  Future<void> logout() async {
    print('trying to logout');
    try {
      await FirebaseAuth.instance.signOut();
      print('Logged out');
    } catch (e) {
      print('Failed to logout: $e');
    }
  }
}