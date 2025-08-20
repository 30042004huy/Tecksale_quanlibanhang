import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database

/// Dịch vụ để tương tác với API VietQR để tạo mã QR thanh toán.
class VietQRService {
  static const String _vietQrApiUrl = 'https://api.vietqr.io/v2/generate';

  // Ánh xạ tên ngân hàng sang Bank ID
  // Đây là dữ liệu tĩnh, bạn có thể mở rộng thêm các ngân hàng khác nếu cần.
  static const Map<String, String> _bankNameToIdMap = {
    'MB Bank': '970422',
    'VietinBank': '970415',
    'Vietcombank': '970436',
    'PVcomBank': '970412',
    'Techcombank': '970407',
    'Agribank': '970405',
    'Sacombank': '970403',
    'BIDV': '970418',
    'ACB': '970416',
    'VPBank': '970432',
    'TPBank': '970423',
    'Eximbank': '970431',
    'SHB': '970443',
    'VIB': '970440',
    'OCB': '970448',
    // Thêm các ngân hàng khác vào đây
    // Nếu tên ngân hàng không có trong map, Bank ID sẽ là một chuỗi rỗng hoặc giá trị mặc định khác.
  };


  /// Tạo mã QR thanh toán bằng cách lấy thông tin ngân hàng trực tiếp từ Firebase.
  ///
  /// [amount]: Số tiền cần thanh toán (tùy chọn).
  ///
  /// Trả về [Uint8List] là dữ liệu ảnh QR code, hoặc `null` nếu có lỗi.
  static Future<Uint8List?> generateQrCode({
    double? amount,
  }) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("Lỗi: Người dùng chưa đăng nhập.");
      return null;
    }

    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    DataSnapshot? snapshot;
    try {
      snapshot = await dbRef.child('nguoidung/${user.uid}/thongtincuahang').get();
    } catch (e) {
      print("Lỗi đọc dữ liệu thông tin cửa hàng từ Firebase: $e");
      return null;
    }

    if (!snapshot.exists || snapshot.value == null) {
      print("Lỗi: Không tìm thấy thông tin cửa hàng hoặc thông tin ngân hàng trong Firebase.");
      return null;
    }

    final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

    final String bankName = data['tenNganHang'] ?? '';
    final String accountNumber = data['soTaiKhoan'] ?? '';
    final String accountName = data['chuTaiKhoan'] ?? '';
    // Lấy bankId từ Firebase trước, nếu không có thì dùng map tĩnh
    final String bankId = data['bankId'] ?? _bankNameToIdMap[bankName] ?? '';


    // Kiểm tra các thông tin cần thiết sau khi lấy từ Firebase
    if (bankId.isEmpty || accountNumber.isEmpty || accountName.isEmpty) {
      print("Lỗi: Thông tin ngân hàng không đầy đủ để tạo QR (Bank ID, Số TK, Tên CTK). Vui lòng kiểm tra lại thông tin cửa hàng.");
      return null;
    }

    final Map<String, dynamic> requestBody = {
      "accountNo": accountNumber,
      "accountName": accountName,
      "acqId": bankId,
      // Đã bỏ trường "addInfo" (nội dung chuyển khoản) theo yêu cầu
      "amount": amount ?? 0, // Sử dụng 0 nếu số tiền không được cung cấp
      "template": "compact2" // Mẫu QR code
    };

    try {
      final response = await http.post(
        Uri.parse(_vietQrApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData['code'] == '00' && responseData['data'] != null) {
          final String qrDataURL = responseData['data']['qrDataURL'];
          final String base64Image = qrDataURL.split(',').last;
          return base64Decode(base64Image); // Trả về dữ liệu ảnh QR
        } else {
          print("Lỗi API VietQR: ${responseData['message'] ?? 'Không rõ lỗi'}");
          return null;
        }
      } else {
        print("Lỗi kết nối API VietQR: Status Code ${response.statusCode}");
        print("Response body: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Lỗi mạng hoặc không thể tạo QR: $e");
      return null;
    }
  }
}
