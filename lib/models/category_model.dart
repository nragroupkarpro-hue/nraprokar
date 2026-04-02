import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class CategoryModel {
  final String? id;
  final String namaBarang;
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

  CategoryModel({
    this.id,
    required this.namaBarang,
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
  });

  Map<String, dynamic> toMap() {
    return {
      'namaBarang': namaBarang,
      'satuan': satuan,
      'lokasi': lokasi,
      'kodeBarang': kodeBarang,
      'kuantitas': kuantitas,
      'hargaPerUnit': hargaPerUnit,
      'jumlahHarga': jumlahHarga,
      'lastPrice': lastPrice,
      'lastPriceUpdate': lastPriceUpdate != null ? Timestamp.fromDate(lastPriceUpdate!) : null,
      'varianInfo': varianInfo,
      'totalModal': totalModal,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
    };
  }

  // Digunakan saat menulis ke Firestore (menambahkan server timestamp)
  Map<String, dynamic> toFirestore() {
    final map = toMap();
    if (createdAt == null) {
      map['createdAt'] = FieldValue.serverTimestamp();
    }
    return map;
  }

  // Factory untuk data dari Map umum
  factory CategoryModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CategoryModel(
      id: id ?? map['id'],
      namaBarang: map['namaBarang'] ?? '',
      satuan: map['satuan'] ?? '',
      lokasi: map['lokasi'] ?? '',
      kodeBarang: map['kodeBarang'] ?? '',
      kuantitas: (map['kuantitas'] ?? 0).toInt(),
      hargaPerUnit: (map['hargaPerUnit'] ?? 0).toDouble(),
      jumlahHarga: (map['jumlahHarga'] ?? 0).toDouble(),
      totalModal: (map['totalModal'] ?? 0.0).toDouble(),
      lastPrice: map['lastPrice'] != null ? (map['lastPrice'] as num).toDouble() : null,
      lastPriceUpdate: map['lastPriceUpdate'] != null ? (map['lastPriceUpdate'] as Timestamp).toDate() : null,
      varianInfo: map['varianInfo'],
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
    );
  }

  // Factory khusus untuk data dari Firestore
  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CategoryModel.fromMap(data, id: id);
  }

  static final NumberFormat _fmt = NumberFormat.decimalPattern('en_US');

  String get hargaPerUnitFormatted => _fmt.format(hargaPerUnit);
  String get jumlahHargaFormatted => _fmt.format(jumlahHarga);

  static String generateAutoCode() {
    final now = DateTime.now();
    final dateCode = DateFormat('ddMMyy').format(now);
    final random = Random().nextInt(9000) + 1000; // Menghasilkan 4 digit (1000-9999)
    return 'BRG$dateCode$random';
  }
}