import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/image_service.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String newText = newValue.text.toUpperCase();
    newText = removeDiacritics(newText);
    return TextEditingValue(
      text: newText,
      selection: newValue.selection,
    );
  }

  String removeDiacritics(String str) {
    var withVowels = str
        .replaceAllMapped(RegExp(r'[áàạảãăằặẳẵâầậẩẫ]'), (match) => 'a')
        .replaceAllMapped(RegExp(r'[ÁÀẠẢÃĂẰẶẲẴÂẦẬẨẪ]'), (match) => 'A')
        .replaceAllMapped(RegExp(r'[éèẹẻẽêềệểễ]'), (match) => 'e')
        .replaceAllMapped(RegExp(r'[ÉÈẸẺẼÊỀỆỂỄ]'), (match) => 'E')
        .replaceAllMapped(RegExp(r'[óòọỏõôồộổỗơờợởỡ]'), (match) => 'o')
        .replaceAllMapped(RegExp(r'[ÓÒỌỎÕÔỒỘỔỖƠỜỢỠ]'), (match) => 'O')
        .replaceAllMapped(RegExp(r'[íìịỉĩ]'), (match) => 'i')
        .replaceAllMapped(RegExp(r'[ÍÌỊỈĨ]'), (match) => 'I')
        .replaceAllMapped(RegExp(r'[úùụủũưừựửữ]'), (match) => 'u')
        .replaceAllMapped(RegExp(r'[ÚÙỤỦŨƯỪỰỦỮ]'), (match) => 'U')
        .replaceAllMapped(RegExp(r'[ýỳỵỷỹ]'), (match) => 'y')
        .replaceAllMapped(RegExp(r'[ÝỲỴỶỸ]'), (match) => 'Y')
        .replaceAllMapped(RegExp(r'[đ]'), (match) => 'd')
        .replaceAllMapped(RegExp(r'[Đ]'), (match) => 'D');
    return withVowels;
  }
}

class ThongTinCuaHangScreen extends StatefulWidget {
  const ThongTinCuaHangScreen({super.key});

  @override
  State<ThongTinCuaHangScreen> createState() => _ThongTinCuaHangScreenState();
}

