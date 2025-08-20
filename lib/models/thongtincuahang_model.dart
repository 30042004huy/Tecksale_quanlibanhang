/// Lớp đại diện cho thông tin cơ bản của cửa hàng,
/// được sử dụng cho việc tạo đơn hàng hoặc mẫu hóa đơn.
/// Chỉ bao gồm các trường cần thiết: tên, địa chỉ, số điện thoại.
class ShopInfoForInvoice {
  final String name;
  final String address;
  final String phone;

  ShopInfoForInvoice({
    required this.name,
    required this.address,
    required this.phone,
  });

  /// Phương thức factory để tạo đối tượng ShopInfoForInvoice từ Map.
  /// Thường được sử dụng khi đọc dữ liệu từ Firebase Realtime Database
  /// tại đường dẫn `nguoidung/uid/thongtincuahang`.
  factory ShopInfoForInvoice.fromMap(Map<dynamic, dynamic> map) {
    return ShopInfoForInvoice(
      name: map['tenCuaHang'] ?? '', // Lấy từ key 'tenCuaHang'
      address: map['diaChi'] ?? '', // Lấy từ key 'diaChi'
      phone: map['soDienThoai'] ?? '', // Lấy từ key 'soDienThoai'
    );
  }

  /// Phương thức để chuyển đổi đối tượng ShopInfoForInvoice thành Map.
  /// Hữu ích nếu cần lưu trữ hoặc truyền dữ liệu cửa hàng dưới dạng đơn giản.
  Map<String, dynamic> toMap() {
    return {
      'tenCuaHang': name,
      'diaChi': address,
      'soDienThoai': phone,
    };
  }
}
