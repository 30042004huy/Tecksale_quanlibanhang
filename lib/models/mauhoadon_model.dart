import 'package:intl/intl.dart'; // Cần thêm gói intl vào pubspec.yaml

/// Lớp tiện ích để định dạng số tiền.
/// (Được bao gồm lại để đảm bảo tính đầy đủ trong file model)
class FormatCurrency {
  /// Định dạng một số tiền (double) thành chuỗi tiền tệ tiếng Việt.
  /// Ví dụ: 150000.0 sẽ trở thành "150.000 đ".
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }
}

/// Enum đại diện cho các kích thước hóa đơn.
enum InvoiceSize {
  A5,
  SeventyFiveMm, // 75mm - Đã thay đổi từ EightyMm
}

/// Lớp đại diện cho thông tin cửa hàng.
class ShopInfo {
  final String name;
  final String phone;
  final String address;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String qrCodeUrl;

  ShopInfo({
    required this.name,
    required this.phone,
    required this.address,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.qrCodeUrl,
  });

  // Phương thức factory để tạo ShopInfo từ Map (ví dụ: từ Firebase)
  factory ShopInfo.fromMap(Map<String, dynamic> map) {
    return ShopInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      accountName: map['accountName'] ?? '',
      qrCodeUrl: map['qrCodeUrl'] ?? 'https://placehold.co/200x200/000000/FFFFFF/png?text=QR+Code',
    );
  }

  // Phương thức để chuyển đổi ShopInfo thành Map (ví dụ: để lưu vào Firebase)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'qrCodeUrl': qrCodeUrl,
    };
  }
}

/// Lớp đại diện cho thông tin khách hàng.
class CustomerInfo {
  final String name;
  final String phone;

  CustomerInfo({
    required this.name,
    required this.phone,
  });

  // Phương thức factory để tạo CustomerInfo từ Map
  factory CustomerInfo.fromMap(Map<String, dynamic> map) {
    return CustomerInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  // Phương thức để chuyển đổi CustomerInfo thành Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}

/// Lớp đại diện cho một mặt hàng trong hóa đơn.
class InvoiceItem {
  final String name;
  final int quantity;
  final String unit; // Đơn vị (chỉ hiển thị ở A5)
  final double unitPrice;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  // Phương thức factory để tạo InvoiceItem từ Map
  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Phương thức để chuyển đổi InvoiceItem thành Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
    };
  }

  /// Tính thành tiền của mặt hàng.
  double get totalPrice => quantity * unitPrice;
}

/// Lớp chính đại diện cho toàn bộ dữ liệu hóa đơn.
class InvoiceData {
  final String invoiceNumber;
  final ShopInfo shopInfo;
  final CustomerInfo customerInfo;
  final List<InvoiceItem> items;
  final double shippingCost;
  final double discount;
  final String notes;
  final InvoiceSize selectedSize; // Kích thước hóa đơn được chọn
  
// Thêm 2 trường này
  final DateTime? orderDate; // ngày đặt hóa đơn
  final int? savedAt;        // timestamp lưu hóa đơn (millisecondsSinceEpoch)

  InvoiceData({
    required this.invoiceNumber,
    required this.shopInfo,
    required this.customerInfo,
    required this.items,
    this.shippingCost = 0.0,
    this.discount = 0.0,
    this.notes = '',
    this.selectedSize = InvoiceSize.A5,
    this.orderDate,      // thêm vào đây
    this.savedAt,        // thêm vào đây
  });

  /// Tính tổng tiền hàng (chưa bao gồm phí vận chuyển và giảm giá).
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  /// Tính tổng số tiền cần thanh toán.
  double get totalPayment => subtotal + shippingCost - discount;

  /// Chuyển đổi tổng số tiền cần thanh toán thành chữ.
  String get totalPaymentInWords => _convertAmountToWords(totalPayment);

