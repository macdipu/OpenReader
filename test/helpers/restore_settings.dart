import 'package:openreader/core/domain/repositories/app_settings_repository.dart';

/// Settings fixture for reader controller tests: only the restore-position
/// flag (ST-05) is answered, everything else is unimplemented.
class RestoreFlagSettings implements AppSettingsRepository {
  RestoreFlagSettings({this.restore = true});

  bool restore;

  @override
  Future<bool> getRestoreReadingPosition() async => restore;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
