import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as developer;
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
  final double?
  lastPrice; // harga terakhir sebelumnya (untuk tracking perubahan)
  final DateTime? lastPriceUpdate; // kapan harga terakhir diubah
  final String? varianInfo; // note varian, misal: "150g", "200g", dll
  final DateTime? createdAt; // tanggal pembuatan data

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
      'lastPriceUpdate': lastPriceUpdate,
      'varianInfo': varianInfo,
    };
  }

  /// used when writing to Firestore
  Map<String, dynamic> toFirestore() {
    final map = toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return map;
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'],
      namaBarang: map['namaBarang'] ?? '',
      satuan: map['satuan'] ?? '',
      lokasi: map['lokasi'] ?? '',
      kodeBarang: map['kodeBarang'] ?? '',
      kuantitas: map['kuantitas'] ?? 0,
      hargaPerUnit: (map['hargaPerUnit'] ?? 0).toDouble(),
      jumlahHarga: (map['jumlahHarga'] ?? 0).toDouble(),
      lastPrice:
          map['lastPrice'] != null
              ? (map['lastPrice'] as num).toDouble()
              : null,
      lastPriceUpdate:
          map['lastPriceUpdate'] != null
              ? (map['lastPriceUpdate'] as Timestamp).toDate()
              : null,
      varianInfo: map['varianInfo'],
      createdAt:
          map['createdAt'] != null
              ? (map['createdAt'] as Timestamp).toDate()
              : null,
    );
  }

  /// deserialiser used by FirestoreService
  factory CategoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CategoryModel(
      id: id,
      namaBarang: data['namaBarang'] ?? '',
      satuan: data['satuan'] ?? '',
      lokasi: data['lokasi'] ?? '',
      kodeBarang: data['kodeBarang'] ?? '',
      kuantitas: data['kuantitas'] ?? 0,
      hargaPerUnit: (data['hargaPerUnit'] ?? 0).toDouble(),
      jumlahHarga: (data['jumlahHarga'] ?? 0).toDouble(),
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
    );
  }

  // gunakan formatter koma-ribuan
  static final NumberFormat _fmt = NumberFormat.decimalPattern('en_US');
  // atau: NumberFormat('#,###', 'en_US');

  String get hargaPerUnitFormatted => _fmt.format(hargaPerUnit);
  String get jumlahHargaFormatted => _fmt.format(jumlahHarga);

  /// Generate kode barang otomatis
  /// Format: BRG[ddMMyy][4-digit random]
  /// Contoh: BRG27022654321
  static String generateAutoCode() {
    final now = DateTime.now();
    final dateCode = DateFormat('ddMMyy').format(now);
    final random = Random().nextInt(9999) + 1000;
    return 'BRG$dateCode${random.toString()}';
  }
}
