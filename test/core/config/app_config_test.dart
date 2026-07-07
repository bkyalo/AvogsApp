import 'package:avogs/core/config/app_config.dart';
import 'package:avogs/core/config/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local environment base url', () {
    const config = AppConfig(environment: AppEnvironment.local);
    expect(config.baseUrl, 'http://localhost:8090/api');
  });

  test('development environment base url', () {
    const config = AppConfig(environment: AppEnvironment.development);
    expect(config.baseUrl, 'https://avogsdev.werevu.co.ke/api');
  });

  test('production environment base url', () {
    const config = AppConfig(environment: AppEnvironment.production);
    expect(config.baseUrl, 'https://avogs.werevu.co.ke/api');
  });
}
