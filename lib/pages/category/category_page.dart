import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nra_pro_kar/models/category_model.dart';
import 'package:nra_pro_kar/services/firestore_service.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  // gunakan locale en_US agar pemisah ribuan berupa koma
  final NumberFormat _fmt = NumberFormat.decimalPattern('en_US');
  // atau: NumberFormat('#,###', 'en_US');

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

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  final FirestoreService service = FirestoreService();
  final searchController = TextEditingController();
  String searchQuery = '';
  int _currentPage = 0;
  static const int _itemsPerPage = 7;

  // Tab management
  late TabController _tabController;
  int _selectedTab = 0; // 0 = Barang Aktif, 1 = History

  // History month/year selector
  late DateTime _selectedHistoryDate;

  final namaBarangController = TextEditingController();
  final satuanController = TextEditingController();
  final lokasiController = TextEditingController();
  final kuantitasController = TextEditingController();
  final hargaPerUnitController = TextEditingController();
  final varianInfoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedHistoryDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Barang"), elevation: 0),
      body: Column(
        children: [
          // Tab selector
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() {
                  _selectedTab = index;
                  _currentPage = 0;
                  searchController.clear();
                  searchQuery = '';
                });
              },
              tabs: const [
                Tab(child: Text('Barang Aktif')),
                Tab(child: Text('History Barang')),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari barang...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              searchQuery = '';
                              _currentPage = 0;
                            });
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                  _currentPage = 0;
                });
              },
            ),
          ),
          // Month selector for history
          if (_selectedTab == 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      setState(() {
                        _selectedHistoryDate = DateTime(
                          _selectedHistoryDate.year,
                          _selectedHistoryDate.month - 1,
                        );
                        _currentPage = 0;
                      });
                    },
                  ),
                  GestureDetector(
                    onTap: () => _selectMonth(context),
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          DateFormat(
                            'MMMM yyyy',
                            'id_ID',
                          ).format(_selectedHistoryDate),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      setState(() {
                        _selectedHistoryDate = DateTime(
                          _selectedHistoryDate.year,
                          _selectedHistoryDate.month + 1,
                        );
                        _currentPage = 0;
                      });
                    },
                  ),
                ],
              ),
            ),
          // Content
          Expanded(
            child:
                _selectedTab == 0
                    ? _buildActiveCategoriesView()
                    : _buildHistoryCategoriesView(),
          ),
        ],
      ),
      floatingActionButton:
          _selectedTab == 0
              ? FloatingActionButton(
                onPressed: showAddCategoryDialog,
                tooltip: 'Tambah Barang',
                child: const Icon(Icons.add),
              )
              : null,
    );
  }

  /// View untuk barang aktif (bulan sekarang)
  Widget _buildActiveCategoriesView() {
    final now = DateTime.now();
    return StreamBuilder<List<CategoryModel>>(
      stream: service.getCategoriesByMonth(now.year, now.month),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var categories = snapshot.data!;

        // Filter berdasarkan search query
        if (searchQuery.isNotEmpty) {
          categories =
              categories
                  .where(
                    (cat) =>
                        cat.namaBarang.toLowerCase().contains(searchQuery) ||
                        cat.satuan.toLowerCase().contains(searchQuery) ||
                        cat.lokasi.toLowerCase().contains(searchQuery),
                  )
                  .toList();
        }

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty
                      ? 'Barang tidak ditemukan'
                      : 'Belum ada barang bulan ini',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return _buildCategoryList(categories);
      },
    );
  }

  /// View untuk history barang (bulan yang dipilih)
  Widget _buildHistoryCategoriesView() {
    return StreamBuilder<List<CategoryModel>>(
      stream: service.getCategoriesByMonth(
        _selectedHistoryDate.year,
        _selectedHistoryDate.month,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var categories = snapshot.data!;

        // Filter berdasarkan search query
        if (searchQuery.isNotEmpty) {
          categories =
              categories
                  .where(
                    (cat) =>
                        cat.namaBarang.toLowerCase().contains(searchQuery) ||
                        cat.satuan.toLowerCase().contains(searchQuery) ||
                        cat.lokasi.toLowerCase().contains(searchQuery),
                  )
                  .toList();
        }

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  searchQuery.isNotEmpty
                      ? 'Barang tidak ditemukan'
                      : 'Tidak ada barang di bulan ini',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return _buildCategoryList(categories);
      },
    );
  }

  /// Widget untuk menampilkan list kategori dengan pagination
  Widget _buildCategoryList(List<CategoryModel> categories) {
    final totalPages = (categories.length / _itemsPerPage).ceil();
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, categories.length);
    final paginatedCategories = categories.sublist(startIndex, endIndex);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: paginatedCategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cat = paginatedCategories[index];
              final kuantitasColor =
                  cat.kuantitas > 0
                      ? Colors.green
                      : cat.kuantitas == 0
                      ? Colors.orange
                      : Colors.red;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  onTap: () => _showCategoryDetail(cat),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      cat.namaBarang.isNotEmpty
                          ? cat.namaBarang[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(
                    cat.namaBarang,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Lokasi: ${cat.lokasi}'),
                      Text(
                        'Qty: ${cat.kuantitas}',
                        style: TextStyle(
                          color: kuantitasColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp ${cat.jumlahHargaFormatted}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        tooltip: 'Salin kode barang',
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: cat.kodeBarang),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kode "${cat.kodeBarang}" disalin'),
                            ),
                          );
                        },
                      ),
                      if (_selectedTab == 0)
                        PopupMenuButton(
                          itemBuilder:
                              (context) => [
                                PopupMenuItem(
                                  child: Row(
                                    children: const [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                  onTap:
                                      () => Future.delayed(
                                        const Duration(milliseconds: 500),
                                        () => _showEditCategoryDialog(cat),
                                      ),
                                ),
                                PopupMenuItem(
                                  child: Row(
                                    children: const [
                                      Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Hapus',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                  onTap:
                                      () => Future.delayed(
                                        const Duration(milliseconds: 500),
                                        () => _showDeleteConfirmation(cat),
                                      ),
                                ),
                              ],
                        )
                      else
                        Icon(
                          Icons.lock_outline,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Pagination Controls
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
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
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Berikutnya'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _selectMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedHistoryDate = picked;
        _currentPage = 0;
      });
    }
  }

  void _showCategoryDetail(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(cat.namaBarang),
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
                        _buildDetailRow('Nama Barang', cat.namaBarang),
                        const Divider(),
                        _buildDetailRow('Satuan', cat.satuan),
                        const Divider(),
                        _buildDetailRow('Lokasi', cat.lokasi),
                        const Divider(),
                        _buildDetailRow(
                          'Kuantitas',
                          cat.kuantitas.toString(),
                          color:
                              cat.kuantitas > 0
                                  ? Colors.green
                                  : cat.kuantitas == 0
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const Divider(),
                        _buildDetailRow(
                          'Harga/Unit',
                          'Rp ${cat.hargaPerUnitFormatted}',
                        ),
                        const Divider(),
                        if (cat.varianInfo != null)
                          _buildDetailRow('Varian/Ukuran', cat.varianInfo!),
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
                              'id_ID',
                            ).format(cat.createdAt!),
                          ),
                        if (cat.createdAt != null) const Divider(),
                        _buildDetailRow('ID', cat.id ?? "-"),
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
            if (_selectedTab == 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditCategoryDialog(cat);
                },
                child: const Text('Edit', style: TextStyle(color: Colors.blue)),
              ),
            if (_selectedTab == 0)
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
    final namaBarangController = TextEditingController(text: cat.namaBarang);
    final satuanController = TextEditingController(text: cat.satuan);
    final lokasiController = TextEditingController(text: cat.lokasi);
    final kuantitasController = TextEditingController(
      text: cat.kuantitas.toString(),
    );
    final hargaPerUnitController = TextEditingController(
      text: cat.hargaPerUnitFormatted,
    );
    final varianInfoController = TextEditingController(
      text: cat.varianInfo ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Barang'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaBarangController,
                      decoration: InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.straighten),
                        hintText: 'Misal: pcs, kg, liter, meter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lokasiController,
                      decoration: InputDecoration(
                        labelText: 'Lokasi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kuantitasController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Kuantitas',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hargaPerUnitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Harga/Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: varianInfoController,
                      decoration: InputDecoration(
                        labelText: 'Varian/Ukuran (Opsional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.info_outline),
                        hintText: 'Misal: 150g, 200g, 1kg, Small, Medium',
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
                      if (namaBarangController.text.isEmpty ||
                          satuanController.text.isEmpty ||
                          lokasiController.text.isEmpty ||
                          kuantitasController.text.isEmpty ||
                          hargaPerUnitController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Mohon isi semua field'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final kuantitas = int.parse(
                        kuantitasController.text.replaceAll(',', ''),
                      );
                      final hargaPerUnit = double.parse(
                        hargaPerUnitController.text.replaceAll(',', ''),
                      );

                      if (kuantitas < 0 || hargaPerUnit < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Nilai tidak boleh negatif'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final jumlahHarga = kuantitas * hargaPerUnit;

                      final updated = CategoryModel(
                        id: cat.id,
                        namaBarang: namaBarangController.text.trim(),
                        satuan: satuanController.text.trim(),
                        lokasi: lokasiController.text.trim(),
                        kodeBarang: cat.kodeBarang,
                        kuantitas: kuantitas,
                        hargaPerUnit: hargaPerUnit,
                        jumlahHarga: jumlahHarga,
                        varianInfo:
                            varianInfoController.text.trim().isNotEmpty
                                ? varianInfoController.text.trim()
                                : null,
                        createdAt: cat.createdAt,
                      );

                      await service.updateCategory(cat.id!, updated);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Barang berhasil diupdate'),
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

  void _showDeleteConfirmation(CategoryModel cat) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Barang?'),
          content: Text(
            'Apakah Anda yakin ingin menghapus barang "${cat.namaBarang}"?\n\nTindakan ini tidak dapat dibatalkan.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await service.deleteCategory(cat.id!);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Barang berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void showAddCategoryDialog() {
    namaBarangController.clear();
    CategoryModel.generateAutoCode(); // Auto-generate kode
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
              title: const Text('Tambah Barang'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: namaBarangController,
                      decoration: InputDecoration(
                        labelText: 'Nama Barang',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: satuanController,
                      decoration: InputDecoration(
                        labelText: 'Satuan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.straighten),
                        hintText: 'Misal: pcs, kg, liter, meter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: lokasiController,
                      decoration: InputDecoration(
                        labelText: 'Lokasi',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: kuantitasController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Kuantitas',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.inventory),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hargaPerUnitController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      decoration: InputDecoration(
                        labelText: 'Harga/Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.attach_money),
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
                      if (namaBarangController.text.isEmpty ||
                          satuanController.text.isEmpty ||
                          lokasiController.text.isEmpty ||
                          kuantitasController.text.isEmpty ||
                          hargaPerUnitController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ Mohon isi semua field'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final kuantitas = int.parse(
                        kuantitasController.text.replaceAll(',', ''),
                      );
                      final hargaPerUnit = double.parse(
                        hargaPerUnitController.text.replaceAll(',', ''),
                      );

                      final jumlahHarga = kuantitas * hargaPerUnit;

                      final category = CategoryModel(
                        namaBarang: namaBarangController.text.trim(),
                        satuan: satuanController.text.trim(),
                        lokasi: lokasiController.text.trim(),
                        kodeBarang: CategoryModel.generateAutoCode(),
                        kuantitas: kuantitas,
                        hargaPerUnit: hargaPerUnit,
                        jumlahHarga: jumlahHarga,
                        varianInfo:
                            varianInfoController.text.trim().isNotEmpty
                                ? varianInfoController.text.trim()
                                : null,
                        createdAt: DateTime.now(),
                      );

                      await service.addCategory(category);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Barang berhasil ditambahkan'),
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

  @override
  void dispose() {
    namaBarangController.dispose();
    satuanController.dispose();
    lokasiController.dispose();
    kuantitasController.dispose();
    hargaPerUnitController.dispose();
    varianInfoController.dispose();
    searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}
