import 'package:intl/intl.dart';

class LoginEntry {
  final String id; // Key từ Firebase
  final String deviceName;
  final DateTime loginTime;
  final String address;

  LoginEntry({
    required this.id,
    required this.deviceName,
    required this.loginTime,
    required this.address,
  });

  // Factory constructor để tạo một đối tượng LoginEntry từ dữ liệu Firebase
  factory LoginEntry.fromMap(String key, Map<dynamic, dynamic> map) {
    return LoginEntry(
      id: key,
      deviceName: map['deviceName'] ?? 'Thiết bị không xác định',
      // Firebase thường lưu thời gian dưới dạng millisecondsSinceEpoch
      loginTime: DateTime.fromMillisecondsSinceEpoch(map['loginTime']),
      address: map['address'] ?? 'Không thể lấy địa chỉ',
    );
  }

  // Hàm tiện ích để định dạng thời gian hiển thị
  String get formattedLoginTime {
    return DateFormat('HH:mm - dd/MM/yyyy', 'vi_VN').format(loginTime);
  }
}
