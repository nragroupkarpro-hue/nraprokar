import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nra_pro_kar/models/category_model.dart';
import 'package:nra_pro_kar/services/firestore_service.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  final NumberFormat _fmt = NumberFormat.decimalPattern('en_US');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = _fmt.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirestoreService service = FirestoreService();
  final searchController = TextEditingController();
  String searchQuery = '';

  final namaBarangController = TextEditingController();
  final satuanController = TextEditingController();
  final lokasiController = TextEditingController();
  final kuantitasController = TextEditingController();
  final hargaPerUnitController = TextEditingController();
  final varianInfoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Data Barang & Stok", style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SEARCH BAR MODERN ---
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20, top: 10),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari barang atau lokasi...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
            
          // --- KONTEN LIST (SCROLL BEBAS) ---
          Expanded(
            child: _buildCategoriesView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddCategoryDialog,
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Barang Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- LOGIKA STREAM (MENAMPILKAN SEMUA DATA) ---
  Widget _buildCategoriesView() {
    return StreamBuilder<List<CategoryModel>>(
      // MENGGUNAKAN getCategories() agar SEMUA data barang dari semua bulan tampil
      stream: service.getCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.teal));

        var categories = snapshot.data!;
        
        // Filter pencarian (Jika user mengetik di kotak pencarian)
        if (searchQuery.isNotEmpty) {
          categories = categories.where((cat) =>
              cat.namaBarang.toLowerCase().contains(searchQuery) ||
              cat.satuan.toLowerCase().contains(searchQuery) ||
              cat.lokasi.toLowerCase().contains(searchQuery)).toList();
        }

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(searchQuery.isNotEmpty ? 'Barang tidak ditemukan' : 'Belum ada data barang', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              ],
            ),
          );
        }
        
        // Memanggil List tanpa Pagination
        return _buildCategoryList(categories);
      },
    );
  }

  // --- WIDGET LIST KARTU MODERN (SCROLL SEPUASNYA) ---
  Widget _buildCategoryList(List<CategoryModel> categories) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final kuantitasColor = cat.kuantitas > 0 ? Colors.teal : cat.kuantitas == 0 ? Colors.orange : Colors.red;

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showCategoryDetail(cat),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon Samping
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.inventory_2, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 16),
                  // Detail Barang
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text("Lokasi: ${cat.lokasi} | Kode: ${cat.kodeBarang}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: kuantitasColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text("Stok: ${cat.kuantitas} ${cat.satuan}", style: TextStyle(color: kuantitasColor, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Text("Rp ${cat.jumlahHargaFormatted}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          ],
                        )
                      ],
                    ),
                  ),
                  // Aksi Samping (Copy & Menu)
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Colors.grey),
                        tooltip: 'Salin kode',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cat.kodeBarang));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kode "${cat.kodeBarang}" disalin')));
                        },
                      ),
                      PopupMenuButton(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: Row(children: const [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                            onTap: () => Future.delayed(const Duration(milliseconds: 500), () => _showEditCategoryDialog(cat)),
                          ),
                          PopupMenuItem(
                            child: Row(children: const [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))]),
                            onTap: () => Future.delayed(const Duration(milliseconds: 500), () => _showDeleteConfirmation(cat)),
                          ),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- FUNGSI ASLI POP UP DETAIL, EDIT & TAMBAH ---

  void _showCategoryDetail(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(cat.namaBarang, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  color: Colors.teal.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Nama Barang', cat.namaBarang),
                        const Divider(),
                        _buildDetailRow('Satuan', cat.satuan),
                        const Divider(),
                        _buildDetailRow('Lokasi', cat.lokasi),
                        const Divider(),
                        _buildDetailRow('Kuantitas', cat.kuantitas.toString(), color: cat.kuantitas > 0 ? Colors.teal : Colors.red),
                        const Divider(),
                        _buildDetailRow('Harga/Unit', 'Rp ${cat.hargaPerUnitFormatted}'),
                        const Divider(),
                        if (cat.varianInfo != null) _buildDetailRow('Varian/Ukuran', cat.varianInfo!),
                        if (cat.varianInfo != null) const Divider(),
                        _buildDetailRow('Jumlah Harga', 'Rp ${cat.jumlahHargaFormatted}', color: Colors.blue),
                        const Divider(),
                        if (cat.createdAt != null) _buildDetailRow('Dibuat Pada', DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(cat.createdAt!)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showEditCategoryDialog(cat);
              },
              child: const Text('Edit', style: TextStyle(color: Colors.blue)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showDeleteConfirmation(cat);
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
        Flexible(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.black), textAlign: TextAlign.end)),
      ],
    );
  }

  void _showEditCategoryDialog(CategoryModel cat) {
    final namaBarangController = TextEditingController(text: cat.namaBarang);
    final satuanController = TextEditingController(text: cat.satuan);
    final lokasiController = TextEditingController(text: cat.lokasi);
    final kuantitasController = TextEditingController(text: cat.kuantitas.toString());
    final hargaPerUnitController = TextEditingController(text: cat.hargaPerUnitFormatted);
    final varianInfoController = TextEditingController(text: cat.varianInfo ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Barang', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: namaBarangController, decoration: InputDecoration(labelText: 'Nama Barang', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.category, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: satuanController, decoration: InputDecoration(labelText: 'Satuan', hintText: 'Misal: pcs, kg', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.straighten, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: lokasiController, decoration: InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_on, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: kuantitasController, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: InputDecoration(labelText: 'Kuantitas', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.inventory, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: hargaPerUnitController, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: InputDecoration(labelText: 'Harga/Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.attach_money, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: varianInfoController, decoration: InputDecoration(labelText: 'Varian/Ukuran (Opsional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.info_outline, color: Colors.teal))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    try {
                      if (namaBarangController.text.isEmpty || satuanController.text.isEmpty || lokasiController.text.isEmpty || kuantitasController.text.isEmpty || hargaPerUnitController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Mohon isi semua field'), backgroundColor: Colors.orange));
                        return;
                      }

                      final kuantitas = int.parse(kuantitasController.text.replaceAll(',', ''));
                      final hargaPerUnit = double.parse(hargaPerUnitController.text.replaceAll(',', ''));

                      if (kuantitas < 0 || hargaPerUnit < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Nilai tidak boleh negatif'), backgroundColor: Colors.orange));
                        return;
                      }

                      final updated = CategoryModel(
                        id: cat.id,
                        namaBarang: namaBarangController.text.trim(),
                        satuan: satuanController.text.trim(),
                        lokasi: lokasiController.text.trim(),
                        kodeBarang: cat.kodeBarang,
                        kuantitas: kuantitas,
                        hargaPerUnit: hargaPerUnit,
                        jumlahHarga: kuantitas * hargaPerUnit,
                        varianInfo: varianInfoController.text.trim().isNotEmpty ? varianInfoController.text.trim() : null,
                        createdAt: cat.createdAt,
                      );

                      await service.updateCategory(cat.id!, updated);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('✅ Barang berhasil diupdate'), backgroundColor: Colors.green));
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

  void _showDeleteConfirmation(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Barang?', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin menghapus barang "${cat.namaBarang}"?\n\nTindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                try {
                  await service.deleteCategory(cat.id!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('✅ Barang berhasil dihapus'), backgroundColor: Colors.green));
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void showAddCategoryDialog() {
    namaBarangController.clear();
    satuanController.clear();
    lokasiController.clear();
    kuantitasController.clear();
    hargaPerUnitController.clear();
    varianInfoController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Tambah Barang', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: namaBarangController, decoration: InputDecoration(labelText: 'Nama Barang', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.category, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: satuanController, decoration: InputDecoration(labelText: 'Satuan', hintText: 'Misal: pcs, kg', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.straighten, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: lokasiController, decoration: InputDecoration(labelText: 'Lokasi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.location_on, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: kuantitasController, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: InputDecoration(labelText: 'Kuantitas Awal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.inventory, color: Colors.teal))),
                    const SizedBox(height: 12),
                    TextField(controller: hargaPerUnitController, keyboardType: TextInputType.number, inputFormatters: [ThousandsFormatter()], decoration: InputDecoration(labelText: 'Harga/Unit', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.attach_money, color: Colors.teal))),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    try {
                      if (namaBarangController.text.isEmpty || satuanController.text.isEmpty || lokasiController.text.isEmpty || kuantitasController.text.isEmpty || hargaPerUnitController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⚠️ Mohon isi semua field wajib'), backgroundColor: Colors.orange));
                        return;
                      }

                      final kuantitas = int.parse(kuantitasController.text.replaceAll(',', ''));
                      final hargaPerUnit = double.parse(hargaPerUnitController.text.replaceAll(',', ''));

                      final category = CategoryModel(
                        namaBarang: namaBarangController.text.trim(),
                        satuan: satuanController.text.trim(),
                        lokasi: lokasiController.text.trim(),
                        kodeBarang: CategoryModel.generateAutoCode(),
                        kuantitas: kuantitas,
                        hargaPerUnit: hargaPerUnit,
                        jumlahHarga: kuantitas * hargaPerUnit,
                        varianInfo: varianInfoController.text.trim().isNotEmpty ? varianInfoController.text.trim() : null,
                        createdAt: DateTime.now(),
                      );

                      await service.addCategory(category);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('✅ Barang berhasil ditambahkan'), backgroundColor: Colors.green));
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

  @override
  void dispose() {
    namaBarangController.dispose();
    satuanController.dispose();
    lokasiController.dispose();
    kuantitasController.dispose();
    hargaPerUnitController.dispose();
    varianInfoController.dispose();
    searchController.dispose();
    super.dispose();
  }
}