import 'package:intl/intl.dart';

final _moneyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

String formatMoney(num amount) => _moneyFormat.format(amount);

String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String toApiDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime parseApiDate(String value) => DateTime.parse(value);
