import 'auth_state.dart';

abstract interface class AuthRepository {
  Stream<AuthState> watch();
  AuthState get current;
  Future<SignedIn> signInWithGoogle();
  Future<SignedIn> refreshSession();
  Future<void> signOut();
}
