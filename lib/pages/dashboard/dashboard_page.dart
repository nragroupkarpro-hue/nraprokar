import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nra_pro_kar/pages/transaction/category_report.dart';
import 'package:nra_pro_kar/pages/transaction/report_page.dart';
import 'package:nra_pro_kar/pages/transaction/transaction_out_page.dart';
import 'package:nra_pro_kar/pages/transaction/transaction_in_page.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:collection/collection.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';

class DashboardPage extends StatefulWidget {
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final FirestoreService service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userName = auth.user?.email?.split('@')[0] ?? 'User';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal.shade600, Colors.teal.shade400],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selamat Datang',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _showExportDialog,
                          icon: const Icon(
                            Icons.file_download,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Export Excel',
                        ),
                        IconButton(
                          onPressed: () => auth.logout(),
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu Grid
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: GridView.count(
                    padding: const EdgeInsets.all(20),
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    children: [
                      _menuCard(
                        context,
                        "Pemasukan",
                        Icons.arrow_downward,
                        TransactionInPage(),
                        Colors.blue.shade400,
                      ),
                      _menuCard(
                        context,
                        "Pengeluaran",
                        Icons.arrow_upward,
                        TransactionOutPage(),
                        Colors.red.shade400,
                      ),
                      _menuCard(
                        context,
                        "Kategori",
                        Icons.inventory_2,
                        CategoryPage(),
                        Colors.orange.shade400,
                      ),
                      _menuCard(
                        context,
                        "Laporan",
                        Icons.assessment,
                        ReportPage(),
                        Colors.green.shade400,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() async {
    final allCats = await service.getCategories().first;
    String? selectedCategoryId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Pilih Barang untuk Export'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children:
                      allCats.map((cat) {
                        return RadioListTile<String>(
                          title: Text(cat.namaBarang),
                          subtitle: Text(
                            'Kode: ${cat.kodeBarang} | ${cat.satuan}',
                          ),
                          value: cat.id ?? '',
                          groupValue: selectedCategoryId,
                          onChanged: (value) {
                            setState(() {
                              selectedCategoryId = value;
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      selectedCategoryId == null
                          ? null
                          : () {
                            Navigator.pop(context);
                            _exportSingleBarang(selectedCategoryId!);
                          },
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportSingleBarang(String categoryId) async {
    try {
      final allTrx = await service.getTransactions().first;
      final allCats = await service.getCategories().first;

      final category = allCats.firstWhereOrNull((c) => c.id == categoryId);
      if (category == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Barang tidak ditemukan')));
        return;
      }

      // Filter transaksi untuk barang ini (masuk + keluar)
      final transactions =
          allTrx.where((t) => t.categoryId == categoryId).toList();
      transactions.sort((a, b) => a.date.compareTo(b.date));

      // Header info barang
      final rows = <List<dynamic>>[
        ['Nama Barang:', category.namaBarang],
        ['Satuan:', category.satuan],
        ['Lokasi:', category.lokasi],
        ['Kode Barang:', category.kodeBarang],
        [],
        [
          'No.',
          'Tanggal',
          'Keterangan',
          'Tipe',
          'Masuk - Kuantitas',
          'Masuk - Harga/unit',
          'Masuk - Jumlah Harga',
          'Keluar - Kuantitas',
          'Keluar - Harga/unit',
          'Keluar - Jumlah Harga',
          'Saldo - Kuantitas',
          'Saldo - Harga/unit',
          'Saldo - Jumlah Harga',
        ],
      ];

      double saldoQty = category.kuantitas.toDouble();
      double saldoHarga = category.hargaPerUnit.toDouble();

      for (int idx = 0; idx < transactions.length; idx++) {
        final tx = transactions[idx];
        final isMasuk = tx.type == 'pemasukan';
        final isKeluar = tx.type == 'pengeluaran';

        double masukQty = isMasuk ? tx.quantity.toDouble() : 0;
        double masukHarga = isMasuk ? tx.pricePerUnit.toDouble() : 0;
        double masukJumlah = masukQty * masukHarga;

        double keluarQty = isKeluar ? tx.quantity.toDouble() : 0;
        double keluarHarga = isKeluar ? tx.pricePerUnit.toDouble() : 0;
        double keluarJumlah = keluarQty * keluarHarga;

        // Update saldo
        if (isMasuk) {
          saldoQty += tx.quantity.toDouble();
        } else if (isKeluar) {
          saldoQty -= tx.quantity.toDouble();
        }
        saldoHarga = tx.pricePerUnit.toDouble();

        rows.add([
          (idx + 1).toString(),
          DateFormat('d-MMM-yy').format(tx.date),
          tx.title.isEmpty ? tx.itemName : tx.title,
          isMasuk ? 'Masuk' : 'Keluar',
          masukQty > 0 ? masukQty.toInt() : '',
          masukHarga > 0 ? masukHarga.toStringAsFixed(0) : '',
          masukJumlah > 0 ? masukJumlah.toStringAsFixed(0) : '',
          keluarQty > 0 ? keluarQty.toInt() : '',
          keluarHarga > 0 ? keluarHarga.toStringAsFixed(0) : '',
          keluarJumlah > 0 ? keluarJumlah.toStringAsFixed(0) : '',
          saldoQty.toInt(),
          saldoHarga.toStringAsFixed(0),
          (saldoQty * saldoHarga).toStringAsFixed(0),
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final filename =
          '${category.namaBarang}_${DateFormat('dd-MM-yyyy').format(DateTime.now())}.csv';

      if (kIsWeb) {
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', filename)
              ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$filename';
        final file = File(path);
        await file.writeAsString(csv);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Export ${category.namaBarang} berhasil'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, st) {
      debugPrint('export error: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Widget page,
    Color color,
  ) {
    return GestureDetector(
      onTap:
          () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.8), color],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              color: color.withOpacity(0.3),
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                ),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 48, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Laporan ${title.toLowerCase()} Anda',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
