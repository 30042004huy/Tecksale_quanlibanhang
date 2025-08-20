import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

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

    // 🔒 Luôn đồng bộ dữ liệu nhánh thông tin cửa hàng
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
    if (uid == null) return;

    final dataToSave = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };

    db
        .ref('nguoidung/$uid/thongtincuahang')
        .update(dataToSave); // ✅ dùng update thay vì set
  }

  Widget _buildInputField({
    required String label,
    required String key,
    String? hint,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputType? keyboardType,
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
                      hint: 'Ví dụ: MB Bank'),
                  _buildInputField(
                      label: 'Số tài khoản',
                      key: 'soTaiKhoan',
                      keyboardType: TextInputType.number,
                      hint: 'Ví dụ: 1234567890123'),
                  _buildInputField(
                      label: 'Chủ tài khoản (Viết hoa không dấu)',
                      key: 'chuTaiKhoan',
                      capitalization: TextCapitalization.characters,
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