class _ThongTinCuaHangScreenState extends State<ThongTinCuaHangScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final db = FirebaseDatabase.instance;

  final _controllers = {
    'tenCuaHang': TextEditingController(),
    'diaChi': TextEditingController(),
    'soDienThoai': TextEditingController(),
    'email': TextEditingController(),
    'maSoThue': TextEditingController(),
    'website': TextEditingController(),
    'tenNganHang': TextEditingController(),
    'soTaiKhoan': TextEditingController(),
    'chuTaiKhoan': TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    if (uid != null) {
      db.ref("nguoidung/$uid/thongtincuahang").keepSynced(true);
    }
    _loadData();
  }

  void _loadData() async {
    if (uid == null) return;

    final snapshot = await db.ref('nguoidung/$uid/thongtincuahang').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      _controllers.forEach((key, controller) {
        controller.text = data[key] ?? '';
      });
    }
  }

  void _saveAll() {
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể lưu: Người dùng chưa đăng nhập.')),
      );
      return;
    }

    final dataToSave = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };

    db
        .ref('nguoidung/$uid/thongtincuahang')
        .update(dataToSave)
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu thông tin cửa hàng!')),
          );
        })
        .catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lưu thông tin: $error')),
          );
        });
  }

  Widget _buildInputField({
    required String label,
    required String key,
    String? hint,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color.fromARGB(255, 212, 222, 229)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade100.withOpacity(0.3),
                blurRadius: 5,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _controllers[key],
            textCapitalization: capitalization,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: (_) => _saveAll(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontStyle: FontStyle.italic),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  final List<String> nganHangPhoBien = [
    'MB Bank',
    'VietinBank',
    'Vietcombank',
    'PVcomBank',
    'Techcombank',
    'Agribank',
    'Sacombank',
    'ACB',
  ];

  Widget _buildPopularBankChip(String name) {
    final isSelected = _controllers['tenNganHang']?.text == name;
    return GestureDetector(
      onTap: () {
        _controllers['tenNganHang']?.text = name;
        _saveAll();
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromARGB(255, 30, 154, 255)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromARGB(255, 30, 154, 255)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.blue.shade300.withOpacity(0.6),
                    blurRadius: 8,
                    offset: const Offset(2, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(1, 2),
                  ),
                ],
        ),
        child: Text(
          name,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.blue.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Card(
      elevation: 5,
      shadowColor: Colors.blue.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }

  Widget _buildSectionTitleWithIcon(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color.fromARGB(255, 30, 154, 255), size: 28),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 30, 154, 255))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin cửa hàng',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitleWithIcon(Icons.store, 'Thông tin cửa hàng'),
                  const SizedBox(height: 16),
                  _buildInputField(
                      label: 'Tên cửa hàng',
                      key: 'tenCuaHang',
                      hint: 'Ví dụ: Cửa hàng TeckStore'),
                  _buildInputField(
                      label: 'Địa chỉ',
                      key: 'diaChi',
                      hint: 'Ví dụ: Thanh Xuân, Hà Nội'),
                  _buildInputField(
                      label: 'Số điện thoại',
                      key: 'soDienThoai',
                      keyboardType: TextInputType.phone,
                      hint: 'Ví dụ: 0378048xxx'),
                  _buildInputField(
                      label: 'Email',
                      key: 'email',
                      keyboardType: TextInputType.emailAddress,
                      hint: 'Ví dụ: abc@gmail.com'),
                  _buildInputField(
                      label: 'Mã số thuế',
                      key: 'maSoThue',
                      hint: 'Ví dụ: 0312345678'),
                  _buildInputField(
                      label: 'Website',
                      key: 'website',
                      hint: 'Ví dụ: www.example.com'),
                ],
              ),
            ),
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitleWithIcon(
                      Icons.account_balance, 'Thông tin ngân hàng'),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn ngân hàng phổ biến',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children:
                        nganHangPhoBien.map(_buildPopularBankChip).toList(),
                  ),
                  const SizedBox(height: 24),
                  _buildInputField(
                      label: 'Tên ngân hàng',
                      key: 'tenNganHang',
                      hint: 'Ví dụ: ACB'),
                  _buildInputField(
                      label: 'Số tài khoản',
                      key: 'soTaiKhoan',
                      keyboardType: TextInputType.number,
                      hint: 'Ví dụ: 1234567890123'),
                  _buildInputField(
                      label: 'Chủ tài khoản (Viết hoa không dấu)',
                      key: 'chuTaiKhoan',
                      capitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      hint: 'Ví dụ: NGUYEN VAN A'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaoQRScreen extends StatefulWidget {
  const TaoQRScreen({super.key});

  @override
  _TaoQRScreenState createState() => _TaoQRScreenState();
}

class _TaoQRScreenState extends State<TaoQRScreen> {
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  Uint8List? _qrImageBytes;
  bool _isLoadingQR = false;
  bool _isSavingImage = false;

  // Ánh xạ tên ngân hàng sang acqId (mã ngân hàng)
  static const Map<String, String> _bankNameToIdMap = {
    'MB Bank': '970422',
    'VietinBank': '970415',
    'Vietcombank': '970436',
    'PVcomBank': '970412',
    'Techcombank': '970407',
    'Agribank': '970405',
    'Sacombank': '970403',
    'ACB': '970416',
    'TPBank': '970423',
    'BIDV': '970418',
    'VPBank': '970432',
    'Eximbank': '970431',
    'MSB': '970426',
    'Nam A Bank': '970428',
    'OCB': '970448',
    'SeABank': '970440',
    'LPBank': '970449',
    'VietABank': '970427',
    'BaoViet Bank': '970438',
    'An Binh Bank': '970425',
    'SCB': '970429',
    'DongA Bank': '970406',
    'PG Bank': '970430',
    'VIB': '970441',
    'NCB': '970419',
    'SHB': '970443',
  };

  @override
  void initState() {
    super.initState();
    _loadBankInfoFromFirebase();
  }

  Future<void> _loadBankInfoFromFirebase() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
      } catch (e) {
        debugPrint("Lỗi đăng nhập ẩn danh: $e");
        return;
      }
    }

    if (user != null) {
      DatabaseReference ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/thongtincuahang');
      try {
        DataSnapshot snapshot = await ref.get();
        if (snapshot.exists && snapshot.value != null) {
          Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _bankNameController.text = data['tenNganHang'] ?? '';
            _accountNumberController.text = data['soTaiKhoan'] ?? '';
            _accountNameController.text = data['chuTaiKhoan'] ?? '';
          });
        }
      } catch (e) {
        debugPrint("Lỗi đọc dữ liệu từ Firebase: $e");
      }
    }
  }

  Future<void> _generateQrCode() async {
    setState(() {
      _isLoadingQR = true;
      _qrImageBytes = null;
    });

    final String bankName = _bankNameController.text.trim();
    final String accountNumber = _accountNumberController.text.trim();
    final String accountName = UpperCaseTextFormatter().formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(text: _accountNameController.text),
    ).text;
    double amount = double.tryParse(_amountController.text) ?? 0;

    if (accountNumber.isEmpty || accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền số tài khoản và tên chủ tài khoản.')),
      );
      setState(() {
        _isLoadingQR = false;
      });
      return;
    }

    // Kiểm tra xem tên ngân hàng có trong danh sách ánh xạ không
    String? acqId;
    String normalizedBankName = bankName.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    for (var entry in _bankNameToIdMap.entries) {
      if (entry.key.toLowerCase().replaceAll(RegExp(r'\s+'), '') == normalizedBankName) {
        acqId = entry.value;
        break;
      }
    }

    if (acqId == null && bankName.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ngân hàng "$bankName" không được hỗ trợ. Vui lòng chọn một ngân hàng từ danh sách: ${nganHangPhoBien.join(", ")}'),
        ),
      );
      setState(() {
        _isLoadingQR = false;
      });
      return;
    }

    final String apiUrl = 'https://api.vietqr.io/v2/generate';
    final Map<String, dynamic> requestBody = {
      "accountNo": accountNumber,
      "accountName": accountName,
      if (acqId != null) "acqId": acqId,
      if (amount > 0) "amount": amount,
      "template": "compact2"
    };

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['code'] == '00' && data['data'] != null) {
          final String qrDataURL = data['data']['qrDataURL'];
          final String base64Image = qrDataURL.split(',').last;
          setState(() {
            _qrImageBytes = base64Decode(base64Image);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi tạo QR: ${data['desc'] ?? 'Không rõ lỗi'}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối API VietQR: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi mạng hoặc không thể tạo QR: $e')),
      );
    } finally {
      setState(() {
        _isLoadingQR = false;
      });
    }
  }

  Future<void> _saveQrImage() async {
    if (_qrImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ảnh QR để lưu.')),
      );
      return;
    }

    setState(() {
      _isSavingImage = true;
    });

    try {
      final Map<String, dynamic> result = await ImageService.saveImageToGallery(_qrImageBytes!);
      final bool success = result['isSuccess'] ?? false;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu ảnh QR vào thư viện!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lỗi'),
            content: const Text('Không thể lưu ảnh vào thư viện. Vui lòng kiểm tra quyền truy cập hoặc dung lượng lưu trữ.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lỗi'),
          content: Text('Lỗi trong quá trình lưu ảnh: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isSavingImage = false;
      });
    }
  }

  final List<String> nganHangPhoBien = [
    'MB Bank',
    'VietinBank',
    'Vietcombank',
    'PVcomBank',
    'Techcombank',
    'Agribank',
    'Sacombank',
    'ACB',
  ];

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0),
    );

    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: const Color.fromARGB(255, 30, 154, 255), width: 2.0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tạo QR',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        elevation: 4.0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Thông tin ngân hàng:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Chọn ngân hàng phổ biến:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: nganHangPhoBien.map((name) {
                return GestureDetector(
                  onTap: () {
                    _bankNameController.text = name;
                    setState(() {});
                  },
                  child: Chip(
                    label: Text(name),
                    backgroundColor: _bankNameController.text == name
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bankNameController,
              decoration: InputDecoration(
                labelText: 'Tên ngân hàng',
                hintText: 'Ví dụ: MB Bank',
                border: defaultInputBorder,
                enabledBorder: defaultInputBorder,
                focusedBorder: focusedInputBorder,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accountNumberController,
              decoration: InputDecoration(
                labelText: 'Số tài khoản',
                border: defaultInputBorder,
                enabledBorder: defaultInputBorder,
                focusedBorder: focusedInputBorder,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _accountNameController,
              decoration: InputDecoration(
                labelText: 'Tên chủ tài khoản',
                border: defaultInputBorder,
                enabledBorder: defaultInputBorder,
                focusedBorder: focusedInputBorder,
              ),
              inputFormatters: [UpperCaseTextFormatter()],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Số tiền (không bắt buộc)',
                border: defaultInputBorder,
                enabledBorder: defaultInputBorder,
                focusedBorder: focusedInputBorder,
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoadingQR ? null : _generateQrCode,
              icon: _isLoadingQR
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.qr_code),
              label: Text(_isLoadingQR ? 'Đang tạo QR...' : 'Tạo QR'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 30, 154, 255),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _qrImageBytes == null || _isSavingImage
                  ? null
                  : _saveQrImage,
              icon: _isSavingImage
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSavingImage
                    ? 'Đang lưu...'
                    : (_qrImageBytes == null ? 'Chưa có ảnh QR' : 'Lưu ảnh QR'),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: _qrImageBytes == null || _isSavingImage
                    ? Colors.grey
                    : const Color.fromARGB(255, 30, 154, 255),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8.0),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: const Color.fromARGB(255, 30, 154, 255),
                  width: 2.0,
                ),
              ),
              height: MediaQuery.of(context).size.width * 0.7,
              width: MediaQuery.of(context).size.width * 0.7,
              child: _qrImageBytes != null
                  ? Image.memory(
                      _qrImageBytes!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('Không thể hiển thị ảnh QR.'));
                      },
                    )
                  : Center(
                      child: Text(
                        'Mã QR sẽ hiển thị ở đây',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}