  /// Hàm chuyển đổi số sang chữ (đơn giản, cần mở rộng cho các trường hợp phức tạp hơn).
  String _convertAmountToWords(double amount) {
    final intAmount = amount.toInt();
    if (intAmount == 0) return 'Không đồng';
    
    final units = ['', 'nghìn', 'triệu', 'tỷ'];
    final digits = ['không', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];

    String readThreeDigits(int n) {
      if (n == 0) return '';
      String s = '';
      int hundreds = n ~/ 100;
      int tens = (n % 100) ~/ 10;
      int ones = n % 10;

      if (hundreds > 0) s += '${digits[hundreds]} trăm ';
      if (tens == 0 && ones == 0) {
        // Do nothing
      } else if (tens == 0) {
        s += 'lẻ ${digits[ones]} ';
      } else if (tens == 1) {
        s += 'mười ';
        if (ones > 0) s += '${digits[ones]} ';
      } else {
        s += '${digits[tens]} mươi ';
        if (ones == 1) s += 'mốt ';
        else if (ones == 5) s += 'lăm ';
        else if (ones > 0) s += '${digits[ones]} ';
      }
      return s;
    }

    String result = '';
    int i = 0;
    int tempAmount = intAmount;

    while (tempAmount > 0) {
      int threeDigits = tempAmount % 1000;
      if (threeDigits > 0) {
        result = '${readThreeDigits(threeDigits)}${units[i]} $result';
      }
      tempAmount ~/= 1000;
      i++;
    }
    return result.trim().replaceAll(RegExp(r'\s+'), ' ').capitalizeFirstLetter() + ' đồng chẵn.';
  }

  // Phương thức factory để tạo InvoiceData từ Map
factory InvoiceData.fromMap(Map<String, dynamic> map) {
  return InvoiceData(
    invoiceNumber: map['invoiceNumber'] ?? '',
    shopInfo: ShopInfo.fromMap(map['shopInfo'] ?? {}),
    customerInfo: CustomerInfo.fromMap(map['customerInfo'] ?? {}),
    items: (map['items'] as List<dynamic>?)
            ?.map((itemMap) => InvoiceItem.fromMap(itemMap))
            .toList() ?? [],
    shippingCost: (map['shippingCost'] as num?)?.toDouble() ?? 0.0,
    discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
    notes: map['notes'] ?? '',
    selectedSize: (map['selectedSize'] != null)
        ? InvoiceSize.values.firstWhere(
            (e) => e.toString() == 'InvoiceSize.${map['selectedSize']}',
            orElse: () => InvoiceSize.A5)
        : InvoiceSize.A5,
    orderDate: map['orderDate'] != null ? DateTime.tryParse(map['orderDate']) : null,
    savedAt: map['savedAt'] as int?,
  );
}

Map<String, dynamic> toMap() {
  return {
    'invoiceNumber': invoiceNumber,
    'shopInfo': shopInfo.toMap(),
    'customerInfo': customerInfo.toMap(),
    'items': items.map((item) => item.toMap()).toList(),
    'shippingCost': shippingCost,
    'discount': discount,
    'notes': notes,
    'selectedSize': selectedSize.toString().split('.').last,
    'orderDate': orderDate?.toIso8601String(),
    'savedAt': savedAt,
  };
}


  // Phương thức copyWith để tạo bản sao với các thay đổi
  InvoiceData copyWith({
    String? invoiceNumber,
    ShopInfo? shopInfo,
    CustomerInfo? customerInfo,
    List<InvoiceItem>? items,
    double? shippingCost,
    double? discount,
    String? notes,
    InvoiceSize? selectedSize,
  }) {
    return InvoiceData(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      shopInfo: shopInfo ?? this.shopInfo,
      customerInfo: customerInfo ?? this.customerInfo,
      items: items ?? this.items,
      shippingCost: shippingCost ?? this.shippingCost,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      selectedSize: selectedSize ?? this.selectedSize,
    );
  }
}

// Extension để viết hoa chữ cái đầu tiên của chuỗi
extension StringCasingExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
