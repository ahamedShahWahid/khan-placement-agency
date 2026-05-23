import 'package:kpa_app/data/me/me_dto.dart';

abstract interface class MeRepository {
  Future<MeDto> fetch();
}
