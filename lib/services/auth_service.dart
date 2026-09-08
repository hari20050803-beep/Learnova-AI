import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user_profile.dart';
import '../utils/dev_log.dart';

/// Thrown by [AuthService] with a message that is safe to show to the user.
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

/// ---------------------------------------------------------------------------
/// AUTH SERVICE
/// All Firebase Authentication + Firestore user-profile logic lives here,
/// so the screens stay clean and only deal with UI.
/// ---------------------------------------------------------------------------
class AuthService {
  AuthService._();

  /// Single shared instance used by all screens.
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// The currently signed-in user (null if nobody is signed in).
  User? get currentUser => _auth.currentUser;

  /// Avatar bytes for the signed-in user, held in memory so every screen can
  /// paint the photo without touching the disk on each build.
  ///
  /// The bytes are also written to the application's own directory by
  /// [saveAvatar] and read back by [loadLocalAvatar] at sign-in, so the photo
  /// survives a restart. Cloud Storage would need the paid Blaze plan; the
  /// device holds the file instead, which means the photo does not follow the
  /// account to another device.
  Uint8List? localAvatarBytes;

  /// Registers a new student account and saves their profile to Firestore.
  ///
  /// Steps:
  ///   1. Create the account in Firebase Authentication.
  ///   2. Save the profile in the "users" collection (doc id = uid).
  ///   3. Sign out, so the user logs in from the Login screen.
  ///
  /// Throws [AuthException] with a friendly message if anything fails.
  Future<void> register({
    required String fullName,
    required String email,
    required String password,
    String gender = '',
    String address = '',
    String university = '',
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = credential.user;
      if (user == null) {
        throw AuthException('Registration failed. Please try again.');
      }

      // Store the name on the auth profile too (useful later).
      await user.updateDisplayName(fullName);

      // Save the user profile in Firestore. The password is NEVER stored
      // here — Firebase Authentication manages it.
      final profile = UserProfile(
        uid: user.uid,
        fullName: fullName,
        email: email,
        gender: gender,
        address: address,
        university: university,
      );
      await _firestore.collection('users').doc(user.uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // The app flow goes back to the Login screen after registering,
      // so end this session cleanly.
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } on FirebaseException catch (e) {
      // Firestore errors (e.g. security rules blocking the write).
      throw AuthException(
        'Account created, but saving the profile failed: ${e.message}',
      );
    } catch (e) {
      throw AuthException('Could not complete registration. ($e)');
    }
  }

  /// Signs in an existing user.
  /// (Ready for the Login screen — the next integration step.)
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      // Anything that is not an auth error (plugin/platform failure, bad
      // Firebase setup, ...). Reported separately so it is never mistaken
      // for "no internet" or "wrong password".
      throw AuthException('Could not sign in right now. ($e)');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() {
    localAvatarBytes = null; // don't leak one user's photo into the next login
    return _auth.signOut();
  }

  // ---------------------------------------------------------------------
  // PROFILE (users/{uid}) — used by the Profile / Settings screen
  // ---------------------------------------------------------------------

  /// Loads the current user's profile. Falls back to the FirebaseAuth
  /// account info (display name, email, account-created date) when a field
  /// is missing from Firestore.
  Future<UserProfile> loadProfile() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw AuthException('You are not logged in. Please login again.');
    }
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      // fromMap defaults every missing field, so accounts created before
      // gender/address existed still load correctly.
      return UserProfile.fromMap(
        doc.data(),
        uid: user.uid,
        fallbackName: user.displayName ?? '',
        fallbackEmail: user.email ?? '',
        fallbackCreatedAt: user.metadata.creationTime,
      );
    } on FirebaseException catch (e) {
      throw AuthException('Could not load your profile: ${e.message}');
    }
  }

  /// Saves the editable profile fields to Firestore (merge, so existing
  /// fields like email/createdAt are kept). Also updates the auth display name.
  Future<void> updateProfile({
    required String fullName,
    String course = '',
    String university = '',
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw AuthException('You are not logged in. Please login again.');
    }
    try {
      await user.updateDisplayName(fullName);
      await _firestore.collection('users').doc(user.uid).set({
        'fullName': fullName,
        'course': course,
        'university': university,
      }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw AuthException('Could not save your profile: ${e.message}');
    }
  }

  /// Path of the avatar file belonging to [uid].
  Future<File> _avatarFile(String uid) async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory(
      '${base.path}${Platform.pathSeparator}profile',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}${Platform.pathSeparator}${uid}_avatar.jpg');
  }

  /// Saves the chosen avatar on this device and shows it straight away.
  ///
  /// Throws [AuthException] only when the file cannot be written; a failure
  /// here does not stop the rest of the profile from being saved.
  Future<void> saveAvatar(Uint8List bytes) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      throw AuthException('You are not logged in. Please login again.');
    }
    try {
      final File file = await _avatarFile(user.uid);
      await file.writeAsBytes(bytes, flush: true);
      localAvatarBytes = bytes;
    } on FileSystemException catch (e) {
      throw AuthException('Could not save the photo: ${e.message}');
    }
  }

  /// Reads the saved avatar back into [localAvatarBytes].
  ///
  /// Called after sign-in and at start-up. Silent on failure: a missing photo
  /// is normal, and the initials avatar is drawn instead.
  Future<void> loadLocalAvatar() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      localAvatarBytes = null;
      return;
    }
    try {
      final File file = await _avatarFile(user.uid);
      localAvatarBytes = await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      localAvatarBytes = null;
    }
  }

  /// Sends a password-reset email to the signed-in user's address.
  /// Used by the Profile / Settings "Change Password" action.
  Future<void> sendPasswordResetEmail() async {
    final String? email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw AuthException('No email is linked to this account.');
    }
    await sendPasswordResetTo(email);
  }

  /// True when [password] is ALREADY this account's password.
  ///
  /// During Forgot Password the app never holds the old password — Firebase
  /// stores only a salted hash and offers no way to read or compare it. The
  /// only reliable client-side test is to try signing in with the candidate
  /// password: if that succeeds, it is the current password.
  ///
  /// Safe to do here because the emailed OTP has already proven the person
  /// owns this address. Any session opened by the probe is closed again
  /// immediately, so the user is never left silently signed in.
  Future<bool> isCurrentPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Signing in worked -> same password. Undo the session right away.
      await _auth.signOut();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        // Expected when the password is different — exactly what we want.
        case 'wrong-password':
        case 'invalid-credential':
        case 'user-not-found':
          return false;
        default:
          throw AuthException(_friendlyAuthMessage(e));
      }
    } catch (e) {
      throw AuthException('Could not verify the password. ($e)');
    }
  }

  /// Finishes the custom Forgot Password flow after the emailed OTP has been
  /// verified.
  ///
  /// IMPORTANT — why this does not write the password directly:
  /// FirebaseAuth can only change a password for a user that is CURRENTLY
  /// SIGNED IN (`User.updatePassword`). At this point in the flow nobody is
  /// signed in — we only know an email address and that a code matched. The
  /// client SDK has no API to set a password for an arbitrary address; that
  /// exists only in the Admin SDK, whose service-account key must never ship
  /// inside an app.
  ///
  /// So this sends Firebase's own reset email, which is the only client-side
  /// way to actually change the password today.
  ///
  /// TO MAKE THE RESET FULLY IN-APP: deploy a Cloud Function that takes the
  /// verified email + new password and calls
  /// `admin.auth().updateUser(uid, {password})`, then replace the body of
  /// this method with an https call to it. Nothing else in the app changes.
  Future<void> completePasswordReset({
    required String email,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;

    // Signed in as this same account (e.g. changing the password from
    // Settings): the client SDK can do it directly, no server needed.
    if (user != null &&
        (user.email ?? '').toLowerCase() == email.trim().toLowerCase()) {
      try {
        await user.updatePassword(newPassword);
        return;
      } on FirebaseAuthException catch (e) {
        throw AuthException(_friendlyAuthMessage(e));
      }
    }

    // Signed out: the password can only be set with the oobCode from
    // Firebase's reset email — see [applyPasswordReset].
    throw AuthException(
      'Open the reset link we emailed you to set a new password.',
    );
  }

  /// Checks a Firebase password-reset code and returns the email it belongs
  /// to, so the Reset Password screen can show the address.
  ///
  /// [oobCode] comes from the link in Firebase's reset email.
  Future<String> verifyPasswordResetCode(String oobCode) async {
    try {
      final String email = await _auth.verifyPasswordResetCode(oobCode);
      devLog('[Reset] verifyPasswordResetCode success — email=$email');
      return email;
    } on FirebaseAuthException catch (e) {
      devLog('[Reset] verifyPasswordResetCode FAILED code=${e.code}');
      throw AuthException(_friendlyResetCodeMessage(e));
    } catch (e) {
      devLog('[Reset] verifyPasswordResetCode FAILED: $e');
      throw AuthException('Could not check the reset link. ($e)');
    }
  }

  /// Sets the new password using the code from Firebase's reset email.
  ///
  /// This is the real password change and it works while SIGNED OUT. It is
  /// part of the free client SDK — no Admin SDK, no Cloud Function, no Blaze.
  /// Once it succeeds the old password stops working immediately.
  Future<void> applyPasswordReset({
    required String oobCode,
    required String newPassword,
  }) async {
    try {
      devLog(
        '[Reset] calling confirmPasswordReset — oobCode len=${oobCode.length}',
      );
      await _auth.confirmPasswordReset(code: oobCode, newPassword: newPassword);
      devLog('[Reset] confirmPasswordReset success');
    } on FirebaseAuthException catch (e) {
      devLog(
        '[Reset] confirmPasswordReset FAILED code=${e.code} msg=${e.message}',
      );
      throw AuthException(_friendlyResetCodeMessage(e));
    } catch (e) {
      devLog('[Reset] confirmPasswordReset FAILED: $e');
      throw AuthException('Could not update the password. ($e)');
    }
  }

  /// Friendly text for the reset-code specific error codes.
  String _friendlyResetCodeMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'expired-action-code':
        return 'This reset link has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'This reset link is invalid or has already been used. '
            'Please request a new one.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account was found for this reset link.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger one.';
      default:
        return e.message ?? 'Could not reset the password. Please try again.';
    }
  }

  /// Sends a password-reset email to any address. Used by the Forgot Password
  /// screen, where nobody is signed in yet.
  Future<void> sendPasswordResetTo(String email) async {
    devLog('[Reset] Sending Firebase reset email to: $email');
    try {
      await _auth.sendPasswordResetEmail(email: email);
      devLog('[Reset] Firebase reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      devLog('[Reset] Firebase reset email failed:');
      devLog('[Reset]   error code: ${e.code}');
      devLog('[Reset]   message: ${e.message}');
      throw AuthException(_friendlyAuthMessage(e));
    } catch (e) {
      devLog('[Reset] Firebase reset email failed:');
      devLog('[Reset]   error code: (non-Firebase)');
      devLog('[Reset]   message: $e');
      throw AuthException('Could not send the reset email. ($e)');
    }
  }

  /// Converts Firebase error codes into messages users can understand.
  String _friendlyAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please login instead.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in the Firebase Console.';
      case 'network-request-failed':
        // Also fires when the device is online but cannot resolve Google's
        // hosts (broken DNS) — common on an emulator after the PC sleeps.
        return 'Could not reach the server. Check your internet connection '
            'and try again.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
