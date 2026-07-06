import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/ledger/domain/bill_source.dart';
import 'package:ocean_baby/features/ledger/services/bill_file_detector.dart';
import 'package:ocean_baby/features/ledger/services/bill_file_parser.dart';

void main() {
  final detector = BillFileDetector();

  group('BillFileDetector', () {
    test('自动识别微信账单表头', () {
      final source = detector.detect([
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)', '支付方式'],
        ['2026-07-05 09:00:00', '商户消费', '便利店', '早餐', '支出', '12.50', '零钱'],
      ]);

      expect(source, BillSource.wechat);
    });

    test('自动跳过微信账单前置说明行', () {
      final detection = detector.detectDetailed([
        ['微信支付账单明细'],
        ['导出时间', '2026-07-05'],
        [],
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)', '支付方式'],
        ['2026-07-05 09:00:00', '商户消费', '便利店', '早餐', '支出', '12.50', '零钱'],
      ]);

      expect(detection.source, BillSource.wechat);
      expect(detection.headerRowIndex, 3);
      expect(detection.columnMap['交易时间'], 0);
      expect(detection.columnMap['金额(元)'], 5);
    });

    test('自动跳过较长的微信账单前置说明行', () {
      final prefaceRows = List.generate(16, (index) => ['说明行 ${index + 1}']);
      final detection = detector.detectDetailed([
        ...prefaceRows,
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)', '支付方式'],
        ['2026-07-05 09:00:00', '商户消费', '便利店', '早餐', '支出', '12.50', '零钱'],
      ]);

      expect(detection.source, BillSource.wechat);
      expect(detection.headerRowIndex, 16);
    });

    test('自动识别支付宝账单表头', () {
      final source = detector.detect([
        ['交易创建时间', '交易分类', '交易对方', '商品说明', '收/支', '金额'],
        ['2026-07-05 10:00:00', '餐饮美食', '咖啡店', '拿铁', '支出', '35.00'],
      ]);

      expect(source, BillSource.alipay);
    });

    test('字段顺序变化时仍保留支付宝列索引', () {
      final detection = detector.detectDetailed([
        ['金额', '收/支', '商品说明', '交易对方', '交易分类', '交易创建时间'],
        ['35.00', '支出', '拿铁', '咖啡店', '餐饮美食', '2026-07-05 10:00:00'],
      ]);

      expect(detection.source, BillSource.alipay);
      expect(detection.columnMap['金额'], 0);
      expect(detection.columnMap['交易创建时间'], 5);
    });

    test('无关文件识别失败', () {
      final source = detector.detect([
        ['姓名', '电话'],
        ['张三', '13800000000'],
      ]);

      expect(source, BillSource.unknown);
    });

    test('说明文字包含字段名但表头不完整时不会误判', () {
      final source = detector.detect([
        ['说明：本文件可能包含交易时间、交易对方、金额等文字'],
        ['姓名', '电话'],
      ]);

      expect(source, BillSource.unknown);
    });
  });

  group('BillFileParser', () {
    test('把微信账单行解析为可写入账本的支出记录', () {
      final preview = BillFileParser().parseRows([
        ['微信支付账单明细'],
        ['交易时间', '交易类型', '交易对方', '商品', '收/支', '金额(元)', '支付方式'],
        ['2026-07-05 09:00:00', '商户消费', '便利店', '早餐', '支出', '12.50', '零钱'],
      ]);

      expect(preview.source, BillSource.wechat);
      expect(preview.records, hasLength(1));
      expect(preview.records.single.counterparty, '便利店');
      expect(preview.records.single.amountCents, 1250);
      expect(preview.records.single.direction, TransactionDirection.expense);
    });

    test('把支付宝账单行解析为可写入账本的收入记录', () {
      final preview = BillFileParser().parseRows([
        ['交易创建时间', '交易分类', '交易对方', '商品说明', '收/支', '金额'],
        ['2026-07-05 10:00:00', '转账红包', '朋友', '转账收款', '收入', '66.00'],
      ]);

      expect(preview.source, BillSource.alipay);
      expect(preview.records, hasLength(1));
      expect(preview.records.single.counterparty, '朋友');
      expect(preview.records.single.amountCents, 6600);
      expect(preview.records.single.direction, TransactionDirection.income);
    });
  });
}
