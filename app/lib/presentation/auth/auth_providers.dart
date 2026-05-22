import 'package:kpa_app/data/api/dio_provider.dart';
import 'package:kpa_app/domain/auth/auth_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// Current auth state — SignedOut on app start; mutated by the bootstrap
/// controller (Task 24), the sign-in controller (Task 25), the sign-out
/// controller (Task 30), and the refresh interceptor's onSignedOut callback.
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() => const SignedOut();

  // ignore: use_setters_to_change_properties
  void set(AuthState s) {
    state = s;
  }
}

/// Mirror of AccessTokenHolder for UI consumers. The holder remains the
/// source of truth for dio interceptors; this provider lets widgets and
/// controllers reactively read the token without depending on the holder.
@Riverpod(keepAlive: true)
class AccessTokenNotifier extends _$AccessTokenNotifier {
  @override
  String? build() {
    final holder = ref.read(accessTokenHolderProvider);
    return holder.current;
  }

  void set(String? token) {
    ref.read(accessTokenHolderProvider).setToken(token);
    state = token;
  }
}
