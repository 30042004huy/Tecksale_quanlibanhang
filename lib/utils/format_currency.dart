import 'package:intl/intl.dart';

class FormatCurrency {
  /// Formats a number into Vietnamese currency format
  /// [amount]: The amount (int, double, or String)
  /// [suffix]: Currency suffix, defaults to 'VNĐ'
  /// [decimalDigits]: Number of decimal digits to display (default: 0)
  static String format(dynamic amount, {String suffix = 'đ', int decimalDigits = 0}) {
    if (amount == null) return '0 $suffix';

    // Convert amount to double for consistent handling
    double value;
    if (amount is double) {
      value = amount;
    } else if (amount is int) {
      value = amount.toDouble();
    } else {
      // Try parsing if amount is String or other type
      value = double.tryParse(amount.toString()) ?? 0.0;
    }

    // Use NumberFormat from intl package for proper currency formatting
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '',
      decimalDigits: decimalDigits,
      customPattern: '#,###',
    );

    // Format the number and append the suffix
    return '${formatter.format(value)} $suffix';
  }
}