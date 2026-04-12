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
  DateTime _selectedDate = DateTime.now();

  void _previousDay() => setState(
    () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
  );
  void _nextDay() => setState(
    () => _selectedDate = _selectedDate.add(const Duration(days: 1)),
  );
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder:
          (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: Colors.teal.shade700),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // Logic Export Excel (TIDAK DIUBAH)
  Future<void> _exportExcel(
    double grandMasuk,
    double grandKeluar,
    List<TransactionModel> transactions,
  ) async {
    try {
      final excel = Excel.createExcel();
      if (excel.tables.containsKey('Sheet1'))
        excel.rename('Sheet1', 'Laporan Harian');
      final Sheet sheetDetail = excel['Laporan Harian'];
      sheetDetail.appendRow([
        TextCellValue('LAPORAN TRANSAKSI HARIAN (DAY-TO-DAY)'),
      ]);
      sheetDetail.appendRow([
        TextCellValue('Tanggal:'),
        TextCellValue(DateFormat('dd MMMM yyyy').format(_selectedDate)),
      ]);
      sheetDetail.appendRow([]);
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
        TextCellValue('Nama Supplier'),
        TextCellValue('No. HP Supplier'),
        TextCellValue('Alamat Supplier'),
        TextCellValue('Surat Jalan'),
      ]);
      transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
          TextCellValue(t.supplierName ?? '-'),
          TextCellValue(t.supplierNumber ?? '-'),
          TextCellValue(t.supplierDetail ?? '-'),
          TextCellValue(t.suratJalan ?? '-'),
        ]);
      }
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Laporan "$filename" berhasil diunduh!'),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Gagal download: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Very soft slate background
      appBar: AppBar(
        title: const Text(
          "Laporan Jurnal Harian",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Navigasi Tanggal Modern
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _previousDay,
                  ),
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.teal.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: _nextDay,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<TransactionModel>>(
              stream: service.getTransactions(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                List<TransactionModel> dailyTransactions =
                    (snapshot.data ?? [])
                        .where(
                          (tx) =>
                              tx.date.year == _selectedDate.year &&
                              tx.date.month == _selectedDate.month &&
                              tx.date.day == _selectedDate.day,
                        )
                        .toList();

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
                    // Premium Gradient Summary Card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors:
                                saldoAkhir >= 0
                                    ? [Color(0xFF0F766E), Color(0xFF14B8A6)]
                                    : [Color(0xFFBE123C), Color(0xFFF43F5E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (saldoAkhir >= 0
                                      ? Colors.teal
                                      : Colors.red)
                                  .withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "SALDO NETTO HARI INI",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currency.format(saldoAkhir),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniStat(
                                    "Masuk",
                                    grandMasuk,
                                    Icons.arrow_circle_down_rounded,
                                    Colors.greenAccent,
                                  ),
                                  Container(
                                    height: 30,
                                    width: 1,
                                    color: Colors.white30,
                                  ),
                                  _buildMiniStat(
                                    "Keluar",
                                    grandKeluar,
                                    Icons.arrow_circle_up_rounded,
                                    Colors.redAccent.shade100,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Label Timeline
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history,
                            size: 20,
                            color: Colors.blueGrey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Riwayat Aktivitas (${dailyTransactions.length})",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // List Transaksi
                    Expanded(
                      child:
                          dailyTransactions.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_busy_rounded,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Tidak ada rekaman transaksi hari ini",
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  20,
                                ),
                                itemCount: dailyTransactions.length,
                                itemBuilder: (context, index) {
                                  final trx = dailyTransactions[index];
                                  final isPemasukan = trx.type == 'pemasukan';
                                  final cardColor =
                                      isPemasukan ? Colors.green : Colors.red;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header Item List
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor.withOpacity(0.05),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(20),
                                                  topRight: Radius.circular(20),
                                                ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cardColor.shade100,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isPemasukan
                                                      ? Icons.south_rounded
                                                      : Icons.north_rounded,
                                                  color: cardColor.shade700,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  trx.title.isNotEmpty
                                                      ? trx.title
                                                      : (isPemasukan
                                                          ? 'Stok Masuk'
                                                          : 'Stok Keluar'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                    color: cardColor.shade800,
                                                  ),
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    currency.format(trx.amount),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: cardColor.shade700,
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('HH:mm').format(
                                                      trx.createdAt.toDate(),
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Body Item List
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildInfoRow(
                                                Icons.inventory_2_rounded,
                                                "Barang",
                                                trx.itemName,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                Icons.store_rounded,
                                                "Tempat",
                                                trx.location,
                                                isHighlight: true,
                                              ),
                                              const SizedBox(height: 8),
                                              _buildInfoRow(
                                                Icons.tag,
                                                "Jumlah",
                                                "${trx.quantity.toInt()} ${trx.unit}  (Rp ${currency.format(trx.pricePerUnit)}/unit)",
                                              ),

                                              // Data Extra jika ada
                                              if ((trx.description != null &&
                                                      trx.description != '-' &&
                                                      trx
                                                          .description!
                                                          .isNotEmpty) ||
                                                  (trx.supplierName != null &&
                                                      trx.supplierName != '-' &&
                                                      trx
                                                          .supplierName!
                                                          .isNotEmpty) ||
                                                  (trx.suratJalan != null &&
                                                      trx.suratJalan != '-' &&
                                                      trx
                                                          .suratJalan!
                                                          .isNotEmpty)) ...[
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  child: Divider(
                                                    height: 1,
                                                    thickness: 1,
                                                  ),
                                                ),
                                                if (trx.description != null &&
                                                    trx.description != '-' &&
                                                    trx
                                                        .description!
                                                        .isNotEmpty) ...[
                                                  _buildInfoRow(
                                                    Icons.description,
                                                    "Catatan",
                                                    trx.description!,
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                if (trx.supplierName != null &&
                                                    trx.supplierName != '-' &&
                                                    trx
                                                        .supplierName!
                                                        .isNotEmpty) ...[
                                                  _buildInfoRow(
                                                    Icons.local_shipping,
                                                    "Supplier",
                                                    trx.supplierName!,
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                if (trx.supplierNumber !=
                                                        null &&
                                                    trx.supplierNumber != '-' &&
                                                    trx
                                                        .supplierNumber!
                                                        .isNotEmpty) ...[
                                                  _buildInfoRow(
                                                    Icons.phone,
                                                    "Telepon",
                                                    trx.supplierNumber!,
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                if (trx.supplierDetail !=
                                                        null &&
                                                    trx.supplierDetail != '-' &&
                                                    trx
                                                        .supplierDetail!
                                                        .isNotEmpty) ...[
                                                  _buildInfoRow(
                                                    Icons.map,
                                                    "Alamat",
                                                    trx.supplierDetail!,
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],
                                                if (trx.suratJalan != null &&
                                                    trx.suratJalan != '-' &&
                                                    trx.suratJalan!.isNotEmpty)
                                                  _buildInfoRow(
                                                    Icons.receipt,
                                                    "S. Jalan",
                                                    trx.suratJalan!,
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                    ),
                    // --- TOMBOL DOWNLOAD DENGAN DATA YANG BENAR ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.withOpacity(0.1),
                            blurRadius: 15,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Export Excel Hari Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),

                          // SEKARANG MENGIRIMKAN DATA TRANSAKSI ASLI
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
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          currency.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
        Icon(icon, size: 16, color: Colors.blueGrey.shade400),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            "$label",
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color:
                  isHighlight ? Colors.blue.shade700 : const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
