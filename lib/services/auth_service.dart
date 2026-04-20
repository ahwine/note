import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(name);

    await _firestore.collection('users').doc(credential.user!.uid).set({
      'uid': credential.user!.uid,
      'name': name,
      'email': email,
      'photoUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _createDefaultFolders(credential.user!.uid);

    return credential;
  }

  Future<UserCredential?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    final doc = await _firestore
        .collection('users')
        .doc(userCredential.user!.uid)
        .get();

    if (!doc.exists) {
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'name': userCredential.user!.displayName ?? '',
        'email': userCredential.user!.email ?? '',
        'photoUrl': userCredential.user!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _createDefaultFolders(userCredential.user!.uid);
    } else {
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'name': userCredential.user!.displayName ?? '',
        'email': userCredential.user!.email ?? '',
        'photoUrl': userCredential.user!.photoURL,
      });
    }

    return userCredential;
  }

  Future<void> _createDefaultFolders(String uid) async {
    final batch = _firestore.batch();

    final folders = [
      {
        'id': 'catatan_$uid',
        'name': 'Catatan',
        'userId': uid,
        'colorIndex': 0,
        'isLocked': false,
        'isSystem': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'id': 'terkunci_$uid',
        'name': 'Terkunci',
        'userId': uid,
        'colorIndex': 5,
        'isLocked': true,
        'isSystem': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    for (final folder in folders) {
      final ref = _firestore
          .collection('users')
          .doc(uid)
          .collection('folders')
          .doc(folder['id'] as String);
      batch.set(ref, folder);
    }

    await batch.commit();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  bool get canChangePasswordWithCurrentAccount {
    final user = _auth.currentUser;
    if (user == null) return false;

    for (final provider in user.providerData) {
      if (provider.providerId == 'password') {
        return true;
      }
    }
    return false;
  }

  bool get isGoogleAccount {
    final user = _auth.currentUser;
    if (user == null) return false;

    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') {
        return true;
      }
    }
    return false;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'User tidak sedang login.',
      );
    }

    if (!canChangePasswordWithCurrentAccount) {
      throw FirebaseAuthException(
        code: 'password-change-not-supported',
        message: 'Akun ini tidak menggunakan login email/password.',
      );
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'Akun ini tidak memiliki email untuk verifikasi ulang.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> deleteAccount({String? currentPassword}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'User tidak sedang login.',
      );
    }

    final hasPasswordProvider = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    final hasGoogleProvider = user.providerData.any(
      (p) => p.providerId == 'google.com',
    );

    if (hasPasswordProvider) {
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'Email akun tidak ditemukan.',
        );
      }

      if (currentPassword == null || currentPassword.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-password',
          message: 'Password wajib diisi.',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
    } else if (hasGoogleProvider) {
      final currentEmail = user.email?.trim().toLowerCase();
      if (currentEmail == null || currentEmail.isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-email',
          message: 'Email akun Google tidak ditemukan.',
        );
      }

      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-reauth-cancelled',
          message: 'Verifikasi Google dibatalkan.',
        );
      }

      final selectedEmail = googleUser.email.trim().toLowerCase();
      if (selectedEmail != currentEmail) {
        await _googleSignIn.signOut();
        throw FirebaseAuthException(
          code: 'google-email-mismatch',
          message: 'Email verifikasi tidak sesuai.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
    } else {
      throw FirebaseAuthException(
        code: 'delete-account-not-supported',
        message: 'Jenis akun ini belum didukung untuk hapus akun.',
      );
    }

    await _deleteUserData(user.uid);
    await user.delete();
    await _googleSignIn.signOut();
  }

  Future<void> _deleteUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    final notesSnapshot = await userRef.collection('notes').get();
    final foldersSnapshot = await userRef.collection('folders').get();
    final tasksSnapshot = await userRef.collection('tasks').get();

    WriteBatch batch = _firestore.batch();
    int operationCount = 0;

    Future<void> commitIfNeeded() async {
      if (operationCount >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        operationCount = 0;
      }
    }

    for (final doc in notesSnapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;
      await commitIfNeeded();
    }

    for (final doc in foldersSnapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;
      await commitIfNeeded();
    }

    for (final doc in tasksSnapshot.docs) {
      batch.delete(doc.reference);
      operationCount++;
      await commitIfNeeded();
    }

    await batch.commit();
    await userRef.delete();
  }
}