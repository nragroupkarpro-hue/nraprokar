import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nra_pro_kar/models/category_model.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';

class AddTransactionPage extends StatefulWidget {
  @override
  _AddTransactionPageState createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  // controllers for fields we still keep
  final _itemCodeController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _type = "pengeluaran";
  String? _selectedCategoryId;
  int quantity = 0;
  DateTime? _selectedDate;

  CategoryModel? _foundCategory;

  final FirestoreService _service = FirestoreService();

  @override
  void initState() {
    super.initState();
    _itemCodeController.addListener(() {
      // clearing previous lookup when code text changes
      if (_foundCategory != null) {
        setState(() {
          _foundCategory = null;
          _selectedCategoryId = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _itemCodeController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Look up a category by kode_barang and populate related fields.
  Future<void> _lookupCategory() async {
    final code = _itemCodeController.text.trim();
    if (code.isEmpty) return;

    final cat = await _service.getCategoryByCode(code);
    if (cat == null) {
      setState(() {
        _foundCategory = null;
        _selectedCategoryId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Kode barang tidak ditemukan'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      setState(() {
        _foundCategory = cat;
        _selectedCategoryId = cat.id;
        _unitController.text = cat.satuan;
        if (_priceController.text.isEmpty) {
          _priceController.text = cat.hargaPerUnit.toString();
        }
      });
    }
  }

  /// Small widget that shows a summary of the currently selected category.
  Widget _buildCategoryInfo(CategoryModel cat) {
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
              'Informasi Barang: ${cat.namaBarang}',
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
              style: const TextStyle(fontSize: 12, color: Colors.teal),
            ),
            if (quantity > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Preview stok setelah transaksi: ${_type == "pengeluaran" ? cat.kuantitas - quantity : cat.kuantitas + quantity} ${cat.satuan}',
                  style: TextStyle(
                    color:
                        _type == "pengeluaran" && cat.kuantitas - quantity < 0
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

  void _save() async {
    final title = _titleController.text.trim();
    final code = _itemCodeController.text.trim();
    final name = _foundCategory?.namaBarang ?? '';
    final unit = _unitController.text.trim();
    final loc = _foundCategory?.lokasi ?? '';
    final description = _descriptionController.text.trim();
    final qty = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    final total = qty * price;

    if (code.isEmpty || _selectedCategoryId == null || qty <= 0 || price <= 0) {
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
          content: Text('⚠️ Jumlah dan harga tidak boleh negatif'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final trx = TransactionModel(
      title: title.isEmpty ? (_foundCategory?.namaBarang ?? '') : title,
      itemCode: code,
      quantity: qty,
      pricePerUnit: price,
      totalPrice: total,
      amount: total,
      description: description,
      type: _type,
      date: _selectedDate ?? DateTime.now(),
      categoryId: _selectedCategoryId!,
      itemName: name,
      unit: unit,
      location: loc,
      createdAt: Timestamp.now(),
    );

    try {
      await _service.addTransaction(trx);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Transaksi berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _selectedDate ??= DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Transaksi"),
        backgroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kode barang & lookup
              TextField(
                controller: _itemCodeController,
                decoration: InputDecoration(
                  labelText: 'Kode Barang',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.qr_code),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Cari berdasarkan kode',
                    onPressed: _lookupCategory,
                  ),
                ),
                onEditingComplete: _lookupCategory,
                onChanged: (val) {
                  if (_foundCategory != null) {
                    setState(() {
                      _foundCategory = null;
                      _selectedCategoryId = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_foundCategory != null) _buildCategoryInfo(_foundCategory!),
              const SizedBox(height: 12),

              // editable satuan, prefilled by lookup
              TextField(
                controller: _unitController,
                decoration: InputDecoration(
                  labelText: 'Satuan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Judul (opsional)
              TextField(
                controller: _titleController,
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
              // Jumlah (wajib)
              TextField(
                controller: _quantityController,
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

              // Harga per Unit (wajib)
              TextField(
                controller: _priceController,
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

              // Total Harga (preview)
              Builder(
                builder: (_) {
                  final qty = double.tryParse(_quantityController.text) ?? 0;
                  final price = double.tryParse(_priceController.text) ?? 0;
                  final total = qty * price;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Harga:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Rp ${total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Deskripsi (opsional)
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Deskripsi (Opsional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                  hintText: 'Masukkan catatan tambahan untuk transaksi ini',
                ),
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text(
                    "Simpan Transaksi",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
