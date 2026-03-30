import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// ===============================
  /// CATEGORY SECTION
  /// ===============================

  final CollectionReference categoriesRef = FirebaseFirestore.instance
      .collection('categories');

  Future<void> addCategory(CategoryModel category) async {
    await categoriesRef.add(category.toFirestore());
  }

  Future<void> updateCategory(String id, CategoryModel category) async {
    await categoriesRef.doc(id).update(category.toFirestore());
  }

  Future<void> deleteCategory(String id) async {
    await categoriesRef.doc(id).delete();
  }

  Stream<List<CategoryModel>> getCategories() {
    // return all categories ordered by date (newest first)
    return categoriesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => CategoryModel.fromFirestore(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  /// Stream categories filtered by a specific month/year. This allows the
  /// UI to display only the data for the selected period while still keeping
  /// historical records intact.
  Stream<List<CategoryModel>> getCategoriesByMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end =
        (month < 12) ? DateTime(year, month + 1, 1) : DateTime(year + 1, 1, 1);

    return categoriesRef
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map(
                    (doc) => CategoryModel.fromFirestore(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    ),
                  )
                  .toList(),
        );
  }

  /// ===============================
  /// CATEGORY BY ID
  /// ===============================

  Stream<CategoryModel> getCategoryById(String id) {
    return categoriesRef
        .doc(id)
        .snapshots()
        .map(
          (doc) => CategoryModel.fromFirestore(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ),
        );
  }

  /// Find a category document by its `kodeBarang` field.
  ///
  /// Returns **null** if no matching document is found.
  Future<CategoryModel?> getCategoryByCode(String code) async {
    final snap =
        await categoriesRef.where('kodeBarang', isEqualTo: code).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return CategoryModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// ===============================
  /// TRANSACTION SECTION
  /// ===============================

  final CollectionReference transactionsRef = FirebaseFirestore.instance
      .collection('transactions');

  Future<void> addTransaction(TransactionModel trx) async {
    await _db.runTransaction((transaction) async {
      final categoryRef = _db.collection('categories').doc(trx.categoryId);

      final snapshot = await transaction.get(categoryRef);
      int kuantitas = snapshot['kuantitas'] ?? 0;
      double currentPrice = (snapshot['hargaPerUnit'] ?? 0).toDouble();

      if (trx.type == "pengeluaran") {
        kuantitas -= trx.quantity.toInt();
      } else {
        kuantitas += trx.quantity.toInt();
      }

      // Tracking harga: jika harga transaksi berbeda dari harga kategori, update
      final Map<String, dynamic> updateData = {'kuantitas': kuantitas};
      if ((currentPrice - trx.pricePerUnit).abs() > 0.01) {
        // Harga berbeda - track perubahan
        updateData['lastPrice'] = currentPrice;
        updateData['hargaPerUnit'] = trx.pricePerUnit;
        updateData['lastPriceUpdate'] = FieldValue.serverTimestamp();
      }

      transaction.update(categoryRef, updateData);
      transaction.set(transactionsRef.doc(), trx.toMap());
    });
  }

  Future<void> addTransactionWithStock(TransactionModel trx) async {
    await _db.runTransaction((transaction) async {
      final categoryRef = _db.collection('categories').doc(trx.categoryId);

      final categorySnap = await transaction.get(categoryRef);

      if (!categorySnap.exists) {
        throw Exception("Kategori tidak ditemukan");
      }

      int currentStock = categorySnap['kuantitas'] ?? 0;

      if (trx.type == "pengeluaran") {
        if (currentStock < trx.quantity) {
          throw Exception("Stok tidak mencukupi");
        }
        currentStock -= trx.quantity.toInt();
      } else {
        currentStock += trx.quantity.toInt();
      }

      transaction.update(categoryRef, {'kuantitas': currentStock});
      transaction.set(transactionsRef.doc(), trx.toMap());
    });
  }

  Future<void> deleteTransaction(String id) async {
    await transactionsRef.doc(id).delete();
  }

  Future<void> deleteTransactionWithStock(
    String id,
    String categoryId,
    int quantity,
    String type,
  ) async {
    await _db.runTransaction((transaction) async {
      final categoryRef = _db.collection('categories').doc(categoryId);
      final transactionRef = transactionsRef.doc(id);

      final categorySnap = await transaction.get(categoryRef);

      if (!categorySnap.exists) {
        throw Exception("Kategori tidak ditemukan");
      }

      int currentStock = categorySnap['kuantitas'] ?? 0;

      // Reverse the transaction effect
      if (type == "pengeluaran") {
        // Add back the quantity that was subtracted
        currentStock += quantity;
      } else {
        // Subtract the quantity that was added
        currentStock -= quantity;
      }

      transaction.update(categoryRef, {'kuantitas': currentStock});
      transaction.delete(transactionRef);
    });
  }

  Future<void> updateTransaction(String id, TransactionModel trx) async {
    await transactionsRef.doc(id).update({
      'itemName': trx.itemName,
      'unit': trx.unit,
      'location': trx.location,
      'itemCode': trx.itemCode,
      'quantity': trx.quantity,
      'pricePerUnit': trx.pricePerUnit,
      'totalPrice': trx.totalPrice,
      'type': trx.type,
      'amount': trx.totalPrice,
      'date': trx.date,
      'description': trx.description,
    });
  }

  Future<void> updateCategoryStock(String categoryId, int newStock) async {
    await categoriesRef.doc(categoryId).update({'stock': newStock});
  }

  /// Checks if a given kodeBarang value already exists in the
  /// categories collection. Returns true when the code is not used yet.
  Future<bool> isKodeBarangUnique(String code) async {
    final snapshot =
        await categoriesRef.where('kodeBarang', isEqualTo: code).limit(1).get();
    return snapshot.docs.isEmpty;
  }

  /// Generates a brand‑new kodeBarang string by invoking the static
  /// helper on CategoryModel repeatedly until a unique value is
  /// produced. This ensures the generated code never collides with an
  /// existing document in Firestore.
  Future<String> generateUniqueKodeBarang() async {
    String kode;
    do {
      kode = CategoryModel.generateAutoCode();
    } while (!await isKodeBarangUnique(kode));
    return kode;
  }

  Stream<List<TransactionModel>> getTransactions() {
    return transactionsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return TransactionModel(
                  id: doc.id,
                  itemName: data['itemName'] ?? data['title'] ?? '',
                  unit: data['unit'] ?? '',
                  location: data['location'] ?? '',
                  itemCode: data['itemCode'] ?? '',
                  quantity: (data['quantity'] as num).toDouble(),
                  pricePerUnit: data['pricePerUnit'] ?? 0,
                  totalPrice: data['totalPrice'] ?? data['amount'] ?? 0,
                  type: data['type'],
                  categoryId: data['categoryId'],
                  amount: data['amount'] ?? 0,
                  createdAt:
                      data['createdAt'] is Timestamp
                          ? (data['createdAt'] as Timestamp)
                          : Timestamp.fromDate(
                            DateTime.parse(data['createdAt'].toString()),
                          ),
                  date:
                      data['createdAt'] is Timestamp
                          ? (data['createdAt'] as Timestamp).toDate()
                          : DateTime.parse(data['createdAt'].toString()),
                  description: data['description'],
                );
              }).toList(),
        );
  }

  /// ===============================
  /// DASHBOARD CALCULATION
  /// ===============================

  Future<int> getTotalIncome() async {
    final snapshot =
        await transactionsRef.where('type', isEqualTo: 'pemasukan').get();

    return snapshot.docs.fold<int>(
      0,
      (sum, doc) => sum + (doc['amount'] as int),
    );
  }

  Future<int> getTotalExpense() async {
    final snapshot =
        await transactionsRef.where('type', isEqualTo: 'pengeluaran').get();

    return snapshot.docs.fold<int>(
      0,
      (sum, doc) => sum + (doc['amount'] as int),
    );
  }

  Future<int> getSaldo() async {
    final income = await getTotalIncome();
    final expense = await getTotalExpense();
    return income - expense;
  }

  /// ===============================
  /// MONTHLY FILTER (UNTUK PDF & GRAFIK)
  /// ===============================

  Future<Map<String, int>> getMonthlySummary(int year, int month) async {
    DateTime start = DateTime(year, month, 1);
    DateTime end = DateTime(year, month + 1, 1);

    final snapshot =
        await transactionsRef
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .get();

    int income = 0;
    int expense = 0;

    for (var doc in snapshot.docs) {
      if (doc['type'] == 'pemasukan') {
        income += doc['amount'] as int;
      } else {
        expense += doc['amount'] as int;
      }
    }

    return {'income': income, 'expense': expense, 'saldo': income - expense};
  }

  /// ===============================
  /// GRAFIK DATA (12 BULAN)
  /// ===============================

  Future<List<double>> getYearlyExpenseChart(int year) async {
    List<double> monthlyExpense = List.generate(12, (_) => 0);

    final snapshot = await transactionsRef.get();

    for (var doc in snapshot.docs) {
      DateTime date = (doc['createdAt'] as Timestamp).toDate();

      if (date.year == year && doc['type'] == 'pengeluaran') {
        monthlyExpense[date.month - 1] += (doc['amount'] as int).toDouble();
      }
    }

    return monthlyExpense;
  }

  /// get all transactions for a specific month/year, optionally filtered by type
  Future<List<TransactionModel>> getMonthlyTransactions(
    int year,
    int month, [
    String? type,
  ]) async {
    DateTime start = DateTime(year, month, 1);
    DateTime end = DateTime(year, month + 1, 1);

    final snapshot =
        await transactionsRef
            .where('createdAt', isGreaterThanOrEqualTo: start)
            .where('createdAt', isLessThan: end)
            .get();

    final List<TransactionModel> list = [];
    for (var doc in snapshot.docs) {
      final trx = TransactionModel.fromMap(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );
      if (type == null || trx.type == type) {
        list.add(trx);
      }
    }
    return list;
  }
}
