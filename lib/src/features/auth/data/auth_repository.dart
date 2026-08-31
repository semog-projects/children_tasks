import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Erro de autenticação tratável pela UI (mensagem já em pt-BR).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Lançado quando o usuário fecha o fluxo do Google sem concluir.
class AuthCancelledException implements Exception {
  const AuthCancelledException();
}

/// Client ID OAuth "Web" do projeto Firebase, necessário para o Google Sign-In
/// nativo (Android/iOS) devolver um idToken aceito pelo Firebase.
/// Passe com `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`. No web não é usado.
const String _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

abstract interface class AuthRepository {
  Stream<User?> authStateChanges();
  User? get currentUser;

  /// Autentica o responsável com a conta Google. No-op se já autenticado.
  Future<void> signInWithGoogle();

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  bool _googleInitialized = false;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithGoogle() async {
    final UserCredential credential;
    try {
      credential = kIsWeb ? await _signInWeb() : await _signInNative();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCancelledException();
      }
      throw AuthException('Falha no login com o Google (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        throw const AuthCancelledException();
      }
      throw AuthException(_firebaseMessage(e));
    }

    final user = credential.user;
    if (user != null) {
      await _upsertUserProfile(user);
    }
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb && GoogleSignIn.instance.supportsAuthenticate()) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  Future<UserCredential> _signInWeb() {
    final provider = GoogleAuthProvider()..addScope('email');
    return _auth.signInWithPopup(provider);
  }

  Future<UserCredential> _signInNative() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const AuthException(
        'Login com Google não é suportado nesta plataforma. Use o app web ou mobile.',
      );
    }
    if (_googleServerClientId.isEmpty) {
      throw const AuthException(
        'GOOGLE_SERVER_CLIENT_ID não configurado para o login nativo '
        '(passe via --dart-define).',
      );
    }

    if (!_googleInitialized) {
      await google.initialize(serverClientId: _googleServerClientId);
      _googleInitialized = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Não foi possível obter o token do Google.');
    }

    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  /// Cria/atualiza `users/{uid}` a cada login. `createdAt` é preservado.
  Future<void> _upsertUserProfile(User user) async {
    final doc = _firestore.collection('users').doc(user.uid);
    final snapshot = await doc.get();

    await doc.set({
      'displayName': user.displayName,
      'email': user.email,
      'photoUrl': user.photoURL,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _firebaseMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'account-exists-with-different-credential' =>
        'Já existe uma conta com este e-mail usando outro método de login.',
      'network-request-failed' => 'Sem conexão. Verifique a internet e tente de novo.',
      'user-disabled' => 'Esta conta foi desativada.',
      _ => 'Não foi possível entrar. Tente novamente.',
    };
  }
}
