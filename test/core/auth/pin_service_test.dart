import 'package:avogs/core/auth/pin_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late PinService pinService;

  setUp(() {
    storage = _MockStorage();
    pinService = PinService(storage);
  });

  test('setPin stores hash and verifyPin accepts correct pin', () async {
    String? storedHash;
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      storedHash = invocation.namedArguments[#value] as String?;
    });
    when(() => storage.read(key: PinService.pinHashKey))
        .thenAnswer((_) async => storedHash);

    await pinService.setPin('1234');
    final ok = await pinService.verifyPin('1234');
    expect(ok, isTrue);
  });

  test('verifyPin rejects wrong pin', () async {
    String? storedHash;
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      storedHash = invocation.namedArguments[#value] as String?;
    });
    when(() => storage.read(key: PinService.pinHashKey))
        .thenAnswer((_) async => storedHash);

    await pinService.setPin('1234');
    final ok = await pinService.verifyPin('9999');
    expect(ok, isFalse);
  });

  test('setPin rejects invalid length', () async {
    expect(() => pinService.setPin('12'), throwsArgumentError);
  });
}
