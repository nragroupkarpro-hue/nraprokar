import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class CategoryModel {
  final String? id;
  final String namaBarang;
  final String? judul; // FIELD BARU
  final String? deskripsi; // FIELD BARU
  final String satuan;
  final String lokasi;
  final String kodeBarang;
  final int kuantitas;
  final double hargaPerUnit;
  final double jumlahHarga;
  final double? lastPrice;
  final DateTime? lastPriceUpdate;
  final String? varianInfo;
  final DateTime? createdAt;
  final double totalModal; // Simpan total uang yang dikeluarkan (Modal)

  String? supplierName;
  String? supplierNumber;
  String? supplierDetail;
  String? suratJalan;

  CategoryModel({
    this.id,
    required this.namaBarang,
    this.judul,
    this.deskripsi,
    required this.satuan,
    required this.lokasi,
    required this.kodeBarang,
    required this.kuantitas,
    required this.hargaPerUnit,
    required this.jumlahHarga,
    this.lastPrice,
    this.lastPriceUpdate,
    this.varianInfo,
    this.createdAt,
    this.totalModal = 0.0,
    this.supplierName,
    this.supplierNumber,
    this.supplierDetail,
    this.suratJalan,
  });

  Map<String, dynamic> toMap() {
    return {
      'namaBarang': namaBarang,
      'judul': judul,
      'deskripsi': deskripsi,
      'satuan': satuan,
      'lokasi': lokasi,
      'kodeBarang': kodeBarang,
      'kuantitas': kuantitas,
      'hargaPerUnit': hargaPerUnit,
      'jumlahHarga': jumlahHarga,
      'lastPrice': lastPrice,
      'lastPriceUpdate':
          lastPriceUpdate != null ? Timestamp.fromDate(lastPriceUpdate!) : null,
      'varianInfo': varianInfo,
      'totalModal': totalModal,
      'supplierName': supplierName,
      'supplierNumber': supplierNumber,
      'supplierDetail': supplierDetail,
      'suratJalan': suratJalan,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'namaBarang': namaBarang,
      'judul': judul,
      'deskripsi': deskripsi,
      'satuan': satuan,
      'lokasi': lokasi,
      'kodeBarang': kodeBarang,
      'kuantitas': kuantitas,
      'hargaPerUnit': hargaPerUnit,
      'jumlahHarga': jumlahHarga,
      'varianInfo': varianInfo,
      'createdAt':
          createdAt != null
              ? Timestamp.fromDate(createdAt!)
              : FieldValue.serverTimestamp(),
      'supplierName': supplierName,
      'supplierNumber': supplierNumber,
      'supplierDetail': supplierDetail,
      'suratJalan': suratJalan,
      'totalModal': totalModal,
      'lastPrice': lastPrice,
      'lastPriceUpdate':
          lastPriceUpdate != null ? Timestamp.fromDate(lastPriceUpdate!) : null,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CategoryModel(
      id: id ?? map['id'],
      namaBarang: map['namaBarang'] ?? '',
      judul: map['judul'],
      deskripsi: map['deskripsi'],
      satuan: map['satuan'] ?? '',
      lokasi: map['lokasi'] ?? '',
      kodeBarang: map['kodeBarang'] ?? '',
      kuantitas: (map['kuantitas'] ?? 0).toInt(),
      hargaPerUnit: (map['hargaPerUnit'] ?? 0).toDouble(),
      jumlahHarga: (map['jumlahHarga'] ?? 0).toDouble(),
      totalModal: (map['totalModal'] ?? 0.0).toDouble(),
      lastPrice:
          map['lastPrice'] != null
              ? (map['lastPrice'] as num).toDouble()
              : null,
      lastPriceUpdate:
          map['lastPriceUpdate'] != null
              ? (map['lastPriceUpdate'] as Timestamp).toDate()
              : null,
      varianInfo: map['varianInfo'],
      supplierName: map['supplierName'],
      supplierNumber: map['supplierNumber'],
      supplierDetail: map['supplierDetail'],
      suratJalan: map['suratJalan'],
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      namaBarang: data['namaBarang'] ?? '',
      judul: data['judul'],
      deskripsi: data['deskripsi'],
      satuan: data['satuan'] ?? '',
      lokasi: data['lokasi'] ?? 'Semua',
      kodeBarang: data['kodeBarang'] ?? '',
      kuantitas: (data['kuantitas'] ?? 0).toInt(),
      hargaPerUnit: (data['hargaPerUnit'] ?? 0).toDouble(),
      jumlahHarga: (data['jumlahHarga'] ?? 0).toDouble(),
      totalModal: (data['totalModal'] ?? 0.0).toDouble(),
      lastPrice:
          data['lastPrice'] != null
              ? (data['lastPrice'] as num).toDouble()
              : null,
      lastPriceUpdate:
          data['lastPriceUpdate'] != null
              ? (data['lastPriceUpdate'] as Timestamp).toDate()
              : null,
      varianInfo: data['varianInfo'],
      createdAt:
          data['createdAt'] != null
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
      supplierName: data['supplierName'],
      supplierNumber: data['supplierNumber'],
      supplierDetail: data['supplierDetail'],
      suratJalan: data['suratJalan'],
    );
  }

  static String generateAutoCode() {
    final rand = Random();
    return 'BRG-${rand.nextInt(90000) + 10000}';
  }

  static final NumberFormat _fmt = NumberFormat.decimalPattern('id_ID');

  String get hargaPerUnitFormatted => _fmt.format(hargaPerUnit);
  String get jumlahHargaFormatted => _fmt.format(jumlahHarga);
}
