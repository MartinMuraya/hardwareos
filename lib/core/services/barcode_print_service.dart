import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class BarcodePrintService {
  /// Generates a PDF containing a single barcode label.
  /// Typically printed on a 50mm x 30mm or 80mm x 40mm thermal label.
  static Future<Uint8List> generateLabelPdf(
      Product product, String businessName) async {
    final pdf = pw.Document();

    // Standard thermal label size (approx 50x30 mm)
    // 1 mm = 2.83465 points
    const pageFormat =
        PdfPageFormat(50 * 2.83465, 30 * 2.83465, marginAll: 2 * 2.83465);

    // Use SKU or the first barcode
    final codeToPrint = product.barcodes.isNotEmpty
        ? product.barcodes.first
        : (product.sku.isNotEmpty ? product.sku : product.id.substring(0, 8));

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(businessName,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                pw.Text(product.name,
                    style: const pw.TextStyle(fontSize: 7),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip),
                pw.SizedBox(height: 2),
                pw.BarcodeWidget(
                  color: PdfColor.fromHex("#000000"),
                  barcode: pw.Barcode.code128(),
                  data: codeToPrint,
                  width: 80,
                  height: 30,
                  drawText: true,
                  textStyle: const pw.TextStyle(fontSize: 6),
                ),
                pw.SizedBox(height: 2),
                pw.Text('KES ${product.sellingPrice.toStringAsFixed(0)}',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Triggers the browser/system print dialog with the generated label.
  static Future<void> printLabel(Product product, String businessName) async {
    final pdfBytes = await generateLabelPdf(product, businessName);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Label_${product.name}',
    );
  }
}
