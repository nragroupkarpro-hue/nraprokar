import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final _db = FirebaseFirestore.instance.collection('categories');

  Future<void> addCategory(CategoryModel category) async {
    await _db.add(category.toMap());
  }

  Stream<QuerySnapshot> getCategories() {
    return _db.snapshots();
  }
}