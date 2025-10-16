import 'package:agixt/models/agixt/auth/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletAuthResult', () {
    test('extracts token from direct field', () {
      final result = WalletAuthResult({'token': 'Bearer abc123'});
      expect(result.jwtToken, equals('abc123'));
    });

    test('extracts token from detail link', () {
      final result = WalletAuthResult({
        'detail': 'https://agixt.dev/callback?token=xyz890',
      });
      expect(result.jwtToken, equals('xyz890'));
    });

    test('extracts token from embedded token fragment', () {
      final result = WalletAuthResult({
        'detail': 'Login via link token=qwerty123&expires=1000',
      });
      expect(result.jwtToken, equals('qwerty123'));
    });

    test('returns null when no token information provided', () {
      final result = WalletAuthResult({'detail': 'No token here'});
      expect(result.jwtToken, isNull);
    });
  });
}
