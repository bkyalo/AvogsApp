import 'package:avogs/core/config/app_environment.dart';

class AppConfig {
  const AppConfig({
    required this.environment,
    this.selectedStoreCode,
  });

  final AppEnvironment environment;
  final String? selectedStoreCode;

  String get baseUrl => environment.baseUrl;

  AppConfig copyWith({
    AppEnvironment? environment,
    String? selectedStoreCode,
    bool clearStore = false,
  }) {
    return AppConfig(
      environment: environment ?? this.environment,
      selectedStoreCode:
          clearStore ? null : (selectedStoreCode ?? this.selectedStoreCode),
    );
  }
}
