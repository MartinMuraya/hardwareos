import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  bool _loading = false;
  bool _importing = false;
  PlatformFile? _file;
  List<Map<String, dynamic>> _parsedRows = [];
  List<_RowError> _errors = [];
  String? _errorMessage;
  int? _importedCount;

  static const _expectedColumns = [
    'sku', 'name', 'category', 'buyPrice', 'sellPrice', 'quantity', 'reorderLevel', 'unit',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.upload_file_rounded, color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Import Products', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('CSV or Excel format', style: theme.textTheme.bodySmall),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 24),
            if (_importedCount != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
                  const SizedBox(height: 12),
                  Text('Successfully imported $_importedCount products!',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ]),
              )
            else ...[
              if (_file == null) _buildFilePicker(theme) else _buildPreview(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor, width: 2, strokeAlign: BorderSide.strokeAlignInside),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          child: Column(children: [
            Icon(Icons.cloud_upload_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text('Choose a file to import', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('CSV (.csv) or Excel (.xlsx)', style: TextStyle(color: theme.hintColor, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(_loading ? 'Reading...' : 'Select File'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _downloadSample,
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Download Sample Template'),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
            ]),
          ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final validRows = _parsedRows.length - _errors.length;
    return Flexible(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_file!.name, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('${_parsedRows.length} total rows · $validRows valid · ${_errors.length} errors',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ]),
              ),
              TextButton(
                onPressed: () => setState(() { _file = null; _parsedRows = []; _errors = []; _errorMessage = null; }),
                child: const Text('Change File'),
              ),
            ]),
            const SizedBox(height: 12),
            if (_errors.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Errors found — fix and re-upload, or ignore to import valid rows only',
                    style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ..._errors.take(5).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('Row ${e.row}: ${e.message}',
                      style: const TextStyle(color: AppColors.error, fontSize: 11)),
                  )),
                  if (_errors.length > 5)
                    Text('...and ${_errors.length - 5} more errors',
                      style: TextStyle(color: theme.hintColor, fontSize: 11)),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  itemCount: _parsedRows.length.clamp(0, 100),
                  itemBuilder: (_, i) {
                    final row = _parsedRows[i];
                    final hasError = _errors.any((e) => e.row == i + 2);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: theme.dividerColor)),
                        color: hasError ? AppColors.error.withValues(alpha: 0.05) : null,
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 40,
                          child: Text('${i + 2}',
                            style: TextStyle(color: theme.hintColor, fontSize: 11)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(row['name']?.toString() ?? '-',
                            style: TextStyle(fontSize: 13, color: hasError ? AppColors.error : theme.colorScheme.onSurface),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(row['sku']?.toString() ?? '-',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text('KES ${row['sellPrice'] ?? '-'}',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent)),
                        ),
                        if (hasError)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.error, color: AppColors.error, size: 14),
                          ),
                      ]),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _importing ? null : _doImport,
                icon: _importing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_rounded, size: 18),
                label: Text(_importing ? 'Importing...' : 'Import ${validRows} Products'),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    setState(() { _loading = true; _errorMessage = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      _file = result.files.first;
      await _parseFile();
    } catch (e) {
      setState(() { _errorMessage = 'Failed to read file: $e'; _loading = false; });
    }
  }

  Future<void> _parseFile() async {
    if (_file == null) return;
    try {
      final bytes = _file!.bytes;
      if (bytes == null) { setState(() { _errorMessage = 'Empty file.'; _loading = false; }); return; }

      String content;
      if (_file!.name.endsWith('.csv')) {
        content = utf8.decode(bytes);
        final rows = const CsvToListConverter(eol: '\n').convert(content);
        _parseRows(rows);
      } else if (_file!.name.endsWith('.xlsx')) {
        final excel = Excel.decodeBytes(bytes);
        for (final sheet in excel.sheets.values) {
          final rows = sheet.rows.map((r) => r.map((c) => c?.value?.toString() ?? '').toList()).toList();
          _parseRows(rows);
          break;
        }
      } else {
        setState(() { _errorMessage = 'Unsupported file format. Use .csv or .xlsx.'; _loading = false; });
        return;
      }
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _errorMessage = 'Failed to parse file: $e'; _loading = false; });
    }
  }

  void _parseRows(List<List<dynamic>> rows) {
    if (rows.length < 2) {
      setState(() { _errorMessage = 'File must have a header row and at least one data row.'; _loading = false; });
      return;
    }

    final headers = rows[0].map((h) => h.toString().trim().toLowerCase()).toList();

    for (final col in _expectedColumns) {
      if (col == 'unit') continue;
      if (!headers.contains(col)) {
        setState(() { _errorMessage = 'Missing required column: "$col". Expected: ${_expectedColumns.join(", ")}'; _loading = false; });
        return;
      }
    }

    _parsedRows = [];
    _errors = [];
    final seenSkus = <String>{};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && (row[0]?.toString().trim() ?? '') == '')) continue;

      final Map<String, dynamic> parsed = {};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        parsed[headers[j]] = row[j];
      }

      final rowNum = i + 1;

      final name = parsed['name']?.toString().trim() ?? '';
      if (name.isEmpty) {
        _errors.add(_RowError(row: rowNum + 1, message: 'Missing Product Name'));
        continue;
      }

      final sellPriceStr = parsed['sellPrice']?.toString().trim() ?? '';
      final sellPrice = double.tryParse(sellPriceStr);
      if (sellPrice == null || sellPrice <= 0) {
        _errors.add(_RowError(row: rowNum + 1, message: 'Invalid Sell Price'));
        continue;
      }

      final buyPriceStr = parsed['buyPrice']?.toString().trim() ?? '';
      final buyPrice = double.tryParse(buyPriceStr);

      final qtyStr = parsed['quantity']?.toString().trim() ?? '';
      final qty = int.tryParse(qtyStr);

      final reorderStr = parsed['reorderLevel']?.toString().trim() ?? '';
      final reorder = int.tryParse(reorderStr);

      final sku = parsed['sku']?.toString().trim().toUpperCase() ?? '';
      if (sku.isNotEmpty && seenSkus.contains(sku)) {
        _errors.add(_RowError(row: rowNum + 1, message: 'Duplicate SKU in upload'));
        continue;
      }
      if (sku.isNotEmpty) seenSkus.add(sku);

      _parsedRows.add({
        'sku': sku,
        'name': name,
        'category': parsed['category']?.toString().trim() ?? 'General',
        'buyPrice': buyPrice ?? 0,
        'sellPrice': sellPrice,
        'quantity': qty ?? 0,
        'reorderLevel': reorder ?? 5,
        'unit': parsed['unit']?.toString().trim() ?? 'pcs',
      });
    }

    if (_parsedRows.isEmpty && _errors.isEmpty) {
      _errorMessage = 'No valid data rows found in the file.';
    }
  }

  Future<void> _doImport() async {
    final validRows = _parsedRows.where((r) => !_errors.any((e) =>
      r['name'] == null || (r['name'] as String).isEmpty
    )).toList();

    if (validRows.isEmpty) {
      setState(() => _errorMessage = 'No valid rows to import.');
      return;
    }

    setState(() => _importing = true);
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final result = await FunctionsService.call('importProducts', {
        'businessId': bizId,
        'products': validRows,
      });
      setState(() {
        _importedCount = result['imported'] as int? ?? 0;
        _importing = false;
      });
    } on FunctionsException catch (e) {
      setState(() { _errorMessage = e.message; _importing = false; });
    }
  }

  void _downloadSample() {
    final csv = const ListToCsvConverter().convert([
      _expectedColumns,
      ['BRK-001', 'Nails 3-inch', 'Hardware', '50', '80', '500', '100', 'kg'],
      ['BRK-002', 'Cement (50kg)', 'Building Materials', '550', '650', '200', '50', 'bag'],
      ['BRK-003', 'Paint White 20L', 'Paint', '1200', '1800', '30', '10', 'litre'],
      ['BRK-004', 'PVC Pipe 4-inch', 'Plumbing', '250', '400', '100', '20', 'piece'],
    ]);
    FilePicker.platform.saveFile(
      dialogTitle: 'Save sample template',
      fileName: 'product_import_template.csv',
      bytes: utf8.encode(csv),
    );
  }
}

class _RowError {
  final int row;
  final String message;
  const _RowError({required this.row, required this.message});
}
