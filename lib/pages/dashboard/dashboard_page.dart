import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../transaction/transaction_data_page.dart';
import '../transaction/report_page.dart';
import '../category/category_page.dart';
import '../category/location_page.dart';
import '../auth/login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final FirestoreService service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('🚪 Keluar Aplikasi?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin mengakhiri sesi ini?'),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Batal', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Soft slate background modern
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPremiumHeader(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text("Menu Utama", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade800)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildGridMenu(),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER SEAMLESS & KARTU SALDO MELAYANG ---
  Widget _buildPremiumHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade800, Colors.teal.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.teal.shade100,
                      child: Icon(Icons.person_rounded, color: Colors.teal.shade800, size: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Selamat Datang,", style: TextStyle(color: Colors.teal.shade100, fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      const Text("Admin NRA", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Keluar',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // KARTU SALDO
          FutureBuilder<int>(
            future: service.getSaldo(),
            builder: (context, snapshot) {
              final saldo = snapshot.data ?? 0;
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.teal.shade100, Colors.teal.shade50]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: Colors.teal.shade700, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Total Saldo Usaha", style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currency.format(saldo),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: saldo >= 0 ? const Color(0xFF1E293B) : Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- GRID MENU MODERN ---
  Widget _buildGridMenu() {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.85, // Proporsi agar kartu terlihat lebih pas
      physics: const BouncingScrollPhysics(),
      children: [
        _buildMenuCard("Data Transaksi", "In / Out Stok", Icons.sync_alt_rounded, Colors.blue, const TransactionDataPage()),
        _buildMenuCard("Data Barang", "Master Stok", Icons.inventory_2_rounded, Colors.orange, const CategoryPage()),
        _buildMenuCard("Kategori Tempat", "Kelola Lokasi", Icons.storefront_rounded, Colors.purple, const LocationPage()),
        _buildMenuCard("Laporan Rekap", "Jurnal Harian", Icons.analytics_rounded, Colors.green, const ReportPage()),
      ],
    );
  }

  // --- KOMPONEN KARTU MENU ---
  Widget _buildMenuCard(String title, String subtitle, IconData icon, MaterialColor color, Widget page) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          borderRadius: BorderRadius.circular(24),
          splashColor: color.shade50,
          highlightColor: color.shade100.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color.shade600),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}