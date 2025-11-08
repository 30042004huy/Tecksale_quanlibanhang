// lib/screens/thongtinwebsite.dart
// (ĐÃ THIẾT KẾ LẠI GIAO DIỆN CHUYÊN NGHIỆP HƠN)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ThongTinWebsiteScreen extends StatefulWidget {
  const ThongTinWebsiteScreen({super.key});

  @override
  State<ThongTinWebsiteScreen> createState() => _ThongTinWebsiteScreenState();
}

class _ThongTinWebsiteScreenState extends State<ThongTinWebsiteScreen> {
  // --- Firebase ---
  final dbRef = FirebaseDatabase.instance.ref();
  final storageRef = FirebaseStorage.instance.ref();
  User? user = FirebaseAuth.instance.currentUser;
  late DatabaseReference _shopInfoRef;

  // --- State ---
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  String _uploadStatus = '';

  // --- Controllers ---
  final _tenShopController = TextEditingController();
  final _sdtController = TextEditingController();
  final _emailController = TextEditingController();
  final _diaChiController = TextEditingController();
  final _facebookController = TextEditingController();
  final _zaloController = TextEditingController();
  final _youtubeController = TextEditingController();
  final _chiuTrachNhiemController = TextEditingController();

  // --- Ảnh ---
  XFile? _logoFile;
  String? _existingLogoUrl;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _shopInfoRef = dbRef.child('website_data/${user!.uid}/shop_info');
      _loadShopInfo();
    } else {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    // Xóa controllers
    _tenShopController.dispose();
    _sdtController.dispose();
    _emailController.dispose();
    _diaChiController.dispose();
    _facebookController.dispose();
    _zaloController.dispose();
    _youtubeController.dispose();
    _chiuTrachNhiemController.dispose();
    super.dispose();
  }

  // --- LOGIC (Không đổi) ---

  Future<void> _loadShopInfo() async {
    try {
      final snapshot = await _shopInfoRef.get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        _tenShopController.text = data['tenShop'] ?? '';
        _sdtController.text = data['sdt'] ?? '';
        _emailController.text = data['email'] ?? '';
        _diaChiController.text = data['diaChi'] ?? '';
        _facebookController.text = data['facebook'] ?? '';
        _zaloController.text = data['zalo'] ?? '';
        _youtubeController.text = data['youtube'] ?? '';
        _chiuTrachNhiemController.text = data['chiuTrachNhiem'] ?? '';
        _existingLogoUrl = data['logoUrl'];
      }
    } catch (e) {
      // Lỗi này sẽ xảy ra nếu App Check (Đọc) bị bật
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải thông tin: $e'), backgroundColor: Colors.red,));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile != null) {
        setState(() => _logoFile = pickedFile);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
    }
  }

  Future<void> _saveInfo() async {
    if (!_formKey.currentState!.validate() || user == null) return;

    setState(() {
      _isSaving = true;
      _uploadStatus = 'Đang lưu...';
    });

    try {
      String logoUrl = _existingLogoUrl ?? '';

      // 1. Upload logo mới (nếu có)
      if (_logoFile != null) {
        setState(() => _uploadStatus = 'Đang tải logo...');
        // Đường dẫn upload đã khớp với Rules mới (website_data)
        final ref = storageRef.child('website_data/${user!.uid}/shop_logo/logo.png');
        final snapshot = await ref.putFile(File(_logoFile!.path));
        logoUrl = await snapshot.ref.getDownloadURL();
      }

      final infoData = {
        'tenShop': _tenShopController.text.trim(),
        'sdt': _sdtController.text.trim(),
        'email': _emailController.text.trim(),
        'diaChi': _diaChiController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'zalo': _zaloController.text.trim(),
        'youtube': _youtubeController.text.trim(),
        'chiuTrachNhiem': _chiuTrachNhiemController.text.trim(),
        'logoUrl': logoUrl,
      };

      setState(() => _uploadStatus = 'Đang lưu thông tin...');
      await _shopInfoRef.set(infoData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thông tin website!'), backgroundColor: Colors.green),
      );
      if (mounted) Navigator.pop(context);

    } catch (e) {
      // Lỗi "unauthorized" hoặc "Too many attempts" sẽ hiển thị ở đây
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lưu: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // --- GIAO DIỆN (Đã thiết kế lại) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông tin Shop', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(12.0),
                children: [
                  // --- Card 1: Logo ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _buildLogoPreview(),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.photo_library, size: 20),
                            label: Text(_logoFile == null ? 'Chọn Logo Shop' : 'Thay đổi Logo'),
                            onPressed: _pickLogo,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Card 2: Thông tin cơ bản ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Thông tin cơ bản'),
                          _buildTextField(_tenShopController, 'Tên Shop', Icons.store),
                          _buildTextField(_sdtController, 'Số điện thoại', Icons.phone),
                          _buildTextField(_emailController, 'Email', Icons.email),
                          _buildTextField(_diaChiController, 'Địa chỉ', Icons.location_on),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Card 3: Mạng xã hội ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           _buildSectionHeader('Mạng xã hội'),
                          _buildTextField(_facebookController, 'Link Facebook', Icons.facebook),
                          _buildTextField(_zaloController, 'Link Zalo (hoặc SĐT Zalo)', Icons.chat),
                          _buildTextField(_youtubeController, 'Link Youtube', Icons.play_circle_fill),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- Card 4: Pháp lý ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           _buildSectionHeader('Thông tin khác'),
                          _buildTextField(_chiuTrachNhiemController, 'Người chịu trách nhiệm', Icons.person),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 100), // Khoảng trống cho nút lưu
                ],
              ),
            ),

          // Nút Lưu (Nổi)
          if (!_isSaving)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, -4))
                  ]
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Lưu thông tin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: _saveInfo,
                ),
              ),
            ),
          
          // Lớp phủ khi đang lưu
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _uploadStatus,
                      style: GoogleFonts.roboto(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- Widgets con ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: GoogleFonts.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
    );
  }
  
  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPreview() {
    if (_logoFile != null) {
      return Image.file(File(_logoFile!.path), fit: BoxFit.cover);
    }
    if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) {
      return Image.network(
        _existingLogoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const Icon(Icons.store, color: Colors.grey, size: 50),
        loadingBuilder: (c, child, progress) => (progress == null)
            ? child
            : const Center(child: CircularProgressIndicator()),
      );
    }
    return const Icon(Icons.store, color: Colors.grey, size: 50);
  }
}