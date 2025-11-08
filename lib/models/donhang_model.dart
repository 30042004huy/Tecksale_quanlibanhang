import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:developer';

/// Lớp tiện ích để định dạng số tiền.
class FormatCurrency {
  static String formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }
  
  // ✨ HÀM CHUYỂN SỐ SANG CHỮ (BỔ SUNG NẾU BẠN CẦN DÙNG Ở ĐÂY)
  // (Lưu ý: Bạn đã có hàm này trong file taodon.dart, 
  // bạn có thể chuyển nó vào đây để dùng chung nếu muốn)
  // static String numberToWords(double number) { ... }
}

/// Enum đại diện cho tình trạng của đơn hàng.
enum OrderStatus {
  draft,
  saved,
  completed,
}

/// Lớp đại diện cho một mặt hàng trong đơn hàng.
class OrderItem {
  final String productId;
  final String name;
  final int quantity;
  final String unit;
  final double unitPrice;
  final String? category;
  final String? description;
  final String? imageUrl;
  final String? baoHanh;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.category,
    this.description,
    this.imageUrl,
    this.baoHanh,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? 'Sản phẩm không tên',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] ?? '',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      category: map['category'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      baoHanh: map['baoHanh'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'category': category,
      'description': description,
      'imageUrl': imageUrl,
      if (baoHanh != null) 'baoHanh': baoHanh,
    };
  }

  OrderItem copyWith({
    String? productId,
    String? name,
    int? quantity,
    String? unit,
    double? unitPrice,
    String? category,
    String? description,
    String? imageUrl,
    String? baoHanh,
  }) {
    return OrderItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      category: category ?? this.category,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      baoHanh: baoHanh ?? this.baoHanh,
    );
  }
}

/// Lớp đại diện cho toàn bộ dữ liệu của một đơn hàng.
class OrderData {
  final String orderId;
  final DateTime orderDate;
  final String customerName; // Vẫn giữ để chứa dữ liệu đã đồng bộ
  final String customerPhone; // Vẫn giữ để chứa dữ liệu đã đồng bộ
  final List<OrderItem> items;
  final double shippingCost;
  final double discount;
  final String notes;
  final OrderStatus status;
  final dynamic savedAt;
  final String employeeId;

  // THÊM: customerInfo (tùy chọn, dùng khi chuyển từ web)
  final Map<String, dynamic>? customerInfo;

  OrderData({
    required this.orderId,
    required this.orderDate,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.shippingCost,
    required this.discount,
    required this.notes,
    required this.status,
    this.savedAt,
    required this.employeeId,
    this.customerInfo, // Có thể null
  });

  // GETTER: Ưu tiên customerInfo, nếu không có thì dùng flat field
  String get displayCustomerName {
    if (customerInfo != null && customerInfo!['name'] != null && customerInfo!['name'].toString().trim().isNotEmpty) {
      return customerInfo!['name'].toString().trim();
    }
    return customerName;
  }

  String get displayCustomerPhone {
    if (customerInfo != null && customerInfo!['phone'] != null && customerInfo!['phone'].toString().trim().isNotEmpty) {
      return customerInfo!['phone'].toString().trim();
    }
    return customerPhone;
  }

  String get displayCustomerAddress {
    return customerInfo?['address']?.toString().trim() ?? '';
  }

  String get displayCustomerEmail {
    return customerInfo?['email']?.toString().trim() ?? '';
  }

