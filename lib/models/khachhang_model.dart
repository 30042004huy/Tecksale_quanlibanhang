/// Lớp đại diện cho thông tin khách hàng được sử dụng trong hóa đơn.
/// Chỉ bao gồm các trường cần thiết cho việc tạo hóa đơn (tên và số điện thoại).
class CustomerForInvoice {
  final String name;
  final String phone;

  CustomerForInvoice({
    required this.name,
    required this.phone,
  });

  /// Phương thức factory để tạo đối tượng CustomerForInvoice từ Map.
  /// Khi lấy dữ liệu từ Firebase, chỉ trích xuất 'name' và 'phone'.
  /// Các trường khác như 'debt' và 'note' sẽ bị bỏ qua trong model này.
  factory CustomerForInvoice.fromMap(Map<dynamic, dynamic> map) {
    return CustomerForInvoice(
      name: map['name'] ?? '', // Lấy tên khách hàng
      phone: map['phone'] ?? '', // Lấy số điện thoại khách hàng
    );
  }

  /// Phương thức để chuyển đổi đối tượng CustomerForInvoice thành Map.
  /// Hữu ích nếu cần lưu trữ hoặc truyền dữ liệu khách hàng dưới dạng đơn giản.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }
}
