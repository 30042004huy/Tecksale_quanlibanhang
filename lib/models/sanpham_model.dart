/// Lớp đại diện cho một sản phẩm.
/// Model này được thiết kế để sử dụng trong các trang như quản lý sản phẩm
/// và đặc biệt là trang tạo đơn hàng, nơi thông tin sản phẩm có thể được
/// tự động điền khi chọn bằng mã hoặc tên.
class SanPham {
  String id; // ID duy nhất của sản phẩm từ Firebase (key)
  String maSP; // Mã sản phẩm (ví dụ: SP001)
  String tenSP; // Tên sản phẩm (ví dụ: Áo thun nam)
  double donGia; // Đơn giá bán của sản phẩm
  String donVi; // Đơn vị tính (ví dụ: Cái, Chiếc, Bộ)
  double? giaNhap; // Giá nhập (tùy chọn, không bắt buộc khi tạo đối tượng)
  int? tonKho; // Tồn kho (tùy chọn, không bắt buộc khi tạo đối tượng)

  SanPham({
    required this.id,
    required this.maSP,
    required this.tenSP,
    required this.donGia,
    required this.donVi,
    this.giaNhap, // Đặt là tùy chọn
    this.tonKho, // Đặt là tùy chọn
  });

  /// Phương thức factory để tạo một đối tượng SanPham từ dữ liệu Map.
  /// Thường được sử dụng khi đọc dữ liệu từ Firebase Realtime Database.
  ///
  /// [map]: Dữ liệu sản phẩm dưới dạng Map<dynamic, dynamic> từ Firebase.
  /// [id]: Key (ID) của sản phẩm trong Firebase.
  factory SanPham.fromMap(Map<dynamic, dynamic> map, String id) {
    return SanPham(
      id: id,
      maSP: map['maSP'] ?? '',
      tenSP: map['tenSP'] ?? '',
      donGia: (map['donGia'] as num?)?.toDouble() ?? 0.0, // Chuyển đổi sang double
      donVi: map['donVi'] ?? '',
      giaNhap: (map['giaNhap'] as num?)?.toDouble(), // Lấy giá nhập (có thể null)
      tonKho: (map['tonKho'] as int?), // Lấy tồn kho (có thể null)
    );
  }

  /// Phương thức để chuyển đổi đối tượng SanPham thành Map.
  /// Thường được sử dụng khi ghi dữ liệu sản phẩm lên Firebase.
  Map<String, dynamic> toMap() {
    return {
      'maSP': maSP,
      'tenSP': tenSP,
      'donGia': donGia,
      'donVi': donVi,
      'giaNhap': giaNhap, // Bao gồm giá nhập
      'tonKho': tonKho, // Bao gồm tồn kho
    };
  }
}
