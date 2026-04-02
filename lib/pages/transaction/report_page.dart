import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';

// Model bantuan untuk merangkum data per Item
class ItemSummary {
  String itemName;
  int qtyMasuk = 0;
  double rpMasuk = 0;
  int qtyKeluar = 0;
  double rpKeluar = 0;

  ItemSummary(this.itemName);

  double get totalBersih => rpMasuk - rpKeluar;
}

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // Default filter ke bulan ini
  DateTime _selectedDate = DateTime.now();

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  // ==========================================
  // FUNGSI DOWNLOAD EXCEL (REKAP & DETAIL)
  // ==========================================
  Future<void> _exportExcel(
    List<ItemSummary> summaries,
    double grandMasuk,
    double grandKeluar,
    List<TransactionModel> transactions, // TAMBAHAN: Data mentah untuk sheet detail
  ) async {
    try {
      final excel = Excel.createExcel();
      
      // Hapus sheet default bawaan
      if (excel.tables.containsKey('Sheet1')) {
        excel.rename('Sheet1', 'Rekap');
      }

      // ==========================================
      // SHEET 1: REKAPITULASI (TOTAL PER BARANG)
      // ==========================================
      final Sheet sheetRekap = excel['Rekap'];

      // === HEADER REKAP ===
      sheetRekap.appendRow([
        TextCellValue('LAPORAN REKAPITULASI KEUANGAN & STOK'),
      ]);
      sheetRekap.appendRow([
        TextCellValue('Periode:'),
        TextCellValue(DateFormat('MMMM yyyy').format(_selectedDate)),
      ]);
      sheetRekap.appendRow([]); // Baris kosong

      // === JUDUL KOLOM REKAP ===
      sheetRekap.appendRow([
        TextCellValue('No.'),
        TextCellValue('Nama Barang'),
        TextCellValue('Jumlah (Qty) Masuk'),
        TextCellValue('Total Pemasukan (Rp)'),
        TextCellValue('Jumlah (Qty) Keluar'),
        TextCellValue('Total Pengeluaran (Rp)'),
        TextCellValue('Sisa Saldo (Rp)'),
      ]);

      // === DATA BARANG REKAP ===
      for (int i = 0; i < summaries.length; i++) {
        final item = summaries[i];
        sheetRekap.appendRow([
          IntCellValue(i + 1),
          TextCellValue(item.itemName),
          IntCellValue(item.qtyMasuk),
          IntCellValue(item.rpMasuk.toInt()),
          IntCellValue(item.qtyKeluar),
          IntCellValue(item.rpKeluar.toInt()),
          IntCellValue(item.totalBersih.toInt()),
        ]);
      }

      // === TOTAL REKAP ===
      sheetRekap.appendRow([]); // Baris kosong
      sheetRekap.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL PEMASUKAN'),
        IntCellValue(grandMasuk.toInt()),
      ]);
      sheetRekap.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL PENGELUARAN'),
        IntCellValue(grandKeluar.toInt()),
      ]);
      sheetRekap.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL BERSIH (Masuk - Keluar)'),
        IntCellValue((grandMasuk - grandKeluar).toInt()),
      ]);

      // ==========================================
      // SHEET 2: DETAIL TRANSAKSI (SEMUA DATA)
      // ==========================================
      final Sheet sheetDetail = excel['Detail Transaksi'];

      // === HEADER DETAIL ===
      sheetDetail.appendRow([
        TextCellValue('DATA TRANSAKSI RINCI (PEMASUKAN & PENGELUARAN)'),
      ]);
      sheetDetail.appendRow([
        TextCellValue('Periode:'),
        TextCellValue(DateFormat('MMMM yyyy').format(_selectedDate)),
      ]);
      sheetDetail.appendRow([]); // Baris kosong

      // === JUDUL KOLOM DETAIL ===
      sheetDetail.appendRow([
        TextCellValue('No.'),
        TextCellValue('Tanggal'),
        TextCellValue('Tipe Transaksi'),
        TextCellValue('Nama Barang / Judul'),
        TextCellValue('Jumlah (Qty)'),
        TextCellValue('Satuan'),
        TextCellValue('Harga Satuan (Rp)'),
        TextCellValue('Total (Rp)'),
        TextCellValue('Keterangan / Catatan'),
      ]);

      // Urutkan transaksi berdasarkan tanggal terlama ke terbaru
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // === ISI DATA DETAIL TRANSAKSI ===
      for (int i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        sheetDetail.appendRow([
          IntCellValue(i + 1),
          TextCellValue(DateFormat('dd-MMM-yyyy').format(t.date)),
          TextCellValue(t.type == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran'),
          TextCellValue(t.itemName.isNotEmpty ? t.itemName : t.title),
          IntCellValue(t.quantity.toInt()),
          TextCellValue(t.unit),
          IntCellValue(t.pricePerUnit.toInt()),
          IntCellValue(t.amount.toInt()),
          TextCellValue(t.description ?? ''),
        ]);
      }

      // Jadikan sheet 'Rekap' sebagai sheet utama saat Excel dibuka
      excel.setDefaultSheet('Rekap');

      final filename =
          'Laporan_Keuangan_${DateFormat('MMMyyyy').format(_selectedDate)}.xlsx';

      // Export berdasarkan platform
      if (kIsWeb) {
        // Web: Download langsung
        final excelBytes = excel.encode();
        if (excelBytes != null) {
          final blob = html.Blob([excelBytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.AnchorElement(href: url)
            ..setAttribute('download', filename)
            ..click();
          html.Url.revokeObjectUrl(url);
        }
      } else {
        // Mobile/Desktop: Simpan ke file
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$filename';
        final file = File(path);
        final excelBytes = excel.encode();
        if (excelBytes != null) {
          await file.writeAsBytes(excelBytes);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ File Excel "$filename" berhasil diunduh! Cek 2 Sheet di dalamnya.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          "Laporan Rekapitulasi",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. KONTROL BULAN (HEADER)
          // ==========================================
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.teal),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.teal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.teal),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. STREAM DATA TRANSAKSI
          // ==========================================
          Expanded(
            child: FutureBuilder<List<TransactionModel>>(
              // Memanggil data berdasarkan bulan yang dipilih di state
              future: service.getMonthlyTransactions(
                _selectedDate.year,
                _selectedDate.month,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<TransactionModel> transactions = snapshot.data ?? [];

                // Jika kosong, tampilkan UI kosong
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Tidak ada transaksi di bulan ini.",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // --- PROSES PERHITUNGAN REKAPITULASI ---
                Map<String, ItemSummary> summaryMap = {};
                double grandMasuk = 0;
                double grandKeluar = 0;

                for (var tx in transactions) {
                  final itemName =
                      tx.itemName.isNotEmpty ? tx.itemName : 'Barang Lainnya';

                  if (!summaryMap.containsKey(itemName)) {
                    summaryMap[itemName] = ItemSummary(itemName);
                  }

                  if (tx.type == 'pemasukan') {
                    summaryMap[itemName]!.qtyMasuk += tx.quantity.toInt();
                    summaryMap[itemName]!.rpMasuk += tx.amount;
                    grandMasuk += tx.amount;
                  } else if (tx.type == 'pengeluaran') {
                    summaryMap[itemName]!.qtyKeluar += tx.quantity.toInt();
                    summaryMap[itemName]!.rpKeluar += tx.amount;
                    grandKeluar += tx.amount;
                  }
                }

                List<ItemSummary> summaryList = summaryMap.values.toList();
                // Urutkan alfabetis
                summaryList.sort((a, b) => a.itemName.compareTo(b.itemName));

                double saldoAkhir = grandMasuk - grandKeluar;

                return Column(
                  children: [
                    // ==========================================
                    // 3. KARTU RINGKASAN GLOBAL (ATAS)
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearBinding(saldoAkhir),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "SISA SALDO BERSIH",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currency.format(saldoAkhir),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStat(
                                  "Pemasukan",
                                  grandMasuk,
                                  Icons.arrow_downward,
                                  Colors.greenAccent,
                                ),
                                Container(
                                  height: 40,
                                  width: 1,
                                  color: Colors.white30,
                                ),
                                _buildMiniStat(
                                  "Pengeluaran",
                                  grandKeluar,
                                  Icons.arrow_upward,
                                  Colors.redAccent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==========================================
                    // 4. LIST RINCIAN PER BARANG
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Rincian per Barang",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "${summaryList.length} Item",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: summaryList.length,
                        itemBuilder: (context, index) {
                          final item = summaryList[index];
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header Nama Barang
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2,
                                          color: Colors.teal,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  // Detail Masuk & Keluar
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildItemStatRow(
                                        "Masuk",
                                        item.qtyMasuk,
                                        item.rpMasuk,
                                        Colors.green,
                                      ),
                                      _buildItemStatRow(
                                        "Keluar",
                                        item.qtyKeluar,
                                        item.rpKeluar,
                                        Colors.red,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Total Bersih Barang
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          item.totalBersih >= 0
                                              ? Colors.blue.shade50
                                              : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "Saldo Item:",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          currency.format(item.totalBersih),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                item.totalBersih >= 0
                                                    ? Colors.blue.shade700
                                                    : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ==========================================
                    // 5. TOMBOL DOWNLOAD EXCEL (BAWAH)
                    // ==========================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: Text(
                            'Download Excel (${DateFormat('MMM yyyy').format(_selectedDate)})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          // KIRIM DATA TRANSAKSI MENTAH JUGA KE EXPORT EXCEL
                          onPressed:
                              () => _exportExcel(
                                summaryList,
                                grandMasuk,
                                grandKeluar,
                                transactions, // <--- Data detail disertakan
                              ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Bantuan ---
  LinearGradient LinearBinding(double saldoAkhir) {
    if (saldoAkhir >= 0) {
      return LinearGradient(
        colors: [Colors.teal.shade700, Colors.teal.shade400],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [Colors.orange.shade800, Colors.red.shade500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  Widget _buildMiniStat(
    String title,
    double amount,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          currency.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildItemStatRow(String label, int qty, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Qty: $qty',
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
        Text(
          currency.format(amount),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}