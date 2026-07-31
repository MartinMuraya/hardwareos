import 'package:flutter_test/flutter_test.dart';
import 'package:hardwareos/core/providers/auth_provider.dart';

void main() {
  test('profile load failure sets unauthenticated and exposes error', () async {
    // Create provider with a profileFetcher that throws to simulate backend failure
    final provider = AuthProvider(
        attachAuthState: false,
        profileFetcher: () async {
          throw Exception('Simulated backend failure');
        });

    await provider.loadProfileForTest();

    expect(provider.state, AuthState.unauthenticated);
    expect(provider.errorMessage, isNotNull);
    expect(provider.profileLoadError, isNotNull);
  });
}