  // Tính tổng tiền
  double get totalAmount {
    double subTotal = items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);
    return subTotal + shippingCost - discount;
  }

  // ✨✨✨ HÀM `fromMap` ĐÃ ĐƯỢC CẬP NHẬT ✨✨✨
  factory OrderData.fromMap(Map<dynamic, dynamic> map) {
    final safeMap = Map<String, dynamic>.from(map);
    log('DEBUG fromMap: Reading orderId: ${safeMap['orderId']}');

    // Parse status
    final String? statusString = safeMap['status'] as String?;
    final OrderStatus parsedStatus = OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusString,
      orElse: () {
        log('WARNING: Status "$statusString" not found, defaulting to draft.');
        return OrderStatus.draft;
      },
    );

    // Parse items
    final itemsList = safeMap['items'] as List<dynamic>?;
    final List<OrderItem> parsedItems = itemsList?.map((item) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          return OrderItem.fromMap(itemMap);
        }).toList() ?? [];

    // --- ✨ BẮT ĐẦU LOGIC ĐỒNG BỘ CUSTOMER INFO ✨ ---

    // 1. Parse customerInfo nếu có
    Map<String, dynamic>? customerInfoMap;
    if (safeMap['customerInfo'] != null) {
      customerInfoMap = Map<String, dynamic>.from(safeMap['customerInfo']);
    }

    // 2. Lấy tên/sđt từ customerInfo (ưu tiên)
    String nameFromInfo = customerInfoMap?['name']?.toString() ?? '';
    String phoneFromInfo = customerInfoMap?['phone']?.toString() ?? '';

    // 3. Lấy tên/sđt từ flat fields (dự phòng cho dữ liệu cũ)
    String nameFromFlat = safeMap['customerName']?.toString() ?? '';
    String phoneFromFlat = safeMap['customerPhone']?.toString() ?? '';

    // 4. Quyết định giá trị cuối cùng cho thuộc tính của object
    // (Ưu tiên info, nếu không có thì dùng flat, nếu không có thì mặc định)
    String finalName = nameFromInfo.isNotEmpty ? nameFromInfo : (nameFromFlat.isNotEmpty ? nameFromFlat : 'Khách lẻ');
    String finalPhone = phoneFromInfo.isNotEmpty ? phoneFromInfo : phoneFromFlat;
    
    // 5. Đảm bảo customerInfoMap trên object không bao giờ null (để đồng bộ dữ liệu cũ)
    if (customerInfoMap == null || customerInfoMap.isEmpty) {
      customerInfoMap = {
        'name': finalName,
        'phone': finalPhone,
      };
    } else {
      // Đảm bảo map luôn chứa name/phone (cho dù ban đầu nó null)
      customerInfoMap['name'] = finalName;
      customerInfoMap['phone'] = finalPhone;
    }
    // --- ✨ KẾT THÚC LOGIC ĐỒNG BỘ ✨ ---

    return OrderData(
      orderId: safeMap['orderId'] ?? '',
      orderDate: DateTime.fromMillisecondsSinceEpoch(safeMap['orderDate'] ?? 0),
      customerName: finalName, // ✨ SỬA: Dùng giá trị đã đồng bộ
      customerPhone: finalPhone, // ✨ SỬA: Dùng giá trị đã đồng bộ
      items: parsedItems,
      shippingCost: (safeMap['shippingCost'] as num?)?.toDouble() ?? 0.0,
      discount: (safeMap['discount'] as num?)?.toDouble() ?? 0.0,
      notes: safeMap['notes']?.toString() ?? '',
      status: parsedStatus,
      savedAt: safeMap['savedAt'],
      employeeId: safeMap['employeeId']?.toString() ?? '',
      customerInfo: customerInfoMap, // ✨ SỬA: Luôn gán map đã đồng bộ
    );
  }

  // ✨✨✨ HÀM `toMap` ĐÃ ĐƯỢC CẬP NHẬT ✨✨✨
  Map<String, dynamic> toMap() {
    final map = {
      'orderId': orderId,
      'orderDate': orderDate.millisecondsSinceEpoch,
      // 'customerName': customerName, // ✨ XÓA
      // 'customerPhone': customerPhone, // ✨ XÓA
      'items': items.map((item) => item.toMap()).toList(),
      'shippingCost': shippingCost,
      'discount': discount,
      'notes': notes,
      'status': status.toString().split('.').last,
      'savedAt': savedAt ?? ServerValue.timestamp,
      'employeeId': employeeId,
    };

    // ✨ LOGIC GHI MỚI (ĐỒNG BỘ) ✨
    // Nếu customerInfo (từ web/tải lên) tồn tại và có dữ liệu, dùng nó
    if (customerInfo != null && customerInfo!.isNotEmpty) {
      // Đảm bảo nó luôn chứa các trường name/phone mới nhất từ getters
      // (Phòng trường hợp người dùng sửa tên/sđt ở đâu đó)
      map['customerInfo'] = {
        ...customerInfo!, // Giữ lại các trường cũ như address, email
        'name': displayCustomerName, // Ghi đè bằng getter
        'phone': displayCustomerPhone, // Ghi đè bằng getter
      };
    } else {
      // Nếu không (từ taodon/cuahang), tạo nó từ các thuộc tính
      map['customerInfo'] = {
        'name': customerName,
        'phone': customerPhone,
      };
    }

    return map;
  }

  OrderData copyWith({
    String? orderId,
    DateTime? orderDate,
    String? customerName,
    String? customerPhone,
    List<OrderItem>? items,
    double? shippingCost,
    double? discount,
    String? notes,
    OrderStatus? status,
    dynamic savedAt,
    String? employeeId,
    Map<String, dynamic>? customerInfo,
  }) {
    return OrderData(
      orderId: orderId ?? this.orderId,
      orderDate: orderDate ?? this.orderDate,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      items: items ?? this.items,
      shippingCost: shippingCost ?? this.shippingCost,
      discount: discount ?? this.discount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      savedAt: savedAt ?? this.savedAt,
      employeeId: employeeId ?? this.employeeId,
      customerInfo: customerInfo ?? this.customerInfo,
    );
  }
}