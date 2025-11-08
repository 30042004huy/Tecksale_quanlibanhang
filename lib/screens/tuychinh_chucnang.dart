// lib/screens/tuychinh_chucnang.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/features_config.dart'; // Import file config mới
import '../services/custom_notification_service.dart'; // Import service thông báo

// Model để quản lý trạng thái của từng chức năng
class FeatureSetting {
  final String id;
  bool isVisible;
  int order;

  FeatureSetting({required this.id, required this.isVisible, required this.order});

  // Tìm thông tin gốc (icon, label) từ config
  FeatureConfig get config => kAllFeatureItems.firstWhere((item) => item.id == id);

  // Chuyển đổi sang Map để lưu vào Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isVisible': isVisible,
      'order': order,
    };
  }

  // Tạo từ Map đọc từ Firebase
  factory FeatureSetting.fromMap(Map<dynamic, dynamic> map) {
    return FeatureSetting(
      id: map['id'],
      isVisible: map['isVisible'],
      order: map['order'],
    );
  }
}

class TuyChinhChucNangScreen extends StatefulWidget {
  const TuyChinhChucNangScreen({super.key});

  @override
  State<TuyChinhChucNangScreen> createState() => _TuyChinhChucNangScreenState();
}

class _TuyChinhChucNangScreenState extends State<TuyChinhChucNangScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  List<FeatureSetting> _settings = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final snapshot = await _dbRef.child('nguoidung/${_user!.uid}/tuychinh/chucnang').get();

      if (snapshot.exists) {
        // Nếu đã có cài đặt, tải về
        final List<dynamic> data = snapshot.value as List<dynamic>;
        final loadedSettings = data.map((item) => FeatureSetting.fromMap(item)).toList();
        
        // Sắp xếp lại theo 'order' đã lưu
        loadedSettings.sort((a, b) => a.order.compareTo(b.order));
        
        // Kiểm tra xem có chức năng nào mới được thêm vào app không
        final Set<String> loadedIds = loadedSettings.map((e) => e.id).toSet();
        for (final config in kAllFeatureItems) {
          if (!loadedIds.contains(config.id)) {
            // Thêm chức năng mới vào cuối danh sách, mặc định là hiển thị
            loadedSettings.add(FeatureSetting(
              id: config.id,
              isVisible: true,
              order: loadedSettings.length,
            ));
          }
        }
        
        setState(() {
          _settings = loadedSettings;
          _isLoading = false;
        });

      } else {
        // Nếu chưa có cài đặt (lần đầu), tạo cài đặt mặc định
        setState(() {
          _settings = kAllFeatureItems.asMap().entries.map((entry) {
            return FeatureSetting(
              id: entry.value.id,
              isVisible: true, // Mặc định hiển thị tất cả
              order: entry.key,
            );
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.show(context, message: 'Lỗi tải cài đặt: $e', textColor: Colors.red);
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    // Yêu cầu: Tối thiểu 1 cái được bật
    final int visibleCount = _settings.where((item) => item.isVisible).length;
    if (visibleCount < 1) {
      CustomNotificationService.show(context, message: 'Bạn phải bật ít nhất 1 chức năng', textColor: Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_user == null) throw Exception('Người dùng chưa đăng nhập');

      // Cập nhật lại 'order' theo vị trí mới
      for (int i = 0; i < _settings.length; i++) {
        _settings[i].order = i;
      }

      // Chuyển danh sách settings thành danh sách Map
      final List<Map<String, dynamic>> dataToSave = _settings.map((item) => item.toMap()).toList();

      // Lưu vào Firebase
      await _dbRef.child('nguoidung/${_user!.uid}/tuychinh/chucnang').set(dataToSave);

      if (mounted) {
        CustomNotificationService.show(context, message: 'Đã lưu cài đặt thành công!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.show(context, message: 'Lỗi khi lưu: $e', textColor: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tùy chỉnh chức năng', style: GoogleFonts.quicksand(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveSettings,
                  tooltip: 'Lưu cài đặt',
                ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings.isEmpty
              ? const Center(child: Text('Không tìm thấy chức năng nào.'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: _settings.length,
                  itemBuilder: (context, index) {
                    final setting = _settings[index];
                    final config = setting.config; // Lấy thông tin (tên, icon)

                    return Card(
                      key: ValueKey(setting.id), // Key quan trọng cho ReorderableListView
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 2,
                      child: SwitchListTile(
                        value: setting.isVisible,
                        onChanged: (bool newValue) {
                          setState(() {
                            setting.isVisible = newValue;
                          });
                        },
                        title: Text(
                          config.label,
                          style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                        ),
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle, color: Colors.grey.shade400),
                            const SizedBox(width: 16),
                            Icon(config.icon, color: config.color, size: 28),
                          ],
                        ),
                        activeColor: Colors.blue.shade700,
                        inactiveThumbColor: const Color.fromARGB(255, 198, 198, 198),
                        inactiveTrackColor: const Color.fromARGB(255, 232, 232, 232),
                      ),
                    );
                  },
                  onReorder: (int oldIndex, int newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final FeatureSetting item = _settings.removeAt(oldIndex);
                      _settings.insert(newIndex, item);
                    });
                  },
                ),
    );
  }
}