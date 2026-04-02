import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';

class TransactionDataPage extends StatefulWidget {
  const TransactionDataPage({Key? key}) : super(key: key);

  @override
  State<TransactionDataPage> createState() => _TransactionDataPageState();
}

class _TransactionDataPageState extends State<TransactionDataPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  int _currentPage = 0;
  static const int _itemsPerPage = 7;

  // Variable tab yang sedang aktif
  String _currentType = 'pemasukan';

  // Variables untuk form Add/Edit
  String? selectedCategoryId;
  int quantity = 0;
  CategoryModel? _foundCategory;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final itemCodeController = TextEditingController();
  final priceController = TextEditingController();
  DateTime? _selectedDate;

  int _filterMode = 0;
  DateTime? _selectedFilter;
  final descriptionFilterController = TextEditingController();

  void _resetPage() {
    setState(() => _currentPage = 0);
  }

  // ==========================================
  // FUNGSI EXPORT KE EXCEL (CSV)
  // ==========================================
  Future<void> _exportData() async {
    try {
      // Ambil semua data transaksi dari Firebase
      final allTrx = await service.getTransactions().first;
      
      // Filter transaksi jika ada pencarian bulan atau teks
      List<TransactionModel> transactions = allTrx;

      if (_selectedFilter != null && _filterMode == 1) {
        transactions = transactions.where((trx) =>
            trx.date.year == _selectedFilter!.year &&
            trx.date.month == _selectedFilter!.month).toList();
      }

      if (descriptionFilterController.text.isNotEmpty) {
        final filterText = descriptionFilterController.text.toLowerCase();
        transactions = transactions.where((trx) =>
            trx.title.toLowerCase().contains(filterText) ||
            trx.itemName.toLowerCase().contains(filterText) ||
            (trx.description?.toLowerCase().contains(filterText) ?? false)).toList();
      }

      // Urutkan dari tanggal terlama ke terbaru
      transactions.sort((a, b) => a.date.compareTo(b.date));

      double totalPemasukan = 0;
      double totalPengeluaran = 0;

      final rows = <List<dynamic>>[];
      
      // Membuat Header Info di dalam Excel
      rows.add(['LAPORAN DATA TRANSAKSI GABUNGAN']);
      rows.add([
        'Periode Filter:', 
        _selectedFilter != null && _filterMode == 1 ? DateFormat('MMMM yyyy').format(_selectedFilter!) : 'Semua Waktu'
      ]);
      rows.add([]); // Baris kosong

      // Membuat Header Kolom Tabel
      rows.add([
        'No.',
        'Tanggal',
        'Tipe',
        'Judul Transaksi',
        'Nama Barang',
        'Satuan',
        'Jumlah (Qty)',
        'Harga/Unit (Rp)',
        'Total Harga (Rp)',
        'Keterangan'
      ]);

      // Memasukkan isi data ke baris-baris Excel
      for (int i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
        
        // Akumulasi Total
        if (tx.type == 'pemasukan') {
          totalPemasukan += tx.amount;
        } else if (tx.type == 'pengeluaran') {
          totalPengeluaran += tx.amount;
        }

        rows.add([
          (i + 1).toString(),
          DateFormat('dd-MMM-yyyy').format(tx.date),
          tx.type == 'pemasukan' ? 'Pemasukan' : 'Pengeluaran',
          tx.title.isNotEmpty ? tx.title : tx.itemName,
          tx.itemName,
          tx.unit,
          tx.quantity.toInt(),
          tx.pricePerUnit.toStringAsFixed(0),
          tx.amount.toStringAsFixed(0),
          tx.description ?? '',
        ]);
      }

      // Baris kosong sebelum rekap Total
      rows.add([]);
      
      // Memasukkan Rekap Total Gabungan
      rows.add(['', '', '', '', '', '', '', 'TOTAL PEMASUKAN', totalPemasukan.toStringAsFixed(0)]);
      rows.add(['', '', '', '', '', '', '', 'TOTAL PENGELUARAN', totalPengeluaran.toStringAsFixed(0)]);
      rows.add(['', '', '', '', '', '', '', 'SISA SALDO (Masuk - Keluar)', (totalPemasukan - totalPengeluaran).toStringAsFixed(0)]);

      // Proses Convert ke bentuk CSV/Excel
      final csv = const ListToCsvConverter().convert(rows);
      final filename = 'Data_Transaksi_Gabungan_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv';

      // Proses Download 
      if (kIsWeb) { // Jika dijalankan di Web Chrome
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', filename)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else { // Jika dijalankan di HP (Android/iOS)
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$filename';
        final file = File(path);
        await file.writeAsString(csv);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Data berhasil didownload ke Excel!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Gagal download: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- WIDGET PREVIEW BARANG DI DALAM POP UP TAMBAH ---
  Widget _buildCategoryInfo(CategoryModel cat, String dialogType) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dialogType == 'pemasukan' ? Colors.teal.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: dialogType == 'pemasukan' ? Colors.teal.shade200 : Colors.red.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barang: ${cat.namaBarang}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Stok saat ini: ${cat.kuantitas} ${cat.satuan}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Harga Rata-rata/Unit: Rp ${cat.hargaPerUnit.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
            ),
            if (quantity > 0) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Preview stok nanti: ${dialogType == "pengeluaran" ? cat.kuantitas - quantity : cat.kuantitas + quantity} ${cat.satuan}',
                  style: TextStyle(
                    color: dialogType == "pengeluaran" && cat.kuantitas - quantity < 0
                        ? Colors.red
                        : Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (dialogType == "pemasukan")
                Builder(
                  builder: (context) {
                    double priceInput = double.tryParse(priceController.text) ?? 0;
                    if (priceInput > 0) {
                      double modalLama = cat.totalModal;
                      if (modalLama == 0 && cat.kuantitas > 0) {
                        modalLama = cat.kuantitas * cat.hargaPerUnit;
                      }
                      double modalBaru = modalLama + (quantity * priceInput);
                      int stokBaru = cat.kuantitas + quantity;
                      double estimasiRataRata = stokBaru > 0 ? modalBaru / stokBaru : 0;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Estimasi Harga Average Baru: Rp ${estimasiRataRata.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Transaksi"),
        actions: [
          // TOMBOL DOWNLOAD EXCEL
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
            tooltip: 'Download Excel',
          ),
          // TOMBOL FILTER
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
            tooltip: 'Filter',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2 TOMBOL BESAR DI ATAS UNTUK PINDAH DATA
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentType == 'pemasukan' ? Colors.green : Colors.grey.shade300,
                      foregroundColor: _currentType == 'pemasukan' ? Colors.white : Colors.black87,
                      elevation: _currentType == 'pemasukan' ? 4 : 0,
                    ),
                    onPressed: () => setState(() {
                      _currentType = 'pemasukan';
                      _resetPage();
                    }),
                    child: const Text('⬇️ Pemasukan'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentType == 'pengeluaran' ? Colors.red : Colors.grey.shade300,
                      foregroundColor: _currentType == 'pengeluaran' ? Colors.white : Colors.black87,
                      elevation: _currentType == 'pengeluaran' ? 4 : 0,
                    ),
                    onPressed: () => setState(() {
                      _currentType = 'pengeluaran';
                      _resetPage();
                    }),
                    child: const Text('⬆️ Pengeluaran'),
                  ),
                ),
              ],
            ),
          ),

          // CHIP FILTER (JIKA ADA)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_filterMode != 0 && _selectedFilter != null)
                  InputChip(
                    label: Text('Bulan: ${DateFormat('MMMM yyyy').format(_selectedFilter!)}'),
                    onDeleted: () => setState(() {
                      _selectedFilter = null;
                      _filterMode = 0;
                    }),
                  ),
                if (descriptionFilterController.text.isNotEmpty)
                  InputChip(
                    label: Text('Cari: ${descriptionFilterController.text.trim()}'),
                    onDeleted: () => setState(() {
                      descriptionFilterController.clear();
                    }),
                  ),
              ],
            ),
          ),

          // LIST DATA TRANSAKSI
          Expanded(
            child: StreamBuilder<List<CategoryModel>>(
              stream: service.getCategories(),
              builder: (context, catSnap) {
                final cats = catSnap.data ?? [];
                final Map<String, CategoryModel> catMap = {
                  for (var c in cats) c.id ?? '': c,
                };

                return StreamBuilder<List<TransactionModel>>(
                  stream: service.getTransactions(),
                  builder: (context, trxSnap) {
                    if (!trxSnap.hasData) return const Center(child: CircularProgressIndicator());

                    List<TransactionModel> transactions = trxSnap.data!;
                    transactions = transactions.where((trx) => trx.type == _currentType).toList();

                    // Menerapkan Filter Waktu
                    if (_selectedFilter != null && _filterMode == 1) {
                      transactions = transactions.where((trx) =>
                          trx.date.year == _selectedFilter!.year &&
                          trx.date.month == _selectedFilter!.month).toList();
                    }

                    // Menerapkan Filter Teks
                    if (descriptionFilterController.text.isNotEmpty) {
                      final filterText = descriptionFilterController.text.toLowerCase();
                      transactions = transactions.where((trx) =>
                          trx.title.toLowerCase().contains(filterText) ||
                          trx.itemName.toLowerCase().contains(filterText)).toList();
                    }

                    if (transactions.isEmpty) {
                      return Center(
                        child: Text(
                          'Belum ada data ${_currentType}.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    // Hitungan Halaman (Pagination)
                    final totalPages = (transactions.length / _itemsPerPage).ceil();
                    final startIndex = _currentPage * _itemsPerPage;
                    final endIndex = (startIndex + _itemsPerPage).clamp(0, transactions.length);
                    final paginatedTransactions = transactions.sublist(startIndex, endIndex);

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: paginatedTransactions.length,
                            itemBuilder: (context, index) {
                              final trx = paginatedTransactions[index];
                              final cat = catMap[trx.categoryId];
                              
                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  // KETIKA DIKLIK, MUNCUL POP UP DETAIL/EDIT/HAPUS
                                  onTap: () => _showTransactionDetail(trx, cat),
                                  leading: CircleAvatar(
                                    backgroundColor: trx.type == 'pengeluaran' ? Colors.red.shade100 : Colors.green.shade100,
                                    child: Icon(
                                      trx.type == 'pengeluaran' ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: trx.type == 'pengeluaran' ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  title: Text(trx.title.isNotEmpty ? trx.title : trx.itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${DateFormat('dd MMM yyyy').format(trx.date)} • Qty: ${trx.quantity.toInt()} ${trx.unit}'),
                                  trailing: Text(
                                    currency.format(trx.amount),
                                    style: TextStyle(
                                      color: trx.type == 'pengeluaran' ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Kontrol Halaman (Pagination Buttons)
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.grey.shade100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('Prev'),
                                ),
                                Text('Hal ${_currentPage + 1} / $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ElevatedButton.icon(
                                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                  label: const Text('Next'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // TOMBOL POP UP ADD (TAMBAH DATA BARU)
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: _currentType == 'pemasukan' ? Colors.green : Colors.red,
        tooltip: 'Tambah Data',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ==========================================
  // POP UP 1: DETAIL, EDIT, & HAPUS
  // ==========================================
  void _showTransactionDetail(TransactionModel trx, CategoryModel? cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            trx.title.isEmpty ? 'Detail Transaksi' : trx.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: trx.type == 'pemasukan' ? Colors.green.shade50 : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Barang', cat?.namaBarang ?? "-"),
                        const Divider(),
                        _buildDetailRow('Nama Item', trx.itemName),
                        const Divider(),
                        _buildDetailRow('Kode', trx.itemCode),
                        const Divider(),
                        _buildDetailRow('Jumlah', '${trx.quantity.toInt()} ${trx.unit}'),
                        const Divider(),
                        _buildDetailRow('Harga/Unit', currency.format(trx.pricePerUnit)),
                        const Divider(),
                        _buildDetailRow(
                          'Total',
                          currency.format(trx.amount),
                          color: trx.type == 'pemasukan' ? Colors.green : Colors.red,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Tipe',
                          trx.type == 'pengeluaran' ? 'Pengeluaran ⬆️' : 'Pemasukan ⬇️',
                          color: trx.type == 'pengeluaran' ? Colors.red : Colors.green,
                        ),
                        const Divider(),
                        _buildDetailRow('Tanggal', DateFormat('dd MMM yyyy').format(trx.date)),
                        if (trx.description?.isNotEmpty ?? false) ...[
                          const Divider(),
                          _buildDetailRow('Catatan', trx.description ?? "-"),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            // TOMBOL TUTUP
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
            ),
            // TOMBOL EDIT
            if (trx.id != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  Navigator.pop(context); // Tutup detail
                  _showEditTransactionDialog(trx, cat); // Buka pop up edit
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                label: const Text('Edit', style: TextStyle(color: Colors.white)),
              ),
            // TOMBOL HAPUS
            if (trx.id != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context); // Tutup pop up detail
                  
                  // Pop up Konfirmasi Hapus
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Data?'),
                      content: const Text(
                        'Yakin ingin menghapus data ini?\n\nStok barang dan Harga Rata-rata akan dikembalikan secara otomatis oleh sistem.',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Ya, Hapus', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  // Eksekusi Hapus
                  if (confirm ?? false) {
                    await service.deleteTransactionWithStock(trx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Data berhasil dihapus & stok dikembalikan!'), backgroundColor: Colors.green),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                label: const Text('Hapus', style: TextStyle(color: Colors.white)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.black),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // POP UP 2: EDIT DATA (Form Edit)
  // ==========================================
  void _showEditTransactionDialog(TransactionModel trx, CategoryModel? cat) {
    titleController.text = trx.title;
    descriptionController.text = trx.description ?? '';
    quantityController.text = trx.quantity.toInt().toString();
    unitController.text = trx.unit;
    itemCodeController.text = trx.itemCode;
    priceController.text = trx.pricePerUnit.toStringAsFixed(0);

    DateTime selectedDate = trx.date;
    String editingCategoryId = cat?.id ?? trx.categoryId;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Transaksi', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info: Tidak bisa ganti barang saat edit
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.yellow.shade100,
                  child: const Text(
                    "⚠️ Info: Untuk menjaga akurasi Harga Rata-Rata, Anda tidak dapat mengubah Kode Barang, Jumlah, dan Harga pada mode Edit. Jika salah, silakan Hapus transaksi ini lalu buat baru.",
                    style: TextStyle(fontSize: 12, color: Colors.brown),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: itemCodeController,
                  readOnly: true, // KUNCI
                  decoration: InputDecoration(
                    labelText: 'Kode Barang (Terkunci)',
                    filled: true, fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Judul Transaksi (Bisa Diubah)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  readOnly: true, // KUNCI
                  decoration: InputDecoration(
                    labelText: 'Jumlah (Terkunci)',
                    filled: true, fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.inventory),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  readOnly: true, // KUNCI
                  decoration: InputDecoration(
                    labelText: 'Harga Satuan (Terkunci)',
                    filled: true, fillColor: Colors.grey.shade200,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Catatan / Deskripsi (Bisa Diubah)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.description),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () async {
                try {
                  final updated = TransactionModel(
                    id: trx.id,
                    title: titleController.text.trim(),
                    itemCode: trx.itemCode, // tetap
                    itemName: trx.itemName, // tetap
                    quantity: trx.quantity, // tetap
                    unit: trx.unit, // tetap
                    pricePerUnit: trx.pricePerUnit, // tetap
                    location: trx.location, // tetap
                    description: descriptionController.text.trim(), // BERUBAH
                    type: trx.type, // tetap
                    amount: trx.amount, // tetap
                    categoryId: editingCategoryId, // tetap
                    createdAt: trx.createdAt, // tetap
                    date: selectedDate, // tetap
                    totalPrice: trx.totalPrice, // tetap
                  );

                  await service.updateTransaction(trx.id!, updated);
                  Navigator.pop(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Catatan berhasil diperbarui!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Simpan Perubahan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // POP UP 3: TAMBAH DATA BARU 
  // ==========================================
  void _showAddDialog() {
    titleController.clear();
    descriptionController.clear();
    unitController.clear();
    itemCodeController.clear();
    priceController.clear();
    quantityController.clear();
    selectedCategoryId = null;
    _foundCategory = null;
    quantity = 0;
    
    // Tipe default di PopUp mengikuti Tab yang sedang aktif
    String dialogType = _currentType; 

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            
            Future<void> lookupInDialog() async {
              final code = itemCodeController.text.trim();
              if (code.isEmpty) return;
              final cat = await service.getCategoryByCode(code);
              if (cat == null) {
                setStateDialog(() {
                  _foundCategory = null;
                  selectedCategoryId = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⚠️ Kode barang tidak ditemukan'), backgroundColor: Colors.orange),
                );
              } else {
                setStateDialog(() {
                  _foundCategory = cat;
                  selectedCategoryId = cat.id;
                  unitController.text = cat.satuan;
                  
                  if (dialogType == 'pengeluaran') {
                    priceController.text = cat.hargaPerUnit.toStringAsFixed(0);
                  } else if (priceController.text.isEmpty) {
                    priceController.text = cat.hargaPerUnit.toStringAsFixed(0);
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text('Tambah Data Baru', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Jenis Transaksi:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Masuk ⬇️', style: TextStyle(fontSize: 13, color: Colors.green)),
                            value: 'pemasukan',
                            groupValue: dialogType,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.green,
                            onChanged: (val) => setStateDialog(() => dialogType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Keluar ⬆️', style: TextStyle(fontSize: 13, color: Colors.red)),
                            value: 'pengeluaran',
                            groupValue: dialogType,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.red,
                            onChanged: (val) {
                              setStateDialog(() {
                                dialogType = val!;
                                if (_foundCategory != null) {
                                  priceController.text = _foundCategory!.hargaPerUnit.toStringAsFixed(0);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    TextField(
                      controller: itemCodeController,
                      decoration: InputDecoration(
                        labelText: 'Kode Barang',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: lookupInDialog),
                      ),
                      onEditingComplete: lookupInDialog,
                      onChanged: (val) {
                        if (_foundCategory != null) setStateDialog(() => _foundCategory = null);
                      },
                    ),
                    if (_foundCategory != null) _buildCategoryInfo(_foundCategory!, dialogType),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: unitController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Satuan', filled: true, fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Transaksi (Opsional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Jumlah (Wajib)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                      onChanged: (val) => setStateDialog(() => quantity = int.tryParse(val) ?? 0),
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      readOnly: dialogType == 'pengeluaran',
                      decoration: InputDecoration(
                        labelText: dialogType == 'pengeluaran' ? "Harga Satuan (Otomatis)" : "Harga Beli per Unit Rp (Wajib)",
                        filled: dialogType == 'pengeluaran',
                        fillColor: dialogType == 'pengeluaran' ? Colors.grey.shade200 : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    
                    Builder(
                      builder: (_) {
                        final qty = double.tryParse(quantityController.text) ?? 0;
                        final price = double.tryParse(priceController.text) ?? 0;
                        return Text('Total: Rp ${(qty * price).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600));
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: dialogType == 'pemasukan' ? Colors.green : Colors.red),
                  onPressed: () async {
                    try {
                      final code = itemCodeController.text.trim();
                      final qty = double.tryParse(quantityController.text) ?? 0;
                      final price = double.tryParse(priceController.text) ?? 0;
                      if (code.isEmpty || selectedCategoryId == null || qty <= 0 || price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Isi data wajib!'), backgroundColor: Colors.orange));
                        return;
                      }

                      final transaction = TransactionModel(
                        title: titleController.text.trim(),
                        itemCode: code,
                        quantity: qty,
                        unit: unitController.text.trim(),
                        pricePerUnit: price,
                        totalPrice: qty * price,
                        amount: qty * price,
                        description: descriptionController.text.trim(),
                        type: dialogType, 
                        date: _selectedDate ?? DateTime.now(),
                        categoryId: selectedCategoryId!,
                        itemName: _foundCategory?.namaBarang ?? '',
                        location: _foundCategory?.lokasi ?? '',
                        createdAt: Timestamp.now(),
                      );

                      await service.addTransaction(transaction);
                      Navigator.pop(context);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Berhasil ditambahkan!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Simpan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateBottomSheet) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filter Data',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Semua Waktu'),
                    leading: Radio(
                      value: 0,
                      groupValue: _filterMode,
                      onChanged: (val) {
                        setStateBottomSheet(() => _filterMode = val as int);
                        setState(() {});
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Filter Bulan'),
                    leading: Radio(
                      value: 1,
                      groupValue: _filterMode,
                      onChanged: (val) {
                        setStateBottomSheet(() => _filterMode = val as int);
                        setState(() {});
                      },
                    ),
                  ),
                  if (_filterMode == 1)
                    ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedFilter ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setStateBottomSheet(() => _selectedFilter = picked);
                          setState(() {});
                        }
                      },
                      child: Text(
                        _selectedFilter == null
                            ? 'Pilih Bulan'
                            : DateFormat('MMMM yyyy').format(_selectedFilter!),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionFilterController,
                    decoration: InputDecoration(
                      labelText: 'Cari berdasarkan judul/nama item',
                      border: const OutlineInputBorder(),
                      suffixIcon: descriptionFilterController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                descriptionFilterController.clear();
                                setStateBottomSheet(() {});
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      setStateBottomSheet(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Terapkan Filter'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    itemCodeController.dispose();
    priceController.dispose();
    descriptionFilterController.dispose();
    super.dispose();
  }
}