import 'package:flutter_test/flutter_test.dart';
import 'package:team_maker/services/pwa_install_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9);

  test('first browser access is eligible for install guidance', () {
    expect(
      shouldOfferPwaInstall(isStandalone: false, dismissedAt: null, now: now),
      isTrue,
    );
  });

  test('standalone mode suppresses install guidance', () {
    expect(
      shouldOfferPwaInstall(isStandalone: true, dismissedAt: null, now: now),
      isFalse,
    );
  });

  test('dismissal suppresses guidance for seven days', () {
    expect(
      shouldOfferPwaInstall(
        isStandalone: false,
        dismissedAt: now.subtract(const Duration(days: 6)),
        now: now,
      ),
      isFalse,
    );
    expect(
      shouldOfferPwaInstall(
        isStandalone: false,
        dismissedAt: now.subtract(const Duration(days: 7)),
        now: now,
      ),
      isTrue,
    );
  });
}
