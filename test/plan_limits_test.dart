import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/plan_limits.dart';

void main() {
  test('Pro selalu lolos semua kuota', () {
    expect(canCreateWorkspace(plan: 'pro', joined: 99), isTrue);
    expect(canInvite(plan: 'pro', members: 99), isTrue);
    expect(canAutoTrack(plan: 'pro', used: 9999), isTrue);
    expect(canExportPdf(plan: 'pro'), isTrue);
    expect(isPro('pro'), isTrue);
    expect(isPro('free'), isFalse);
  });

  test('Gratis: workspace maks 2', () {
    expect(canCreateWorkspace(plan: 'free', joined: 0), isTrue);
    expect(canCreateWorkspace(plan: 'free', joined: 1), isTrue);
    expect(canCreateWorkspace(plan: 'free', joined: 2), isFalse);
    expect(PlanLimits.freeWorkspaces, 2);
  });

  test('Gratis: anggota maks 3', () {
    expect(canInvite(plan: 'free', members: 2), isTrue);
    expect(canInvite(plan: 'free', members: 3), isFalse);
    expect(PlanLimits.freeMembers, 3);
  });

  test('Gratis: auto-track maks 150 per bulan', () {
    expect(canAutoTrack(plan: 'free', used: 149), isTrue);
    expect(canAutoTrack(plan: 'free', used: 150), isFalse);
    expect(PlanLimits.freeAutoPerMonth, 150);
  });

  test('Gratis: PDF diblokir', () {
    expect(canExportPdf(plan: 'free'), isFalse);
    expect(canExportPdf(plan: ''), isFalse);
  });
}
