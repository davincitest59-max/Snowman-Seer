import '../domain/bill_source.dart';

class BillFileDetection {
  BillFileDetection({
    required this.source,
    required this.headerRowIndex,
    required Map<String, int> columnMap,
  }) : columnMap = Map.unmodifiable(columnMap);

  const BillFileDetection.unknown()
    : source = BillSource.unknown,
      headerRowIndex = -1,
      columnMap = const {};

  final BillSource source;
  final int headerRowIndex;
  final Map<String, int> columnMap;
}

class BillFileDetector {
  static const _maxHeaderScanRows = 30;

  static const _wechatFields = ['交易时间', '交易类型', '交易对方', '收/支', '金额(元)', '支付方式'];

  static const _alipayFields = ['交易创建时间', '交易分类', '交易对方', '商品说明', '收/支', '金额'];

  BillSource detect(List<List<String>> rows) => detectDetailed(rows).source;

  BillFileDetection detectDetailed(List<List<String>> rows) {
    final scanCount = rows.length < _maxHeaderScanRows
        ? rows.length
        : _maxHeaderScanRows;

    for (var rowIndex = 0; rowIndex < scanCount; rowIndex += 1) {
      final cells = rows[rowIndex]
          .map((cell) => cell.trim())
          .toList(growable: false);
      if (cells.every((cell) => cell.isEmpty)) continue;

      final wechatMap = _buildColumnMap(cells, _wechatFields);
      final alipayMap = _buildColumnMap(cells, _alipayFields);
      final wechatHits = wechatMap.length;
      final alipayHits = alipayMap.length;

      if (wechatHits >= 4 && wechatHits > alipayHits) {
        return BillFileDetection(
          source: BillSource.wechat,
          headerRowIndex: rowIndex,
          columnMap: wechatMap,
        );
      }
      if (alipayHits >= 4 && alipayHits > wechatHits) {
        return BillFileDetection(
          source: BillSource.alipay,
          headerRowIndex: rowIndex,
          columnMap: alipayMap,
        );
      }
    }

    return const BillFileDetection.unknown();
  }

  Map<String, int> _buildColumnMap(List<String> cells, List<String> fields) {
    final result = <String, int>{};
    for (final field in fields) {
      final index = cells.indexWhere((cell) => cell == field);
      if (index != -1) result[field] = index;
    }
    return result;
  }
}
