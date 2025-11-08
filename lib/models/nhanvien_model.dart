// VỊ TRÍ: file nhanvien_model.dart
// THAY THẾ TOÀN BỘ NỘI DUNG FILE BẰNG ĐOẠN CODE NÀY

class NhanVien {
  final String id;
  final String ten;
  final String ma;
  final int timestamp;

  const NhanVien({
    required this.id,
    required this.ten,
    required this.ma,
    required this.timestamp,
  });

  // Factory constructor để tạo đối tượng từ dữ liệu Map của Firebase
  factory NhanVien.fromMap(String id, Map<dynamic, dynamic> map) {
    return NhanVien(
      id: id,
      // Đảm bảo đọc đúng trường "ten" từ Firebase
      ten: map['ten']?.toString().trim() ?? 'Không có tên',
      ma: map['ma']?.toString().trim() ?? '',
      timestamp: map['timestamp'] is int ? map['timestamp'] : 0,
    );
  }

  // Thêm hàm toMap để có thể sử dụng nếu cần
  Map<String, dynamic> toMap() {
    return {
      'ten': ten,
      'ma': ma,
      'timestamp': timestamp,
    };
  }
}