// File: nhanvien.dart (Đã sửa lỗi treo UI, tối ưu và nâng cấp giao diện)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

// =================================================================
// 1. DATA MODEL (Không thay đổi)
// =================================================================
class NhanVien {
  final String id;
  final String ten;
  final String ma;
  final int timestamp;

  const NhanVien({
    required this.id,
    required this.ten,
    required this.ma,
    required this.timestamp,
  });

  factory NhanVien.fromMap(String id, Map map) => NhanVien(
        id: id,
        ten: map['ten']?.trim() ?? 'Chưa đặt tên',
        ma: map['ma']?.trim() ?? '',
        timestamp: map['timestamp'] is int ? map['timestamp'] : DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toMap() => {
        'ten': ten,
        'ma': ma,
        'timestamp': timestamp, // Giữ lại timestamp cũ khi sửa, chỉ cập nhật khi tạo mới
      };
}

// =================================================================
// 2. MAIN WIDGET
// =================================================================
class NhanVienScreen extends StatefulWidget {
  const NhanVienScreen({super.key});

  @override
  State<NhanVienScreen> createState() => _NhanVienScreenState();
}

class _NhanVienScreenState extends State<NhanVienScreen> {
  DatabaseReference? _nhanVienRef;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // 3. INITIALIZATION
  // -----------------------------------------------------------------
  Future<void> _initializeFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _nhanVienRef = FirebaseDatabase.instance.ref().child('nguoidung/${user.uid}/nhanvien');
        // Kích hoạt tính năng lưu offline
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        _nhanVienRef!.keepSynced(true);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Lỗi khởi tạo dữ liệu: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // -----------------------------------------------------------------
  // 4. CRUD OPERATIONS
  // -----------------------------------------------------------------

  // ✨ SỬA LỖI & TỐI ƯU HOÀN TOÀN LOGIC CỦA DIALOG
  Future<void> _handleNhanVienAction({NhanVien? nvToEdit}) async {
    final isEditing = nvToEdit != null;
    final tenController = TextEditingController(text: isEditing ? nvToEdit!.ten : '');
    final maController = TextEditingController(text: isEditing ? nvToEdit!.ma : '');
    bool isSaving = false; // Trạng thái chờ, chỉ dùng trong Dialog

    await showDialog(
      context: context,
      barrierDismissible: !isSaving, // Không cho tắt dialog khi đang lưu
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(isEditing ? 'Sửa nhân viên' : 'Thêm nhân viên', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTextField(tenController, 'Tên nhân viên (Bắt buộc)', Icons.person_outline),
                        const SizedBox(height: 16),
                        _buildTextField(maController, 'Mã nhân viên (Tùy chọn)', Icons.badge_outlined),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (tenController.text.trim().isEmpty) {
                          _showSnackBar('Tên nhân viên không được để trống.', isError: true);
                          return;
                        }

                        setDialogState(() => isSaving = true);

                        try {
                          final newId = _nhanVienRef!.push().key!;
                          final newNv = NhanVien(
                            id: isEditing ? nvToEdit!.id : newId,
                            ten: tenController.text.trim(),
                            ma: maController.text.trim(),
                            timestamp: isEditing ? nvToEdit!.timestamp : DateTime.now().millisecondsSinceEpoch,
                          );

                          if (_nhanVienRef == null) throw Exception('Database reference not initialized');

                          if (isEditing) {
                            await _nhanVienRef!.child(nvToEdit!.id).update(newNv.toMap());
                            if (mounted) _showSnackBar('Cập nhật thành công.');
                          } else {
                            await _nhanVienRef!.child(newNv.id).set(newNv.toMap());
                            if (mounted) _showSnackBar('Thêm nhân viên thành công.');
                          }

                          if (mounted) Navigator.pop(dialogContext); // Đóng dialog sau khi thành công
                        } catch (e) {
                          if (mounted) _showSnackBar('Đã xảy ra lỗi: $e', isError: true);
                        } finally {
                          if (mounted) {
                             setDialogState(() => isSaving = false);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(isEditing ? 'Lưu' : 'Thêm'),
                    ),
                  ],
                ),
                // Lớp phủ chờ, chỉ hiển thị khi isSaving = true
                if (isSaving)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _xoaNhanVien(NhanVien nv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa nhân viên "${nv.ten}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (_nhanVienRef == null) throw Exception('Database reference not initialized');
        await _nhanVienRef!.child(nv.id).remove();
        if (mounted) _showSnackBar('Đã xóa nhân viên "${nv.ten}".');
      } catch (e) {
        if (mounted) _showSnackBar('Lỗi khi xóa: $e', isError: true);
      }
    }
  }

  // -----------------------------------------------------------------
  // 5. UI UTILITIES
  // -----------------------------------------------------------------

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSearchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchTerm = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm nhân viên...',
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchTerm.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchTerm = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          ),
        ),
      );
      
  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_searchTerm.isNotEmpty ? Icons.search_off : Icons.group_off_outlined, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(
          _searchTerm.isNotEmpty ? 'Không tìm thấy kết quả.' : 'Chưa có nhân viên nào.',
          style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey.shade600),
        ),
      ],
    ),
  );

  // -----------------------------------------------------------------
  // 6. MAIN BUILD METHOD
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('Quản lý nhân viên', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        // ✨ THÊM DÒNG NÀY ĐỂ ĐỔI MÀU NÚT BACK
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Thêm nhân viên',
            onPressed: () => _handleNhanVienAction(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildNhanVienList()),
              ],
            ),
    );
  }

  // -----------------------------------------------------------------
  // 7. LIST VIEW & CARD WIDGET
  // -----------------------------------------------------------------

  Widget _buildNhanVienList() {
    if (_nhanVienRef == null) {
      return Center(child: Text('Yêu cầu đăng nhập để xem dữ liệu.', style: GoogleFonts.roboto(color: Colors.red)));
    }
    return StreamBuilder<DatabaseEvent>(
      stream: _nhanVienRef!.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
        }

        final data = snapshot.data?.snapshot.value;
        if (data == null || data is! Map) {
          return _buildEmptyState();
        }

        var list = data.entries.map((e) => NhanVien.fromMap(e.key, e.value)).toList();

        if (_searchTerm.isNotEmpty) {
          list = list.where((nv) => nv.ten.toLowerCase().contains(_searchTerm) || nv.ma.toLowerCase().contains(_searchTerm)).toList();
        }

        list.sort((a, b) => a.ten.toLowerCase().compareTo(b.ten.toLowerCase()));

        if (list.isEmpty) {
          return _buildEmptyState();
        }

        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final nv = list[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(child: _buildNhanVienCard(nv)),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ✨ TÁCH CARD RA THÀNH WIDGET RIÊNG CHO SẠCH SẼ VÀ ĐẸP HƠN
  Widget _buildNhanVienCard(NhanVien nv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade200, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleNhanVienAction(nvToEdit: nv),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  nv.ten.isNotEmpty ? nv.ten[0].toUpperCase() : '?',
                  style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue.shade800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nv.ten, style: GoogleFonts.roboto(fontSize: 17, fontWeight: FontWeight.bold)),
                    if (nv.ma.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Mã: ${nv.ma}', style: GoogleFonts.roboto(color: Colors.black54)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                tooltip: 'Xóa',
                onPressed: () => _xoaNhanVien(nv),
              ),
            ],
          ),
        ),
      ),
    );
  }
}