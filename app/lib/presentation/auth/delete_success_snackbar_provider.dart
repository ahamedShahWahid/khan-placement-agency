import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_success_snackbar_provider.g.dart';

/// One-time flag — Sign-in screen reads it and clears it after showing
/// the "Your account has been deleted." snackbar.
@Riverpod(keepAlive: true)
class DeleteSuccessSnackbar extends _$DeleteSuccessSnackbar {
  @override
  bool build() => false;

  void fire() => state = true;
  void consume() => state = false;
}
