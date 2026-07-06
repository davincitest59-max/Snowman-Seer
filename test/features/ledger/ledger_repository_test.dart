import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/ledger/data/ledger_repository.dart';
import 'package:ocean_baby/features/ledger/domain/bill_source.dart';
import 'package:ocean_baby/features/ledger/domain/transaction_record.dart';

void main() {
  test('相同指纹的账本记录只保存一次', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final record = _record(
      counterparty: '便利店',
      note: '',
      confirmationStatus: ConfirmationStatus.pending,
    );

    await repo.upsert(record);
    await repo.upsert(record);

    final records = await repo.listAll();
    expect(records, hasLength(1));
    expect(records.single.counterparty, '便利店');
    expect(records.single.amountCents, 1250);
  });

  test('相同指纹再次保存会更新记录内容', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);

    await repo.upsert(
      _record(
        counterparty: '',
        note: '',
        confirmationStatus: ConfirmationStatus.pending,
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '便利店',
        note: '已确认',
        confirmationStatus: ConfirmationStatus.confirmed,
      ),
    );

    final records = await repo.listAll();
    expect(records, hasLength(1));
    expect(records.single.counterparty, '便利店');
    expect(records.single.note, '已确认');
    expect(records.single.confirmationStatus, ConfirmationStatus.confirmed);
  });

  test('迁移会创建账本排序索引和 schema 版本', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);

    final indexes = await db.db.rawQuery("PRAGMA index_list('ledger_records')");
    final userVersion = await db.db.rawQuery('PRAGMA user_version');

    expect(
      indexes.map((row) => row['name']),
      contains('idx_ledger_records_occurred_at'),
    );
    expect(userVersion.single['user_version'], AppDatabase.schemaVersion);
  });

  test('可以统计导入预览中的重复记录', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final record = _record(
      counterparty: '便利店',
      note: '',
      confirmationStatus: ConfirmationStatus.confirmed,
    );

    await repo.upsert(record);

    final duplicateCount = await repo.countExistingFingerprints([
      record.fingerprint,
      'new|fingerprint',
    ]);
    expect(duplicateCount, 1);
  });

  test('可以统计每日每周每月收入与支出', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);
    final now = DateTime(2026, 7, 8, 12);

    await repo.upsert(
      _record(
        counterparty: '工资',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.income,
        amountCents: 10000,
        occurredAt: DateTime(2026, 7, 8, 9),
        fingerprint: 'income-today',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '午餐',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.expense,
        amountCents: 3525,
        occurredAt: DateTime(2026, 7, 8, 12),
        fingerprint: 'expense-today',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '水果',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.expense,
        amountCents: 1000,
        occurredAt: DateTime(2026, 7, 7, 18),
        fingerprint: 'expense-this-week',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '兼职',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.income,
        amountCents: 5000,
        occurredAt: DateTime(2026, 7, 6, 18),
        fingerprint: 'income-this-week',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '上周奖金',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.income,
        amountCents: 8000,
        occurredAt: DateTime(2026, 7, 5, 18),
        fingerprint: 'income-this-month-only',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '上月支出',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.expense,
        amountCents: 9900,
        occurredAt: DateTime(2026, 6, 30, 18),
        fingerprint: 'expense-last-month',
      ),
    );

    final statistics = await repo.summarizePeriods(now);

    expect(statistics.day.incomeCents, 10000);
    expect(statistics.day.expenseCents, 3525);
    expect(statistics.week.incomeCents, 15000);
    expect(statistics.week.expenseCents, 4525);
    expect(statistics.month.incomeCents, 23000);
    expect(statistics.month.expenseCents, 4525);
  });

  test('本周统计包含跨月周内的上月账单', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);

    await repo.upsert(
      _record(
        counterparty: '周一早餐',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        amountCents: 2000,
        occurredAt: DateTime(2026, 6, 29, 8),
        fingerprint: 'expense-cross-month-week',
      ),
    );
    await repo.upsert(
      _record(
        counterparty: '周三午餐',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        amountCents: 3000,
        occurredAt: DateTime(2026, 7, 1, 12),
        fingerprint: 'expense-current-month',
      ),
    );

    final statistics = await repo.summarizePeriods(DateTime(2026, 7, 1, 18));

    expect(statistics.week.expenseCents, 5000);
    expect(statistics.month.expenseCents, 3000);
  });

  test('统计当前周期时不会解析上月无关旧账单的完整元数据', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = LedgerRepository(db);

    await repo.upsert(
      _record(
        counterparty: '工资',
        note: '',
        confirmationStatus: ConfirmationStatus.confirmed,
        direction: TransactionDirection.income,
        amountCents: 10000,
        occurredAt: DateTime(2026, 7, 8, 9),
        fingerprint: 'income-current-month',
      ),
    );
    await db.db.insert('ledger_records', {
      'source': 'legacy_wechat',
      'origin': 'legacy_notification',
      'occurred_at': DateTime(2026, 6, 30, 18).toIso8601String(),
      'amount_cents': 9900,
      'amount': 99.0,
      'direction': 'expense',
      'counterparty': '旧账单',
      'description': '历史旧账单',
      'payment_method': '零钱',
      'original_category': '旧分类',
      'user_category': '旧分类',
      'note': '',
      'import_batch_id': '旧备份',
      'confirmation_status': 'legacy_pending',
      'fingerprint': 'legacy-last-month',
      'updated_at': DateTime(2026, 6, 30, 18, 5).toIso8601String(),
    });

    final statistics = await repo.summarizePeriods(DateTime(2026, 7, 8, 12));

    expect(statistics.day.incomeCents, 10000);
    expect(statistics.week.incomeCents, 10000);
    expect(statistics.month.incomeCents, 10000);
    expect(statistics.month.expenseCents, 0);
  });
}

TransactionRecord _record({
  required String counterparty,
  required String note,
  required ConfirmationStatus confirmationStatus,
  TransactionDirection direction = TransactionDirection.expense,
  int amountCents = 1250,
  DateTime? occurredAt,
  String? fingerprint,
}) {
  final date = occurredAt ?? DateTime(2026, 7, 5, 9, 30);
  return TransactionRecord(
    id: '',
    source: BillSource.wechat,
    origin: RecordOrigin.notification,
    occurredAt: date,
    amount: amountCents / 100,
    amountCents: amountCents,
    direction: direction,
    counterparty: counterparty,
    description: '微信支付 ${(amountCents / 100).toStringAsFixed(2)} 元',
    paymentMethod: '零钱',
    originalCategory: '商户消费',
    userCategory: '未分类',
    note: note,
    importBatchId: '通知自动记账',
    confirmationStatus: confirmationStatus,
    fingerprint: fingerprint ?? 'wechat|2026-07-05T09:30:00|1250|便利店',
    updatedAt: date,
  );
}
