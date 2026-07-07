import 'package:avogs/core/utils/formatters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptPdfService {
  Future<void> shareSalesReceipt({
    required String reference,
    required String customerName,
    required String storeCode,
    required String documentDate,
    required List<ReceiptLine> lines,
    required double total,
    String? paymentMethod,
    String? currency,
  }) async {
    final doc = _buildDoc(
      title: "AVO'Gs Sale",
      reference: reference,
      subtitle: customerName,
      meta: [
        'Store: $storeCode',
        'Date: $documentDate',
        if (paymentMethod != null) 'Payment: $paymentMethod',
      ],
      lines: lines,
      total: total,
    );
    final bytes = await doc.save();
    final filename = '$reference.pdf';
    await _sharePdf(bytes, filename, subject: reference);
  }

  Future<void> printSalesReceipt({
    required String reference,
    required String customerName,
    required String storeCode,
    required String documentDate,
    required List<ReceiptLine> lines,
    required double total,
    String? paymentMethod,
    String? currency,
  }) async {
    final doc = _buildDoc(
      title: "AVO'Gs Sale",
      reference: reference,
      subtitle: customerName,
      meta: [
        'Store: $storeCode',
        'Date: $documentDate',
        if (paymentMethod != null) 'Payment: $paymentMethod',
      ],
      lines: lines,
      total: total,
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Document _buildDoc({
    required String title,
    required String reference,
    required String subtitle,
    required List<String> meta,
    required List<ReceiptLine> lines,
    required double total,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(reference, style: const pw.TextStyle(fontSize: 10)),
              pw.Text(subtitle),
              for (final line in meta)
                pw.Text(line, style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              for (final line in lines)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '${line.description}\n${line.quantity} x ${formatMoney(line.unitPrice)}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                    pw.Text(
                      formatMoney(line.total),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    formatMoney(total),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  'Thank you!',
                  style: pw.TextStyle(color: PdfColor.fromInt(0xFF1B3A2A)),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  Future<void> _sharePdf(
    List<int> bytes,
    String filename, {
    String? subject,
  }) async {
    final data = Uint8List.fromList(bytes);
    final xFile = XFile.fromData(
      data,
      name: filename,
      mimeType: 'application/pdf',
    );

    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: subject,
        ),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, filename);
    await xFile.saveTo(path);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path, mimeType: 'application/pdf', name: filename)],
        subject: subject,
      ),
    );
  }
}

class ReceiptLine {
  const ReceiptLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double total;
}

final receiptPdfServiceProvider = Provider((_) => ReceiptPdfService());
