/// Lớp đại diện cho thông tin ngân hàng của cửa hàng.
/// Bao gồm tên ngân hàng, số tài khoản, tên chủ tài khoản và Bank ID.
class BankInfo {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String bankId; // Mã Bank ID cho VietQR

  BankInfo({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.bankId,
  });

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

  /// Phương thức factory để tạo đối tượng BankInfo từ Map.
  /// Khi lấy dữ liệu từ Firebase, nó sẽ trích xuất các trường và tự động xác định bankId.
  factory BankInfo.fromMap(Map<dynamic, dynamic> map) {
    final String fetchedBankName = map['tenNganHang'] ?? '';
    final String fetchedBankId = map['bankId'] ?? _bankNameToIdMap[fetchedBankName] ?? '';

    return BankInfo(
      bankName: fetchedBankName,
      accountNumber: map['soTaiKhoan'] ?? '',
      accountName: map['chuTaiKhoan'] ?? '',
      bankId: fetchedBankId, // Sử dụng bankId đã lấy hoặc ánh xạ
    );
  }

  /// Phương thức để chuyển đổi đối tượng BankInfo thành Map.
  /// Hữu ích để lưu trữ dữ liệu ngân hàng lên Firebase.
  Map<String, dynamic> toMap() {
    return {
      'tenNganHang': bankName,
      'soTaiKhoan': accountNumber,
      'chuTaiKhoan': accountName,
      'bankId': bankId, // Lưu cả bankId để tránh tính toán lại
    };
  }
}
