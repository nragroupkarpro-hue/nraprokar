import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/category_model.dart';
import 'package:intl/intl.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({Key? key}) : super(key: key);

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _searchController = TextEditingController();
  String _searchQuery = "";

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
          // --- SEARCH BAR LENGKUNG ---
          Container(
            color: Colors.teal,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: "Cari nama atau kode barang...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      }) 
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // --- LIST DATA ---
          Expanded(
            child: StreamBuilder<List<CategoryModel>>(
              stream: service.getCategories(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                List<CategoryModel> categories = snapshot.data!;
                
                // Terapkan filter pencarian
                if (_searchQuery.isNotEmpty) {
                  categories = categories.where((cat) => 
                      cat.namaBarang.toLowerCase().contains(_searchQuery) || 
                      cat.kodeBarang.toLowerCase().contains(_searchQuery)).toList();
                }

                if (categories.isEmpty) {
                  return const Center(child: Text("Barang tidak ditemukan."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                  Text("Kode: ${cat.kodeBarang}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                        child: Text("Stok: ${cat.kuantitas} ${cat.satuan}", style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(currency.format(cat.hargaPerUnit), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                                    ],
                                  )
                                ],
                              ),
                            ),
                            // Tombol Aksi (Tiga Titik)
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.grey),
                              onPressed: () {
                                // Panggil dialog edit/hapus Anda di sini
                              },
                            )
                          ],
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
      // Jika ada fitur tambah kategori
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigator.push ke form tambah barang baru
        },
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Barang Baru", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}