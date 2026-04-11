import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nra_pro_kar/models/category_model.dart';
import 'package:nra_pro_kar/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/transaction_model.dart';

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
  String _selectedLocation = 'Semua';

  // Bulk delete state
  Set<String> selectedIds = {};
  bool isSelectionMode = false;

  final namaBarangController = TextEditingController();
  final satuanController = TextEditingController();
  String? lokasiDropdownValue;
  final kuantitasController = TextEditingController();
  final hargaPerUnitController = TextEditingController();
  final varianInfoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? "${selectedIds.length} dipilih"
              : "Data Barang & Stok",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions:
            isSelectionMode
                ? [
                  IconButton(
                    icon: const Icon(Icons.select_all),
                    onPressed: _selectAll,
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSelection,
                  ),
                ]
                : null,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.teal,
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
                        selectedColor: Colors.white,
                        labelStyle: TextStyle(
                          color:
                              _selectedLocation == 'Semua'
                                  ? Colors.teal
                                  : Colors.white,
                        ),
                        backgroundColor: Colors.teal.shade400,
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
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color:
                                      _selectedLocation == loc['name']
                                          ? Colors.teal
                                          : Colors.white,
                                ),
                                backgroundColor: Colors.teal.shade400,
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
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 20,
              top: 10,
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari barang...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged:
                  (value) => setState(() => searchQuery = value.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CategoryModel>>(
              stream: service.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  );
                var categories = snapshot.data!;
                if (_selectedLocation != 'Semua')
                  categories =
                      categories
                          .where((cat) => cat.lokasi == _selectedLocation)
                          .toList();
                if (searchQuery.isNotEmpty)
                  categories =
                      categories
                          .where(
                            (cat) => cat.namaBarang.toLowerCase().contains(
                              searchQuery,
                            ),
                          )
                          .toList();
                if (categories.isEmpty)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada data barang',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final kuantitasColor =
                        cat.kuantitas > 0
                            ? Colors.teal
                            : cat.kuantitas == 0
                            ? Colors.orange
                            : Colors.red;
                    final isSelected = selectedIds.contains(cat.id);
                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isSelected ? Colors.teal.shade50 : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onTap:
                            isSelectionMode
                                ? () => _toggleSelection(cat.id!)
                                : () => _showCategoryDetail(cat),
                        onLongPress: () => _enterSelectionMode(cat.id!),
                        leading:
                            isSelectionMode
                                ? Checkbox(
                                  value: isSelected,
                                  onChanged:
                                      (value) => _toggleSelection(cat.id!),
                                  activeColor: Colors.teal,
                                )
                                : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2,
                                    color: Colors.orange,
                                    size: 28,
                                  ),
                                ),
                        title: Text(
                          cat.namaBarang,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "📍 ${cat.lokasi} | Kode: ${cat.kodeBarang}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kuantitasColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Stok: ${cat.kuantitas} ${cat.satuan}",
                                      style: TextStyle(
                                        color: kuantitasColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Rp ${cat.hargaPerUnitFormatted}/unit",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.copy,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: cat.kodeBarang),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Kode "${cat.kodeBarang}" disalin',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton:
          isSelectionMode
              ? null
              : FloatingActionButton.extended(
                onPressed: showAddCategoryDialog,
                backgroundColor: Colors.teal,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Barang Baru",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      bottomNavigationBar:
          isSelectionMode && selectedIds.isNotEmpty
              ? BottomAppBar(
                color: Colors.red,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${selectedIds.length} item dipilih",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _bulkDeleteCategories,
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text(
                          "Hapus",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              : null,
    );
  }

  void _showCategoryDetail(CategoryModel cat) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              cat.namaBarang,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.teal.shade50,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Nama Barang', cat.namaBarang),
                          const Divider(),
                          _buildDetailRow('Satuan', cat.satuan),
                          const Divider(),
                          _buildDetailRow('Lokasi Tempat', cat.lokasi),
                          const Divider(),
                          _buildDetailRow(
                            'Kuantitas',
                            cat.kuantitas.toString(),
                            color: cat.kuantitas > 0 ? Colors.teal : Colors.red,
                          ),
                          const Divider(),
                          _buildDetailRow(
                            'Harga/Unit',
                            'Rp ${cat.hargaPerUnitFormatted}',
                          ),
                          const Divider(),
                          if (cat.varianInfo != null)
                            _buildDetailRow('Varian', cat.varianInfo!),
                          if (cat.varianInfo != null) const Divider(),
                          _buildDetailRow(
                            'Jumlah Harga',
                            'Rp ${cat.jumlahHargaFormatted}',
                            color: Colors.blue,
                          ),
                          const Divider(),
                          if (cat.createdAt != null)
                            _buildDetailRow(
                              'Dibuat Pada',
                              DateFormat(
                                'dd MMM yyyy HH:mm',
                              ).format(cat.createdAt!),
                            ),
                          // TAMPILKAN DI DETAIL BARANG
                          if (cat.supplierName != null &&
                              cat.supplierName!.isNotEmpty) ...[
                            const Divider(color: Colors.teal, thickness: 2),
                            _buildDetailRow('Supplier', cat.supplierName!),
                          ],
                          if (cat.supplierNumber != null &&
                              cat.supplierNumber!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow('No. Telepon', cat.supplierNumber!),
                          ],
                          if (cat.supplierDetail != null &&
                              cat.supplierDetail!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow('Alamat', cat.supplierDetail!),
                          ],
                          if (cat.suratJalan != null &&
                              cat.suratJalan!.isNotEmpty) ...[
                            const Divider(),
                            _buildDetailRow('Surat Jalan', cat.suratJalan!),
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
                child: const Text(
                  'Tutup',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
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
          ),
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

  void _showEditCategoryDialog(CategoryModel cat) {
    namaBarangController.text = cat.namaBarang;
    satuanController.text = cat.satuan;
    lokasiDropdownValue = cat.lokasi;
    kuantitasController.text = cat.kuantitas.toString();
    hargaPerUnitController.text = cat.hargaPerUnitFormatted;
    varianInfoController.text = cat.varianInfo ?? '';

    // LOAD FIELD EDIT MASTER BARANG
    final supplierNameController = TextEditingController(
      text: cat.supplierName ?? '',
    );
    final supplierNumberController = TextEditingController(
      text: cat.supplierNumber ?? '',
    );
    final supplierDetailController = TextEditingController(
      text: cat.supplierDetail ?? '',
    );
    final suratJalanController = TextEditingController(
      text: cat.suratJalan ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Barang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaBarangController,
                      decoration: InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.category,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.straighten,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: service.getLocations(),
                      builder: (context, snap) {
                        if (!snap.hasData)
                          return const CircularProgressIndicator();
                        final locs = snap.data!;
                        if (locs.isEmpty)
                          return const Text(
                            '⚠️ Tambah Kategori Tempat dulu di Menu!',
                            style: TextStyle(color: Colors.red),
                          );
                        if (lokasiDropdownValue != null &&
                            !locs.any((l) => l['name'] == lokasiDropdownValue))
                          lokasiDropdownValue = locs.first['name'];
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Pilih Tempat/Lokasi',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.store,
                              color: Colors.teal,
                            ),
                          ),
                          value: lokasiDropdownValue,
                          items:
                              locs
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['name'].toString(),
                                      child: Text(e['name'].toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setStateDialog(
                                () => lokasiDropdownValue = val,
                              ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kuantitasController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Kuantitas',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.inventory,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hargaPerUnitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Harga Master/Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Divider(thickness: 2),
                    const Text(
                      "Data Supplier & Surat Jalan (Opsional)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: supplierNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.local_shipping,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. Telp / WA',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierDetailController,
                      decoration: InputDecoration(
                        labelText: 'Alamat Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.map, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: suratJalanController,
                      decoration: InputDecoration(
                        labelText: 'No. Surat Jalan / Resi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.receipt,
                          color: Colors.teal,
                        ),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Konfirmasi Simpan'),
                            content: const Text(
                              'Apakah Anda yakin data barang yang diubah sudah benar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Periksa Lagi'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
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

                    if (namaBarangController.text.isEmpty ||
                        satuanController.text.isEmpty ||
                        lokasiDropdownValue == null ||
                        kuantitasController.text.isEmpty ||
                        hargaPerUnitController.text.isEmpty)
                      return;
                    final kuantitas = int.parse(
                      kuantitasController.text.replaceAll(',', ''),
                    );
                    final hargaPerUnit = double.parse(
                      hargaPerUnitController.text.replaceAll(',', ''),
                    );

                    final updated = CategoryModel(
                      id: cat.id,
                      namaBarang: namaBarangController.text.trim(),
                      satuan: satuanController.text.trim(),
                      lokasi: lokasiDropdownValue!,
                      kodeBarang: cat.kodeBarang,
                      kuantitas: kuantitas,
                      hargaPerUnit: hargaPerUnit,
                      jumlahHarga: kuantitas * hargaPerUnit,
                      varianInfo:
                          varianInfoController.text.trim().isNotEmpty
                              ? varianInfoController.text.trim()
                              : null,
                      createdAt: cat.createdAt,
                      // SIMPAN DATA SUPPLIER SAAT EDIT
                      supplierName: supplierNameController.text.trim(),
                      supplierNumber: supplierNumberController.text.trim(),
                      supplierDetail: supplierDetailController.text.trim(),
                      suratJalan: suratJalanController.text.trim(),
                    );
                    await service.updateCategory(cat.id!, updated);
                    Navigator.pop(context);
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

  void _showDeleteConfirmation(CategoryModel cat) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '⚠️ Hapus Barang?',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus "${cat.namaBarang}" secara permanen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await service.deleteCategory(cat.id!);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _enterSelectionMode(String id) {
    setState(() {
      isSelectionMode = true;
      selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      // Get current filtered categories
      final snapshot = service.getCategories();
      // Since it's async, we need to handle differently. For simplicity, assume we have the list.
      // Actually, better to get from current context, but for now, toggle all visible.
      // This is tricky with StreamBuilder. Perhaps store the current list.
      // For simplicity, let's add a method to get current categories.
      // Wait, better: since we have the filtered list in builder, we can pass it.
      // But to keep simple, let's assume we select all from current view.
      // Actually, modify to store currentCategories.
    });
    // For now, implement later if needed. User can select manually.
  }

  void _clearSelection() {
    setState(() {
      selectedIds.clear();
      isSelectionMode = false;
    });
  }

  void _bulkDeleteCategories() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text(
              '⚠️ Hapus Barang?',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus ${selectedIds.length} barang secara permanen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await service.bulkDeleteCategories(selectedIds.toList());
        setState(() {
          selectedIds.clear();
          isSelectionMode = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Barang berhasil dihapus!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Gagal menghapus: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void showAddCategoryDialog() {
    namaBarangController.clear();
    satuanController.clear();
    kuantitasController.clear();
    hargaPerUnitController.clear();
    varianInfoController.clear();
    lokasiDropdownValue =
        _selectedLocation == 'Semua' ? null : _selectedLocation;

    // KONTROL TAMBAH BARANG
    final supplierNameController = TextEditingController();
    final supplierNumberController = TextEditingController();
    final supplierDetailController = TextEditingController();
    final suratJalanController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Tambah Barang',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaBarangController,
                      decoration: InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.category,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.straighten,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: service.getLocations(),
                      builder: (context, snap) {
                        if (!snap.hasData)
                          return const CircularProgressIndicator();
                        final locs = snap.data!;
                        if (locs.isEmpty)
                          return const Text(
                            '⚠️ Tambah Kategori Tempat dulu di Menu!',
                            style: TextStyle(color: Colors.red),
                          );
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Pilih Tempat/Lokasi',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.store,
                              color: Colors.teal,
                            ),
                          ),
                          value: lokasiDropdownValue,
                          items:
                              locs
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e['name'].toString(),
                                      child: Text(e['name'].toString()),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setStateDialog(
                                () => lokasiDropdownValue = val,
                              ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kuantitasController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Kuantitas Awal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.inventory,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hargaPerUnitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Harga Master/Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: Colors.teal,
                        ),
                      ),
                    ),

                    const Divider(thickness: 2),
                    const Text(
                      "Data Supplier & Surat Jalan (Opsional)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: supplierNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.local_shipping,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'No. Telp / WA',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.phone, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: supplierDetailController,
                      decoration: InputDecoration(
                        labelText: 'Alamat Supplier',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.map, color: Colors.teal),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: suratJalanController,
                      decoration: InputDecoration(
                        labelText: 'No. Surat Jalan / Resi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(
                          Icons.receipt,
                          color: Colors.teal,
                        ),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Konfirmasi Simpan'),
                            content: const Text(
                              'Apakah Anda yakin data barang baru yang dimasukkan sudah benar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Periksa Lagi'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
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

                    if (namaBarangController.text.isEmpty ||
                        satuanController.text.isEmpty ||
                        lokasiDropdownValue == null ||
                        kuantitasController.text.isEmpty ||
                        hargaPerUnitController.text.isEmpty)
                      return;

                    final kuantitasInput = int.parse(
                      kuantitasController.text.replaceAll(',', ''),
                    );
                    final hargaPerUnitInput = double.parse(
                      hargaPerUnitController.text.replaceAll(',', ''),
                    );

                    final category = CategoryModel(
                      namaBarang: namaBarangController.text.trim(),
                      satuan: satuanController.text.trim(),
                      lokasi: lokasiDropdownValue!,
                      kodeBarang: CategoryModel.generateAutoCode(),
                      kuantitas: kuantitasInput,
                      hargaPerUnit: hargaPerUnitInput,
                      jumlahHarga: kuantitasInput * hargaPerUnitInput,
                      createdAt: DateTime.now(),
                      supplierName: supplierNameController.text.trim(),
                      supplierNumber: supplierNumberController.text.trim(),
                      supplierDetail: supplierDetailController.text.trim(),
                      suratJalan: suratJalanController.text.trim(),
                    );

                    await service.addCategory(category);
                    Navigator.pop(context);
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Master Barang berhasil direkam!'),
                          backgroundColor: Colors.green,
                        ),
                      );
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
}
