// ignore_for_file: use_super_parameters

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

  String _currentType = 'pemasukan';
  String _selectedLocation = 'Semua';

  // Bulk delete state
  Set<String> selectedIds = {};
  bool isSelectionMode = false;

  String? selectedCategoryId;
  int quantity = 0;
  CategoryModel? _foundCategory;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final itemCodeController = TextEditingController();
  final priceController = TextEditingController();

  final supplierNameController = TextEditingController();
  final supplierDetailController = TextEditingController();
  final supplierNumberController = TextEditingController();
  final suratJalanController = TextEditingController();

  int _filterMode = 0;
  DateTime? _selectedFilter;
  final descriptionFilterController = TextEditingController();

  void _resetPage() {
    setState(() => _currentPage = 0);
  }

  Future<void> _exportData() async {
    try {
      final allTrx = await service.getTransactions().first;
      List<TransactionModel> transactions = allTrx;

      if (_selectedFilter != null && _filterMode == 1) {
        transactions =
            transactions
                .where(
                  (trx) =>
                      trx.date.year == _selectedFilter!.year &&
                      trx.date.month == _selectedFilter!.month,
                )
                .toList();
      }
      if (descriptionFilterController.text.isNotEmpty) {
        final filterText = descriptionFilterController.text.toLowerCase();
        transactions =
            transactions
                .where(
                  (trx) =>
                      trx.title.toLowerCase().contains(filterText) ||
                      trx.itemName.toLowerCase().contains(filterText) ||
                      (trx.description?.toLowerCase().contains(filterText) ??
                          false),
                )
                .toList();
      }
      transactions.sort((a, b) => a.date.compareTo(b.date));

      double totalPemasukan = 0;
      double totalPengeluaran = 0;
      final rows = <List<dynamic>>[];
      rows.add(['LAPORAN DATA TRANSAKSI GABUNGAN']);
      rows.add([
        'Periode Filter:',
        _selectedFilter != null && _filterMode == 1
            ? DateFormat('MMMM yyyy').format(_selectedFilter!)
            : 'Semua Waktu',
      ]);
      rows.add([]);
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
        'Keterangan',
        'Nama Supplier',
        'No. Telepon',
        'Detail/Alamat',
        'Surat Jalan',
      ]);

      for (int i = 0; i < transactions.length; i++) {
        final tx = transactions[i];
        if (tx.type == 'pemasukan')
          totalPemasukan += tx.amount;
        else if (tx.type == 'pengeluaran')
          totalPengeluaran += tx.amount;

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
          tx.description ?? '-',
          tx.supplierName ?? '-',
          tx.supplierNumber ?? '-',
          tx.supplierDetail ?? '-',
          tx.suratJalan ?? '-',
        ]);
      }
      rows.add([]);
      rows.add([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'TOTAL PEMASUKAN',
        totalPemasukan.toStringAsFixed(0),
      ]);
      rows.add([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'TOTAL PENGELUARAN',
        totalPengeluaran.toStringAsFixed(0),
      ]);
      rows.add([
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'SISA SALDO',
        (totalPemasukan - totalPengeluaran).toStringAsFixed(0),
      ]);

      final csv = const ListToCsvConverter().convert(rows);
      final filename =
          'Data_Transaksi_${DateFormat('dd_MM_yyyy').format(DateTime.now())}.csv';

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Excel berhasil diunduh!'),
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

  Widget _buildCategoryInfo(CategoryModel cat, String dialogType) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              dialogType == 'pemasukan'
                  ? Colors.teal.shade50
                  : Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                dialogType == 'pemasukan'
                    ? Colors.teal.shade200
                    : Colors.red.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Barang: ${cat.namaBarang}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              '📍 Lokasi: ${cat.lokasi}',
              style: const TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 4),
            Text(
              'Stok saat ini: ${cat.kuantitas} ${cat.satuan}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              'Harga Master/Unit: Rp ${cat.hargaPerUnit.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.blueGrey,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Preview stok nanti: ${dialogType == "pengeluaran" ? cat.kuantitas - quantity : cat.kuantitas + quantity} ${cat.satuan}',
                  style: TextStyle(
                    color:
                        dialogType == "pengeluaran" &&
                                cat.kuantitas - quantity < 0
                            ? Colors.red
                            : Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.grey.shade200,
            width: double.infinity,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: service.getLocations(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                final locations = snap.data!;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Semua Tempat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: _selectedLocation == 'Semua',
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color:
                              _selectedLocation == 'Semua'
                                  ? Colors.white
                                  : Colors.black,
                        ),
                        onSelected:
                            (val) =>
                                setState(() => _selectedLocation = 'Semua'),
                      ),
                      ...locations
                          .map(
                            (loc) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(
                                  loc['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: _selectedLocation == loc['name'],
                                selectedColor: Colors.blue,
                                labelStyle: TextStyle(
                                  color:
                                      _selectedLocation == loc['name']
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                onSelected:
                                    (val) => setState(
                                      () => _selectedLocation = loc['name'],
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _currentType == 'pemasukan'
                              ? Colors.green
                              : Colors.grey.shade300,
                      foregroundColor:
                          _currentType == 'pemasukan'
                              ? Colors.white
                              : Colors.black87,
                    ),
                    onPressed:
                        () => setState(() {
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
                      backgroundColor:
                          _currentType == 'pengeluaran'
                              ? Colors.red
                              : Colors.grey.shade300,
                      foregroundColor:
                          _currentType == 'pengeluaran'
                              ? Colors.white
                              : Colors.black87,
                    ),
                    onPressed:
                        () => setState(() {
                          _currentType = 'pengeluaran';
                          _resetPage();
                        }),
                    child: const Text('⬆️ Pengeluaran'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_filterMode != 0 && _selectedFilter != null)
                  InputChip(
                    label: Text(
                      'Bulan: ${DateFormat('MMMM yyyy').format(_selectedFilter!)}',
                    ),
                    onDeleted:
                        () => setState(() {
                          _selectedFilter = null;
                          _filterMode = 0;
                        }),
                  ),
                if (descriptionFilterController.text.isNotEmpty)
                  InputChip(
                    label: Text(
                      'Cari: ${descriptionFilterController.text.trim()}',
                    ),
                    onDeleted:
                        () =>
                            setState(() => descriptionFilterController.clear()),
                  ),
              ],
            ),
          ),
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
                    if (!trxSnap.hasData)
                      return const Center(child: CircularProgressIndicator());
                    List<TransactionModel> transactions =
                        trxSnap.data!
                            .where((trx) => trx.type == _currentType)
                            .toList();
                    if (_selectedLocation != 'Semua')
                      transactions =
                          transactions
                              .where((trx) => trx.location == _selectedLocation)
                              .toList();
                    if (_selectedFilter != null && _filterMode == 1)
                      transactions =
                          transactions
                              .where(
                                (trx) =>
                                    trx.date.year == _selectedFilter!.year &&
                                    trx.date.month == _selectedFilter!.month,
                              )
                              .toList();
                    if (descriptionFilterController.text.isNotEmpty)
                      transactions =
                          transactions
                              .where(
                                (trx) =>
                                    trx.title.toLowerCase().contains(
                                      descriptionFilterController.text
                                          .toLowerCase(),
                                    ) ||
                                    trx.itemName.toLowerCase().contains(
                                      descriptionFilterController.text
                                          .toLowerCase(),
                                    ),
                              )
                              .toList();

                    if (transactions.isEmpty)
                      return Center(
                        child: Text(
                          'Belum ada data $_currentType.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    final totalPages =
                        (transactions.length / _itemsPerPage).ceil();
                    final startIndex = _currentPage * _itemsPerPage;
                    final endIndex = (startIndex + _itemsPerPage).clamp(
                      0,
                      transactions.length,
                    );
                    final paginatedTransactions = transactions.sublist(
                      startIndex,
                      endIndex,
                    );

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
                                  onTap: () => _showTransactionDetail(trx, cat),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        trx.type == 'pengeluaran'
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                    child: Icon(
                                      trx.type == 'pengeluaran'
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color:
                                          trx.type == 'pengeluaran'
                                              ? Colors.red
                                              : Colors.green,
                                    ),
                                  ),
                                  title: Text(
                                    trx.title.isNotEmpty
                                        ? trx.title
                                        : trx.itemName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TEMPAT : ${trx.location}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        Text(
                                          'JUMLAH : ${trx.quantity.toInt()} ${trx.unit} (${currency.format(trx.pricePerUnit)} / UNIT)',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        if (trx.description != null &&
                                            trx.description != '-' &&
                                            trx.description!.isNotEmpty)
                                          Text(
                                            'CATATAN : ${trx.description}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (trx.supplierName != null &&
                                            trx.supplierName != '-' &&
                                            trx.supplierName!.isNotEmpty)
                                          Text(
                                            'SUPPLIER : ${trx.supplierName}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (trx.supplierNumber != null &&
                                            trx.supplierNumber != '-' &&
                                            trx.supplierNumber!.isNotEmpty)
                                          Text(
                                            'NO. TELP : ${trx.supplierNumber}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (trx.supplierDetail != null &&
                                            trx.supplierDetail != '-' &&
                                            trx.supplierDetail!.isNotEmpty)
                                          Text(
                                            'ALAMAT : ${trx.supplierDetail}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        if (trx.suratJalan != null &&
                                            trx.suratJalan != '-' &&
                                            trx.suratJalan!.isNotEmpty)
                                          Text(
                                            'SURAT JALAN : ${trx.suratJalan}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Text(
                                          DateFormat(
                                            'dd MMMM yyyy',
                                          ).format(trx.date),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Text(
                                    currency.format(trx.amount),
                                    style: TextStyle(
                                      color:
                                          trx.type == 'pengeluaran'
                                              ? Colors.red
                                              : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.grey.shade100,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      _currentPage > 0
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                  icon: const Icon(Icons.arrow_back, size: 16),
                                  label: const Text('Prev'),
                                ),
                                Text(
                                  'Hal ${_currentPage + 1} / $totalPages',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed:
                                      _currentPage < totalPages - 1
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor:
            _currentType == 'pemasukan' ? Colors.green : Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

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
                  color:
                      trx.type == 'pemasukan'
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Nama Item', trx.itemName),
                        const Divider(),
                        _buildDetailRow(
                          '📍 Lokasi',
                          trx.location,
                          color: Colors.blue,
                        ),
                        const Divider(),
                        _buildDetailRow('Kode', trx.itemCode),
                        const Divider(),
                        _buildDetailRow(
                          'Jumlah',
                          '${trx.quantity.toInt()} ${trx.unit}',
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Total Harga',
                          currency.format(trx.amount),
                          color:
                              trx.type == 'pemasukan'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Tanggal',
                          DateFormat('dd MMM yyyy').format(trx.date),
                        ),
                        if (trx.description != null &&
                            trx.description!.isNotEmpty &&
                            trx.description != '-') ...[
                          const Divider(),
                          _buildDetailRow('Catatan', trx.description!),
                        ],
                        if (trx.supplierName != null &&
                            trx.supplierName!.isNotEmpty &&
                            trx.supplierName != '-') ...[
                          const Divider(),
                          _buildDetailRow('Supplier', trx.supplierName!),
                        ],
                        if (trx.supplierNumber != null &&
                            trx.supplierNumber!.isNotEmpty &&
                            trx.supplierNumber != '-') ...[
                          const Divider(),
                          _buildDetailRow('No. Telepon', trx.supplierNumber!),
                        ],
                        if (trx.supplierDetail != null &&
                            trx.supplierDetail!.isNotEmpty &&
                            trx.supplierDetail != '-') ...[
                          const Divider(),
                          _buildDetailRow('Alamat', trx.supplierDetail!),
                        ],
                        if (trx.suratJalan != null &&
                            trx.suratJalan!.isNotEmpty &&
                            trx.suratJalan != '-') ...[
                          const Divider(),
                          _buildDetailRow('Surat Jalan', trx.suratJalan!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(color: Colors.grey)),
            ),
            if (trx.id != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () {
                  Navigator.pop(context);
                  _showEditTransactionDialog(trx, cat);
                },
                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                label: const Text(
                  'Edit',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            if (trx.id != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text(
                            '⚠️ Konfirmasi Hapus',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          content: const Text(
                            'Yakin ingin menghapus transaksi ini? Stok barang akan dikembalikan otomatis.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Ya, Hapus',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirm == true) {
                    await service.deleteTransactionWithStock(trx);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Data dihapus!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                  }
                },
                icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                label: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
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
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _showEditTransactionDialog(TransactionModel trx, CategoryModel? cat) {
    titleController.text = trx.title;
    descriptionController.text =
        trx.description == '-' ? '' : (trx.description ?? '');
    quantityController.text = trx.quantity.toInt().toString();
    unitController.text = trx.unit;
    itemCodeController.text = trx.itemCode;
    priceController.text = trx.pricePerUnit.toStringAsFixed(0);

    supplierNameController.text =
        trx.supplierName == '-' ? '' : (trx.supplierName ?? '');
    supplierDetailController.text =
        trx.supplierDetail == '-' ? '' : (trx.supplierDetail ?? '');
    supplierNumberController.text =
        trx.supplierNumber == '-' ? '' : (trx.supplierNumber ?? '');
    suratJalanController.text =
        trx.suratJalan == '-' ? '' : (trx.suratJalan ?? '');

    DateTime selectedDate = trx.date;
    String editingCategoryId = cat?.id ?? trx.categoryId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text(
                'Edit Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.yellow.shade100,
                      child: const Text(
                        "⚠️ Info: Jumlah & Harga dikunci mati. Jika salah, silakan Hapus transaksi ini lalu buat baru.",
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.teal,
                      ),
                      title: const Text(
                        'Tanggal Transaksi',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null)
                          setStateDialog(() => selectedDate = date);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Transaksi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan / Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),

                    const Divider(height: 30, thickness: 2),
                    const Text(
                      "Data Supplier & Surat Jalan (Opsional)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: supplierNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.local_shipping),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. Telepon / WA Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierDetailController,
                      decoration: InputDecoration(
                        labelText: 'Detail / Alamat Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.map),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: suratJalanController,
                      decoration: InputDecoration(
                        labelText: 'No. Surat Jalan / Resi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.receipt),
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
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Konfirmasi Simpan'),
                            content: const Text(
                              'Apakah Anda yakin perubahan data ini sudah benar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Periksa Lagi'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Ya, Simpan',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm != true) return;

                    try {
                      final updated = TransactionModel(
                        id: trx.id,
                        title: titleController.text.trim(),
                        itemCode: trx.itemCode,
                        itemName: trx.itemName,
                        quantity: trx.quantity,
                        unit: trx.unit,
                        pricePerUnit: trx.pricePerUnit,
                        location: trx.location,
                        description: descriptionController.text.trim(),
                        type: trx.type,
                        amount: trx.amount,
                        categoryId: editingCategoryId,
                        createdAt: trx.createdAt,
                        date: selectedDate,
                        totalPrice: trx.totalPrice,
                        supplierName: supplierNameController.text.trim(),
                        supplierDetail: supplierDetailController.text.trim(),
                        supplierNumber: supplierNumberController.text.trim(),
                        suratJalan: suratJalanController.text.trim(),
                      );
                      await service.updateTransaction(trx.id!, updated);
                      Navigator.pop(context);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Data berhasil diperbarui!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddDialog() {
    titleController.clear();
    descriptionController.clear();
    unitController.clear();
    itemCodeController.clear();
    priceController.clear();
    quantityController.clear();
    supplierNameController.clear();
    supplierDetailController.clear();
    supplierNumberController.clear();
    suratJalanController.clear();
    selectedCategoryId = null;
    _foundCategory = null;
    quantity = 0;
    String dialogType = _currentType;
    DateTime selectedDate = DateTime.now();

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
              } else {
                setStateDialog(() {
                  _foundCategory = cat;
                  selectedCategoryId = cat.id;
                  unitController.text = cat.satuan;
                  priceController.text = cat.hargaPerUnit.toStringAsFixed(0);

                  // OTOMATIS TARIK DATA DARI MASTER BARANG
                  supplierNameController.text =
                      cat.supplierName == '-' ? '' : (cat.supplierName ?? '');
                  supplierNumberController.text =
                      cat.supplierNumber == '-'
                          ? ''
                          : (cat.supplierNumber ?? '');
                  supplierDetailController.text =
                      cat.supplierDetail == '-'
                          ? ''
                          : (cat.supplierDetail ?? '');
                  suratJalanController.text =
                      cat.suratJalan == '-' ? '' : (cat.suratJalan ?? '');
                });
              }
            }

            return AlertDialog(
              title: const Text(
                'Tambah Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Jenis Transaksi:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Masuk ⬇️',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.green,
                              ),
                            ),
                            value: 'pemasukan',
                            groupValue: dialogType,
                            activeColor: Colors.green,
                            onChanged:
                                (val) =>
                                    setStateDialog(() => dialogType = val!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text(
                              'Keluar ⬆️',
                              style: TextStyle(fontSize: 13, color: Colors.red),
                            ),
                            value: 'pengeluaran',
                            groupValue: dialogType,
                            activeColor: Colors.red,
                            onChanged:
                                (val) =>
                                    setStateDialog(() => dialogType = val!),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.teal,
                      ),
                      title: const Text(
                        'Tanggal Transaksi',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null)
                          setStateDialog(() => selectedDate = date);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemCodeController,
                      decoration: InputDecoration(
                        labelText: 'Kode Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.qr_code),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: lookupInDialog,
                        ),
                      ),
                      onEditingComplete: lookupInDialog,
                      onChanged: (val) {
                        if (_foundCategory != null)
                          setStateDialog(() => _foundCategory = null);
                      },
                    ),
                    if (_foundCategory != null)
                      _buildCategoryInfo(_foundCategory!, dialogType),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Jumlah (Wajib)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                      onChanged:
                          (val) => setStateDialog(
                            () => quantity = int.tryParse(val) ?? 0,
                          ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Opsional',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan / Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 30, thickness: 2),
                    const Text(
                      "Data Supplier & Surat Jalan (Opsional)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: supplierNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.local_shipping),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. Telepon / WA Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierDetailController,
                      decoration: InputDecoration(
                        labelText: 'Detail / Alamat Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.map),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: suratJalanController,
                      decoration: InputDecoration(
                        labelText: 'No. Surat Jalan / Resi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.receipt),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        dialogType == 'pemasukan' ? Colors.green : Colors.red,
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Konfirmasi Simpan'),
                            content: const Text(
                              'Apakah Anda yakin data transaksi yang dimasukkan sudah benar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Periksa Lagi'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Ya, Simpan',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                    );
                    if (confirm != true) return;

                    final code = itemCodeController.text.trim();
                    final qty = double.tryParse(quantityController.text) ?? 0;
                    final price = double.tryParse(priceController.text) ?? 0;
                    if (code.isEmpty ||
                        selectedCategoryId == null ||
                        qty <= 0 ||
                        price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Isi data wajib!'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    try {
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
                        date: selectedDate,
                        categoryId: selectedCategoryId!,
                        itemName: _foundCategory?.namaBarang ?? '',
                        location: _foundCategory?.lokasi ?? '',
                        createdAt: Timestamp.now(),
                        supplierName: supplierNameController.text.trim(),
                        supplierDetail: supplierDetailController.text.trim(),
                        supplierNumber: supplierNumberController.text.trim(),
                        suratJalan: suratJalanController.text.trim(),
                      );
                      await service.addTransaction(transaction);
                      Navigator.pop(context);
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Berhasil ditambahkan!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    'Simpan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openFilterSheet() {}

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    unitController.dispose();
    itemCodeController.dispose();
    priceController.dispose();
    descriptionFilterController.dispose();
    supplierNameController.dispose();
    supplierDetailController.dispose();
    supplierNumberController.dispose();
    suratJalanController.dispose();
    super.dispose();
  }
}
