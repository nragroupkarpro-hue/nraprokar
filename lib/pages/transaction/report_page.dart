import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:excel/excel.dart';

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';

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

  // --- FILTER HARIAN (DAY-TO-DAY) ---
  DateTime _selectedDate = DateTime.now();

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ==========================================
  // FUNGSI DOWNLOAD EXCEL (LAPORAN HARIAN)
  // ==========================================
  Future<void> _exportExcel(
    double grandMasuk,
    double grandKeluar,
    List<TransactionModel> transactions,
  ) async {
    try {
      final excel = Excel.createExcel();

      if (excel.tables.containsKey('Sheet1')) {
        excel.rename('Sheet1', 'Laporan Harian');
      }

      final Sheet sheetDetail = excel['Laporan Harian'];

      // === HEADER DETAIL ===
      sheetDetail.appendRow([
        TextCellValue('LAPORAN TRANSAKSI HARIAN (DAY-TO-DAY)'),
      ]);
      sheetDetail.appendRow([
        TextCellValue('Tanggal:'),
        TextCellValue(DateFormat('dd MMMM yyyy').format(_selectedDate)),
      ]);
      sheetDetail.appendRow([]); // Baris kosong

      // === JUDUL KOLOM ===
      sheetDetail.appendRow([
        TextCellValue('No.'),
        TextCellValue('Tipe Transaksi'),
        TextCellValue('Judul Transaksi'),
        TextCellValue('Nama Barang'),
        TextCellValue('Asal Tempat (Lokasi)'),
        TextCellValue('Jumlah (Qty)'),
        TextCellValue('Satuan'),
        TextCellValue('Harga Satuan (Rp)'),
        TextCellValue('Total (Rp)'),
        TextCellValue('Keterangan / Catatan'),
        // TIGA KOLOM BARU UNTUK SUPPLIER DAN SURAT JALAN
        TextCellValue('Nama Supplier'),
        TextCellValue('No. HP Supplier'),
        TextCellValue('Alamat Supplier'),
        TextCellValue('Surat Jalan'),
      ]);

      // Urutkan transaksi berdasarkan waktu
      transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // === ISI DATA TRANSAKSI ===
      for (int i = 0; i < transactions.length; i++) {
        final t = transactions[i];
        sheetDetail.appendRow([
          IntCellValue(i + 1),
          TextCellValue(t.type == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran'),
          TextCellValue(t.title.isNotEmpty ? t.title : '-'),
          TextCellValue(t.itemName),
          TextCellValue(t.location),
          IntCellValue(t.quantity.toInt()),
          TextCellValue(t.unit),
          IntCellValue(t.pricePerUnit.toInt()),
          IntCellValue(t.amount.toInt()),
          TextCellValue(t.description ?? '-'),
          // ISI DATA SUPPLIER DAN SURAT JALAN
          TextCellValue(t.supplierName ?? '-'),
          TextCellValue(t.supplierNumber ?? '-'),
          TextCellValue(t.supplierDetail ?? '-'),
          TextCellValue(t.suratJalan ?? '-'),
        ]);
      }

      // === TOTAL HARIAN ===
      sheetDetail.appendRow([]);
      sheetDetail.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL PEMASUKAN HARI INI'),
        IntCellValue(grandMasuk.toInt()),
      ]);
      sheetDetail.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('TOTAL PENGELUARAN HARI INI'),
        IntCellValue(grandKeluar.toInt()),
      ]);
      sheetDetail.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('SALDO BERSIH HARI INI'),
        IntCellValue((grandMasuk - grandKeluar).toInt()),
      ]);

      excel.setDefaultSheet('Laporan Harian');

      final filename =
          'Laporan_Harian_${DateFormat('dd_MM_yyyy').format(_selectedDate)}.xlsx';

      if (kIsWeb) {
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
            content: Text('✅ Laporan Excel "$filename" berhasil diunduh!'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Laporan Day-to-Day",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. KONTROL TANGGAL (HARIAN)
          // ==========================================
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _previousDay,
                  tooltip: 'Hari Sebelumnya',
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _nextDay,
                  tooltip: 'Hari Berikutnya',
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. STREAM DATA TRANSAKSI
          // ==========================================
          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: service.getTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                }

                // FILTER DATA HANYA UNTUK HARI YANG DIPILIH
                List<TransactionModel> allTransactions = snapshot.data ?? [];
                List<TransactionModel> dailyTransactions =
                    allTransactions.where((tx) {
                      return tx.date.year == _selectedDate.year &&
                          tx.date.month == _selectedDate.month &&
                          tx.date.day == _selectedDate.day;
                    }).toList();

                double grandMasuk = 0;
                double grandKeluar = 0;

                for (var tx in dailyTransactions) {
                  if (tx.type == 'pemasukan')
                    grandMasuk += tx.amount;
                  else if (tx.type == 'pengeluaran')
                    grandKeluar += tx.amount;
                }

                double saldoAkhir = grandMasuk - grandKeluar;

                return Column(
                  children: [
                    // =============================================
                    // 3. KARTU RINGKASAN HARIAN (ATAS)
                    // =============================================
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                saldoAkhir >= 0
                                    ? [
                                      Theme.of(context).colorScheme.primary,
                                      Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer,
                                    ]
                                    : [
                                      Colors.orange.shade800,
                                      Colors.red.shade500,
                                    ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                              "SALDO BERSIH HARI INI",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
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
                    // 4. LIST DETAIL TRANSAKSI HARIAN
                    // ==========================================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Rincian Transaksi Hari Ini",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "${dailyTransactions.length} Data",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child:
                          dailyTransactions.isEmpty
                              ? Center(
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
                                      "Tidak ada aktivitas di hari ini.",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: dailyTransactions.length,
                                itemBuilder: (context, index) {
                                  final trx = dailyTransactions[index];
                                  final isPemasukan = trx.type == 'pemasukan';
                                  final cardColor =
                                      isPemasukan ? Colors.green : Colors.red;

                                  return Card(
                                    elevation: 1,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header Transaksi
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cardColor.withOpacity(
                                                    0.1,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  isPemasukan
                                                      ? Icons.arrow_downward
                                                      : Icons.arrow_upward,
                                                  color: cardColor,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trx.title.isNotEmpty
                                                          ? trx.title
                                                          : (isPemasukan
                                                              ? 'Stok Masuk'
                                                              : 'Stok Keluar'),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    Text(
                                                      DateFormat(
                                                        'HH:mm',
                                                      ).format(
                                                        trx.createdAt.toDate(),
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                currency.format(trx.amount),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: cardColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            child: Divider(height: 1),
                                          ),

                                          // Info Detail: Tempat, Barang, Qty, Deskripsi
                                          _buildInfoRow(
                                            Icons.inventory_2,
                                            "Barang",
                                            trx.itemName,
                                          ),
                                          const SizedBox(height: 6),
                                          _buildInfoRow(
                                            Icons.store,
                                            "Tempat",
                                            trx.location,
                                            isHighlight: true,
                                          ),
                                          const SizedBox(height: 6),
                                          _buildInfoRow(
                                            Icons.tag,
                                            "Jumlah",
                                            "${trx.quantity.toInt()} ${trx.unit}  (Rp ${currency.format(trx.pricePerUnit)}/unit)",
                                          ),

                                          if (trx.description != null &&
                                              trx.description != '-' &&
                                              trx.description!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.description,
                                              "Catatan",
                                              trx.description!,
                                            ),
                                          ],

                                          // --- TAMPILAN FIELD BARU (SUPPLIER & SURAT JALAN) ---
                                          if (trx.supplierName != null &&
                                              trx.supplierName != '-' &&
                                              trx.supplierName!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.local_shipping,
                                              "Supplier",
                                              trx.supplierName!,
                                            ),
                                          ],
                                          if (trx.supplierNumber != null &&
                                              trx.supplierNumber != '-' &&
                                              trx
                                                  .supplierNumber!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.phone,
                                              "No. Telp",
                                              trx.supplierNumber!,
                                            ),
                                          ],
                                          if (trx.supplierDetail != null &&
                                              trx.supplierDetail != '-' &&
                                              trx
                                                  .supplierDetail!
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.map,
                                              "Alamat",
                                              trx.supplierDetail!,
                                            ),
                                          ],
                                          if (trx.suratJalan != null &&
                                              trx.suratJalan != '-' &&
                                              trx.suratJalan!.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            _buildInfoRow(
                                              Icons.receipt,
                                              "Surat Jalan",
                                              trx.suratJalan!,
                                            ),
                                          ],
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
                        color: Theme.of(context).colorScheme.surface,
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
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.download, color: Colors.white),
                          label: const Text(
                            'Download Excel Hari Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed:
                              dailyTransactions.isEmpty
                                  ? null
                                  : () => _exportExcel(
                                    grandMasuk,
                                    grandKeluar,
                                    dailyTransactions,
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

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? Colors.blue.shade700 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
