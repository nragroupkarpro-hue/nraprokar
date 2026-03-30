import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/firestore_service.dart';
import '../../models/category_model.dart';

class CategoryPage extends StatefulWidget {
  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirestoreService service = FirestoreService();

  final namaBarangController = TextEditingController();
  final kodeBarangController = TextEditingController();
  final satuanController = TextEditingController();
  final lokasiController = TextEditingController();
  final kuantitasController = TextEditingController();
  final hargaPerUnitController = TextEditingController();

  // --- filter controllers ---
  final namaBarangFilterController = TextEditingController();
  final kodeBarangFilterController = TextEditingController();

  /// filtering options
  int _filterMode = 0; // 0=all, 1=month
  DateTime? _selectedFilter; // date picked for filtering

  @override
  void dispose() {
    namaBarangController.dispose();
    kodeBarangController.dispose();
    satuanController.dispose();
    lokasiController.dispose();
    kuantitasController.dispose();
    hargaPerUnitController.dispose();
    namaBarangFilterController.dispose();
    kodeBarangFilterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Barang"),
        backgroundColor: Colors.teal,
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
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Halaman ini berisi data barang: nama barang, kode, satuan, lokasi, kuantitas, harga per unit, dan jumlah harga.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          // active filter indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (namaBarangFilterController.text.isNotEmpty)
                  InputChip(
                    label: Text(
                      'Nama: ${namaBarangFilterController.text.trim()}',
                    ),
                    onDeleted: () {
                      setState(() {
                        namaBarangFilterController.clear();
                      });
                    },
                  ),
                if (kodeBarangFilterController.text.isNotEmpty)
                  InputChip(
                    label: Text(
                      'Kode: ${kodeBarangFilterController.text.trim()}',
                    ),
                    onDeleted: () {
                      setState(() {
                        kodeBarangFilterController.clear();
                      });
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CategoryModel>>(
              stream: service.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<CategoryModel> data = snapshot.data!;

                // apply filters from text fields
                if (namaBarangFilterController.text.isNotEmpty ||
                    kodeBarangFilterController.text.isNotEmpty) {
                  data =
                      data.where((cat) {
                        bool keep = true;
                        final namaFilter =
                            namaBarangFilterController.text.toLowerCase();
                        if (namaFilter.isNotEmpty) {
                          keep &=
                              cat.namaBarang?.toLowerCase().contains(
                                namaFilter,
                              ) ??
                              false;
                        }
                        final kodeFilter =
                            kodeBarangFilterController.text.toLowerCase();
                        if (kodeFilter.isNotEmpty) {
                          keep &=
                              cat.kodeBarang?.toLowerCase().contains(
                                kodeFilter,
                              ) ??
                              false;
                        }
                        return keep;
                      }).toList();
                }

                if (data.isEmpty) {
                  return Center(
                    child: Text(
                      'Tidak ada data sesuai filter',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: data.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final cat = data[index];
                      final statusColor =
                          cat.kuantitas > 0
                              ? Colors.green
                              : cat.kuantitas == 0
                              ? Colors.orange
                              : Colors.red;

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal.shade100,
                            child: Icon(Icons.inventory_2, color: Colors.teal),
                          ),
                          title: Text(
                            cat.namaBarang,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Lokasi: ${cat.lokasi}'),
                              Text(
                                'Qty: ${cat.kuantitas} ${cat.satuan}',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
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
                                      content: Text(
                                        'Kode "${cat.kodeBarang}" disalin',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              PopupMenuButton(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showEditDialog(cat);
                                  } else if (value == 'delete') {
                                    _confirmDelete(cat);
                                  }
                                },
                                itemBuilder: (context) {
                                  return [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus'),
                                    ),
                                  ];
                                },
                                child: const Icon(Icons.more_vert),
                              ),
                            ],
                          ),
                          onTap: () => _showDetailDialog(cat),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Tambah Barang"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaBarangController,
                    decoration: const InputDecoration(
                      labelText: "Nama Barang",
                      hintText: "Misal: Beras, Telur, Gula",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: satuanController,
                    decoration: const InputDecoration(
                      labelText: "Satuan",
                      hintText: "Misal: pcs, kg, liter, meter",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lokasiController,
                    decoration: const InputDecoration(
                      labelText: "Lokasi Penyimpanan",
                      hintText: "Misal: Gudang A, Rak 1B, Lemari 3",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kodeBarangController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: "Kode Barang",
                      hintText: "Tekan ikon untuk generate kode",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.autorenew),
                        tooltip: 'Auto-generate kode',
                        onPressed: () async {
                          final kode = await service.generateUniqueKodeBarang();
                          setState(() {
                            kodeBarangController.text = kode;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kuantitasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Kuantitas",
                      hintText: "Jumlah unit barang",
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hargaPerUnitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Harga per Unit (Rp)",
                      hintText: "Contoh: 150000",
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
                  final nama = namaBarangController.text.trim();
                  String kode = kodeBarangController.text.trim();
                  final satuan = satuanController.text.trim();
                  final lokasi = lokasiController.text.trim();
                  final kuantitasText = kuantitasController.text.trim();
                  final hargaText = hargaPerUnitController.text.trim();

                  // if user forgot to generate a code, create one now
                  if (kode.isEmpty) {
                    kode = await service.generateUniqueKodeBarang();
                    kodeBarangController.text = kode;
                  }

                  if (nama.isEmpty ||
                      kode.isEmpty ||
                      satuan.isEmpty ||
                      lokasi.isEmpty ||
                      kuantitasText.isEmpty ||
                      hargaText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Semua field harus diisi'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  int? kuantitas = int.tryParse(kuantitasText);
                  double? harga = double.tryParse(hargaText);

                  if (kuantitas == null || harga == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Kuantitas dan harga harus angka'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (kuantitas < 0 || harga < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Nilai tidak boleh negatif'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final jumlahHarga = kuantitas * harga;

                  await service.addCategory(
                    CategoryModel(
                      namaBarang: nama,
                      satuan: satuan,
                      lokasi: lokasi,
                      kodeBarang: kode,
                      kuantitas: kuantitas,
                      hargaPerUnit: harga,
                      jumlahHarga: jumlahHarga,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Barang ditambahkan'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  namaBarangController.clear();
                  kodeBarangController.clear();
                  satuanController.clear();
                  lokasiController.clear();
                  kuantitasController.clear();
                  hargaPerUnitController.clear();
                },
                child: const Text("Simpan"),
              ),
            ],
          ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            void updateFilterState(VoidCallback updates) {
              setStateSheet(updates);
              setState(updates);
            }

            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  left: 16,
                  right: 16,
                  top: 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Data Barang',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: namaBarangFilterController,
                      decoration: InputDecoration(
                        labelText: 'Cari Nama Barang',
                        hintText: 'Contoh: Laptop, Mouse',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              updateFilterState(() {
                                namaBarangFilterController.clear();
                                kodeBarangFilterController.clear();
                              });
                            },
                            child: const Text('Reset Semua'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text(
                              'Terapkan',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetailDialog(CategoryModel cat) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(cat.namaBarang),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow('Nama Barang', cat.namaBarang),
                          const Divider(),
                          const Divider(),
                          _buildDetailRow('Satuan', cat.satuan),
                          const Divider(),
                          _buildDetailRow('Lokasi', cat.lokasi),
                          const Divider(),
                          _buildDetailRow(
                            'Kuantitas',
                            '${cat.kuantitas} ${cat.satuan}',
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
                            'Rp ${cat.hargaPerUnit.toStringAsFixed(0)}',
                          ),
                          const Divider(),
                          _buildDetailRow(
                            'Jumlah Harga',
                            'Rp ${cat.jumlahHarga.toStringAsFixed(0)}',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Keterangan: Data ini merepresentasikan inventaris barang. Gunakan tombol Edit untuk memperbarui atau Hapus untuk menghapus barang.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showEditDialog(cat);
                },
                child: const Text('Edit'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(cat);
                },
                child: const Text('Hapus'),
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

  void _showEditDialog(CategoryModel cat) {
    // populate all controllers including kode
    namaBarangController.text = cat.namaBarang;
    satuanController.text = cat.satuan;
    lokasiController.text = cat.lokasi;
    kodeBarangController.text = cat.kodeBarang;
    kuantitasController.text = cat.kuantitas.toString();
    hargaPerUnitController.text = cat.hargaPerUnit.toString();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Barang'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: namaBarangController,
                    decoration: const InputDecoration(labelText: 'Nama Barang'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kodeBarangController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Kode Barang',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.autorenew),
                        tooltip: 'Auto-generate kode',
                        onPressed: () async {
                          final kode = await service.generateUniqueKodeBarang();
                          setState(() {
                            kodeBarangController.text = kode;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: satuanController,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lokasiController,
                    decoration: const InputDecoration(labelText: 'Lokasi'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kuantitasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuantitas'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: hargaPerUnitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga/Unit (Rp)',
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
                  final nama = namaBarangController.text.trim();
                  String kode = kodeBarangController.text.trim();
                  final satuan = satuanController.text.trim();
                  final lokasi = lokasiController.text.trim();
                  final kuantitasText = kuantitasController.text.trim();
                  final hargaText = hargaPerUnitController.text.trim();

                  // auto‑generate new code if somehow left blank
                  if (kode.isEmpty) {
                    kode = await service.generateUniqueKodeBarang();
                    kodeBarangController.text = kode;
                  }

                  if (nama.isEmpty ||
                      kode.isEmpty ||
                      satuan.isEmpty ||
                      lokasi.isEmpty ||
                      kuantitasText.isEmpty ||
                      hargaText.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Semua field harus diisi'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  int? kuantitas = int.tryParse(kuantitasText);
                  double? harga = double.tryParse(hargaText);

                  if (kuantitas == null || harga == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Kuantitas dan harga harus angka'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  if (kuantitas < 0 || harga < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚠️ Nilai tidak boleh negatif'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final jumlahHarga = kuantitas * harga;

                  await service.updateCategory(
                    cat.id!,
                    CategoryModel(
                      id: cat.id,
                      namaBarang: nama,
                      satuan: satuan,
                      lokasi: lokasi,
                      kodeBarang: kode,
                      kuantitas: kuantitas,
                      hargaPerUnit: harga,
                      jumlahHarga: jumlahHarga,
                    ),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Barang berhasil diupdate'),
                      backgroundColor: Colors.green,
                    ),
                  );

                  namaBarangController.clear();
                  kodeBarangController.clear();
                  satuanController.clear();
                  lokasiController.clear();
                  kuantitasController.clear();
                  hargaPerUnitController.clear();
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
  }

  void _confirmDelete(CategoryModel cat) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Konfirmasi Hapus'),
            content: Text(
              'Hapus barang "${cat.namaBarang}"? Aksi ini tidak dapat dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  if (cat.id != null) {
                    await service.deleteCategory(cat.id!);
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Barang berhasil dihapus'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
  }
}
