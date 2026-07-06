import '../domain/bill_source.dart';
import '../domain/import_preview.dart';
import '../domain/transaction_record.dart';
import 'bill_file_detector.dart';

class BillFileParser {
  BillFileParser({BillFileDetector? detector})
    : _detector = detector ?? BillFileDetector();

  final BillFileDetector _detector;

  ImportPreview parseRows(List<List<String>> rows) {
    final detection = _detector.detectDetailed(rows);
    if (detection.source == BillSource.unknown) {
      return ImportPreview(source: BillSource.unknown, duplicateCount: 0);
    }

    final records = <TransactionRecord>[];
    final errorRows = <int>[];
    for (
      var rowIndex = detection.headerRowIndex + 1;
      rowIndex < rows.length;
      rowIndex += 1
    ) {
      final row = rows[rowIndex];
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      final record = _parseRecord(detection, row, rowIndex);
      if (record == null) {
        errorRows.add(rowIndex + 1);
      } else {
        records.add(record);
      }
    }

    return ImportPreview(
      source: detection.source,
      records: records,
      errorRows: errorRows,
      duplicateCount: 0,
    );
  }

  TransactionRecord? _parseRecord(
    BillFileDetection detection,
    List<String> row,
    int rowIndex,
  ) {
    final source = detection.source;
    final timeText = _cell(row, detection, _timeColumn(source));
    final counterparty = _cell(row, detection, '交易对方');
    final directionText = _cell(row, detection, '收/支');
    final amountText = _cell(row, detection, _amountColumn(source));
    final category = _cell(row, detection, _categoryColumn(source));
    final description = _cell(row, detection, _descriptionColumn(source));
    final paymentMethod = _cell(row, detection, '支付方式');

    final occurredAt = DateTime.tryParse(timeText.replaceFirst(' ', 'T'));
    final amount = _parseAmount(amountText);
    final direction = _parseDirection(directionText);
    if (occurredAt == null ||
        amount == null ||
        direction == TransactionDirection.unknown) {
      return null;
    }

    final amountCents = (amount * 100).round();
    final fingerprint = [
      source.name,
      occurredAt.toIso8601String(),
      amountCents,
      direction.name,
      counterparty,
      rowIndex,
    ].join('|');

    return TransactionRecord(
      id: '',
      source: source,
      origin: RecordOrigin.fileImport,
      occurredAt: occurredAt,
      amount: amount,
      amountCents: amountCents,
      direction: direction,
      counterparty: counterparty.isEmpty ? '未知对象' : counterparty,
      description: description.isEmpty ? category : description,
      paymentMethod: paymentMethod.isEmpty ? '未知' : paymentMethod,
      originalCategory: category.isEmpty ? '未分类' : category,
      userCategory: '未分类',
      note: '',
      importBatchId: '账单文件导入',
      confirmationStatus: ConfirmationStatus.confirmed,
      fingerprint: fingerprint,
      updatedAt: DateTime.now(),
    );
  }

  String _cell(List<String> row, BillFileDetection detection, String column) {
    final index = detection.columnMap[column];
    if (index == null || index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  String _timeColumn(BillSource source) {
    return source == BillSource.wechat ? '交易时间' : '交易创建时间';
  }

  String _amountColumn(BillSource source) {
    return source == BillSource.wechat ? '金额(元)' : '金额';
  }

  String _categoryColumn(BillSource source) {
    return source == BillSource.wechat ? '交易类型' : '交易分类';
  }

  String _descriptionColumn(BillSource source) {
    return source == BillSource.wechat ? '商品' : '商品说明';
  }

  double? _parseAmount(String text) {
    final normalized = text
        .replaceAll('¥', '')
        .replaceAll('￥', '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(normalized);
  }

  TransactionDirection _parseDirection(String text) {
    if (text.contains('支出') || text.contains('付款')) {
      return TransactionDirection.expense;
    }
    if (text.contains('收入') || text.contains('收款')) {
      return TransactionDirection.income;
    }
    return TransactionDirection.unknown;
  }
}
