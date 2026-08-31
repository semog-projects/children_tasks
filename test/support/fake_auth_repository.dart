import 'dart:async';

import 'package:childrentasks/src/features/auth/data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// [AuthRepository] em memória para testes de widget.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({User? initialUser, this.onSignIn}) : _current = initialUser;

  final StreamController<User?> _controller = StreamController<User?>.broadcast();
  User? _current;

  /// Se fornecido, roda no lugar do login padrão (para simular erro/cancelamento).
  final Future<void> Function(FakeAuthRepository repo)? onSignIn;

  static User user({String? name = 'Ana', String? email = 'ana@example.com'}) =>
      MockUser(displayName: name, email: email, uid: 'uid-ana');

  @override
  Stream<User?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  User? get currentUser => _current;

  @override
  Future<void> signInWithGoogle() async {
    if (onSignIn != null) {
      await onSignIn!(this);
      return;
    }
    setUser(user());
  }

  @override
  Future<void> signOut() async => setUser(null);

  void setUser(User? value) {
    _current = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}
