import 'bill_source.dart';

class TransactionRecord {
  TransactionRecord({
    required this.id,
    required this.source,
    required this.origin,
    required this.occurredAt,
    required double amount,
    int? amountCents,
    required this.direction,
    required this.counterparty,
    required this.description,
    required this.paymentMethod,
    required this.originalCategory,
    required this.userCategory,
    required this.note,
    required this.importBatchId,
    required this.confirmationStatus,
    required this.fingerprint,
    required this.updatedAt,
  }) : amountCents = amountCents ?? (amount * 100).round(),
       amount = (amountCents ?? (amount * 100).round()) / 100;

  final String id;
  final BillSource source;
  final RecordOrigin origin;
  final DateTime occurredAt;
  final double amount;
  final int amountCents;
  final TransactionDirection direction;
  final String counterparty;
  final String description;
  final String paymentMethod;
  final String originalCategory;
  final String userCategory;
  final String note;
  final String importBatchId;
  final ConfirmationStatus confirmationStatus;
  final String fingerprint;
  final DateTime updatedAt;
}
