import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../platform/notification_listener.dart';
import '../../mood/ui/mood_page_title.dart';
import '../data/ledger_repository.dart';
import '../domain/bill_source.dart';
import '../domain/transaction_record.dart';
import '../services/notification_bill_parser.dart';
import 'import_bill_page.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.repository,
    NotificationListenerBridge? listenerBridge,
  }) : listenerBridge = listenerBridge ?? const NotificationListenerBridge();

  final LedgerRepository repository;
  final NotificationListenerBridge listenerBridge;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final _notificationParser = NotificationBillParser();
  late Future<List<TransactionRecord>> _recordsFuture;
  late Future<LedgerPeriodStatistics> _statisticsFuture;
  StreamSubscription<AppNotification>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _reload();
    _notificationSubscription = widget.listenerBridge.notifications().listen(
      _handleNotification,
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _reload() {
    _recordsFuture = widget.repository.listAll();
    _statisticsFuture = widget.repository.summarizePeriods(DateTime.now());
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImportBillPage(repository: widget.repository),
      ),
    );
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _handleNotification(AppNotification notification) async {
    final record = _notificationParser.parse(
      packageName: notification.packageName,
      title: notification.title,
      body: notification.body,
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        notification.postedAtMillis,
      ),
    );
    if (record == null) return;
    await widget.repository.upsert(record);
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MoodPageTitle('账本'),
        const SizedBox(height: 16),
        LedgerActionsPanel(
          onImport: _openImport,
          onManualRecord: () => _editRecord(),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TransactionRecord>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <TransactionRecord>[];
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final pendingCount = records
                .where(
                  (record) =>
                      record.confirmationStatus == ConfirmationStatus.pending,
                )
                .length;
            return Column(
              children: [
                _LedgerSection(title: '待确认账单', value: '$pendingCount 条记录等待确认'),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<LedgerPeriodStatistics>(
          future: _statisticsFuture,
          builder: (context, snapshot) {
            return LedgerStatisticsView(
              statistics: snapshot.data ?? const LedgerPeriodStatistics.empty(),
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<TransactionRecord>>(
          future: _recordsFuture,
          builder: (context, snapshot) {
            final records = snapshot.data ?? const <TransactionRecord>[];
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (records.isEmpty) {
              return const _LedgerSection(title: '交易列表', value: '暂无交易记录');
            }
            return Column(children: _buildMonthlySections(records));
          },
        ),
      ],
    );
  }

  List<Widget> _buildMonthlySections(List<TransactionRecord> records) {
    final grouped = <String, List<TransactionRecord>>{};
    for (final record in records) {
      final key =
          '${record.occurredAt.year}年${record.occurredAt.month.toString().padLeft(2, '0')}月';
      grouped.putIfAbsent(key, () => []).add(record);
    }
    return grouped.entries.expand((entry) {
      return <Widget>[
        LedgerMonthlySection(
          monthLabel: entry.key,
          records: entry.value,
          onRecordTap: (record) => _editRecord(record: record),
        ),
      ];
    }).toList();
  }

  Future<void> _editRecord({TransactionRecord? record}) async {
    final draft = await showDialog<_RecordDraft>(
      context: context,
      builder: (_) => _RecordDialog(record: record),
    );
    if (draft == null) return;

    final now = DateTime.now();
    final fingerprint =
        record?.fingerprint ??
        [
          'manual',
          now.microsecondsSinceEpoch,
          draft.occurredAt.toIso8601String(),
          draft.amountCents,
          draft.counterparty,
        ].join('|');
    final nextRecord = TransactionRecord(
      id: record?.id ?? '',
      source: BillSource.unknown,
      origin: RecordOrigin.manual,
      occurredAt: draft.occurredAt,
      amount: draft.amountCents / 100,
      amountCents: draft.amountCents,
      direction: draft.direction,
      counterparty: draft.counterparty,
      description: draft.description,
      paymentMethod: draft.paymentMethod,
      originalCategory: '手动记账',
      userCategory: draft.userCategory,
      note: draft.note,
      importBatchId: '手动记账',
      confirmationStatus: ConfirmationStatus.confirmed,
      fingerprint: fingerprint,
      updatedAt: now,
    );
    if (record == null) {
      await widget.repository.upsert(nextRecord);
    } else {
      await widget.repository.updateById(nextRecord);
    }
    if (!mounted) return;
    setState(_reload);
  }
}

class LedgerStatisticsView extends StatelessWidget {
  const LedgerStatisticsView({super.key, required this.statistics});

  final LedgerPeriodStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const ValueKey('ledger-statistics-expansion'),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: EdgeInsets.zero,
      title: Text(
        '收支统计',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      children: [
        _StatisticsTile(title: '今日收支', summary: statistics.day),
        _StatisticsTile(title: '本周收支', summary: statistics.week),
        _StatisticsTile(title: '本月收支', summary: statistics.month),
      ],
    );
  }
}

class LedgerActionsPanel extends StatelessWidget {
  const LedgerActionsPanel({
    super.key,
    required this.onImport,
    required this.onManualRecord,
  });

  final VoidCallback onImport;
  final VoidCallback onManualRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('ledger-import-action'),
            onPressed: onImport,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('导入账单'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('ledger-manual-action'),
            onPressed: onManualRecord,
            icon: const Icon(Icons.add),
            label: const Text('手动记一笔'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatisticsTile extends StatelessWidget {
  const _StatisticsTile({required this.title, required this.summary});

  final String title;
  final LedgerMoneySummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          '收入 ${_formatMoney(summary.income)}\n'
          '支出 ${_formatMoney(summary.expense)}\n'
          '结余 ${_formatMoney(summary.balance)}',
        ),
      ),
    );
  }

  String _formatMoney(double value) {
    return '¥${value.toStringAsFixed(2)}';
  }
}

