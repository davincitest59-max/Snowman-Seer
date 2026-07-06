import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/ledger/data/ledger_repository.dart';
import 'package:ocean_baby/features/ledger/domain/bill_source.dart';
import 'package:ocean_baby/features/ledger/domain/transaction_record.dart';
import 'package:ocean_baby/features/ledger/ui/ledger_page.dart';
import 'package:ocean_baby/features/mood/domain/mood_entry.dart';
import 'package:ocean_baby/features/mood/ui/mood_page.dart';
import 'package:ocean_baby/platform/notification_listener.dart';

void main() {
  testWidgets('账本统计显示今日本周本月收入支出结余', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LedgerStatisticsView(
            statistics: LedgerPeriodStatistics(
              day: LedgerMoneySummary(incomeCents: 10000, expenseCents: 3525),
              week: LedgerMoneySummary(incomeCents: 15000, expenseCents: 4525),
              month: LedgerMoneySummary(incomeCents: 23000, expenseCents: 4525),
            ),
          ),
        ),
      ),
    );

    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('今日收支'), findsOneWidget);
    expect(find.text('本周收支'), findsOneWidget);
    expect(find.text('本月收支'), findsOneWidget);
    expect(find.textContaining('收入 ¥100.00'), findsOneWidget);
    expect(find.textContaining('支出 ¥35.25'), findsOneWidget);
    expect(find.textContaining('结余 ¥64.75'), findsOneWidget);
    expect(find.textContaining('收入 ¥230.00'), findsOneWidget);
  });

  testWidgets('账本统计可以收起并再次展开', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LedgerStatisticsView(
            statistics: LedgerPeriodStatistics(
              day: LedgerMoneySummary(incomeCents: 10000, expenseCents: 3525),
              week: LedgerMoneySummary(incomeCents: 15000, expenseCents: 4525),
              month: LedgerMoneySummary(incomeCents: 23000, expenseCents: 4525),
            ),
          ),
        ),
      ),
    );

    expect(find.text('收支统计'), findsOneWidget);
    expect(find.text('今日收支'), findsOneWidget);

    await tester.tap(find.text('收支统计'));
    await tester.pumpAndSettle();

    expect(find.text('今日收支'), findsNothing);
    expect(find.text('本周收支'), findsNothing);
    expect(find.text('本月收支'), findsNothing);

    await tester.tap(find.text('收支统计'));
    await tester.pumpAndSettle();

    expect(find.text('今日收支'), findsOneWidget);
    expect(find.text('本周收支'), findsOneWidget);
    expect(find.text('本月收支'), findsOneWidget);
  });

  testWidgets('账本月份分组可以展开和收起', (tester) async {
    final record = TransactionRecord(
      id: '1',
      source: BillSource.wechat,
      origin: RecordOrigin.manual,
      occurredAt: DateTime(2026, 7, 6, 9),
      amount: 12.5,
      amountCents: 1250,
      direction: TransactionDirection.expense,
      counterparty: '便利店',
      description: '早餐',
      paymentMethod: '零钱',
      originalCategory: '商户消费',
      userCategory: '餐饮',
      note: '',
      importBatchId: '手动记账',
      confirmationStatus: ConfirmationStatus.confirmed,
      fingerprint: 'test',
      updatedAt: DateTime(2026, 7, 6, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LedgerMonthlySection(monthLabel: '2026年07月', records: [record]),
        ),
      ),
    );

    expect(find.text('2026年07月'), findsOneWidget);
    expect(find.text('便利店'), findsOneWidget);

    await tester.tap(find.text('2026年07月'));
    await tester.pumpAndSettle();

    expect(find.text('便利店'), findsNothing);

    await tester.tap(find.text('2026年07月'));
    await tester.pumpAndSettle();

    expect(find.text('便利店'), findsOneWidget);
  });

  testWidgets('待确认账单位于导入账单下方和收支统计上方', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LedgerPage(
            repository: _FakeLedgerRepository([
              _ledgerRecord(confirmationStatus: ConfirmationStatus.pending),
            ]),
            listenerBridge: const _SilentNotificationListenerBridge(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final importTop = tester.getTopLeft(find.text('导入账单')).dy;
    final pendingTop = tester.getTopLeft(find.text('待确认账单')).dy;
    final statisticsTop = tester.getTopLeft(find.text('收支统计')).dy;

    expect(importTop, lessThan(pendingTop));
    expect(pendingTop, lessThan(statisticsTop));
  });

  testWidgets('心情页显示历史心情列表', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoodHistoryList(
            entries: [
              MoodEntry(
                day: DateTime(2026, 7, 6),
                mood: MoodType.happy,
                promptShown: true,
                updatedAt: DateTime(2026, 7, 6, 9),
              ),
              MoodEntry(
                day: DateTime(2026, 7, 5),
                mood: MoodType.sad,
                promptShown: true,
                updatedAt: DateTime(2026, 7, 5, 9),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('历史心情'), findsOneWidget);
    expect(find.text('2026-07-06'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('2026-07-05'), findsOneWidget);
    expect(find.text('伤心'), findsOneWidget);
    final firstDot = tester.widget<Container>(
      find.byKey(const ValueKey('mood-history-dot-0')),
    );
    expect((firstDot.decoration! as BoxDecoration).color, Colors.green);
  });
}

TransactionRecord _ledgerRecord({
  ConfirmationStatus confirmationStatus = ConfirmationStatus.confirmed,
}) {
  return TransactionRecord(
    id: '1',
    source: BillSource.wechat,
    origin: RecordOrigin.manual,
    occurredAt: DateTime(2026, 7, 6, 9),
    amount: 12.5,
    amountCents: 1250,
    direction: TransactionDirection.expense,
    counterparty: '便利店',
    description: '早餐',
    paymentMethod: '零钱',
    originalCategory: '商户消费',
    userCategory: '餐饮',
    note: '',
    importBatchId: '手动记账',
    confirmationStatus: confirmationStatus,
    fingerprint: 'test-$confirmationStatus',
    updatedAt: DateTime(2026, 7, 6, 9),
  );
}

class _SilentNotificationListenerBridge extends NotificationListenerBridge {
  const _SilentNotificationListenerBridge();

  @override
  Stream<AppNotification> notifications() => const Stream.empty();
}

class _FakeLedgerRepository implements LedgerRepository {
  const _FakeLedgerRepository(this.records);

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> listAll() async => records;

  @override
  Future<LedgerPeriodStatistics> summarizePeriods(DateTime now) async {
    return const LedgerPeriodStatistics.empty();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
