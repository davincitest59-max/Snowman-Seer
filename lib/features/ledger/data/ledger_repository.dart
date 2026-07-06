import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/database/app_database.dart';
import '../domain/bill_source.dart';
import '../domain/transaction_record.dart';

class LedgerRepository {
  const LedgerRepository(this._database);

  final AppDatabase _database;

  Future<void> upsert(TransactionRecord record) async {
    final changed = await _database.db.update(
      'ledger_records',
      _toRow(record),
      where: 'fingerprint = ?',
      whereArgs: [record.fingerprint],
    );
    if (changed == 0) {
      await _database.db.insert(
        'ledger_records',
        _toRow(record),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<void> updateById(TransactionRecord record) async {
    await _database.db.update(
      'ledger_records',
      _toRow(record),
      where: 'id = ?',
      whereArgs: [int.parse(record.id)],
    );
  }

  Future<void> deleteById(String id) async {
    await _database.db.delete(
      'ledger_records',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  Future<List<TransactionRecord>> listAll() async {
    final rows = await _database.db.query(
      'ledger_records',
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<LedgerPeriodStatistics> summarizePeriods(DateTime now) async {
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final monthStart = DateTime(now.year, now.month);
    var lowerBound = dayStart;
    if (weekStart.isBefore(lowerBound)) lowerBound = weekStart;
    if (monthStart.isBefore(lowerBound)) lowerBound = monthStart;

    final rows = await _database.db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS day_income_cents,
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS day_expense_cents,
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS week_income_cents,
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS week_expense_cents,
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS month_income_cents,
        COALESCE(SUM(CASE WHEN occurred_at >= ? AND direction = ? THEN amount_cents ELSE 0 END), 0) AS month_expense_cents
      FROM ledger_records
      WHERE occurred_at >= ?
      ''',
      [
        dayStart.toIso8601String(),
        TransactionDirection.income.name,
        dayStart.toIso8601String(),
        TransactionDirection.expense.name,
        weekStart.toIso8601String(),
        TransactionDirection.income.name,
        weekStart.toIso8601String(),
        TransactionDirection.expense.name,
        monthStart.toIso8601String(),
        TransactionDirection.income.name,
        monthStart.toIso8601String(),
        TransactionDirection.expense.name,
        lowerBound.toIso8601String(),
      ],
    );
    final row = rows.single;
    return LedgerPeriodStatistics(
      day: LedgerMoneySummary(
        incomeCents: _aggregateCents(row, 'day_income_cents'),
        expenseCents: _aggregateCents(row, 'day_expense_cents'),
      ),
      week: LedgerMoneySummary(
        incomeCents: _aggregateCents(row, 'week_income_cents'),
        expenseCents: _aggregateCents(row, 'week_expense_cents'),
      ),
      month: LedgerMoneySummary(
        incomeCents: _aggregateCents(row, 'month_income_cents'),
        expenseCents: _aggregateCents(row, 'month_expense_cents'),
      ),
    );
  }

  Future<int> countExistingFingerprints(Iterable<String> fingerprints) async {
    return (await findExistingFingerprints(fingerprints)).length;
  }

  Future<Set<String>> findExistingFingerprints(
    Iterable<String> fingerprints,
  ) async {
    final uniqueFingerprints = fingerprints.toSet().toList(growable: false);
    if (uniqueFingerprints.isEmpty) return <String>{};

    final placeholders = List.filled(uniqueFingerprints.length, '?').join(',');
    final rows = await _database.db.rawQuery(
      'SELECT fingerprint FROM ledger_records WHERE fingerprint IN ($placeholders)',
      uniqueFingerprints,
    );
    return rows.map((row) => row['fingerprint'] as String).toSet();
  }

  Map<String, Object?> _toRow(TransactionRecord record) {
    return {
      'source': record.source.name,
      'origin': record.origin.name,
      'occurred_at': record.occurredAt.toIso8601String(),
      'amount_cents': record.amountCents,
      'amount': record.amount,
      'direction': record.direction.name,
      'counterparty': record.counterparty,
      'description': record.description,
      'payment_method': record.paymentMethod,
      'original_category': record.originalCategory,
      'user_category': record.userCategory,
      'note': record.note,
      'import_batch_id': record.importBatchId,
      'confirmation_status': record.confirmationStatus.name,
      'fingerprint': record.fingerprint,
      'updated_at': record.updatedAt.toIso8601String(),
    };
  }

  TransactionRecord _fromRow(Map<String, Object?> row) {
    final amountCents = row['amount_cents'] as int?;
    final amount = amountCents == null
        ? row['amount'] as double
        : amountCents / 100;
    return TransactionRecord(
      id: (row['id'] as int).toString(),
      source: BillSource.values.byName(row['source'] as String),
      origin: RecordOrigin.values.byName(row['origin'] as String),
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      amount: amount,
      amountCents: amountCents,
      direction: TransactionDirection.values.byName(row['direction'] as String),
      counterparty: row['counterparty'] as String,
      description: row['description'] as String,
      paymentMethod: row['payment_method'] as String,
      originalCategory: row['original_category'] as String,
      userCategory: row['user_category'] as String,
      note: row['note'] as String,
      importBatchId: row['import_batch_id'] as String,
      confirmationStatus: ConfirmationStatus.values.byName(
        row['confirmation_status'] as String,
      ),
      fingerprint: row['fingerprint'] as String,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }

  int _aggregateCents(Map<String, Object?> row, String column) {
    final value = row[column];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class LedgerPeriodStatistics {
  const LedgerPeriodStatistics({
    required this.day,
    required this.week,
    required this.month,
  });

  const LedgerPeriodStatistics.empty()
    : day = const LedgerMoneySummary.empty(),
      week = const LedgerMoneySummary.empty(),
      month = const LedgerMoneySummary.empty();

  final LedgerMoneySummary day;
  final LedgerMoneySummary week;
  final LedgerMoneySummary month;
}

class LedgerMoneySummary {
  const LedgerMoneySummary({
    required this.incomeCents,
    required this.expenseCents,
  });

  const LedgerMoneySummary.empty() : incomeCents = 0, expenseCents = 0;

  factory LedgerMoneySummary.fromRecords(Iterable<TransactionRecord> records) {
    var incomeCents = 0;
    var expenseCents = 0;
    for (final record in records) {
      switch (record.direction) {
        case TransactionDirection.income:
          incomeCents += record.amountCents;
        case TransactionDirection.expense:
          expenseCents += record.amountCents;
        case TransactionDirection.unknown:
          break;
      }
    }
    return LedgerMoneySummary(
      incomeCents: incomeCents,
      expenseCents: expenseCents,
    );
  }

  final int incomeCents;
  final int expenseCents;

  int get balanceCents => incomeCents - expenseCents;

  double get income => incomeCents / 100;
  double get expense => expenseCents / 100;
  double get balance => balanceCents / 100;
}
