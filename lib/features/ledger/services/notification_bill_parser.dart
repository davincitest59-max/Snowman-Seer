import '../domain/bill_source.dart';
import '../domain/transaction_record.dart';

class NotificationBillParser {
  TransactionRecord? parse({
    required String packageName,
    String? title,
    required String body,
    required DateTime postedAt,
  }) {
    final source = _sourceFromPackage(packageName);
    if (source == BillSource.unknown) return null;

    final text = [title, body].whereType<String>().join(' ');
    final amount = _extractAmount(text);
    if (amount == null) return null;

    final direction = _extractDirection(text);
    if (direction == TransactionDirection.unknown) return null;

    final counterparty = _extractCounterparty(text);
    final fingerprint = _buildFingerprint(
      source: source,
      occurredAt: postedAt,
      amount: amount,
      direction: direction,
      counterparty: counterparty,
      body: body,
    );

    return TransactionRecord(
      id: fingerprint,
      source: source,
      origin: RecordOrigin.notification,
      occurredAt: postedAt,
      amount: amount,
      direction: direction,
      counterparty: counterparty ?? '',
      description: body,
      paymentMethod: '未知',
      originalCategory: '通知自动记账',
      userCategory: '未分类',
      note: '',
      importBatchId: '通知自动记账',
      confirmationStatus: counterparty == null
          ? ConfirmationStatus.pending
          : ConfirmationStatus.confirmed,
      fingerprint: fingerprint,
      updatedAt: postedAt,
    );
  }

  BillSource _sourceFromPackage(String packageName) {
    if (packageName == 'com.tencent.mm') return BillSource.wechat;
    if (packageName == 'com.eg.android.AlipayGphone') return BillSource.alipay;
    return BillSource.unknown;
  }

  double? _extractAmount(String body) {
    final match = RegExp(
      r'(?:¥|￥)\s*(\d+(?:\.\d{1,2})?)|(\d+(?:\.\d{1,2})?)\s*元',
    ).firstMatch(body);
    if (match == null) return null;
    return double.tryParse(match.group(1) ?? match.group(2)!);
  }

  TransactionDirection _extractDirection(String body) {
    if (body.contains('付款') || body.contains('支付成功') || body.contains('成功付款')) {
      return TransactionDirection.expense;
    }
    if (body.contains('收款') || body.contains('到账')) {
      return TransactionDirection.income;
    }
    return TransactionDirection.unknown;
  }

  String? _extractCounterparty(String body) {
    final wechat = RegExp(r'向(.+?)付款').firstMatch(body);
    if (wechat != null) return _normalizeCounterparty(wechat.group(1));

    final alipay = RegExp(r'给\s*([^\s，,。；;]+)').firstMatch(body);
    if (alipay != null) return _normalizeCounterparty(alipay.group(1));

    return null;
  }

  String? _normalizeCounterparty(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  String _buildFingerprint({
    required BillSource source,
    required DateTime occurredAt,
    required double amount,
    required TransactionDirection direction,
    required String? counterparty,
    required String body,
  }) {
    return [
      source.name,
      occurredAt.toIso8601String(),
      (amount * 100).round().toString(),
      direction.name,
      counterparty ?? '',
      body,
    ].join('|');
  }
}
