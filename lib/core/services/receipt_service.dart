import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptData {
  final String storeName;
  final String storePhone;
  final DateTime date;
  final String cashier;
  final String receiptNumber;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final String paymentMethod;

  const ReceiptData({
    required this.storeName,
    required this.storePhone,
    required this.date,
    required this.cashier,
    required this.receiptNumber,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.grandTotal,
    required this.paymentMethod,
  });
}

class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final double subtotal;

  const ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.subtotal,
  });
}

class ReceiptService {
  static Future<List<int>> generateEscPos(ReceiptData data, {String paperSize = '58mm'}) async {
    final profile = await CapabilityProfile.load();
    final size = paperSize == '80mm' ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(size, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      data.storeName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );

    if (data.storePhone.isNotEmpty) {
      bytes += generator.text(
        'Tel: ${data.storePhone}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    final timeStr = '${data.date.day}/${data.date.month}/${data.date.year} ${data.date.hour}:${data.date.minute}';
    bytes += generator.text(timeStr, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Cashier: ${data.cashier}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Receipt: ${data.receiptNumber}', styles: const PosStyles(align: PosAlign.center));

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Qty', width: 1, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Price', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    for (final item in data.items) {
      final name = item.name.length > 14 ? '${item.name.substring(0, 14)}..' : item.name;
      bytes += generator.row([
        PosColumn(text: '${item.quantity}', width: 1, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: name, width: 5),
        PosColumn(text: item.price.toStringAsFixed(0), width: 3, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: item.subtotal.toStringAsFixed(0), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr();

    if (data.discount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 6, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: '-${data.discount.toStringAsFixed(0)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    if (data.tax > 0) {
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 6, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: data.tax.toStringAsFixed(0), width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: data.grandTotal.toStringAsFixed(0), width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);

    bytes += generator.text('Payment: ${data.paymentMethod.toUpperCase()}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.emptyLines(1);
    bytes += generator.text('Thank You For Shopping', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.emptyLines(2);
    bytes += generator.cut();

    return bytes;
  }

  static Future<Uint8List> generatePdf(ReceiptData data) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(data.storeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            if (data.storePhone.isNotEmpty)
              pw.Text('Tel: ${data.storePhone}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.Text('${data.date.day}/${data.date.month}/${data.date.year}  ${data.date.hour}:${data.date.minute}',
              style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Cashier: ${data.cashier}', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Receipt: ${data.receiptNumber}', style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            ]),
            ...data.items.map((item) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('${item.quantity}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text(item.name, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(item.price.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10)),
                pw.Text(item.subtotal.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10)),
              ],
            )),
            pw.Divider(),
            if (data.discount > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('Discount: -${data.discount.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            if (data.tax > 0)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
                pw.Text('Tax: ${data.tax.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 10)),
              ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
              pw.Text('TOTAL: ${data.grandTotal.toStringAsFixed(0)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            ]),
            pw.SizedBox(height: 8),
            pw.Text('Payment: ${data.paymentMethod.toUpperCase()}', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 16),
            pw.Text('Thank You For Shopping',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<bool> printViaBluetooth(List<int> bytes) async {
    try {
      final bluetooth = BlueThermalPrinter.instance;
      final connected = await bluetooth.isConnected;
      if (connected != true) {
        final devices = await bluetooth.getBondedDevices();
        if (devices.isEmpty) return false;
        await bluetooth.connect(devices.first);
      }
      await bluetooth.writeBytes(Uint8List.fromList(bytes));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> printViaWifi(String ip, int port, List<int> bytes) async {
    final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    socket.add(bytes);
    await socket.flush();
    await socket.close();
  }

  static Future<void> sharePdf(ReceiptData data) async {
    final pdfBytes = await generatePdf(data);
    await Printing.sharePdf(bytes: pdfBytes, filename: 'receipt_${data.receiptNumber}.pdf');
  }
}
