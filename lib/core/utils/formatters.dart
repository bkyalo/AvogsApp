import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

String formatMoney(num amount) => _moneyFormat.format(amount);

String compactMoney(num amount) {
  final value = amount.toDouble();
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return value.toStringAsFixed(0);
}

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String toApiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime parseApiDate(String value) => DateTime.parse(value);
