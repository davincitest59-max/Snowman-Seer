import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/ledger/domain/bill_source.dart';
import 'package:ocean_baby/features/ledger/services/notification_bill_parser.dart';

void main() {
  final parser = NotificationBillParser();

  group('NotificationBillParser', () {
    test('自动识别微信付款通知', () {
      final record = parser.parse(
        packageName: 'com.tencent.mm',
        title: '微信支付',
        body: '你已向便利店付款 ¥12.50',
        postedAt: DateTime(2026, 7, 5, 9, 30),
      );

      expect(record, isNotNull);
      expect(record!.source, BillSource.wechat);
      expect(record.amount, 12.50);
      expect(record.amountCents, 1250);
      expect(record.direction, TransactionDirection.expense);
      expect(record.counterparty, '便利店');
      expect(record.confirmationStatus, ConfirmationStatus.confirmed);
    });

    test('自动识别支付宝付款通知', () {
      final record = parser.parse(
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝通知',
        body: '成功付款 35.00 元 给 咖啡店',
        postedAt: DateTime(2026, 7, 5, 10, 15),
      );

      expect(record, isNotNull);
      expect(record!.source, BillSource.alipay);
      expect(record.amount, 35.00);
      expect(record.direction, TransactionDirection.expense);
      expect(record.counterparty, '咖啡店');
    });

    test('非交易通知不会写入账本', () {
      final record = parser.parse(
        packageName: 'com.tencent.mm',
        title: '微信',
        body: '你收到一条新消息',
        postedAt: DateTime(2026, 7, 5, 11),
      );

      expect(record, isNull);
    });

    test('交易关键词里的订单号不会被误识别为金额', () {
      final record = parser.parse(
        packageName: 'com.tencent.mm',
        title: '微信支付',
        body: '订单123付款成功，请查看详情',
        postedAt: DateTime(2026, 7, 5, 11, 30),
      );

      expect(record, isNull);
    });

    test('支付宝对象不会包含后续备注信息', () {
      final record = parser.parse(
        packageName: 'com.eg.android.AlipayGphone',
        title: '支付宝通知',
        body: '成功付款 35.00 元 给 咖啡店 订单123',
        postedAt: DateTime(2026, 7, 5, 11, 45),
      );

      expect(record, isNotNull);
      expect(record!.counterparty, '咖啡店');
    });

    test('金额存在但对象缺失时生成待确认账单', () {
      final record = parser.parse(
        packageName: 'com.tencent.mm',
        title: '微信支付',
        body: '支付成功 ¥18.00',
        postedAt: DateTime(2026, 7, 5, 12),
      );

      expect(record, isNotNull);
      expect(record!.amount, 18.00);
      expect(record.confirmationStatus, ConfirmationStatus.pending);
    });
  });
}
