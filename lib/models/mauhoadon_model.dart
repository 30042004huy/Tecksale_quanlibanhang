import 'package:intl/intl.dart';

class FormatCurrency {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }
}

enum InvoiceSize {
  A5,
  SeventyFiveMm,
  SeventyFiveMmCompact, 
}

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

class CustomerInfo {
  final String name;
  final String phone;

  CustomerInfo({
    required this.name,
    required this.phone,
  });

  factory CustomerInfo.fromMap(Map<String, dynamic> map) {
    return CustomerInfo(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final String unit;
  final double unitPrice;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
    };
  }

  double get totalPrice => quantity * unitPrice;
}

class InvoiceData {
  final String invoiceNumber;
  final ShopInfo shopInfo;
  final CustomerInfo customerInfo;
  final List<InvoiceItem> items;
  final double shippingCost;
  final double discount;
  final String notes;
  final InvoiceSize selectedSize;
  final DateTime? orderDate;
  final int? savedAt;
  final String? employeeName;

  // ✨ BẮT ĐẦU THÊM CÁC TRƯỜNG MỚI
  final bool showShopInfo;
  final bool showCustomerInfo;
  final bool showBankInfo;
  final bool showQrCode;
  // ✨ KẾT THÚC THÊM CÁC TRƯỜNG MỚI

  InvoiceData({
    required this.invoiceNumber,
    required this.shopInfo,
    required this.customerInfo,
    required this.items,
    this.shippingCost = 0.0,
    this.discount = 0.0,
    this.notes = '',
    this.selectedSize = InvoiceSize.A5,
    this.orderDate,
    this.savedAt,
    this.employeeName,
    // ✨ THÊM VÀO CONSTRUCTOR
    this.showShopInfo = true,
    this.showCustomerInfo = true,
    this.showBankInfo = true,
    this.showQrCode = true,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get totalPayment => subtotal + shippingCost - discount;

  String get totalPaymentInWords => _convertAmountToWords(totalPayment);

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
      employeeName: map['employeeName']?.toString(),
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
      'employeeName': employeeName,
    };
  }


  // ✨ CẬP NHẬT HÀM `copyWith`
  InvoiceData copyWith({
    String? invoiceNumber,
    ShopInfo? shopInfo,
    CustomerInfo? customerInfo,
    List<InvoiceItem>? items,
    double? shippingCost,
    double? discount,
    String? notes,
    InvoiceSize? selectedSize,
    String? employeeName,
    bool? showShopInfo,
    bool? showCustomerInfo,
    bool? showBankInfo,
    bool? showQrCode,
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
      orderDate: orderDate,
      savedAt: savedAt,
      employeeName: employeeName ?? this.employeeName,
      showShopInfo: showShopInfo ?? this.showShopInfo,
      showCustomerInfo: showCustomerInfo ?? this.showCustomerInfo,
      showBankInfo: showBankInfo ?? this.showBankInfo,
      showQrCode: showQrCode ?? this.showQrCode,
    );
  }
}

extension StringCasingExtension on String {
  String capitalizeFirstLetter() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}