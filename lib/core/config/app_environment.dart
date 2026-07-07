enum AppEnvironment {
  local,
  development,
  production,
}

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
