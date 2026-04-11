import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TransactionModel {
  String? id;
  String title;
  String itemName;
  String unit;
  String location;
  String itemCode;
  double quantity;
  double pricePerUnit;
  double totalPrice;
  String type;
  double amount;
  String categoryId;
  Timestamp createdAt;
  DateTime date;
  String? description;

  // --- FIELD BARU ---
  String? supplierName;
  String? supplierDetail;
  String? supplierNumber;
  String? suratJalan;

  TransactionModel({
    this.id,
    this.title = '',
    required this.itemName,
    required this.unit,
    required this.location,
    required this.itemCode,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.createdAt,
    required this.date,
    this.description,
    this.supplierName,
    this.supplierDetail,
    this.supplierNumber,
    this.suratJalan,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      title: map['title'] ?? '',
      itemName: map['itemName'] ?? '',
      unit: map['unit'] ?? '',
      location: map['location'] ?? '',
      itemCode: map['itemCode'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      pricePerUnit: (map['pricePerUnit'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      type: map['type'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      categoryId: map['categoryId'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
      date: (map['date'] as Timestamp).toDate(),
      description: map['description'],
      // Tarik field baru dari database
      supplierName: map['supplierName'],
      supplierDetail: map['supplierDetail'],
      supplierNumber: map['supplierNumber'],
      suratJalan: map['suratJalan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.isEmpty ? '-' : title,
      'itemName': itemName,
      'unit': unit,
      'location': location,
      'itemCode': itemCode,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalPrice': totalPrice,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'createdAt': createdAt,
      'date': date,
      // --- PERBAIKAN DATA NULL: Mengubah null / kosong menjadi strip "-" ---
      'description': (description?.isEmpty ?? true) ? '-' : description,
      'supplierName': (supplierName?.isEmpty ?? true) ? '-' : supplierName,
      'supplierDetail':
          (supplierDetail?.isEmpty ?? true) ? '-' : supplierDetail,
      'supplierNumber':
          (supplierNumber?.isEmpty ?? true) ? '-' : supplierNumber,
      'suratJalan': (suratJalan?.isEmpty ?? true) ? '-' : suratJalan,
    };
  }

  static final NumberFormat _fmt = NumberFormat.decimalPattern('id_ID');
  String get pricePerUnitFormatted => _fmt.format(pricePerUnit);
  String get totalPriceFormatted => _fmt.format(totalPrice);
  String get amountFormatted => _fmt.format(amount);
}
