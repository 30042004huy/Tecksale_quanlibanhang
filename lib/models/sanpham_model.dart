// VỊ TRÍ: lib/models/sanpham_model.dart

/// Lớp đại diện cho một sản phẩm.
class SanPham {
  String id;      // ID duy nhất của sản phẩm từ Firebase (key)
  String maSP;    // Mã sản phẩm (ví dụ: SP001)
  String tenSP;   // Tên sản phẩm (ví dụ: Áo thun nam)
  double donGia;  // Đơn giá bán của sản phẩm
  String donVi;   // Đơn vị tính (ví dụ: Cái, Chiếc, Bộ)
  double? giaNhap; // Giá nhập (tùy chọn)
  int? tonKho;    // Tồn kho (tùy chọn)

  SanPham({
    required this.id,
    required this.maSP,
    required this.tenSP,
    required this.donGia,
    required this.donVi,
    this.giaNhap,
    this.tonKho,
  });

  /// ✨ HÀM fromMap ĐÃ ĐƯỢC SỬA LẠI ĐỂ AN TOÀN TUYỆT ĐỐI ✨
  /// Phương thức factory để tạo một đối tượng SanPham từ dữ liệu Map.
  /// Giờ đây nó sẽ không bao giờ gây crash, ngay cả khi dữ liệu trên Firebase bị thiếu.
  factory SanPham.fromMap(Map<dynamic, dynamic> map, String id) {
    return SanPham(
      id: id,
      // Cung cấp giá trị mặc định ('') nếu 'maSP' không tồn tại hoặc null
      maSP: map['maSP']?.toString() ?? '', 
      tenSP: map['tenSP']?.toString() ?? 'Sản phẩm không tên',
      donGia: (map['donGia'] as num?)?.toDouble() ?? 0.0,
      // Cung cấp giá trị mặc định ('') nếu 'donVi' không tồn tại hoặc null
      donVi: map['donVi']?.toString() ?? '', 
      giaNhap: (map['giaNhap'] as num?)?.toDouble(),
      tonKho: (map['tonKho'] as num?)?.toInt() ?? 0,
    );
  }

  /// ✨ HÀM toMap ĐÃ ĐƯỢC SỬA LẠI ĐỂ NHẤT QUÁN ✨
  /// Phương thức để chuyển đổi đối tượng SanPham thành Map.
  /// Đảm bảo các trường bắt buộc luôn được lưu lên Firebase.
  Map<String, dynamic> toMap() {
    return {
      'maSP': maSP, // Bỏ điều kiện if không cần thiết, đảm bảo maSP luôn được lưu
      'tenSP': tenSP,
      'donGia': donGia,
      'donVi': donVi, // Bỏ điều kiện if không cần thiết, đảm bảo donVi luôn được lưu
      if (giaNhap != null) 'giaNhap': giaNhap,
      if (tonKho != null) 'tonKho': tonKho,
    };
  }
}