class LedgerMonthlySection extends StatelessWidget {
  const LedgerMonthlySection({
    super.key,
    required this.monthLabel,
    required this.records,
    this.onRecordTap,
  });

  final String monthLabel;
  final List<TransactionRecord> records;
  final ValueChanged<TransactionRecord>? onRecordTap;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('ledger-month-$monthLabel'),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        monthLabel,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      children: records
          .map(
            (record) => _RecordTile(
              record: record,
              onTap: () => onRecordTap?.call(record),
            ),
          )
          .toList(),
    );
  }
}

class _LedgerSection extends StatelessWidget {
  const _LedgerSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(title: Text(title), subtitle: Text(value)),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record, required this.onTap});

  final TransactionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountPrefix = record.direction == TransactionDirection.expense
        ? '-'
        : '+';
    final source = switch (record.source) {
      BillSource.wechat => '微信',
      BillSource.alipay => '支付宝',
      BillSource.unknown => '未知',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          record.direction == TransactionDirection.expense
              ? Icons.north_east
              : Icons.south_west,
        ),
        title: Text(record.counterparty),
        subtitle: Text(
          '$source · ${DateFormat('yyyy-MM-dd HH:mm').format(record.occurredAt)}\n${record.description}',
        ),
        isThreeLine: true,
        trailing: Text(
          '$amountPrefix¥${record.amount.toStringAsFixed(2)}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _RecordDialog extends StatefulWidget {
  const _RecordDialog({this.record});

  final TransactionRecord? record;

  @override
  State<_RecordDialog> createState() => _RecordDialogState();
}

class _RecordDialogState extends State<_RecordDialog> {
  final _counterpartyController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  final _categoryController = TextEditingController(text: '未分类');
  final _noteController = TextEditingController();
  late TransactionDirection _direction;
  late DateTime _occurredAt;

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _direction = record?.direction ?? TransactionDirection.expense;
    _occurredAt = record?.occurredAt ?? DateTime.now();
    if (record != null) {
      _counterpartyController.text = record.counterparty;
      _amountController.text = record.amount.toStringAsFixed(2);
      _descriptionController.text = record.description;
      _paymentMethodController.text = record.paymentMethod;
      _categoryController.text = record.userCategory;
      _noteController.text = record.note;
    }
  }

  @override
  void dispose() {
    _counterpartyController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _paymentMethodController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.record == null ? '手动记一笔' : '修改账单'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<TransactionDirection>(
              segments: const [
                ButtonSegment(
                  value: TransactionDirection.expense,
                  label: Text('支出'),
                ),
                ButtonSegment(
                  value: TransactionDirection.income,
                  label: Text('收入'),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (value) =>
                  setState(() => _direction = value.single),
            ),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: '金额'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            TextField(
              controller: _counterpartyController,
              decoration: const InputDecoration(labelText: '对象/商户'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '说明'),
            ),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: '分类'),
            ),
            TextField(
              controller: _paymentMethodController,
              decoration: const InputDecoration(labelText: '支付方式'),
            ),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: '备注'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_occurredAt)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _occurredAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _occurredAt = picked);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final amount = double.tryParse(_amountController.text.trim());
            final counterparty = _counterpartyController.text.trim();
            if (amount == null || amount <= 0 || counterparty.isEmpty) return;
            Navigator.of(context).pop(
              _RecordDraft(
                direction: _direction,
                occurredAt: _occurredAt,
                amountCents: (amount * 100).round(),
                counterparty: counterparty,
                description: _descriptionController.text.trim(),
                paymentMethod: _paymentMethodController.text.trim().isEmpty
                    ? '未知'
                    : _paymentMethodController.text.trim(),
                userCategory: _categoryController.text.trim().isEmpty
                    ? '未分类'
                    : _categoryController.text.trim(),
                note: _noteController.text.trim(),
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _RecordDraft {
  const _RecordDraft({
    required this.direction,
    required this.occurredAt,
    required this.amountCents,
    required this.counterparty,
    required this.description,
    required this.paymentMethod,
    required this.userCategory,
    required this.note,
  });

  final TransactionDirection direction;
  final DateTime occurredAt;
  final int amountCents;
  final String counterparty;
  final String description;
  final String paymentMethod;
  final String userCategory;
  final String note;
}
