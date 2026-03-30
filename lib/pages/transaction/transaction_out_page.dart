import 'dart:convert';
import 'dart:html' as html;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:collection/collection.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';
import '../../models/category_model.dart';
import 'package:flutter/foundation.dart';

class TransactionOutPage extends StatefulWidget {
  const TransactionOutPage({Key? key}) : super(key: key);

  @override
  State<TransactionOutPage> createState() => _TransactionOutPageState();
}

class _TransactionOutPageState extends State<TransactionOutPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  int _currentPage = 0;
  static const int _itemsPerPage = 7;

  String? selectedCategoryId;
  String type = "pengeluaran";
  int quantity = 0;

  // temporarily holds the category looked up from kode barang while
  // the add/edit dialog is open. we clear it whenever the code changes.
  CategoryModel? _foundCategory;

  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final itemCodeController = TextEditingController();
  final priceController = TextEditingController();
  DateTime? _selectedDate;

  Widget _buildCategoryInfo(CategoryModel cat) {
    final priceDiff =
        cat.lastPrice != null ? cat.hargaPerUnit - (cat.lastPrice ?? 0) : 0;
    final isPriceUp = priceDiff > 0;
    final priceChangeIcon = isPriceUp ? '📈' : (priceDiff < 0 ? '📉' : '');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Barang: ${cat.namaBarang}${cat.varianInfo != null ? " (${cat.varianInfo})" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Stok saat ini: ${cat.kuantitas} ${cat.satuan}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('Lokasi: ${cat.lokasi}', style: const TextStyle(fontSize: 12)),
            Text(
              'Harga/Unit: Rp ${cat.hargaPerUnit.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.teal,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cat.lastPrice != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    'Harga Terakhir: Rp ${cat.lastPrice?.toStringAsFixed(0) ?? "-"}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  if (priceDiff != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isPriceUp
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$priceChangeIcon ${priceDiff.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isPriceUp ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Preview stok setelah transaksi: ${type == "pengeluaran" ? cat.kuantitas - quantity : cat.kuantitas + quantity} ${cat.satuan}',
                  style: TextStyle(
                    color:
                        type == "pengeluaran" && cat.kuantitas - quantity < 0
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

  int _filterMode = 0;
  DateTime? _selectedFilter;
  final descriptionFilterController = TextEditingController();

  void _resetPage() {
    setState(() => _currentPage = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengeluaran"),
        actions: [
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_filterMode != 0 && _selectedFilter != null)
                  InputChip(
                    label: Text(
                      'Bulan: ${DateFormat('MMMM yyyy').format(_selectedFilter!)}',
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedFilter = null;
                        _filterMode = 0;
                      });
                    },
                  ),
                if (descriptionFilterController.text.isNotEmpty)
                  InputChip(
                    label: Text(
                      'Cari: ${descriptionFilterController.text.trim()}',
                    ),
                    onDeleted: () {
                      setState(() {
                        descriptionFilterController.clear();
                      });
                    },
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
                    if (!trxSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    List<TransactionModel> transactions = trxSnap.data!;

                    // show only pengeluaran entries
                    transactions =
                        transactions
                            .where((trx) => trx.type == 'pengeluaran')
                            .toList();

                    if (_selectedFilter != null && _filterMode == 1) {
                      transactions =
                          transactions
                              .where(
                                (trx) =>
                                    trx.date.year == _selectedFilter!.year &&
                                    trx.date.month == _selectedFilter!.month,
                              )
                              .toList();
                      _resetPage();
                    }

                    if (descriptionFilterController.text.isNotEmpty) {
                      final filterText =
                          descriptionFilterController.text.toLowerCase();
                      transactions =
                          transactions
                              .where(
                                (trx) =>
                                    trx.title.toLowerCase().contains(
                                      filterText,
                                    ) ||
                                    trx.itemName.toLowerCase().contains(
                                      filterText,
                                    ) ||
                                    (trx.description?.toLowerCase().contains(
                                          filterText,
                                        ) ??
                                        false),
                              )
                              .toList();
                      _resetPage();
                    }

                    if (transactions.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada transaksi',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    }

                    // Hitung pagination
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
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: paginatedTransactions.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final trx = paginatedTransactions[index];
                              final cat = catMap[trx.categoryId];
                              final catName =
                                  cat?.namaBarang ?? 'Barang tidak ditemukan';

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () => _showTransactionDetail(trx, cat),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        trx.type == 'pengeluaran'
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                    child: Icon(
                                      trx.type == 'pengeluaran'
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
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
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${DateFormat('dd MMM yyyy').format(trx.date)} • $catName',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Item: ${trx.itemName} (${trx.itemCode})',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      Text(
                                        'Qty: ${trx.quantity.toInt()} ${trx.unit} • Lokasi: ${trx.location}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  trailing: SizedBox(
                                    width: 110,
                                    child: Text(
                                      currency.format(trx.amount),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
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
                                ),
                              );
                            },
                          ),
                        ),
                        // Pagination Controls
                        if (totalPages > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              border: Border(
                                top: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      _currentPage > 0
                                          ? () => setState(() => _currentPage--)
                                          : null,
                                  icon: const Icon(Icons.arrow_back, size: 18),
                                  label: const Text('Sebelumnya'),
                                ),
                                Text(
                                  'Halaman ${_currentPage + 1} dari $totalPages',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed:
                                      _currentPage < totalPages - 1
                                          ? () => setState(() => _currentPage++)
                                          : null,
                                  icon: const Icon(
                                    Icons.arrow_forward,
                                    size: 18,
                                  ),
                                  label: const Text('Berikutnya'),
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
        onPressed: showAddDialog,
        tooltip: 'Tambah Pengeluaran',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Filter Transaksi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Semua'),
                    leading: Radio(
                      value: 0,
                      groupValue: _filterMode,
                      onChanged: (val) {
                        setState(() => _filterMode = val as int);
                        this.setState(() {});
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text('Filter Bulan'),
                    leading: Radio(
                      value: 1,
                      groupValue: _filterMode,
                      onChanged: (val) {
                        setState(() => _filterMode = val as int);
                        this.setState(() {});
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
                          setState(() => _selectedFilter = picked);
                          this.setState(() {});
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
                      suffixIcon:
                          descriptionFilterController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  descriptionFilterController.clear();
                                  setState(() {});
                                  this.setState(() {});
                                },
                              )
                              : null,
                    ),
                    onChanged: (val) {
                      setState(() {});
                      this.setState(() {});
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
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Barang', cat?.namaBarang ?? "-"),
                        const Divider(),
                        _buildDetailRow('Nama Item', trx.itemName),
                        const Divider(),
                        _buildDetailRow('Kode Item', trx.itemCode),
                        const Divider(),
                        _buildDetailRow('Satuan', trx.unit),
                        const Divider(),
                        _buildDetailRow(
                          'Jumlah',
                          '${trx.quantity.toInt()} ${trx.unit}',
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Harga/Unit',
                          currency.format(trx.pricePerUnit),
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Total',
                          currency.format(trx.amount),
                          color: Colors.blue,
                        ),
                        const Divider(),
                        _buildDetailRow('Lokasi', trx.location),
                        const Divider(),
                        _buildDetailRow(
                          'Tipe',
                          trx.type == 'pengeluaran'
                              ? 'Pengeluaran'
                              : 'Pemasukan',
                          color:
                              trx.type == 'pengeluaran'
                                  ? Colors.red
                                  : Colors.green,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Tanggal',
                          DateFormat('dd MMM yyyy').format(trx.date),
                        ),
                        if (trx.description?.isNotEmpty ?? false) ...[
                          const Divider(),
                          _buildDetailRow('Deskripsi', trx.description ?? "-"),
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
              child: const Text('Tutup'),
            ),
            if (trx.id != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditTransactionDialog(trx, cat);
                },
                child: const Text('Edit', style: TextStyle(color: Colors.blue)),
              ),
            if (trx.id != null)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Hapus Transaksi?'),
                          content: const Text(
                            'Apakah Anda yakin ingin menghapus transaksi ini?\n\nTindakan ini tidak dapat dibatalkan.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Hapus',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirm ?? false) {
                    await service.deleteTransaction(trx.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Transaksi berhasil dihapus'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
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
    final titleController = TextEditingController(text: trx.title);
    final descriptionController = TextEditingController(
      text: trx.description ?? '',
    );
    final quantityController = TextEditingController(
      text: trx.quantity.toInt().toString(),
    );
    final unitController = TextEditingController(text: trx.unit);
    final itemCodeController = TextEditingController(text: trx.itemCode);
    final priceController = TextEditingController(
      text: trx.pricePerUnit.toString(),
    );

    DateTime selectedDate = trx.date;
    String selectedType = trx.type;

    // we'll keep track of the category found by kode inside this dialog
    CategoryModel? found = cat;
    String? editingCategoryId = cat?.id;

    // initialize preview quantity so stock info is correct
    quantity = trx.quantity.toInt();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> lookupInDialog() async {
              final code = itemCodeController.text.trim();
              if (code.isEmpty) return;
              // use `c` here so we don't shadow the outer `cat` parameter
              final c = await service.getCategoryByCode(code);
              if (c == null) {
                setState(() {
                  found = null;
                  editingCategoryId = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Kode barang tidak ditemukan'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                setState(() {
                  found = c;
                  editingCategoryId = c.id;
                  unitController.text = c.satuan;
                  if (priceController.text.isEmpty) {
                    priceController.text = c.hargaPerUnit.toString();
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text('Edit Transaksi'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          tooltip: 'Cari berdasarkan kode',
                          onPressed: lookupInDialog,
                        ),
                      ),
                      onEditingComplete: lookupInDialog,
                      onChanged: (val) {
                        if (found != null) {
                          setState(() {
                            found = null;
                            editingCategoryId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (found != null) _buildCategoryInfo(found!),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Transaksi (Opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.title),
                        hintText: 'Misal: Penerimaan Barang, Pemakaian',
                      ),
                    ),
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
                          (val) => setState(() {
                            quantity = int.tryParse(val) ?? 0;
                          }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Harga per Unit Rp (Wajib)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        final qty =
                            double.tryParse(quantityController.text) ?? 0;
                        final price =
                            double.tryParse(priceController.text) ?? 0;
                        return Text(
                          'Total: Rp ${(qty * price).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                  onPressed: () async {
                    try {
                      final code = itemCodeController.text.trim();
                      final qty = double.tryParse(quantityController.text) ?? 0;
                      final price = double.tryParse(priceController.text) ?? 0;
                      if (code.isEmpty ||
                          selectedCategoryId == null ||
                          qty <= 0 ||
                          price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ Isi kode barang yang valid, jumlah, satuan & harga',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (qty < 0 || price < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ Jumlah dan harga tidak boleh negatif',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final updated = TransactionModel(
                        id: trx.id,
                        title: titleController.text.trim(),
                        itemCode: code,
                        itemName: found?.namaBarang ?? trx.itemName,
                        quantity: qty,
                        unit: unitController.text.trim(),
                        pricePerUnit: price,
                        location: found?.lokasi ?? trx.location,
                        description: descriptionController.text.trim(),
                        type: selectedType,
                        amount: price * qty,
                        categoryId: editingCategoryId!,
                        createdAt: trx.createdAt,
                        date: selectedDate,
                        totalPrice: price * qty,
                      );

                      await service.updateTransaction(trx.id!, updated);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Transaksi berhasil diupdate'),
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
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showAddDialog() {
    titleController.clear();
    descriptionController.clear();
    unitController.clear();
    itemCodeController.clear();
    priceController.clear();
    quantityController.clear();
    selectedCategoryId = null;
    _foundCategory = null;
    type = "pengeluaran";
    quantity = 0;
    _selectedDate = null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> lookupInDialog() async {
              final code = itemCodeController.text.trim();
              if (code.isEmpty) return;
              // use `c` here so we don't shadow the outer `cat` parameter
              final c = await service.getCategoryByCode(code);
              if (c == null) {
                setState(() {
                  _foundCategory = null;
                  selectedCategoryId = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⚠️ Kode barang tidak ditemukan'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } else {
                setState(() {
                  _foundCategory = c;
                  selectedCategoryId = c.id;
                  unitController.text = c.satuan;
                  if (priceController.text.isEmpty) {
                    priceController.text = c.hargaPerUnit.toString();
                  }
                });
              }
            }

            return AlertDialog(
              title: const Text('Tambah Pengeluaran'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          tooltip: 'Cari berdasarkan kode',
                          onPressed: lookupInDialog,
                        ),
                      ),
                      onEditingComplete: lookupInDialog,
                      onChanged: (val) {
                        if (_foundCategory != null) {
                          setState(() {
                            _foundCategory = null;
                            selectedCategoryId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_foundCategory != null)
                      _buildCategoryInfo(_foundCategory!),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Judul Transaksi (Opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.title),
                        hintText: 'Misal: Penerimaan Barang, Pemakaian',
                      ),
                    ),
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
                          (val) => setState(() {
                            quantity = int.tryParse(val) ?? 0;
                          }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Harga per Unit Rp (Wajib)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        final qty =
                            double.tryParse(quantityController.text) ?? 0;
                        final price =
                            double.tryParse(priceController.text) ?? 0;
                        return Text(
                          'Total: Rp ${(qty * price).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Deskripsi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                  onPressed: () async {
                    try {
                      final code = itemCodeController.text.trim();
                      final qty = double.tryParse(quantityController.text) ?? 0;
                      final price = double.tryParse(priceController.text) ?? 0;
                      if (code.isEmpty ||
                          selectedCategoryId == null ||
                          qty <= 0 ||
                          price <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ Isi kode barang yang valid, jumlah, satuan & harga',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (qty < 0 || price < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '⚠️ Jumlah dan harga tidak boleh negatif',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
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
                        type: type,
                        date: _selectedDate ?? DateTime.now(),
                        categoryId: selectedCategoryId!,
                        itemName: _foundCategory?.namaBarang ?? '',
                        location: _foundCategory?.lokasi ?? '',
                        createdAt: Timestamp.now(),
                      );

                      await service.addTransaction(transaction);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Transaksi berhasil ditambahkan'),
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
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportToCsv() async {
    try {
      final allTrx = await service.getTransactions().first;
      final allCats = await service.getCategories().first;

      // Kelompokkan transaksi per categoryId
      final Map<String, List<TransactionModel>> txByCategory = {};
      for (var t in allTrx.where((t) => t.type == 'pengeluaran')) {
        if (!txByCategory.containsKey(t.categoryId)) {
          txByCategory[t.categoryId] = [];
        }
        txByCategory[t.categoryId]!.add(t);
      }

      // Buat file untuk setiap barang
      for (var categoryId in txByCategory.keys) {
        final category = allCats.firstWhereOrNull((c) => c.id == categoryId);
        if (category == null) continue;

        final transactions = txByCategory[categoryId]!;
        transactions.sort((a, b) => a.date.compareTo(b.date));

        // Header info
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
        double saldoHarga = category.hargaPerUnit;

        for (int idx = 0; idx < transactions.length; idx++) {
          final tx = transactions[idx];
          final isKeluar = tx.type == 'pengeluaran';

          double masukQty = isKeluar ? 0 : tx.quantity;
          double masukHarga = isKeluar ? 0 : tx.pricePerUnit;
          double masukJumlah = masukQty * masukHarga;

          double keluarQty = isKeluar ? tx.quantity : 0;
          double keluarHarga = isKeluar ? tx.pricePerUnit : 0;
          double keluarJumlah = keluarQty * keluarHarga;

          if (isKeluar) {
            saldoQty -= tx.quantity;
          } else {
            saldoQty += tx.quantity;
          }
          saldoHarga = tx.pricePerUnit; // update harga terakhir

          rows.add([
            (idx + 1).toString(),
            DateFormat('d-MMM-yy').format(tx.date),
            tx.title.isEmpty ? tx.itemName : tx.title,
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
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Export berhasil—file telah diunduh'),
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
      double saldoHarga = category.hargaPerUnit;

      for (int idx = 0; idx < transactions.length; idx++) {
        final tx = transactions[idx];
        final isMasuk = tx.type == 'pemasukan';
        final isKeluar = tx.type == 'pengeluaran';

        double masukQty = isMasuk ? tx.quantity : 0;
        double masukHarga = isMasuk ? tx.pricePerUnit : 0;
        double masukJumlah = masukQty * masukHarga;

        double keluarQty = isKeluar ? tx.quantity : 0;
        double keluarHarga = isKeluar ? tx.pricePerUnit : 0;
        double keluarJumlah = keluarQty * keluarHarga;

        // Update saldo
        if (isMasuk) {
          saldoQty += tx.quantity;
        } else if (isKeluar) {
          saldoQty -= tx.quantity;
        }
        saldoHarga = tx.pricePerUnit;

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
