import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import '../models/transaction_model.dart';

Future<void> generateReport({
  required int year,
  required int month,
  required int income,
  required int expense,
  List<TransactionModel>? transactions,
  String? type,
}) async {
  final pdf = pw.Document();
  final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final title =
      'Laporan ${type == null ? '' : (type == 'pengeluaran' ? 'Pengeluaran' : 'Pemasukan')} ${DateFormat('MMMM yyyy').format(DateTime(year, month))}';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build:
          (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Ringkasan',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        'Pemasukan',
                        style: pw.TextStyle(color: PdfColors.green),
                      ),
                      pw.Text(
                        formatter.format(income),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Pengeluaran',
                        style: pw.TextStyle(color: PdfColors.red),
                      ),
                      pw.Text(
                        formatter.format(expense),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'Saldo',
                        style: pw.TextStyle(color: PdfColors.blue),
                      ),
                      pw.Text(
                        formatter.format(income - expense),
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              if (transactions != null && transactions.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Detail Transaksi',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                // Legend to indicate types
                pw.Row(
                  children: [
                    pw.Container(
                      width: 12,
                      height: 12,
                      decoration: pw.BoxDecoration(color: PdfColors.green),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text('Pemasukan', style: pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(width: 16),
                    pw.Container(
                      width: 12,
                      height: 12,
                      decoration: pw.BoxDecoration(color: PdfColors.red),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text('Pengeluaran', style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.SizedBox(height: 10),
                // Build table with colored 'Tipe' badges for clarity
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    // header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Tanggal',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Item',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Qty',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Harga/Unit',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Total',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            'Tipe',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // data rows
                    ...transactions.map((t) {
                      final isExpense = t.type == 'pengeluaran';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(
                              DateFormat('dd/MM/yyyy').format(t.date),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(t.itemName),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('${t.quantity.toInt()} ${t.unit}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(formatter.format(t.pricePerUnit)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(formatter.format(t.amount)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: pw.BoxDecoration(
                                color:
                                    isExpense ? PdfColors.red : PdfColors.green,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                isExpense ? 'Pengeluaran' : 'Pemasukan',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ],
            ],
          ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) async => pdf.save());
}
