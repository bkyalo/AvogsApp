enum AppEnvironment {
  local,
  development,
  production,
}

/// Change this one line before building, then run `flutter build apk --release`.
const AppEnvironment kDefaultEnvironment = AppEnvironment.development;

extension AppEnvironmentX on AppEnvironment {
  String get label => switch (this) {
        AppEnvironment.local => 'Local',
        AppEnvironment.development => 'Development',
        AppEnvironment.production => 'Production',
      };

  String get baseUrl => switch (this) {
        AppEnvironment.local => 'http://localhost:8090/api',
        AppEnvironment.development => 'https://avogsdev.werevu.co.ke/api',
        AppEnvironment.production => 'https://avogs.werevu.co.ke/api',
      };
}
