import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/mauhoadon_model.dart'; // Đảm bảo đường dẫn đúng

Future<ShopInfo> loadShopInfoFromFirebase() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    // Xử lý trường hợp người dùng chưa đăng nhập hoặc không có UID
    return ShopInfo(
      name: 'Cửa hàng của bạn',
      phone: 'Chưa có SĐT',
      address: 'Chưa có địa chỉ',
      bankName: 'Chưa có ngân hàng',
      accountNumber: 'Chưa có STK',
      accountName: 'Chưa có chủ TK',
      qrCodeUrl: '',
    );
  }

  final db = FirebaseDatabase.instance;
  final snapshot = await db.ref('nguoidung/$uid/thongtincuahang').get();

  if (snapshot.exists) {
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    return ShopInfo.fromMap({
      'name': data['tenCuaHang'], // Map 'tenCuaHang' từ Firebase sang 'name' trong ShopInfo
      'phone': data['soDienThoai'], // Map 'soDienThoai' từ Firebase sang 'phone'
      'address': data['diaChi'], // Map 'diaChi' từ Firebase sang 'address'
      'bankName': data['tenNganHang'],
      'accountNumber': data['soTaiKhoan'],
      'accountName': data['chuTaiKhoan'],
      'qrCodeUrl': data['qrCodeUrl'] ?? '', // Nếu có trường QR code
    });
  } else {
    // Trả về thông tin mặc định nếu không tìm thấy dữ liệu
    return ShopInfo(
      name: 'Cửa hàng của bạn',
      phone: 'Chưa có SĐT',
      address: 'Chưa có địa chỉ',
      bankName: 'Chưa có ngân hàng',
      accountNumber: 'Chưa có STK',
      accountName: 'Chưa có chủ TK',
      qrCodeUrl: '',
    );
  }
}