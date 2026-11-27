import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthResult {
  final String idToken;
  final String email;
  final String displayName;
  final String photoUrl;

  const GoogleAuthResult({
    required this.idToken,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });
}

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Initiates interactive Google Sign-In and exchanges credentials with Firebase Auth
  /// to obtain a cryptographically signed Firebase ID token.
  static Future<GoogleAuthResult?> signInWithGoogle() async {
    try {
      // Disconnect/sign out any previously cached account so user can pick account
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User aborted the sign-in modal/picker
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) return null;

      final String? idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return null;

      return GoogleAuthResult(
        idToken: idToken,
        email: user.email ?? googleUser.email,
        displayName: user.displayName ?? googleUser.displayName ?? '',
        photoUrl: user.photoURL ?? googleUser.photoUrl ?? '',
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Sign-in error: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
