import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../models/audit_log.dart';
import '../services/sync_service.dart';

// ─── Data model for a parsed (but not yet imported) row ──────────────────────
class _ParsedRow {
  final int rowIndex;
  final DateTime? date;
  final String? productName;
  final int? quantity;
  final double? unitPrice;
  final String? notes;
  final Product? matchedProduct; // null = no match found
  final String? error;

  _ParsedRow({
    required this.rowIndex,
    this.date,
    this.productName,
    this.quantity,
    this.unitPrice,
    this.notes,
    this.matchedProduct,
    this.error,
  });

  bool get isValid => error == null && matchedProduct != null && date != null && quantity != null && quantity! > 0;
}

class ExcelImportScreen extends StatefulWidget {
  final User currentUser;

  const ExcelImportScreen({super.key, required this.currentUser});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<_ParsedRow> _rows = [];
  String? _fileName;
  bool _isParsing = false;
  bool _isImporting = false;
  String? _parseError;
  List<Product> _products = [];

  int get _validCount => _rows.where((r) => r.isValid).length;
  int get _errorCount => _rows.where((r) => !r.isValid).length;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final p = await _db.readAllProducts();
    if (mounted) setState(() => _products = p);
  }

  // ── Case-insensitive product lookup ────────────────────────────────────────
  Product? _findProduct(String name) {
    final lower = name.trim().toLowerCase();
    try {
      return _products.firstWhere((p) => p.name.trim().toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }

  // ── Parse dd/mm/yyyy date ──────────────────────────────────────────────────
  DateTime? _parseDate(String raw) {
    // Accepts dd/mm/yyyy, dd-mm-yyyy, yyyy-mm-dd
    raw = raw.trim();
    try {
      if (raw.contains('/')) {
        final parts = raw.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } else if (raw.contains('-') && raw.length == 10) {
        // Could be yyyy-mm-dd or dd-mm-yyyy
        final parts = raw.split('-');
        if (parts[0].length == 4) {
          return DateTime.parse(raw); // ISO format
        } else {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      }
    } catch (_) {}
    return null;
  }

  String _cellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final v = cell.value;
    if (v is TextCellValue) return (v.value.text ?? '').trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is DateTimeCellValue) {
      return DateFormat('dd/MM/yyyy').format(
        DateTime(v.year, v.month, v.day),
      );
    }
    return v.toString().trim();
  }

  Future<void> _pickAndParse() async {
    setState(() { _isParsing = true; _parseError = null; _rows = []; _fileName = null; });

    try {
      // withData: true — returns bytes directly via content URI (no real path needed).
      // This avoids PlatformException(unknown_path) on Samsung/Android Downloads.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isParsing = false);
        return;
      }

      final file = result.files.first;
      setState(() => _fileName = file.name);

      // Resolve bytes — try in priority order to handle all Android storage locations
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (_) {}
      }
      if (bytes == null) {
        throw Exception(
          'Could not read the file.\n'
          'Please copy the .xlsx file to your phone\'s Downloads folder first, then try again.',
        );
      }

      final excel = Excel.decodeBytes(bytes);

      // Use the first sheet
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      if (sheet.rows.isEmpty) {
        setState(() { _parseError = 'The spreadsheet is empty.'; _isParsing = false; });
        return;
      }

      // Find headers (first non-empty row)
      final headerRow = sheet.rows.first;
      final headers = headerRow.map((c) => _cellString(c).toLowerCase()).toList();

      // Map column indices
      final dateCol = headers.indexWhere((h) => h.contains('date'));
      final productCol = headers.indexWhere((h) => h.contains('product'));
      final qtyCol = headers.indexWhere((h) => h.contains('qty') || h.contains('quantity'));
      final priceCol = headers.indexWhere((h) => h.contains('price') || h.contains('unit'));
      final notesCol = headers.indexWhere((h) => h.contains('note'));

      if (dateCol == -1 || productCol == -1 || qtyCol == -1) {
        setState(() {
          _parseError = 'Required columns not found.\n'
              'Expected: Date, Product Name, Quantity\n'
              'Found: ${headers.where((h) => h.isNotEmpty).join(', ')}';
          _isParsing = false;
        });
        return;
      }

      final parsed = <_ParsedRow>[];

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        // Skip completely empty rows
        final isEmpty = row.every((c) => _cellString(c).isEmpty);
        if (isEmpty) continue;

        String? rowError;

        // Date
        final rawDate = dateCol < row.length ? _cellString(row[dateCol]) : '';
        DateTime? date;
        if (rawDate.isEmpty) {
          rowError = 'Missing date';
        } else {
          date = _parseDate(rawDate);
          if (date == null) rowError = 'Invalid date "$rawDate" — use dd/mm/yyyy';
        }

        // Product name
        final productName = productCol < row.length ? _cellString(row[productCol]) : '';
        Product? matched;
        if (productName.isEmpty) {
          rowError ??= 'Missing product name';
        } else {
          matched = _findProduct(productName);
          if (matched == null) rowError ??= 'Product "$productName" not found in app';
        }

        // Quantity
        int? qty;
        final rawQty = qtyCol < row.length ? _cellString(row[qtyCol]) : '';
        if (rawQty.isEmpty) {
          rowError ??= 'Missing quantity';
        } else {
          qty = int.tryParse(rawQty.split('.').first);
          if (qty == null || qty <= 0) rowError ??= 'Invalid quantity "$rawQty"';
        }

        // Unit price (optional — falls back to product selling price)
        double? unitPrice;
        if (priceCol >= 0 && priceCol < row.length) {
          final rawPrice = _cellString(row[priceCol]);
          if (rawPrice.isNotEmpty) {
            unitPrice = double.tryParse(rawPrice.replaceAll(RegExp(r'[^\d.]'), ''));
          }
        }

        // Notes (optional)
        final notes = (notesCol >= 0 && notesCol < row.length) ? _cellString(row[notesCol]) : null;

        parsed.add(_ParsedRow(
          rowIndex: i + 1, // 1-based for display
          date: date,
          productName: productName.isEmpty ? null : productName,
          quantity: qty,
          unitPrice: unitPrice,
          notes: notes?.isEmpty == true ? null : notes,
          matchedProduct: matched,
          error: rowError,
        ));
      }

      setState(() {
        _rows = parsed;
        _isParsing = false;
      });
    } catch (e) {
      setState(() {
        _parseError = 'Failed to read file: $e';
        _isParsing = false;
      });
    }
  }

  Future<void> _importValid() async {
    if (_validCount == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Import $_validCount Sales?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'This will add $_validCount historical sales records to your database. '
          '${_errorCount > 0 ? '$_errorCount invalid rows will be skipped.' : ''}',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Import', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isImporting = true);

    int imported = 0;
    int failed = 0;
    final companyId = DatabaseHelper.instance.currentCompanyId;

    for (final row in _rows.where((r) => r.isValid)) {
      try {
        final product = row.matchedProduct!;
        final price = row.unitPrice ?? product.sellingPrice;
        final total = price * row.quantity!;

        final sale = Sale(
          companyId: companyId,
          productId: product.id!,
          productName: product.name,
          quantitySold: row.quantity!,
          unitPrice: price,
          totalAmount: total,
          saleDate: row.date!.toIso8601String(),
          notes: row.notes ?? 'Imported from Excel',
        );

        await _db.createSale(sale);
        imported++;
      } catch (_) {
        failed++;
      }
    }

    // Log the import action
    await _db.logAction(AuditLog(
      companyId: companyId,
      userId: widget.currentUser.id!,
      userName: widget.currentUser.fullName,
      action: 'excel_import',
      details: 'Imported $imported sales from $_fileName ($failed failed)',
      timestamp: DateTime.now().toIso8601String(),
    ));

    // Push new sales to Supabase
    await SyncService.instance.pushAll(companyId);

    setState(() => _isImporting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported $imported records${failed > 0 ? ', $failed failed' : ''}',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: failed == 0 ? const Color(0xFF4CAF50) : const Color(0xFFFFB300),
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context, true); // Signal refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Import Sales from Excel',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemplateCard(),
            const SizedBox(height: 24),
            _buildPickButton(),
            if (_parseError != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(_parseError!),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildSummaryBar(),
              const SizedBox(height: 16),
              _buildPreviewTable(),
              const SizedBox(height: 24),
              _buildImportButton(),
            ],
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                    color: Color(0xFFFFF8E1), shape: BoxShape.circle),
                child: const Icon(Icons.table_chart_outlined,
                    color: Color(0xFFFFB300), size: 20),
              ),
              const SizedBox(width: 12),
              Text('Required Excel Format',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeaderRow(),
          const SizedBox(height: 8),
          _buildExampleRow('15/03/2025', 'Coca-Cola 500ml', '12', '2.50', 'Morning shift'),
          _buildExampleRow('16/03/2025', 'Fanta Orange', '8', '', ''),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rules:',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                _buildRule('Date must be dd/mm/yyyy format'),
                _buildRule('Product Name must exactly match a product in the app'),
                _buildRule('Quantity must be a whole number greater than 0'),
                _buildRule('Unit Price is optional — uses product selling price if blank'),
                _buildRule('Notes is optional'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        _buildHeaderCell('Date', flex: 3),
        _buildHeaderCell('Product Name', flex: 4),
        _buildHeaderCell('Qty', flex: 1),
        _buildHeaderCell('Price', flex: 2),
        _buildHeaderCell('Notes', flex: 3),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        color: Colors.black,
        child: Text(text,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildExampleRow(String date, String product, String qty, String price, String notes) {
    return Row(
      children: [
        _buildDataCell(date, flex: 3),
        _buildDataCell(product, flex: 4),
        _buildDataCell(qty, flex: 1),
        _buildDataCell(price, flex: 2),
        _buildDataCell(notes, flex: 3),
      ],
    );
  }

  Widget _buildDataCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Text(text,
            style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 11, color: Color(0xFFFFB300))),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildPickButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isParsing ? null : _pickAndParse,
        icon: _isParsing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.upload_file_outlined),
        label: Text(
          _isParsing
              ? 'Reading file...'
              : (_fileName != null ? 'Change File' : 'Select Excel File (.xlsx)'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: GoogleFonts.poppins(
                    fontSize: 13, color: const Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('$_validCount',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4CAF50))),
                Text('Ready to import',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          Expanded(
            child: Column(
              children: [
                Text('${_rows.length}',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                Text('Total rows',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey[200]),
          Expanded(
            child: Column(
              children: [
                Text('$_errorCount',
                    style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _errorCount > 0
                            ? const Color(0xFFE53935)
                            : Colors.grey[400])),
                Text('Errors',
                    style: GoogleFonts.poppins(
                        fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Preview (${_rows.length} rows)',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const Divider(height: 1),
          ..._rows.take(50).map((row) {
            final hasError = !row.isValid;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: hasError
                    ? const Color(0xFFFFF3F3)
                    : const Color(0xFFF9FFF9),
                border: Border(
                    bottom: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(
                      hasError
                          ? Icons.error_outline
                          : Icons.check_circle_outline,
                      color: hasError
                          ? const Color(0xFFE53935)
                          : const Color(0xFF4CAF50),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (row.date != null)
                              _previewChip(fmt.format(row.date!),
                                  const Color(0xFFE3F2FD)),
                            if (row.matchedProduct != null)
                              _previewChip(row.matchedProduct!.name,
                                  const Color(0xFFFFF8E1))
                            else if (row.productName != null)
                              _previewChip(row.productName!, const Color(0xFFFFEBEE),
                                  textColor: const Color(0xFFE53935)),
                            if (row.quantity != null)
                              _previewChip('×${row.quantity}', Colors.grey[100]!),
                          ],
                        ),
                        if (hasError && row.error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Row ${row.rowIndex}: ${row.error}',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFFE53935)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_rows.length > 50)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '… and ${_rows.length - 50} more rows (not shown)',
                style: GoogleFonts.poppins(
                    fontSize: 12, color: Colors.grey[500],
                    fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewChip(String label, Color bg,
      {Color? textColor}) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: textColor ?? Colors.black87,
              fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_validCount == 0 || _isImporting) ? null : _importValid,
        icon: _isImporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.file_download_outlined),
        label: Text(
          _isImporting
              ? 'Importing...'
              : 'Import $_validCount Valid Records',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB300),
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.grey[200],
          disabledForegroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}
