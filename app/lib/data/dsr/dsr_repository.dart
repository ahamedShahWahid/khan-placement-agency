import 'package:kpa_app/data/dsr/dsr_dto.dart';

abstract interface class DsrRepository {
  Future<String> exportData();
  Future<DsrDeleteResponse> deleteAccount();
}
