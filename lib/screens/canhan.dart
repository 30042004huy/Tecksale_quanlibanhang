import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class CaNhanScreen extends StatefulWidget {
  const CaNhanScreen({super.key});

  @override
  State<CaNhanScreen> createState() => _CaNhanScreenState();
}

class _CaNhanScreenState extends State<CaNhanScreen> {
  final _hotenController = TextEditingController();
  final _sdtController = TextEditingController();
  final _diachiController = TextEditingController();
  String? _email;
  String? _uid;
  bool _loading = true;
  Timer? _debounce;

  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadOfflineData();
    _loadUserData();
  }

  Future<void> _loadOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hotenController.text = prefs.getString('hoten') ?? '';
      _sdtController.text = prefs.getString('sdt') ?? '';
      _diachiController.text = prefs.getString('diachi') ?? '';
      _loading = false;
    });
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _uid = user.uid;
      _email = user.email;
    });

    final snapshot = await _database.child('nguoidung/$_uid/canhan').get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      _hotenController.text = data['hoten'] ?? '';
      _sdtController.text = data['sdt'] ?? '';
      _diachiController.text = data['diachi'] ?? '';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hoten', _hotenController.text);
      await prefs.setString('sdt', _sdtController.text);
      await prefs.setString('diachi', _diachiController.text);
    }
  }

  Future<void> _saveUserData(String field, String value) async {
    if (_uid == null || !mounted) return;
    try {
      await _database.child('nguoidung/$_uid/canhan').update({field: value.trim()});
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(field, value.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã cập nhật $field', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white)),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật $field: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _debounceSave(String field, String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      if (field == 'sdt' && value.length < 10) return;
      if (value.isNotEmpty) _saveUserData(field, value);
    });
  }

  void _copyToClipboard(String text, String label) {
    if (!mounted) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label vào bộ nhớ tạm', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<bool> _reauthenticate(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;
      final credential = EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showMessageDialog({
    required String title,
    required String message,
    required Color titleColor,
    bool autoClose = true,
  }) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor)),
        content: Text(message, style: GoogleFonts.inter(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: GoogleFonts.inter(color: const Color(0xFF3B82F6))),
          ),
        ],
      ),
    );
    if (autoClose) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  Future<void> _showLoadingDialog() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6))),
            SizedBox(height: 16),
            Text('Đang xử lý...', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xác nhận Quên Mật Khẩu',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Bạn có chắc chắn muốn gửi email đặt lại mật khẩu đến $_email không?',
            style: GoogleFonts.inter(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Xác nhận', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_email == null) return;

    await _showLoadingDialog();

    try {
      await _auth.sendPasswordResetEmail(email: _email!);
      if (mounted) Navigator.pop(context); // Close loading
      _showMessageDialog(
        title: 'Thành công',
        message: 'Email đặt lại mật khẩu đã được gửi đến $_email',
        titleColor: Colors.green.shade700,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      _showMessageDialog(
        title: 'Lỗi',
        message: 'Lỗi khi gửi email đặt lại mật khẩu: $e',
        titleColor: Colors.red.shade700,
      );
    }
  }

  Future<void> _startChangePassword() async {
    final currentPasswordController = TextEditingController();
    bool obscureCurrent = true;

    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Xác thực Mật khẩu Hiện tại',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
          content: TextField(
            controller: currentPasswordController,
            decoration: _inputDecoration('Nhập mật khẩu hiện tại').copyWith(
              suffixIcon: IconButton(
                icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
              ),
            ),
            obscureText: obscureCurrent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text.trim();
                if (currentPassword.isEmpty) {
                  Navigator.pop(dialogContext, false);
                  return;
                }

                await _showLoadingDialog();

                final success = await _reauthenticate(currentPassword);

                if (mounted) Navigator.pop(context); // Close loading

                Navigator.pop(dialogContext, success);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Tiếp tục', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _showNewPasswordDialog();
    } else if (result == false) {
      _showMessageDialog(
        title: 'Lỗi',
        message: 'Mật khẩu hiện tại không đúng',
        titleColor: Colors.red.shade700,
      );
    }
    // If null, cancel, do nothing
  }

  Future<void> _showNewPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool minLengthMet = false;
    bool passwordsMatch = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Đặt Mật khẩu Mới',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yêu cầu: Mật khẩu tối thiểu 6 ký tự',
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                onChanged: (value) {
                  minLengthMet = value.trim().length >= 6;
                  passwordsMatch = value.trim() == confirmPasswordController.text.trim();
                  setDialogState(() {});
                },
                decoration: _inputDecoration('Nhập mật khẩu mới').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
                obscureText: obscureNew,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                onChanged: (value) {
                  passwordsMatch = value.trim() == newPasswordController.text.trim();
                  setDialogState(() {});
                },
                decoration: _inputDecoration('Nhập lại mật khẩu mới').copyWith(
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      if (passwordsMatch && minLengthMet)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                ),
                obscureText: obscureConfirm,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Hủy', style: GoogleFonts.inter(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: (minLengthMet && passwordsMatch)
                  ? () async {
                      final newPassword = newPasswordController.text.trim();

                      await _showLoadingDialog();

                      try {
                        await _auth.currentUser!.updatePassword(newPassword);
                        if (mounted) Navigator.pop(context); // Close loading
                        Navigator.pop(dialogContext); // Close dialog
                        _showMessageDialog(
                          title: 'Thành công',
                          message: 'Đổi mật khẩu thành công',
                          titleColor: Colors.green.shade700,
                        );
                      } catch (e) {
                        if (mounted) Navigator.pop(context); // Close loading
                        Navigator.pop(dialogContext); // Close dialog
                        _showMessageDialog(
                          title: 'Lỗi',
                          message: 'Lỗi khi đổi mật khẩu: $e',
                          titleColor: Colors.red.shade700,
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Xác nhận', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey.shade500, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
        filled: true,
        fillColor: Colors.grey.shade50,
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String fieldName,
    TextInputType? keyboardType,
  }) =>
      _buildLabeledField(
        label: label,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          inputFormatters: fieldName == 'sdt' ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)] : null,
          decoration: _inputDecoration(hint).copyWith(
            suffixIcon: Icon(
              Icons.check_circle_outline,
              color: controller.text.isNotEmpty && (fieldName != 'sdt' || controller.text.length >= 10) ? Colors.green.shade600 : Colors.grey.shade400,
              size: 18,
            ),
          ),
          style: GoogleFonts.inter(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w400),
          onChanged: (value) => _debounceSave(fieldName, value),
        ),
      );

  Widget _buildLabeledField({
    required String label,
    required Widget child,
    EdgeInsetsGeometry? margin,
  }) =>
      Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      );

  Widget _buildInfoDisplay({
    required IconData icon,
    required String label,
    required String value,
    Widget? actionButton,
    List<Widget>? actionButtonsBelow,
  }) =>
      _buildLabeledField(
        label: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.blueGrey.shade700, size: 22),
                  const SizedBox(width: 12),
                  Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w400))),
                  if (actionButton != null) ...[const SizedBox(width: 8), actionButton],
                ],
              ),
            ),
            if (actionButtonsBelow != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: actionButtonsBelow,
              ),
            ],
          ],
        ),
      );

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Thông Tin Cá Nhân',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF3B82F6), Colors.blue.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Thông tin Người dùng'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTextField(controller: _hotenController, label: 'Họ và Tên', hint: 'Nhập họ và tên', fieldName: 'hoten'),
                          _buildTextField(
                              controller: _sdtController, label: 'Số Điện Thoại', hint: 'Nhập số điện thoại', fieldName: 'sdt', keyboardType: TextInputType.phone),
                          _buildTextField(controller: _diachiController, label: 'Địa Chỉ', hint: 'Nhập địa chỉ', fieldName: 'diachi'),
                        ],
                      ),
                    ),
                  ),
                  _buildSectionTitle('Thông tin Tài khoản'),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoDisplay(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: _email ?? 'Chưa có email',
                            actionButton: IconButton(
                              onPressed: () => _copyToClipboard(_email ?? '', 'Email'),
                              icon: const Icon(Icons.content_copy, color: Color(0xFF3B82F6), size: 18),
                              tooltip: 'Sao chép Email',
                            ),
                          ),
                          _buildInfoDisplay(
                            icon: Icons.perm_identity_outlined,
                            label: 'UID',
                            value: _uid ?? 'Chưa có UID',
                            actionButton: IconButton(
                              onPressed: () => _copyToClipboard(_uid ?? '', 'UID'),
                              icon: const Icon(Icons.content_copy, color: Color(0xFF3B82F6), size: 18),
                              tooltip: 'Sao chép UID',
                            ),
                          ),
                          _buildInfoDisplay(
                            icon: Icons.lock_outline,
                            label: 'Mật Khẩu',
                            value: '••••••••',
                            actionButtonsBelow: [
                              ElevatedButton.icon(
                                onPressed: _startChangePassword,
                                icon: const Icon(Icons.edit, size: 16, color: Colors.white),
                                label: Text('Đổi mật khẩu', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  elevation: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _forgotPassword,
                                icon: const Icon(Icons.help, size: 16, color: Colors.white),
                                label: Text('Quên mật khẩu', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  elevation: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}