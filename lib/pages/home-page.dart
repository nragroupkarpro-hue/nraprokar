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
      appBar: AppBar(title: Text("Manajemen Jatah Makan")),
      body: StreamBuilder<List<TransactionModel>>(
        stream: _service.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());

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
              Card(
                margin: EdgeInsets.all(12),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "Saldo: ${currency.format(saldo)}",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text("Total Pemasukan: ${currency.format(totalIncome)}"),
                      Text(
                        "Total Pengeluaran: ${currency.format(totalExpense)}",
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    var t = transactions[index];
                    return ListTile(
                      title: Text(t.title),
                      subtitle: Text(DateFormat.yMMMd().format(t.date)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currency.format(t.amount)),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _service.deleteTransaction(t.id!);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTransactionPage()),
          );
        },
      ),
    );
  }
}
