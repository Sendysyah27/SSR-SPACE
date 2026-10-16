import 'package:flutter_test/flutter_test.dart';
import 'package:ssr_space/services/plan_limits.dart';

void main() {
  test('Pro selalu lolos semua kuota', () {
    expect(canCreateWorkspace(plan: 'pro', joined: 99), isTrue);
    expect(canInvite(plan: 'pro', members: 99), isTrue);
    expect(canAutoTrack(plan: 'pro', used: 9999), isTrue);
    expect(canExportPdf(plan: 'pro'), isTrue);
    expect(canAddWallet(plan: 'pro', used: 99), isTrue);
    expect(canAddBudget(plan: 'pro', used: 99), isTrue);
    expect(canUseAi(plan: 'pro', used: 9999), isTrue);
    expect(canAddGoal(plan: 'pro', used: 99), isTrue);
    expect(canAddDebt(plan: 'pro', used: 99), isTrue);
    expect(canAddBill(plan: 'pro', used: 99), isTrue);
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

  test('Gratis: dompet maks 7', () {
    expect(canAddWallet(plan: 'free', used: 6), isTrue);
    expect(canAddWallet(plan: 'free', used: 7), isFalse);
    expect(PlanLimits.freeWallets, 7);
  });

  test('Gratis: budget maks 7 per bulan', () {
    expect(canAddBudget(plan: 'free', used: 6), isTrue);
    expect(canAddBudget(plan: 'free', used: 7), isFalse);
    expect(PlanLimits.freeBudgetsPerMonth, 7);
  });

  test('Gratis: AI maks 30 per bulan', () {
    expect(canUseAi(plan: 'free', used: 29), isTrue);
    expect(canUseAi(plan: 'free', used: 30), isFalse);
    expect(PlanLimits.freeAiPerMonth, 30);
  });

  test('Gratis: goals maks 3', () {
    expect(canAddGoal(plan: 'free', used: 2), isTrue);
    expect(canAddGoal(plan: 'free', used: 3), isFalse);
    expect(PlanLimits.freeGoals, 3);
  });

  test('Gratis: utang-piutang maks 5', () {
    expect(canAddDebt(plan: 'free', used: 4), isTrue);
    expect(canAddDebt(plan: 'free', used: 5), isFalse);
    expect(PlanLimits.freeDebts, 5);
  });

  test('Gratis: tagihan maks 5', () {
    expect(canAddBill(plan: 'free', used: 4), isTrue);
    expect(canAddBill(plan: 'free', used: 5), isFalse);
    expect(PlanLimits.freeBills, 5);
  });
}
