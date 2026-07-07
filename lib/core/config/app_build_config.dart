import 'package:avogs/core/config/app_environment.dart';

/// Compile-time defaults baked in at build time via `--dart-define=APP_ENV=...`.
///
/// Example release build against the dev API:
/// `flutter build apk --release --dart-define=APP_ENV=development`
class AppBuildConfig {
  AppBuildConfig._();

  static const _rawEnv = String.fromEnvironment('APP_ENV', defaultValue: 'local');

  static AppEnvironment get defaultEnvironment => _parse(_rawEnv);

  static AppEnvironment _parse(String raw) {
    return AppEnvironment.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppEnvironment.local,
    );
  }
}
