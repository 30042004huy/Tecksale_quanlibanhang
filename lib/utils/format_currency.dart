import 'package:intl/intl.dart';

class FormatCurrency {
  /// Định dạng số thành tiền tệ Việt Nam (ví dụ: 100,000 đ)
  static String format(dynamic amount, {String suffix = 'đ', int decimalDigits = 0}) {
    if (amount == null) return '0 $suffix';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '',
      decimalDigits: decimalDigits,
    );
    return '${formatter.format(value)} $suffix';
  }

  /// ✨ HÀM MỚI: Chuyển đổi số thành chữ tiếng Việt
  static String numberToWords(double amount) {
    int intAmount = amount.toInt(); // 🔹 đổi từ final -> int
    if (intAmount <= 0) return 'Không đồng';

    final digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
    final units = ['', 'nghìn', 'triệu', 'tỷ'];

    String readThreeDigits(int n) {
      int tram = n ~/ 100;
      int chuc = (n % 100) ~/ 10;
      int donvi = n % 10;
      String result = '';

      if (tram > 0) {
        result += '${digits[tram]} trăm ';
      }
      if (chuc > 1) {
        result += '${digits[chuc]} mươi ';
        if (donvi == 1) result += 'mốt ';
        else if (donvi == 5) result += 'lăm ';
        else if (donvi > 0) result += '${digits[donvi]} ';
      } else if (chuc == 1) {
        result += 'mười ';
        if (donvi == 5) result += 'lăm ';
        else if (donvi > 0) result += '${digits[donvi]} ';
      } else if (donvi > 0 && (tram > 0 || n > 999)) {
        result += 'linh ${digits[donvi]} ';
      } else if (donvi > 0) {
        result += '${digits[donvi]} ';
      }
      return result;
    }

    if (intAmount == 0) return 'Không đồng';
    String result = '';
    int i = 0;
    while (intAmount > 0) {
      int threeDigits = intAmount % 1000;
      if (threeDigits > 0) {
        result = '${readThreeDigits(threeDigits)}${units[i]} $result';
      }
      intAmount = intAmount ~/ 1000;
      i++;
    }

    // Dọn dẹp và viết hoa chữ cái đầu
    String finalResult = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    return '${finalResult[0].toUpperCase()}${finalResult.substring(1)} đồng';
  }
}