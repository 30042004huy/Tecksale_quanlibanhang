import 'package:intl/intl.dart'; // Cần thêm gói intl vào pubspec.yaml
import 'package:firebase_database/firebase_database.dart'; // Để sử dụng ServerValue.timestamp
import 'dart:developer';

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

/// Enum đại diện cho tình trạng của đơn hàng.
enum OrderStatus {
  draft, // Đơn nháp
  saved, // Đơn đã lưu (chưa hoàn tất)
  completed, // Đơn hoàn tất
}

/// Lớp đại diện cho một mặt hàng trong đơn hàng.
class OrderItem {
  final String productId; // ID sản phẩm (nếu có)
  final String name;
  final int quantity;
  final String unit; // Đơn vị (ví dụ: cái, kg, hộp)
  final double unitPrice;
  // Các trường này có thể null nếu không được lưu trong Firebase
  final String? category;
  final String? description;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.category,
    this.description,
    this.imageUrl,
  });

  // Phương thức factory để tạo OrderItem từ Map (ví dụ: từ Firebase)
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
    );
  }

  // Phương thức để chuyển đổi OrderItem thành Map
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
    };
  }

  // Phương thức copyWith để tạo bản sao với các thay đổi
  OrderItem copyWith({
    String? productId,
    String? name,
    int? quantity,
    String? unit,
    double? unitPrice,
    String? category,
    String? description,
    String? imageUrl,
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
    );
  }
}

/// Lớp đại diện cho toàn bộ dữ liệu của một đơn hàng.
class OrderData {
  final String orderId; // ID đơn hàng
  final DateTime orderDate; // Ngày tạo đơn
  final String customerName;
  final String customerPhone;
  final List<OrderItem> items;
  final double shippingCost; // Chi phí vận chuyển
  final double discount; // Giảm giá
  final String notes;
  final OrderStatus status; // Trạng thái của đơn hàng
  final dynamic savedAt; // Dấu thời gian khi lưu đơn hàng

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
  });

  // [ĐÃ SỬA LỖI] Phương thức factory để tạo OrderData từ Map (ví dụ: từ Firebase)
  factory OrderData.fromMap(Map<dynamic, dynamic> map) {
    // Chuyển đổi map đầu vào để dễ sử dụng và tránh lỗi kiểu dữ liệu
    final safeMap = Map<String, dynamic>.from(map);

    // Thêm log để kiểm tra giá trị status thực tế từ Firebase
    log('DEBUG fromMap: Reading orderId: ${safeMap['orderId']}');
    log('DEBUG fromMap: Reading status from Firebase: ${safeMap['status']}');

    final String? statusString = safeMap['status'] as String?;
    final OrderStatus parsedStatus = OrderStatus.values.firstWhere(
      (e) => e.toString().split('.').last == statusString,
      orElse: () {
        log('WARNING: Status "$statusString" not found, defaulting to draft.');
        return OrderStatus.draft; // Mặc định là 'draft' nếu không tìm thấy
      },
    );

    // [FIX 1] Chuyển đổi 'customerInfo' sang Map<String, dynamic> một cách an toàn
    final customerInfoMap = safeMap['customerInfo'] != null
        ? Map<String, dynamic>.from(safeMap['customerInfo'])
        : <String, dynamic>{};

    // [FIX 2] Chuyển đổi từng 'item' trong list sang Map<String, dynamic>
    final itemsList = safeMap['items'] as List<dynamic>?;
    final List<OrderItem> parsedItems = itemsList?.map((item) {
          // Đây là bước chuyển đổi quan trọng nhất để tránh lỗi type 'Map<dynamic, dynamic>' is not a subtype of type 'Map<String, dynamic>'
          final itemMap = Map<String, dynamic>.from(item as Map<dynamic, dynamic>);
          return OrderItem.fromMap(itemMap);
        }).toList() ?? [];

    return OrderData(
      orderId: safeMap['orderId'] ?? '',
      orderDate: DateTime.fromMillisecondsSinceEpoch(safeMap['orderDate'] ?? 0),
      // Sử dụng map đã được chuyển đổi an toàn
      customerName: customerInfoMap['name'] ?? 'Không có tên',
      customerPhone: customerInfoMap['phone'] ?? 'Không có SĐT',
      // Sử dụng danh sách item đã được phân tích
      items: parsedItems,
      shippingCost: (safeMap['shippingCost'] as num?)?.toDouble() ?? 0.0,
      discount: (safeMap['discount'] as num?)?.toDouble() ?? 0.0,
      notes: safeMap['notes'] ?? '',
      status: parsedStatus,
      savedAt: safeMap['savedAt'],
    );
  }


  // Phương thức để chuyển đổi OrderData thành Map
  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'orderDate': orderDate.millisecondsSinceEpoch, // Lưu dưới dạng timestamp
      'customerInfo': {
        'name': customerName,
        'phone': customerPhone,
      },
      'items': items.map((item) => item.toMap()).toList(),
      'shippingCost': shippingCost,
      'discount': discount,
      'notes': notes,
      'status': status.toString().split('.').last, // Lưu tên enum
      'savedAt': savedAt ?? ServerValue.timestamp, // Sử dụng ServerValue.timestamp khi lưu mới
    };
  }

  // Phương thức copyWith để tạo bản sao với các thay đổi
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
    );
  }

  // Tính tổng tiền đơn hàng
  double get totalAmount {
    double subTotal = items.fold(0.0, (sum, item) => sum + item.unitPrice * item.quantity);
    return subTotal + shippingCost - discount;
  }
}
