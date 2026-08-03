import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobify_app/data/auth/auth_repository.dart';
import 'package:jobify_app/data/auth/auth_repository_provider.dart';
import 'package:jobify_app/data/auth/auth_state.dart';
import 'package:jobify_app/data/auth/user_role.dart';
import 'package:jobify_app/presentation/profile/sign_out_controller.dart';
import 'package:jobify_app/presentation/routing/locale_controller.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  AuthState get current =>
      const SignedIn(userId: 'u1', email: 'e@e.com', role: UserRole.applicant);
  @override
  Future<SignedIn> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<SignedIn> completeWebSignIn(String idToken) =>
      throw UnimplementedError();
  @override
  Future<SignedIn> refreshSession() => throw UnimplementedError();
  @override
  Future<String> refreshAccessTokenForInterceptor() =>
      throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}

void main() {
  test(
    'submit() resets the locale override back to device-follow',
    () async {
      final c = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
        ],
      );
      addTearDown(c.dispose);
      final localeSub = c.listen(localeControllerProvider, (_, __) {});
      addTearDown(localeSub.close);

      c.read(localeControllerProvider.notifier).setFromLanguage('hi');
      expect(c.read(localeControllerProvider), const Locale('hi'));

      await c.read(signOutControllerProvider.notifier).submit();

      expect(c.read(localeControllerProvider), isNull);
    },
  );
}
