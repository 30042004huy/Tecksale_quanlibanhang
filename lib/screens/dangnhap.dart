
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tecksale_quanlybanhang/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trangchu.dart';
import 'hotro.dart';
import '../services/login_history_service.dart'; // ✨ THÊM DÒNG NÀY

class DangNhapScreen extends StatefulWidget {
  @override
  _DangNhapScreenState createState() => _DangNhapScreenState();
}

class _DangNhapScreenState extends State<DangNhapScreen> {
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  final Color primaryColor = const Color.fromARGB(255, 30, 154, 255);

  final TextEditingController _emailUserController = TextEditingController();
  final TextEditingController _emailDomainController = TextEditingController(text: '@gmail.com');
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmailUser = prefs.getString('emailUser');
    final savedRemember = prefs.getBool('rememberMe') ?? false;

    if (savedRemember && savedEmailUser != null) {
      setState(() {
        _rememberMe = true;
        _emailUserController.text = savedEmailUser;
      });
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('emailUser', _emailUserController.text.trim());
        await prefs.setBool('rememberMe', true);
      } else {
        await prefs.remove('emailUser');
        await prefs.setBool('rememberMe', false);
      }
    } catch (e) {
      print("Lỗi khi lưu thông tin đăng nhập: $e");
    }
  }

  Future<void> _dangNhap() async {
    if (_isLoading) return;

    String emailUser = _emailUserController.text.trim();
    String emailDomain = _emailDomainController.text.trim();
    String email = emailUser + emailDomain;
    final password = _passwordController.text.trim();

    if (emailUser.isEmpty || password.isEmpty) {
      await _showErrorDialog('Vui lòng nhập đầy đủ email và mật khẩu.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _authService.signIn(email, password);
      final user = userCredential.user;

      if (user != null) {
        await user.reload();
        final bool? isEnabled = await _authService.isUserEnabled(user.uid);

        if (isEnabled != null && isEnabled == false) {
          await _authService.signOut();
          await _showErrorDialog('Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ hỗ trợ.');
          return;
        }

        await _saveCredentials();
        await LoginHistoryService().recordLogin();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TrangChuScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'Email hoặc mật khẩu không đúng.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Tài khoản của bạn đã bị vô hiệu hóa. Vui lòng liên hệ hỗ trợ.';
      } else {
        errorMessage = 'Đã xảy ra lỗi khi đăng nhập: ${e.message}';
      }
      await _showErrorDialog(errorMessage);
    } catch (e) {
      await _showErrorDialog('Đã xảy ra lỗi không xác định. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 20,
        backgroundColor: Colors.white,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(height: 8),
              const Text(
                'Cảnh báo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: Colors.red),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 100,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    bool isLoading = false;
    bool isSuccess = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 16,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFE3F2FD)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, color: Color(0xFF1976D2), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Đặt lại mật khẩu',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isLoading && !isSuccess)
                  const Text(
                    'Nhập email của bạn để đặt lại mật khẩu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                  ),
                if (!isLoading && !isSuccess) const SizedBox(height: 20),
                if (!isLoading && !isSuccess)
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.email, color: primaryColor),
                    ),
                    style: const TextStyle(color: Colors.black),
                  ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Color(0xFF1976D2)),
                  ),
                if (isSuccess)
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                if (isSuccess)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Email đặt lại mật khẩu đã được gửi!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                    ),
                  ),
                if (isSuccess) const SizedBox(height: 20),
                if (!isLoading && !isSuccess)
                 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontSize: 16, color: Color.fromARGB(255, 66, 66, 66)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập email.')),
                            );
                            return;
                          }
                          setState(() => isLoading = true);
                          try {
                            await _authService.sendPasswordResetEmail(emailController.text.trim());
                            setState(() {
                              isLoading = false;
                              isSuccess = true;
                            });
                            await Future.delayed(const Duration(seconds: 2));
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Gửi email thất bại: ${e.toString()}')),
                            );
                          }
                        },
                        
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        ),
                        child: const Text(
                          'Gửi',
                          style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailUserController.dispose();
    _emailDomainController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(35),
                      child: Image.asset('assets/images/logoapp.png', height: 100, width: 100, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 20),
                    const Text('Đăng nhập', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _emailUserController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email, color: primaryColor),
                              labelStyle: const TextStyle(color: Colors.black),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade400),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  bottomLeft: Radius.circular(12),
                                ),
                              ),
                            ),
                            style: const TextStyle(color: Colors.black),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _emailDomainController,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey.shade400),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                            ),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock, color: primaryColor),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: primaryColor),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: primaryColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: const TextStyle(color: Colors.black),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (value) => setState(() => _rememberMe = value ?? false),
                              activeColor: primaryColor,
                            ),
                            const Text('Lưu thông tin', style: TextStyle(color: Colors.black)),
                          ],
                        ),
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text('Quên mật khẩu?', style: TextStyle(color: primaryColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _dangNhap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 40),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HoTroScreen()),
                      ),
                      icon: Icon(Icons.support_agent, color: primaryColor),
                      label: Text('Hỗ trợ ngay', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      '© Design TeckSale by Huy Lữ',
                      style: TextStyle(
                        fontFamily: 'CanvaSans',
                        fontSize: 14,
                        color: const Color.fromARGB(255, 174, 174, 174),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 5),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}