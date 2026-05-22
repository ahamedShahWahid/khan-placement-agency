import 'package:kpa_app/data/jobs/jobs_repository_impl.dart';
import 'package:kpa_app/presentation/job_detail/job_detail_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unsave_job_controller.g.dart';

@riverpod
class UnsaveJobController extends _$UnsaveJobController {
  @override
  FutureOr<void> build(String jobId) async {}

  Future<void> submit() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(jobsRepositoryProvider).unsave(jobId);
      // TODO(task-29): ref.invalidate(savedControllerProvider);
      ref.invalidate(jobDetailControllerProvider(jobId));
    });
  }
}
