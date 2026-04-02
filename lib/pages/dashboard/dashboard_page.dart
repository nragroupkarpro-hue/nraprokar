import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/firestore_service.dart';
// Import halaman yang dituju
import '../transaction/transaction_data_page.dart';
import '../transaction/report_page.dart';
import '../category/category_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart'; // Pastikan path ini sesuai dengan letak login_page.dart Anda

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        elevation: 0,
        actions: [
          // --- TOMBOL LOGOUT BARU DENGAN POP-UP KONFIRMASI ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar (Logout)',
            onPressed: () async {
              // 1. Tampilkan Pop-Up Konfirmasi
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Keluar Aplikasi?', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Ya, Keluar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              // 2. Eksekusi Logout jika dikonfirmasi (Pilih "Ya, Keluar")
              if (confirm == true) {
                try {
                  // Proses Sign Out dari Firebase
                  await FirebaseAuth.instance.signOut();
                  
                  // Pindah ke Halaman Login & Hapus semua riwayat halaman sebelumnya
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginPage()),
                      (Route<dynamic> route) => false, // false berarti semua riwayat dihapus
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Gagal keluar: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & KARTU SALDO UTAMA ---
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Halo, Admin", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 20),
                FutureBuilder<int>(
                  future: service.getSaldo(), // Mengambil total saldo dari service
                  builder: (context, snapshot) {
                    final saldo = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Total Saldo Usaha", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(
                                currency.format(saldo),
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: saldo >= 0 ? Colors.teal.shade800 : Colors.red),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.teal.shade50, shape: BoxShape.circle),
                            child: const Icon(Icons.account_balance_wallet, color: Colors.teal, size: 32),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- MENU GRID ---
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Menu Utama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMenuCard(context, "Data Transaksi", "Input & Kelola", Icons.swap_horiz_rounded, Colors.blue, const TransactionDataPage()),
                _buildMenuCard(context, "Kategori & Stok", "Data Barang", Icons.inventory_2_rounded, Colors.orange, const CategoryPage()),
                _buildMenuCard(context, "Laporan Rekap", "Excel & Detail", Icons.analytics_rounded, Colors.purple, const ReportPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget Bantuan untuk Desain Kartu Menu
  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget page) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => page)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}