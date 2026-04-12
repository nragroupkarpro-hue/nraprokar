// ignore_for_file: use_super_parameters
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  int _currentPage = 0;
  static const int _itemsPerPage = 10; // Load slightly more items for better UX

  String _currentType = 'pemasukan';
  String _selectedLocation = 'Semua';

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

  // Logic Log Export (Tidak Diubah)
  Future<void> _exportData() async {
    try {
      final allTrx = await service.getTransactions().first;
      List<TransactionModel> transactions = allTrx;
      if (_selectedFilter != null && _filterMode == 1)
        transactions =
            transactions
                .where(
                  (trx) =>
                      trx.date.year == _selectedFilter!.year &&
                      trx.date.month == _selectedFilter!.month,
                )
                .toList();
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

  // Helper Input UI
  InputDecoration _modernInputDecoration(
    String label,
    IconData icon, {
    bool isReadOnly = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(
        icon,
        color: isReadOnly ? Colors.grey.shade400 : Colors.teal.shade600,
        size: 22,
      ),
      filled: true,
      fillColor: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade50,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.teal.shade400, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget _buildCategoryInfo(CategoryModel cat, String dialogType) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            dialogType == 'pemasukan'
                ? Colors.green.shade50
                : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              dialogType == 'pemasukan'
                  ? Colors.green.shade200
                  : Colors.red.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color:
                    dialogType == 'pemasukan'
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cat.namaBarang,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blueGrey, size: 16),
              const SizedBox(width: 4),
              Text(
                'Lokasi: ${cat.lokasi}',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stok di gudang: ${cat.kuantitas} ${cat.satuan}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            'Harga Master: Rp ${cat.hargaPerUnit.toStringAsFixed(0)} / unit',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (quantity > 0)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    dialogType == 'pengeluaran' && cat.kuantitas - quantity < 0
                        ? Colors.red.shade100
                        : Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Preview stok nanti: ${dialogType == "pengeluaran" ? cat.kuantitas - quantity : cat.kuantitas + quantity} ${cat.satuan}',
                style: TextStyle(
                  color:
                      dialogType == "pengeluaran" &&
                              cat.kuantitas - quantity < 0
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Data Transaksi",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _exportData,
            tooltip: 'Download Excel',
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
          // --- Kategori Lokasi Modern ---
          Container(
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
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
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text(
                          'Semua Tempat',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: _selectedLocation == 'Semua',
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              _selectedLocation == 'Semua'
                                  ? Colors.teal.shade800
                                  : Colors.white,
                        ),
                        backgroundColor: Colors.teal.shade600,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onSelected:
                            (val) =>
                                setState(() => _selectedLocation = 'Semua'),
                      ),
                      ...locations
                          .map(
                            (loc) => Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: ChoiceChip(
                                label: Text(
                                  loc['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                selected: _selectedLocation == loc['name'],
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color:
                                      _selectedLocation == loc['name']
                                          ? Colors.teal.shade800
                                          : Colors.white,
                                ),
                                backgroundColor: Colors.teal.shade600,
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
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

          // --- Tab Segmented Control Modern ---
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          () => setState(() {
                            _currentType = 'pemasukan';
                            _resetPage();
                          }),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              _currentType == 'pemasukan'
                                  ? Colors.white
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow:
                              _currentType == 'pemasukan'
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : [],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_downward_rounded,
                              color:
                                  _currentType == 'pemasukan'
                                      ? Colors.green.shade600
                                      : Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pemasukan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _currentType == 'pemasukan'
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap:
                          () => setState(() {
                            _currentType = 'pengeluaran';
                            _resetPage();
                          }),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color:
                              _currentType == 'pengeluaran'
                                  ? Colors.white
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow:
                              _currentType == 'pengeluaran'
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : [],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_upward_rounded,
                              color:
                                  _currentType == 'pengeluaran'
                                      ? Colors.red.shade600
                                      : Colors.grey.shade500,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pengeluaran',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _currentType == 'pengeluaran'
                                        ? Colors.red.shade700
                                        : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if ((_filterMode != 0 && _selectedFilter != null) ||
              descriptionFilterController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (_filterMode != 0 && _selectedFilter != null)
                    InputChip(
                      label: Text(
                        'Bulan: ${DateFormat('MMMM yyyy').format(_selectedFilter!)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide.none,
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
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide.none,
                      onDeleted:
                          () => setState(
                            () => descriptionFilterController.clear(),
                          ),
                    ),
                ],
              ),
            ),

          // --- List Transaksi Clean ---
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
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.teal),
                      );
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada data ${_currentType}.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                              ),
                            ),
                          ],
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
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: paginatedTransactions.length,
                            itemBuilder: (context, index) {
                              final trx = paginatedTransactions[index];
                              final cat = catMap[trx.categoryId];
                              final isPemasukan = trx.type == 'pemasukan';
                              final cardColor =
                                  isPemasukan ? Colors.green : Colors.red;

                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                color: Colors.white,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () => _showTransactionDetail(trx, cat),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: cardColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Icon(
                                            isPemasukan
                                                ? Icons.arrow_downward
                                                : Icons.arrow_upward,
                                            color: cardColor.shade600,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      trx.title.isNotEmpty
                                                          ? trx.title
                                                          : trx.itemName,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 16,
                                                        color: Color(
                                                          0xFF1E293B,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    currency.format(trx.amount),
                                                    style: TextStyle(
                                                      color: cardColor.shade700,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () {
                                                      final copyText =
                                                          'Kode: ${trx.itemCode}\nNama: ${trx.itemName}\nJumlah: ${trx.quantity.toInt()} ${trx.unit}\nHarga: ${currency.format(trx.amount)}';
                                                      Clipboard.setData(
                                                        ClipboardData(
                                                          text: copyText,
                                                        ),
                                                      );
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            '✅ Disalin ke clipboard!',
                                                          ),
                                                          backgroundColor:
                                                              Colors.green,
                                                          duration: Duration(
                                                            milliseconds: 1500,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    child: Icon(
                                                      Icons.copy,
                                                      size: 18,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.blueGrey.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '📍 ${trx.location}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors
                                                            .blueGrey
                                                            .shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              _buildInfoText(
                                                'Jumlah:',
                                                '${trx.quantity.toInt()} ${trx.unit} (${currency.format(trx.pricePerUnit)}/unit)',
                                              ),
                                              if (trx.description != null &&
                                                  trx.description != '-' &&
                                                  trx.description!.isNotEmpty)
                                                _buildInfoText(
                                                  'Catatan:',
                                                  trx.description!,
                                                ),
                                              if (trx.supplierName != null &&
                                                  trx.supplierName != '-' &&
                                                  trx.supplierName!.isNotEmpty)
                                                _buildInfoText(
                                                  'Supplier:',
                                                  trx.supplierName!,
                                                ),
                                              if (trx.supplierNumber != null &&
                                                  trx.supplierNumber != '-' &&
                                                  trx
                                                      .supplierNumber!
                                                      .isNotEmpty)
                                                _buildInfoText(
                                                  'No. Telp:',
                                                  trx.supplierNumber!,
                                                ),
                                              if (trx.supplierDetail != null &&
                                                  trx.supplierDetail != '-' &&
                                                  trx
                                                      .supplierDetail!
                                                      .isNotEmpty)
                                                _buildInfoText(
                                                  'Alamat:',
                                                  trx.supplierDetail!,
                                                ),
                                              if (trx.suratJalan != null &&
                                                  trx.suratJalan != '-' &&
                                                  trx.suratJalan!.isNotEmpty)
                                                _buildInfoText(
                                                  'Surat Jalan:',
                                                  trx.suratJalan!,
                                                ),
                                              const SizedBox(height: 8),
                                              Text(
                                                DateFormat(
                                                  'dd MMMM yyyy, HH:mm',
                                                ).format(trx.date),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  offset: const Offset(0, -2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed:
                                      _currentPage > 0
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                  icon: const Icon(
                                    Icons.arrow_back_ios,
                                    size: 14,
                                  ),
                                  label: const Text('Prev'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Hal ${_currentPage + 1} / $totalPages',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed:
                                      _currentPage < totalPages - 1
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                  icon: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                  ),
                                  label: const Text('Next'),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor:
            _currentType == 'pemasukan'
                ? Colors.green.shade600
                : Colors.red.shade600,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          _currentType == 'pemasukan' ? "Barang Masuk" : "Barang Keluar",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DETAIL & EDIT DIALOGS ---
  void _showTransactionDetail(TransactionModel trx, CategoryModel? cat) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                trx.type == 'pemasukan'
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            trx.type == 'pemasukan'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color:
                                trx.type == 'pemasukan'
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            trx.title.isEmpty ? 'Detail Transaksi' : trx.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Nama Item', trx.itemName),
                          const Divider(height: 20),
                          _buildDetailRow(
                            '📍 Lokasi',
                            trx.location,
                            color: Colors.blue.shade700,
                          ),
                          const Divider(height: 20),
                          _buildDetailRow('Kode Item', trx.itemCode),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Kuantitas',
                            '${trx.quantity.toInt()} ${trx.unit}',
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Total Transaksi',
                            currency.format(trx.amount),
                            color:
                                trx.type == 'pemasukan'
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                          ),
                          const Divider(height: 20),
                          _buildDetailRow(
                            'Waktu',
                            DateFormat('dd MMMM yyyy, HH:mm').format(trx.date),
                          ),
                        ],
                      ),
                    ),
                    if ((trx.description != null &&
                            trx.description != '-' &&
                            trx.description!.isNotEmpty) ||
                        (trx.supplierName != null &&
                            trx.supplierName != '-' &&
                            trx.supplierName!.isNotEmpty) ||
                        (trx.suratJalan != null &&
                            trx.suratJalan != '-' &&
                            trx.suratJalan!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Catatan & Bukti Dokumen",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            if (trx.description != null &&
                                trx.description != '-' &&
                                trx.description!.isNotEmpty) ...[
                              _buildDetailRow('Catatan', trx.description!),
                              const Divider(height: 20),
                            ],
                            if (trx.supplierName != null &&
                                trx.supplierName != '-' &&
                                trx.supplierName!.isNotEmpty) ...[
                              _buildDetailRow('Supplier', trx.supplierName!),
                              const Divider(height: 20),
                            ],
                            if (trx.supplierNumber != null &&
                                trx.supplierNumber != '-' &&
                                trx.supplierNumber!.isNotEmpty) ...[
                              _buildDetailRow(
                                'No. Telepon',
                                trx.supplierNumber!,
                              ),
                              const Divider(height: 20),
                            ],
                            if (trx.supplierDetail != null &&
                                trx.supplierDetail != '-' &&
                                trx.supplierDetail!.isNotEmpty) ...[
                              _buildDetailRow('Alamat', trx.supplierDetail!),
                              const Divider(height: 20),
                            ],
                            if (trx.suratJalan != null &&
                                trx.suratJalan != '-' &&
                                trx.suratJalan!.isNotEmpty)
                              _buildDetailRow('Surat Jalan', trx.suratJalan!),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Tutup',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ),
                        if (trx.id != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditTransactionDialog(trx, cat);
                            },
                            icon: const Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Edit',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if (trx.id != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              Navigator.pop(context);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        '⚠️ Batalkan Transaksi?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red,
                                        ),
                                      ),
                                      content: const Text(
                                        'Menghapus data ini akan mengembalikan jumlah stok barang seperti semula secara otomatis.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Kembali'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade600,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text(
                                            'Ya, Hapus',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
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
                                      content: Text(
                                        '✅ Data dihapus & Stok direstorasi!',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                              }
                            },
                            icon: const Icon(
                              Icons.delete,
                              size: 16,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Hapus',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
              fontSize: 14,
            ),
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Text(
                    'Perbarui Transaksi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Jumlah & Harga dikunci. Untuk mengubah nominal, hapus transaksi ini lalu buat baru.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.calendar_month,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          title: const Text(
                            'Tanggal Input',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          subtitle: Text(
                            DateFormat('dd MMMM yyyy').format(selectedDate),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: titleController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Judul Transaksi',
                            Icons.title,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(color: Colors.black),
                          maxLines: 2,
                          decoration: _modernInputDecoration(
                            'Catatan Khusus',
                            Icons.description,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(thickness: 1.5),
                        ),
                        const Text(
                          "Data Surat Jalan & Supplier",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: supplierNameController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Nama Supplier',
                            Icons.local_shipping,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: supplierNumberController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.phone,
                          decoration: _modernInputDecoration(
                            'No. Telepon / WA',
                            Icons.phone,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: supplierDetailController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Alamat Supplier',
                            Icons.map,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: suratJalanController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'No. Surat Jalan / Resi',
                            Icons.receipt,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text('Konfirmasi Pembaruan'),
                                content: const Text(
                                  'Apakah Anda yakin perubahan data ini sudah benar?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Periksa Lagi'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade600,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text(
                                      'Simpan',
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
                            supplierDetail:
                                supplierDetailController.text.trim(),
                            supplierNumber:
                                supplierNumberController.text.trim(),
                            suratJalan: suratJalanController.text.trim(),
                          );
                          await service.updateTransaction(trx.id!, updated);
                          Navigator.pop(context);
                        } catch (e) {
                          /* ignore */
                        }
                      },
                      child: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
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
      builder:
          (context) => StatefulBuilder(
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: const Text(
                  'Form Input Transaksi',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap:
                                    () => setStateDialog(
                                      () => dialogType = 'pemasukan',
                                    ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        dialogType == 'pemasukan'
                                            ? Colors.white
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow:
                                        dialogType == 'pemasukan'
                                            ? [
                                              const BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Masuk ⬇️',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap:
                                    () => setStateDialog(
                                      () => dialogType = 'pengeluaran',
                                    ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        dialogType == 'pengeluaran'
                                            ? Colors.white
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow:
                                        dialogType == 'pengeluaran'
                                            ? [
                                              const BoxShadow(
                                                color: Colors.black12,
                                                blurRadius: 4,
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Keluar ⬆️',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_month,
                            color: Colors.teal.shade700,
                          ),
                        ),
                        title: const Text(
                          'Pilih Tanggal',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        subtitle: Text(
                          DateFormat('dd MMMM yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: itemCodeController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Kode Barang',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: Icon(
                            Icons.qr_code,
                            color: Colors.teal.shade600,
                          ),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: Colors.white,
                              ),
                              onPressed: lookupInDialog,
                            ),
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              style: const TextStyle(color: Colors.black),
                              keyboardType: TextInputType.number,
                              decoration: _modernInputDecoration(
                                'Qty (Wajib)',
                                Icons.inventory,
                              ),
                              onChanged:
                                  (val) => setStateDialog(
                                    () => quantity = int.tryParse(val) ?? 0,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: titleController,
                              style: const TextStyle(color: Colors.black),
                              decoration: _modernInputDecoration(
                                'Judul',
                                Icons.title,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // PENAMBAHAN FIELD DESKRIPSI SECARA JELAS
                      TextField(
                        controller: descriptionController,
                        style: const TextStyle(color: Colors.black),
                        maxLines: 2,
                        decoration: _modernInputDecoration(
                          'Deskripsi / Catatan',
                          Icons.description,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(thickness: 1.5),
                      const Text(
                        "Kelengkapan Dokumen / Supplier",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: supplierNameController,
                        style: const TextStyle(color: Colors.black),
                        decoration: _modernInputDecoration(
                          'Nama Supplier / Toko',
                          Icons.local_shipping,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: supplierNumberController,
                        style: const TextStyle(color: Colors.black),
                        keyboardType: TextInputType.phone,
                        decoration: _modernInputDecoration(
                          'No. Telepon / WA',
                          Icons.phone,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: supplierDetailController,
                        style: const TextStyle(color: Colors.black),
                        decoration: _modernInputDecoration(
                          'Alamat Asal',
                          Icons.map,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: suratJalanController,
                        style: const TextStyle(color: Colors.black),
                        decoration: _modernInputDecoration(
                          'Surat Jalan / Resi',
                          Icons.receipt,
                        ),
                      ),
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          dialogType == 'pemasukan'
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: const Text('Verifikasi Final'),
                              content: const Text(
                                'Pastikan data barang dan jumlah sudah tepat sebelum disimpan.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Kembali'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Simpan Data',
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
                          price <= 0)
                        return;
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
                      } catch (e) {
                        /* ignore */
                      }
                    },
                    child: const Text(
                      'Proses Transaksi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
