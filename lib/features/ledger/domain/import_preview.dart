import 'bill_source.dart';
import 'transaction_record.dart';

class ImportPreview {
  ImportPreview({
    required this.source,
    Iterable<TransactionRecord> records = const [],
    Iterable<int> errorRows = const [],
    required this.duplicateCount,
  }) : records = List.unmodifiable(records),
       errorRows = List.unmodifiable(errorRows);

  final BillSource source;
  final List<TransactionRecord> records;
  final List<int> errorRows;
  final int duplicateCount;
}
