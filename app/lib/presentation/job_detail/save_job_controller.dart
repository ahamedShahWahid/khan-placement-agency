import 'package:kpa_app/data/jobs/jobs_dto.dart';
import 'package:kpa_app/data/jobs/jobs_repository_impl.dart';
import 'package:kpa_app/presentation/job_detail/job_detail_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'save_job_controller.g.dart';

@riverpod
class SaveJobController extends _$SaveJobController {
  @override
  FutureOr<SavedJobDto?> build(String jobId) => null;

  Future<void> submit() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final sv = await ref.read(jobsRepositoryProvider).save(jobId);
      // TODO(task-29): ref.invalidate(savedControllerProvider);
      ref.invalidate(jobDetailControllerProvider(jobId));
      return sv;
    });
  }
}
