import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'widgets.dart';

class ReceiptPhoto {
  ReceiptPhoto({
    required this.id,
    required this.name,
    required this.originalType,
    required this.image,
    required this.bytes,
    required this.width,
    required this.height,
    this.transactionId = '',
    this.createdAt,
  });
  final String id, name, originalType, image, transactionId;
  final int bytes, width, height;
  final DateTime? createdAt;
  factory ReceiptPhoto.fromMap(String id, Map<String, dynamic> data) =>
      ReceiptPhoto(
        id: id,
        name: data['name'] as String,
        originalType: data['originalType'] as String,
        image: data['image'] as String,
        bytes: data['bytes'] as int,
        width: data['width'] as int,
        height: data['height'] as int,
        transactionId: data['transactionId'] as String? ?? '',
        createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      );
  late final Uint8List imageBytes = base64Decode(image.split(',').last);
  String get format => switch (originalType) {
    'image/png' => 'PNG → JPEG',
    'image/webp' => 'WebP → JPEG',
    'image/heic' || 'image/heif' => 'HEIC → JPEG',
    _ => 'JPEG',
  };
  Map<String, dynamic> createData(String parentId) => {
    'name': name,
    'originalType': originalType,
    'image': image,
    'bytes': bytes,
    'width': width,
    'height': height,
    'transactionId': parentId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

Future<Uint8List> receiptPdf(List<ReceiptPhoto> receipts) async {
  if (receipts.isEmpty) throw ArgumentError('No receipts');
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'),
  );
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
  );
  for (final receipt in receipts) {
    final image = pw.MemoryImage(receipt.imageBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'هم‌نوا · رسید',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(receipt.name, style: const pw.TextStyle(fontSize: 11)),
              if (receipt.createdAt != null)
                pw.Text(
                  dateLabel(receipt.createdAt!),
                  style: const pw.TextStyle(fontSize: 11),
                ),
              pw.SizedBox(height: 16),
              pw.Expanded(child: pw.Image(image, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 12),
              pw.Text(
                'نسخهٔ فشردهٔ رسید',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
  }
  return pdf.save();
}
