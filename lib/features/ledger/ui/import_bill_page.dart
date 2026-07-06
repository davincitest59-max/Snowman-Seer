import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../../../platform/ocean_file_picker.dart';
import '../data/ledger_repository.dart';
import '../domain/bill_source.dart';
import '../domain/import_preview.dart';
import '../services/bill_file_parser.dart';

class ImportBillPage extends StatefulWidget {
  const ImportBillPage({
    super.key,
    required this.repository,
    OceanFilePicker? filePicker,
  }) : filePicker = filePicker ?? const OceanFilePickerBridge();

  final LedgerRepository repository;
  final OceanFilePicker filePicker;

  @override
  State<ImportBillPage> createState() => _ImportBillPageState();
}

class _ImportBillPageState extends State<ImportBillPage> {
  final _parser = BillFileParser();
  ImportPreview? _preview;
  Set<String> _duplicateFingerprints = const {};
  String? _fileName;
  String? _message;
  bool _busy = false;

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final pickedFile = await widget.filePicker.pickFile(
        mimeTypes: const [
          'text/csv',
          'text/plain',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/octet-stream',
        ],
      );
      if (pickedFile == null) return;

      final rows = _readRows(pickedFile.name, pickedFile.bytes);
      final preview = _parser.parseRows(rows);
      final duplicateFingerprints = await widget.repository
          .findExistingFingerprints(
            preview.records.map((record) => record.fingerprint),
          );
      setState(() {
        _fileName = pickedFile.name;
        _duplicateFingerprints = duplicateFingerprints;
        _preview = ImportPreview(
          source: preview.source,
          records: preview.records,
          errorRows: preview.errorRows,
          duplicateCount: duplicateFingerprints.length,
        );
        _message = preview.source == BillSource.unknown ? '未识别为微信或支付宝账单' : null;
      });
    } catch (error) {
      setState(() => _message = '读取失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importRecords() async {
    final preview = _preview;
    if (preview == null || preview.records.isEmpty) return;

    setState(() => _busy = true);
    final importableRecords = preview.records.where(
      (record) => !_duplicateFingerprints.contains(record.fingerprint),
    );
    var importedCount = 0;
    for (final record in importableRecords) {
      await widget.repository.upsert(record);
      importedCount += 1;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = '已导入 $importedCount 条账单，跳过 ${preview.duplicateCount} 条重复记录';
    });
  }

  List<List<String>> _readRows(String fileName, Uint8List bytes) {
    final extension = fileName.split('.').last.toLowerCase();
    if (extension == 'xlsx' || extension == 'xls') {
      final workbook = Excel.decodeBytes(bytes);
      final sheetName = workbook.tables.keys.first;
      final sheet = workbook.tables[sheetName]!;
      return sheet.rows
          .map(
            (row) => row
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList(growable: false),
          )
          .toList(growable: false);
    }

    final content = utf8.decode(bytes, allowMalformed: true);
    return const CsvToListConverter(shouldParseNumbers: false)
        .convert(content)
        .map((row) {
          return row
              .map((cell) => cell.toString().trim())
              .toList(growable: false);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('导入账单')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(_fileName ?? '选择账单文件'),
              subtitle: const Text('CSV、Excel 或文本账单'),
              trailing: FilledButton(
                onPressed: _busy ? null : _pickFile,
                child: Text(_busy ? '读取中' : '选择'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('导入预览'),
              subtitle: Text(_previewText(preview)),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || preview == null || preview.records.isEmpty
                ? null
                : _importRecords,
            icon: const Icon(Icons.done),
            label: const Text('导入到账本'),
          ),
        ],
      ),
    );
  }

  String _previewText(ImportPreview? preview) {
    if (preview == null) return '选择文件后显示可导入交易';
    final source = switch (preview.source) {
      BillSource.wechat => '微信',
      BillSource.alipay => '支付宝',
      BillSource.unknown => '未知',
    };
    return '$source账单，可导入 ${preview.records.length - preview.duplicateCount} 条，重复 ${preview.duplicateCount} 条，错误 ${preview.errorRows.length} 行';
  }
}
