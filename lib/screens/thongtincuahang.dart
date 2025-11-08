import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class ThongTinCuaHangScreen extends StatefulWidget {
  const ThongTinCuaHangScreen({super.key});

  @override
  State<ThongTinCuaHangScreen> createState() => _ThongTinCuaHangScreenState();
}

class _ThongTinCuaHangScreenState extends State<ThongTinCuaHangScreen> {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final db = FirebaseDatabase.instance;
  Timer? _debounce;
  final Map<String, String?> _fieldErrors = {}; // ✨ Biến để lưu trạng thái lỗi

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
    _loadData();
    _controllers.forEach((key, controller) {
      controller.addListener(_onFieldChanged);
    });
  }
  
  @override
  void dispose() {
    _debounce?.cancel();
    _controllers.forEach((key, controller) {
      controller.removeListener(_onFieldChanged);
      controller.dispose();
    });
    super.dispose();
  }

  void _loadData() async {
    if (uid == null) return;
    final snapshot = await db.ref('nguoidung/$uid/thongtincuahang').get();
    if (snapshot.exists && mounted) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      _controllers.forEach((key, controller) {
        controller.text = data[key] ?? '';
      });
      _validatePaymentFields(); // Kiểm tra lỗi ngay khi tải dữ liệu
    }
  }

  void _onFieldChanged() {
    _validatePaymentFields(); // Kiểm tra lỗi mỗi khi có thay đổi
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveAll();
    });
  }

  // ✨ HÀM LƯU ĐÃ ĐƯỢC BỎ THÔNG BÁO SNACKBAR
  void _saveAll() {
    if (uid == null || !mounted) return;

    final dataToSave = {
      for (final entry in _controllers.entries) entry.key: entry.value.text.trim(),
    };

    db.ref('nguoidung/$uid/thongtincuahang').update(dataToSave);
  }
  
  // ✨ HÀM MỚI: Kiểm tra các trường thông tin thanh toán
  void _validatePaymentFields() {
    final bankName = _controllers['tenNganHang']!.text.trim();
    final accountNumber = _controllers['soTaiKhoan']!.text.trim();
    final accountHolder = _controllers['chuTaiKhoan']!.text.trim();

    // Kiểm tra xem có bất kỳ trường thanh toán nào đã được điền chưa
    final isAnyPaymentFieldFilled = bankName.isNotEmpty || accountNumber.isNotEmpty || accountHolder.isNotEmpty;
    
    setState(() {
      if (isAnyPaymentFieldFilled) {
        // Nếu có 1 trường được điền, tất cả các trường còn lại là bắt buộc
        _fieldErrors['tenNganHang'] = bankName.isEmpty ? 'Vui lòng không để trống' : null;
        _fieldErrors['soTaiKhoan'] = accountNumber.isEmpty ? 'Vui lòng không để trống' : null;
        _fieldErrors['chuTaiKhoan'] = accountHolder.isEmpty ? 'Vui lòng không để trống' : null;
      } else {
        // Nếu tất cả đều trống, xóa mọi lỗi
        _fieldErrors['tenNganHang'] = null;
        _fieldErrors['soTaiKhoan'] = null;
        _fieldErrors['chuTaiKhoan'] = null;
      }
    });
  }

  // ✨ WIDGET ĐÃ ĐƯỢC CẬP NHẬT ĐỂ HIỂN THỊ LỖI
  Widget _buildInputField({
    required String label,
    required String key,
    required IconData icon,
    String? hint,
    TextCapitalization capitalization = TextCapitalization.words,
    TextInputType? keyboardType,
  }) {
    final errorText = _fieldErrors[key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _controllers[key],
        textCapitalization: capitalization,
        keyboardType: keyboardType,
        style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.roboto(color: errorText != null ? Colors.red : Colors.grey.shade700),
          hintText: hint,
          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorText: errorText, // Hiển thị lỗi
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: errorText != null ? Colors.red.shade400 : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: errorText != null ? Colors.red : Colors.blue.shade700, width: 2),
          ),
        ),
      ),
    );
  }

  final List<String> nganHangPhoBien = [
    'MB Bank', 'VietinBank', 'Vietcombank', 'Techcombank', 'Agribank', 'BIDV', 'Sacombank'
  ];
  
  Widget _buildPopularBankChip(String name) {
    final isSelected = _controllers['tenNganHang']?.text == name;
    return GestureDetector(
      onTap: () {
        setState(() {
          _controllers['tenNganHang']?.text = name;
        });
        // Listener trên controller sẽ tự động gọi _onFieldChanged
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300
          ),
        ),
        child: Text(
          name,
          style: GoogleFonts.roboto(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.quicksand(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Thông tin cửa hàng', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.1),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Thông tin chung'),
              _buildInputField(label: 'Tên cửa hàng', key: 'tenCuaHang', icon: Icons.store_outlined, hint: 'TeckSale'),
              _buildInputField(label: 'Địa chỉ', key: 'diaChi', icon: Icons.location_on_outlined, hint: 'Thanh Xuân, Hà Nội'),
              _buildInputField(label: 'Số điện thoại', key: 'soDienThoai', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
              _buildInputField(label: 'Email', key: 'email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              _buildInputField(label: 'Mã số thuế', key: 'maSoThue', icon: Icons.policy_outlined),
              _buildInputField(label: 'Website', key: 'website', icon: Icons.language_outlined),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Thông tin thanh toán'),
               Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Ngân hàng phổ biến',
                  style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade800),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: nganHangPhoBien.map(_buildPopularBankChip).toList(),
              ),
              const SizedBox(height: 24),
              _buildInputField(label: 'Tên ngân hàng', key: 'tenNganHang', icon: Icons.account_balance_outlined),
              _buildInputField(label: 'Số tài khoản', key: 'soTaiKhoan', icon: Icons.pin_outlined, keyboardType: TextInputType.number),
              _buildInputField(
                label: 'Chủ tài khoản (Viết hoa, không dấu)', 
                key: 'chuTaiKhoan', 
                icon: Icons.person_outlined,
                capitalization: TextCapitalization.characters,
              ),
            ],
          ),
        ),
      ),
    );
  }
}