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
  String _selectedLocation = 'Semua';

  Set<String> selectedIds = {};
  bool isSelectionMode = false;

  final namaBarangController = TextEditingController();
  final judulController = TextEditingController();
  final deskripsiController = TextEditingController();
  final satuanController = TextEditingController();
  String? lokasiDropdownValue;
  final kuantitasController = TextEditingController();
  final hargaPerUnitController = TextEditingController();
  final varianInfoController = TextEditingController();
  List<String> visibleCategoryIds = [];

  // Modern Input Decoration Helper
  InputDecoration _modernInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.teal.shade600, size: 22),
      filled: true,
      fillColor: Colors.grey.shade50,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? "${selectedIds.length} dipilih"
              : "Data Barang & Stok",
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
            decoration: BoxDecoration(
              color: Colors.teal.shade700,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: service.getLocations(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox();
                    final locations = snap.data!;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip('Semua Tempat'),
                          ...locations
                              .map((loc) => _buildFilterChip(loc['name']))
                              .toList(),
                        ],
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 15, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Cari barang (Nama / Kode)...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.teal.shade400,
                        ),
                        suffixIcon:
                            searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    searchController.clear();
                                    setState(() => searchQuery = '');
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => searchQuery = value.toLowerCase()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
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
                            (cat) =>
                                cat.namaBarang.toLowerCase().contains(
                                  searchQuery,
                                ) ||
                                cat.kodeBarang.toLowerCase().contains(
                                  searchQuery,
                                ),
                          )
                          .toList();

                visibleCategoryIds =
                    categories
                        .where((cat) => cat.id != null)
                        .map((cat) => cat.id!)
                        .toList();

                if (categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.teal.shade300,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada data barang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blueGrey.shade400,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isLowStock = cat.kuantitas <= 0;
                    final kuantitasColor =
                        isLowStock ? Colors.red : Colors.teal;
                    final isSelected = selectedIds.contains(cat.id);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.teal.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isSelected
                                  ? Colors.teal.shade300
                                  : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                )
                                : Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.orange.shade100,
                                        Colors.orange.shade50,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_rounded,
                                    color: Colors.orange.shade700,
                                    size: 26,
                                  ),
                                ),
                        title: Text(
                          cat.namaBarang,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.blueGrey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    cat.lokasi,
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade600,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    " • Kode: ${cat.kodeBarang}",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kuantitasColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "Stok: ${cat.kuantitas} ${cat.satuan}",
                                      style: TextStyle(
                                        color: kuantitasColor.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Rp ${cat.hargaPerUnitFormatted}/unit",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.teal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 22,
                            color: Colors.blueGrey,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: cat.kodeBarang),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Kode "${cat.kodeBarang}" berhasil disalin!',
                                ),
                                backgroundColor: Colors.teal.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                backgroundColor: Colors.teal.shade600,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Barang Baru",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
      bottomNavigationBar:
          isSelectionMode && selectedIds.isNotEmpty
              ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${selectedIds.length} item dipilih",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _bulkDeleteCategories,
                      icon: const Icon(Icons.delete_sweep, color: Colors.white),
                      label: const Text(
                        "Hapus Semua",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : null,
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedLocation == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.teal.shade700 : Colors.white,
          ),
        ),
        selected: isSelected,
        selectedColor: Colors.white,
        backgroundColor: Colors.teal.shade500,
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? Colors.white : Colors.transparent,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        onSelected: (val) => setState(() => _selectedLocation = label),
      ),
    );
  }

  void _showCategoryDetail(CategoryModel cat) {
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
                            color: Colors.teal.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.inventory_2,
                            color: Colors.teal.shade600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            cat.namaBarang,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
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
                          _buildDetailRow('Kode Barang', cat.kodeBarang),
                          const Divider(height: 24),
                          _buildDetailRow('Satuan', cat.satuan),
                          const Divider(height: 24),
                          _buildDetailRow('Lokasi Tempat', cat.lokasi),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Kuantitas',
                            '${cat.kuantitas} ${cat.satuan}',
                            color:
                                cat.kuantitas > 0
                                    ? Colors.teal.shade700
                                    : Colors.red.shade700,
                          ),
                          const Divider(height: 24),
                          _buildDetailRow(
                            'Harga/Unit',
                            'Rp ${cat.hargaPerUnitFormatted}',
                          ),
                          const Divider(height: 24),
                          if (cat.varianInfo != null &&
                              cat.varianInfo!.isNotEmpty) ...[
                            _buildDetailRow('Varian', cat.varianInfo!),
                            const Divider(height: 24),
                          ],
                          _buildDetailRow(
                            'Total Aset',
                            'Rp ${cat.jumlahHargaFormatted}',
                            color: Colors.blue.shade700,
                          ),
                        ],
                      ),
                    ),
                    if ((cat.supplierName != null &&
                            cat.supplierName!.isNotEmpty) ||
                        (cat.suratJalan != null &&
                            cat.suratJalan!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      const Text(
                        "Data Asal Barang",
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
                            if (cat.supplierName != null &&
                                cat.supplierName!.isNotEmpty) ...[
                              _buildDetailRow('Supplier', cat.supplierName!),
                              const Divider(height: 20),
                            ],
                            if (cat.supplierNumber != null &&
                                cat.supplierNumber!.isNotEmpty) ...[
                              _buildDetailRow(
                                'No. Telepon',
                                cat.supplierNumber!,
                              ),
                              const Divider(height: 20),
                            ],
                            if (cat.supplierDetail != null &&
                                cat.supplierDetail!.isNotEmpty) ...[
                              _buildDetailRow('Alamat', cat.supplierDetail!),
                              const Divider(height: 20),
                            ],
                            if (cat.suratJalan != null &&
                                cat.suratJalan!.isNotEmpty)
                              _buildDetailRow('Surat Jalan', cat.suratJalan!),
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
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showEditCategoryDialog(cat);
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showDeleteConfirmation(cat);
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  void _showEditCategoryDialog(CategoryModel cat) {
    namaBarangController.text = cat.namaBarang;
    judulController.text = cat.judul ?? '';
    deskripsiController.text = cat.deskripsi ?? '';
    satuanController.text = cat.satuan;
    lokasiDropdownValue = cat.lokasi;
    kuantitasController.text = cat.kuantitas.toString();
    hargaPerUnitController.text = cat.hargaPerUnitFormatted;
    varianInfoController.text = cat.varianInfo ?? '';
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setStateDialog) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: const Text(
                    'Edit Master Barang',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: namaBarangController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Nama Barang',
                            Icons.category,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: judulController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Judul (Opsional)',
                            Icons.title,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: deskripsiController,
                          style: const TextStyle(color: Colors.black),
                          maxLines: 2,
                          decoration: _modernInputDecoration(
                            'Deskripsi Barang',
                            Icons.description,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: satuanController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Satuan (pcs, box, kg)',
                            Icons.straighten,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: service.getLocations(),
                          builder: (context, snap) {
                            if (!snap.hasData)
                              return const CircularProgressIndicator();
                            final locs = snap.data!;
                            if (lokasiDropdownValue != null &&
                                !locs.any(
                                  (l) => l['name'] == lokasiDropdownValue,
                                ))
                              lokasiDropdownValue = locs.first['name'];
                            return DropdownButtonFormField<String>(
                              decoration: _modernInputDecoration(
                                'Pilih Tempat/Lokasi',
                                Icons.store,
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: kuantitasController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsFormatter()],
                          decoration: _modernInputDecoration(
                            'Kuantitas',
                            Icons.inventory,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: hargaPerUnitController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsFormatter()],
                          decoration: _modernInputDecoration(
                            'Harga Master/Unit',
                            Icons.attach_money,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(),
                        const Text(
                          "Data Asal / Supplier (Opsional)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: supplierNameController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Nama Supplier',
                            Icons.local_shipping,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: supplierNumberController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.phone,
                          decoration: _modernInputDecoration(
                            'No. Telp / WA',
                            Icons.phone,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: supplierDetailController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Alamat Supplier',
                            Icons.map,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
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
                          judul:
                              judulController.text.trim().isNotEmpty
                                  ? judulController.text.trim()
                                  : null,
                          deskripsi:
                              deskripsiController.text.trim().isNotEmpty
                                  ? deskripsiController.text.trim()
                                  : null,
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

  void _showDeleteConfirmation(CategoryModel cat) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '⚠️ Hapus Barang?',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Menghapus "${cat.namaBarang}" akan menghilangkan data ini secara permanen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
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
        if (selectedIds.isEmpty) isSelectionMode = false;
      } else {
        selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      selectedIds = visibleCategoryIds.toSet();
      if (selectedIds.isNotEmpty) isSelectionMode = true;
    });
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              '⚠️ Hapus Massal?',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Yakin ingin menghapus ${selectedIds.length} barang secara permanen?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Hapus Semua',
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
      } catch (e) {
        /* ignore */
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
    final judulController = TextEditingController();
    final deskripsiController = TextEditingController();
    final supplierNameController = TextEditingController();
    final supplierNumberController = TextEditingController();
    final supplierDetailController = TextEditingController();
    final suratJalanController = TextEditingController();

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
                    'Registrasi Barang Baru',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Informasi Utama Barang
                        const Text(
                          "Informasi Utama",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: namaBarangController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Nama Barang',
                            Icons.category,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: judulController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Judul (Opsional)',
                            Icons.title,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: deskripsiController,
                          style: const TextStyle(color: Colors.black),
                          maxLines: 2,
                          decoration: _modernInputDecoration(
                            'Deskripsi Barang',
                            Icons.description,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: satuanController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Satuan (pcs, box, kg)',
                            Icons.straighten,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: service.getLocations(),
                          builder: (context, snap) {
                            if (!snap.hasData)
                              return const CircularProgressIndicator();
                            final locs = snap.data!;
                            return DropdownButtonFormField<String>(
                              decoration: _modernInputDecoration(
                                'Pilih Tempat/Lokasi',
                                Icons.store,
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

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Section 2: Informasi Stok dan Harga
                        const Text(
                          "Stok & Harga Modal",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: kuantitasController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsFormatter()],
                          decoration: _modernInputDecoration(
                            'Kuantitas Awal (Stok)',
                            Icons.inventory,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: hargaPerUnitController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.number,
                          inputFormatters: [ThousandsFormatter()],
                          decoration: _modernInputDecoration(
                            'Harga Modal per Unit',
                            Icons.attach_money,
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Section 3: Data Asal Barang (Supplier)
                        const Text(
                          "Data Asal Barang (Opsional)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: supplierNumberController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.phone,
                          decoration: _modernInputDecoration(
                            'No. Telp / WA',
                            Icons.phone,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: supplierDetailController,
                          style: const TextStyle(color: Colors.black),
                          decoration: _modernInputDecoration(
                            'Alamat Supplier',
                            Icons.map,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        backgroundColor: Colors.teal.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () async {
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
                          judul:
                              judulController.text.trim().isNotEmpty
                                  ? judulController.text.trim()
                                  : null,
                          deskripsi:
                              deskripsiController.text.trim().isNotEmpty
                                  ? deskripsiController.text.trim()
                                  : null,
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
                      },
                      child: const Text(
                        'Simpan Data',
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
}
