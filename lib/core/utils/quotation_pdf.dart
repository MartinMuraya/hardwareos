import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/quotation.dart';
import '../models/quotation_item.dart';

Future<Uint8List> generateQuotationPdf(Quotation q) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (ctx) => [
        _header(q),
        pw.SizedBox(height: 32),
        _companyInfo(),
        pw.SizedBox(height: 16),
        _customerInfo(q),
        pw.SizedBox(height: 24),
        _itemsTable(q.items),
        pw.SizedBox(height: 16),
        _totals(q),
        if (q.notes.isNotEmpty) ...[
          pw.SizedBox(height: 24),
          _notes(q),
        ],
        pw.SizedBox(height: 24),
        _terms(q),
        pw.SizedBox(height: 32),
        _footer(q),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _header(Quotation q) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('QUOTATION',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(q.quotationNumber,
            style: pw.TextStyle(
              fontSize: 14,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _statusColor(q.status),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Text(q.statusLabel.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _companyInfo() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('YOUR BUSINESS NAME',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('123 Business Street, Nairobi',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.Text('Phone: +254 712 345 678',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
        pw.Text('Email: info@hardwareos.com',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
      ],
    ),
  );
}

pw.Widget _customerInfo(Quotation q) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('BILL TO',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(q.customerName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            if (q.customerPhone.isNotEmpty)
              pw.Text(q.customerPhone,
                style: pw.TextStyle(fontSize: 11, color: PdfColors.grey600)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('DATE',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text('${q.createdAt.day}/${q.createdAt.month}/${q.createdAt.year}',
              style: const pw.TextStyle(fontSize: 12)),
            if (q.validUntil != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('VALID UNTIL',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey500,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('${q.validUntil!.day}/${q.validUntil!.month}/${q.validUntil!.year}',
                style: const pw.TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ],
    ),
  );
}

pw.Widget _itemsTable(List<QuotationItem> items) {
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300),
      bottom: pw.BorderSide(color: PdfColors.grey300),
    ),
    children: [
      _tableRow(
        ['#', 'Item', 'Qty', 'Unit Price', 'Total'],
        isHeader: true,
      ),
      ...items.asMap().entries.map((entry) {
        final i = entry.key + 1;
        final item = entry.value;
        return _tableRow([
          '$i',
          item.name,
          '${item.quantity}',
          'KES ${item.unitPrice.toStringAsFixed(2)}',
          'KES ${item.total.toStringAsFixed(2)}',
        ]);
      }),
    ],
  );
}

pw.TableRow _tableRow(List<String> cells, {bool isHeader = false}) {
  return pw.TableRow(
    children: cells.asMap().entries.map((entry) {
      final i = entry.key;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        alignment: i == 0 ? pw.Alignment.center : (i >= 2 ? pw.Alignment.centerRight : pw.Alignment.centerLeft),
        child: pw.Text(
          entry.value,
          style: pw.TextStyle(
            fontSize: isHeader ? 10 : 11,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.grey600 : PdfColors.black,
          ),
        ),
      );
    }).toList(),
  );
}

pw.Widget _totals(Quotation q) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey50,
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _totalRow('Subtotal', q.subtotal),
        if (q.discountAmount > 0)
          _totalRow('Discount (${q.discountType == 'percentage' ? '${q.discount}%' : 'KES ${q.discount.toStringAsFixed(2)}'})', -q.discountAmount),
        pw.Divider(height: 16),
        _totalRow('Total', q.total, bold: true, color: PdfColors.blue800),
      ],
    ),
  );
}

pw.Widget _totalRow(String label, double amount, {bool bold = false, PdfColor? color}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(label,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.SizedBox(width: 40),
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            'KES ${amount.abs().toStringAsFixed(2)}',
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _notes(Quotation q) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('NOTES',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey500,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(q.notes,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      ],
    ),
  );
}

pw.Widget _terms(Quotation q) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('TERMS & CONDITIONS',
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey500,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(q.terms,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      ],
    ),
  );
}

pw.Widget _footer(Quotation q) {
  return pw.Column(
    children: [
      pw.Divider(),
      pw.SizedBox(height: 12),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated by HardwareOS',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
          pw.Text('Page 1 of 1',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
        ],
      ),
    ],
  );
}

PdfColor _statusColor(String status) {
  switch (status) {
    case 'draft':    return PdfColors.orange;
    case 'sent':     return PdfColors.blue;
    case 'accepted': return PdfColors.green;
    case 'rejected': return PdfColors.red;
    case 'converted':return PdfColors.purple;
    default:         return PdfColors.grey;
  }
}
