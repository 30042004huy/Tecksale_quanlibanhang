import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:developer';
import 'login_history_screen.dart';

class CaNhanScreen extends StatefulWidget {
  const CaNhanScreen({super.key});

  @override
  State<CaNhanScreen> createState() => _CaNhanScreenState();
}

class _CaNhanScreenState extends State<CaNhanScreen> {
  // Controllers
  final _hotenController = TextEditingController();
  final _sdtController = TextEditingController();
  final _diachiController = TextEditingController();

  // User Data
  String? _email;
  String? _uid;
  bool _loading = true;
  bool _isPhoneNumberVerified = false;
  String _currentPhoneNumber = '';

  // Firebase & Utils
  final _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  Timer? _debounce;
  StreamSubscription<DatabaseEvent>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _hotenController.addListener(() => _onTextChanged('hoten', _hotenController.text));
    _sdtController.addListener(() => _onTextChanged('sdt', _sdtController.text));
    _diachiController.addListener(() => _onTextChanged('diachi', _diachiController.text));
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _debounce?.cancel();
    _hotenController.dispose();
    _sdtController.dispose();
    _diachiController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _uid = user.uid;
    _email = user.email;
    _checkVerificationStatus(user);

    _userSubscription = _database.child('nguoidung/$_uid/canhan').onValue.listen(
      (event) {
        if (!mounted) return;
        if (event.snapshot.exists) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _updateTextController(_hotenController, data['hoten']);
          _updateTextController(_sdtController, data['sdt']);
          _updateTextController(_diachiController, data['diachi']);
          
          if (_currentPhoneNumber != (data['sdt'] ?? '')) {
            _currentPhoneNumber = data['sdt'] ?? '';
            _checkVerificationStatus(user);
          }
        }
        if (_loading) setState(() => _loading = false);
      },
      onError: (error) {
        if (mounted) setState(() => _loading = false);
        _showErrorSnackBar("Không thể tải dữ liệu: ${error.toString()}");
      },
    );
  }

  void _checkVerificationStatus(User? user) {
    if (user == null) return;
    // user.phoneNumber chứa số đã xác thực với Firebase Auth
    // _currentPhoneNumber là số lưu trong Realtime Database
    final verifiedPhoneNumber = user.phoneNumber;
    final isVerified = verifiedPhoneNumber != null &&
                       verifiedPhoneNumber.isNotEmpty &&
                       _currentPhoneNumber.contains(verifiedPhoneNumber.substring(3)); // So sánh phần số (bỏ +84)

    if (mounted && _isPhoneNumberVerified != isVerified) {
      setState(() {
        _isPhoneNumberVerified = isVerified;
      });
    }
  }

  // --- Logic xác thực số điện thoại ---

  Future<void> _startPhoneVerification() async {
    final phoneNumber = _sdtController.text.trim();
    if (phoneNumber.length < 9) {
      _showErrorSnackBar("Số điện thoại không hợp lệ");
      return;
    }

    // Luôn thêm +84 vào đầu nếu chưa có
    final fullPhoneNumber = phoneNumber.startsWith('+84') ? phoneNumber : '+84${phoneNumber.substring(1)}';
    
    _showLoadingDialog();

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Tự động xác thực (hiếm khi xảy ra trên máy thật)
        await _auth.currentUser?.linkWithCredential(credential);
        if (mounted) {
          Navigator.pop(context); // Đóng loading
          _showSuccessSnackBar("Xác thực thành công!");
          setState(() => _isPhoneNumberVerified = true);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) Navigator.pop(context); // Đóng loading
        _showErrorSnackBar("Xác thực thất bại: ${e.message}");
        log("Lỗi Firebase Auth: ${e.code}");
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          Navigator.pop(context); // Đóng loading
          _showOtpDialog(verificationId);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _showOtpDialog(String verificationId) async {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nhập mã OTP', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Mã xác thực đã được gửi đến số điện thoại của bạn.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration("Nhập 6 chữ số OTP"),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              final credential = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: otpController.text.trim(),
              );
              try {
                await _auth.currentUser?.linkWithCredential(credential);
                if(mounted) {
                   Navigator.pop(context); // Đóng dialog OTP
                  _showSuccessSnackBar("Xác thực thành công!");
                   setState(() => _isPhoneNumberVerified = true);
                }
              } catch (e) {
                 _showErrorSnackBar("Mã OTP không đúng hoặc đã hết hạn.");
              }
            },
            child: Text('Xác nhận', style: GoogleFonts.roboto(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700)
          ),
        ],
      ),
    );
  }


  // --- Các hàm và widget khác (giữ nguyên từ trước) ---
  // ... (Dán toàn bộ các hàm _updateTextController, _onTextChanged, _saveUserData, _copyToClipboard,
  //      _reauthenticate, _showMessageDialog, _showLoadingDialog, _forgotPassword,
  //      _startChangePassword, _showNewPasswordDialog, _inputDecoration, v.v... vào đây)

  void _updateTextController(TextEditingController controller, String? newText) {
    if (newText != null && controller.text != newText) {
      final currentSelection = controller.selection;
      controller.text = newText;
      try {
         controller.selection = currentSelection;
      } catch (e) {
        // Bỏ qua lỗi
      }
    }
  }

  void _onTextChanged(String field, String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _saveUserData(field, value);
    });
  }

  Future<void> _saveUserData(String field, String value) async {
    if (_uid == null || !mounted) return;
    try {
      await _database.child('nguoidung/$_uid/canhan').update({field: value.trim()});
    } catch (e) {
      _showErrorSnackBar('Lỗi khi cập nhật: $e');
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    _showSuccessSnackBar('Đã sao chép $label');
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      duration: const Duration(seconds: 2),
    ));
  }
  
  void _showErrorSnackBar(String message) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ));
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      );

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shadowColor: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                title,
                style: GoogleFonts.quicksand(fontWeight: FontWeight.w900, fontSize: 18, color: const Color(0xFF3B82F6)),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onCopy,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3B82F6)),
      title: Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
      subtitle: Text(subtitle, style: GoogleFonts.roboto(fontSize: 15, color: Colors.black54)),
      trailing: onCopy != null 
        ? IconButton(icon: const Icon(Icons.copy_outlined, size: 20, color: Colors.grey), onPressed: onCopy)
        : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF3B82F6)),
      title: Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  // ... (Thêm lại các hàm mật khẩu nếu bạn đã xóa chúng)
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
        title: Text(title, style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 18, color: titleColor)),
        content: Text(message, style: GoogleFonts.roboto(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Đóng', style: GoogleFonts.roboto(color: const Color(0xFF3B82F6))),
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
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text('Bạn có chắc chắn muốn gửi email đặt lại mật khẩu đến $_email không?',
            style: GoogleFonts.roboto(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Hủy', style: GoogleFonts.roboto(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Xác nhận', style: GoogleFonts.roboto(color: Colors.white)),
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
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 20)),
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
              child: Text('Hủy', style: GoogleFonts.roboto(color: Colors.grey.shade600)),
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
              child: Text('Tiếp tục', style: GoogleFonts.roboto(color: Colors.white)),
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
              style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Yêu cầu: Mật khẩu tối thiểu 6 ký tự',
                  style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade600)),
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
              child: Text('Hủy', style: GoogleFonts.roboto(color: Colors.grey.shade600)),
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
              child: Text('Xác nhận', style: GoogleFonts.roboto(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Thông Tin Cá Nhân', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22)),
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(
    color: Colors.white, // Thêm dòng này
  ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSectionCard(
                      title: 'Thông tin liên hệ',
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- HỌ VÀ TÊN ---
                              Text("Họ và Tên", style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _hotenController,
                                decoration: _inputDecoration("Nhập họ và tên").copyWith(prefixIcon: const Icon(Icons.person_outline)),
                              ),
                              const SizedBox(height: 16),

                              // --- SỐ ĐIỆN THOẠI VÀ NÚT XÁC THỰC ---
                              Text("Số Điện Thoại", style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _sdtController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: _inputDecoration("Nhập số điện thoại").copyWith(
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: _isPhoneNumberVerified
                                      ? const Icon(Icons.check_circle, color: Colors.green, key: ValueKey('verified'))
                                      : TextButton(
                                          onPressed: _startPhoneVerification,
                                          child: const Text("Xác thực"),
                                          style: TextButton.styleFrom(foregroundColor: Colors.orange.shade800),
                                          key: const ValueKey('verify'),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // --- ĐỊA CHỈ ---
                              Text("Địa chỉ", style: GoogleFonts.roboto(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.grey.shade800)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _diachiController,
                                decoration: _inputDecoration("Nhập địa chỉ").copyWith(prefixIcon: const Icon(Icons.location_on_outlined)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _buildSectionCard(
                      title: 'Tài khoản & Bảo mật',
                      children: [
                        _buildInfoTile(
                          icon: Icons.email_outlined,
                          title: 'Email',
                          subtitle: _email ?? 'Không có',
                          onCopy: () => _copyToClipboard(_email ?? '', 'Email'),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                         _buildInfoTile(
                          icon: Icons.badge_outlined,
                          title: 'User ID',
                          subtitle: _uid ?? 'Không có',
                          onCopy: () => _copyToClipboard(_uid ?? '', 'User ID'),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _buildActionTile(
                          icon: Icons.history_outlined,
                          title: 'Lịch sử đăng nhập',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginHistoryScreen())),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.lock_reset_outlined),
                            label: const Text('Đổi Mật Khẩu'),
                            onPressed: _startChangePassword,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF3B82F6), side: const BorderSide(color: Color(0xFF3B82F6)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.help_outline),
                            label: const Text('Quên Mật Khẩu'),
                            onPressed: _forgotPassword,
                             style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange.shade700, side: BorderSide(color: Colors.orange.shade700),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }
}