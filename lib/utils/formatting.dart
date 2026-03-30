import 'package:intl/intl.dart';

extension NumFormatting on num {
  String withCommas() => NumberFormat.decimalPattern('id_ID').format(this);
  String toRupiah({bool symbol = true}) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: symbol ? 'Rp ' : '',
  ).format(this);
}
