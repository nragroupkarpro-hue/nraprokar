import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class TransactionService {
  final _db = FirebaseFirestore.instance;

  Future<void> addTransaction(TransactionModel trx) async {
    await _db.runTransaction((transaction) async {
      final categoryRef =
          _db.collection('categories').doc(trx.categoryId);

      final snapshot = await transaction.get(categoryRef);
      int stock = snapshot['stock'];

      if (trx.type == "pengeluaran") {
        stock -= trx.quantity.toInt();
      } else {
        stock += trx.quantity.toInt();
      }

      transaction.update(categoryRef, {'stock': stock});
      transaction.set(_db.collection('transactions').doc(), trx.toMap());
    });
  }

  Stream<QuerySnapshot> getTransactions() {
    return _db.collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}