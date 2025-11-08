import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:device_info_plus/device_info_plus.dart';

class LoginHistoryService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Ghi lại thông tin đăng nhập hiện tại của người dùng lên Firebase
  Future<void> recordLogin() async {
    final user = _auth.currentUser;
    if (user == null) return; // Không có người dùng, không làm gì cả

    try {
      final String deviceIdentifier = await _getDeviceIdentifier();
      final String address = await _getCurrentLocation();
      final int loginTime = DateTime.now().millisecondsSinceEpoch;

      final loginData = {
        'deviceName': deviceIdentifier,
        'loginTime': loginTime,
        'address': address,
      };

      // Đẩy dữ liệu lên Firebase
      await _dbRef
          .child('nguoidung/${user.uid}/lichsudangnhap')
          .push()
          .set(loginData);
    } catch (e) {
      print('Lỗi khi ghi lại lịch sử đăng nhập: $e');
      // Có thể xử lý lỗi ở đây, ví dụ: lưu vào bộ nhớ đệm để thử lại sau
    }
  }

  /// Lấy tên thiết bị (model)
  Future<String> _getDeviceIdentifier() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return 'Android: ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return 'iOS: ${iosInfo.utsname.machine}';
      }
      return 'Thiết bị không xác định';
    } catch (e) {
      return 'Không thể lấy thông tin thiết bị';
    }
  }

  /// Lấy vị trí hiện tại và chuyển đổi thành địa chỉ
  Future<String> _getCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // Kiểm tra xem dịch vụ vị trí có được bật không
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Dịch vụ vị trí đã bị tắt.';
      }

      // Kiểm tra quyền truy cập vị trí
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'Quyền truy cập vị trí bị từ chối.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return 'Quyền truy cập vị trí bị từ chối vĩnh viễn.';
      }

      // Lấy tọa độ
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Độ chính xác trung bình để nhanh hơn
      );

      // Chuyển đổi tọa độ sang địa chỉ
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks[0];
        // Ghép chuỗi địa chỉ cho dễ đọc
        return '${place.street}, ${place.subAdministrativeArea}, ${place.administrativeArea}';
      } else {
        return 'Không tìm thấy địa chỉ.';
      }
    } catch (e) {
      return 'Không thể lấy địa chỉ: ${e.toString()}';
    }
  }
}
