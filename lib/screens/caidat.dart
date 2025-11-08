import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
// import 'package:animate_do/animate_do.dart'; // Đã xóa
import 'dangnhap.dart';
import 'canhan.dart';
import 'thongtincuahang.dart';
import 'mauhoadon.dart';
import 'caidatmayin.dart';
import 'nhanvien.dart';
import 'cuahang.dart';
import 'tuychinh_chucnang.dart';

class CaiDatScreen extends StatefulWidget {
  const CaiDatScreen({super.key});

  @override
  State<CaiDatScreen> createState() => _CaiDatScreenState();
}

class _CaiDatScreenState extends State<CaiDatScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String _greetingName = '';
  bool _isLoadingName = true;
  StreamSubscription<DatabaseEvent>? _storeNameSubscription;

  @override
  void initState() {
    super.initState();
    _listenForGreetingName();
  }

  @override
  void dispose() {
    _storeNameSubscription?.cancel();
    super.dispose();
  }

  void _listenForGreetingName() {
    if (_user == null) {
      setState(() {
        _greetingName = 'bạn';
        _isLoadingName = false;
      });
      return;
    }

    _storeNameSubscription?.cancel();

    _storeNameSubscription = FirebaseDatabase.instance
        .ref('nguoidung/${_user!.uid}/thongtincuahang/tenCuaHang')
        .onValue
        .listen((event) {
      if (mounted) {
        final storeName = event.snapshot.value as String?;
        if (storeName != null && storeName.trim().isNotEmpty) {
          setState(() {
            _greetingName = storeName;
          });
        } else {
          setState(() {
            _greetingName = _user!.email ?? 'bạn';
          });
        }
        if (_isLoadingName) {
          setState(() {
            _isLoadingName = false;
          });
        }
      }
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _greetingName = _user!.email ?? 'bạn';
          _isLoadingName = false;
        });
      }
    });
  }

  // ✨ Widget cho một mục cài đặt (Dùng Quicksand)
  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Color? titleColor, // Thêm màu chữ tùy chọn
  }) {
    // Bỏ FadeInUp
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.quicksand( // ✨ Đổi lại font
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Giống bản gốc
                      color: titleColor ?? Colors.black87, // Dùng màu chữ tùy chọn
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✨ Widget cho tiêu đề của một nhóm cài đặt (Dùng Quicksand)
  Widget _buildSectionTitle(String title) {
    // Bỏ FadeInUp
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.quicksand( // ✨ Đổi lại font
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800, // ✨ Giống bản gốc
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Future<void> _dangXuat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xác nhận đăng xuất', style: GoogleFonts.quicksand(fontWeight: FontWeight.w600)),
        content: Text('Bạn có chắc chắn muốn đăng xuất không?', style: GoogleFonts.quicksand()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: GoogleFonts.quicksand(fontWeight: FontWeight.w600))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text('Đăng xuất', style: GoogleFonts.quicksand(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => DangNhapScreen()),
        (route) => false,
      );
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // ✨ Giống bản gốc
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150.0, // ✨ Giống bản gốc
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            iconTheme: const IconThemeData(
              color: Colors.white,
            ),
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade500, Colors.blue.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 16),
                title: Text(
                  'Cài đặt & Quản lý', // ✨ Giống bản gốc
                  style: GoogleFonts.quicksand( // ✨ Đổi lại font
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                // ✨ ÁP DỤNG CHÍNH XÁC ĐOẠN MÃ CỦA BẠN
                background: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, left: 50, right: 24),
                    child: _isLoadingName
                        ? Container( // Hiệu ứng chờ tải
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: 200,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          )
                        // ✨ BỐ CỤC LỜI CHÀO ĐÃ ĐƯỢC CẬP NHẬT
                        : Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Xin chào, ",
                                style: GoogleFonts.quicksand(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 22,
                                ),
                              ),
                              Text(
                                _greetingName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.quicksand(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700, // Ít đậm hơn
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                // ✨ KẾT THÚC ĐOẠN MÃ CỦA BẠN
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ✨ Đã bỏ hết 'delay'
              _buildSectionTitle('Tài Khoản'),
              _buildSettingItem(
                icon: Icons.person_outline_rounded,
                iconColor: Colors.blue,
                title: 'Thông tin cá nhân',
                onTap: () => _navigateTo(const CaNhanScreen()),
              ),
              _buildSettingItem(
                icon: Icons.people_alt_outlined,
                iconColor: Colors.green,
                title: 'Quản lý nhân viên',
                onTap: () => _navigateTo(const NhanVienScreen()),
              ),
              _buildSectionTitle('Cửa Hàng'),
              _buildSettingItem(
                icon: Icons.store_outlined,
                iconColor: Colors.orange,
                title: 'Thông tin cửa hàng',
                onTap: () => _navigateTo(const ThongTinCuaHangScreen()),
              ),
              _buildSettingItem(
                icon: Icons.restaurant_menu_outlined,
                iconColor: Colors.purple,
                title: 'Quản lý nhà hàng',
                onTap: () => _navigateTo(const CuaHangScreen()),
              ),
              _buildSettingItem(
                icon: Icons.dashboard_customize_outlined,
                iconColor: Colors.cyan,
                title: 'Tùy chỉnh chức năng',
                onTap: () => _navigateTo(const TuyChinhChucNangScreen()),
              ),
              _buildSectionTitle('Thiết bị & In ấn'),
              _buildSettingItem(
                icon: Icons.print_outlined,
                iconColor: Colors.teal,
                title: 'Cài đặt máy in',
                onTap: () => _navigateTo(const CaiDatMayInScreen()),
              ),
              _buildSettingItem(
                icon: Icons.receipt_long_outlined,
                iconColor: Colors.indigo,
                title: 'Mẫu hóa đơn',
                onTap: () => _navigateTo(const MauHoaDonScreen()),
              ),
              _buildSectionTitle(''),
_buildSettingItem(
                icon: Icons.logout,
                iconColor: Colors.red.shade600,
                title: 'Đăng xuất',
                titleColor: Colors.red.shade600, // ✨ Chữ màu đỏ
                onTap: _dangXuat,
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),
    );
  }
}