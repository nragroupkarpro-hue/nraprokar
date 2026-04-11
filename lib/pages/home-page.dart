import 'package:flutter/material.dart';
import 'package:nra_pro_kar/pages/transaction/add-transaction-page.dart';
import '../models/transaction_model.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';

class HomePage extends StatelessWidget {
  final FirestoreService _service = FirestoreService();
  final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen Jatah Makan"), elevation: 0),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _service.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var transactions = snapshot.data!;

          double totalIncome = transactions
              .where((t) => t.type == "pemasukan")
              .fold(0.0, (sum, item) => sum + item.amount);

          double totalExpense = transactions
              .where((t) => t.type == "pengeluaran")
              .fold(0.0, (sum, item) => sum + item.amount);

          double saldo = totalIncome - totalExpense;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      "Saldo: ${currency.format(saldo)}",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: saldo >= 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSummaryItem(
                          context,
                          "Pemasukan",
                          currency.format(totalIncome),
                          Icons.arrow_upward,
                          Colors.green,
                        ),
                        _buildSummaryItem(
                          context,
                          "Pengeluaran",
                          currency.format(totalExpense),
                          Icons.arrow_downward,
                          Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    var t = transactions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          t.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          DateFormat.yMMMd().format(t.date),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currency.format(t.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    t.type == "pemasukan"
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                _service.deleteTransaction(t.id!);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTransactionPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text("Tambah Transaksi"),
        elevation: 4,
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
