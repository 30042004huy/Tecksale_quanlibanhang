// lib/screens/website_product_edit_screen.dart
// (NÂNG CẤP TOÀN DIỆN GIAO DIỆN VÀ LOGIC GIÁ)

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/sanpham_model.dart';
import '../utils/format_currency.dart';
import '../services/custom_notification_service.dart';

class WebsiteProductEditScreen extends StatefulWidget {
  final SanPham privateProduct;
  final Map<String, dynamic>? publicData;
  final String? publicProductId;

  const WebsiteProductEditScreen({
    super.key,
    required this.privateProduct,
    this.publicData,
    this.publicProductId,
  });

  @override
  State<WebsiteProductEditScreen> createState() =>
      _WebsiteProductEditScreenState();
}

class _WebsiteProductEditScreenState extends State<WebsiteProductEditScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  final storageRef = FirebaseStorage.instance.ref();
  User? user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String _uploadStatus = '';

  // ✨ 1. THAY ĐỔI LOGIC CONTROLLER
  late TextEditingController _giaBanController; // Bị khóa, lấy từ private.donGia
  late TextEditingController _giaGocChuaGiamController; // Mới: Giá gạch ngang
  late TextEditingController _thuTuController; // Mới: Sắp xếp
  late TextEditingController _moTaController;
  late TextEditingController _thuongHieuController;
  late TextEditingController _nhaCungCapController;
  late TextEditingController _baoHanhController;

  List<XFile> _newImageFiles = [];
  List<String> _existingImageUrls = [];
  final List<String> _urlsToDelete = []; 

  @override
  void initState() {
    super.initState();
    
    // ✨ 2. LOGIC GIÁ MỚI
    // Giá Bán (giaBan) LÀ donGia từ kho tổng
    final giaBan = widget.privateProduct.donGia;
    
    // Giá Gốc (giaGoc) LÀ giá gạch ngang (compare-at price)
    final giaGocChuaGiam = (widget.publicData?['giaGoc'] as num?)?.toDouble() ?? 0.0;
    
    // Thứ tự (thuTu)
    final thuTu = (widget.publicData?['thuTu'] as num?)?.toInt() ?? 999;

    _giaBanController = TextEditingController(text: giaBan.toString());
    _giaGocChuaGiamController = TextEditingController(text: giaGocChuaGiam == 0.0 ? '' : giaGocChuaGiam.toString());
    _thuTuController = TextEditingController(text: thuTu == 999 ? '' : thuTu.toString());
    
    _moTaController = TextEditingController(text: widget.publicData?['moTa'] ?? '');
    _thuongHieuController = TextEditingController(text: widget.publicData?['thuongHieu'] ?? '');
    _nhaCungCapController = TextEditingController(text: widget.publicData?['nhaCungCap'] ?? '');
    _baoHanhController = TextEditingController(text: widget.publicData?['baoHanh'] ?? '12 tháng'); 
    
    if (widget.publicData?['anhWeb'] != null) {
      try {
        _existingImageUrls = List<String>.from(widget.publicData!['anhWeb'] as List);
      } catch (e) { _existingImageUrls = []; }
    }
  }

  @override
  void dispose() {
    _giaBanController.dispose();
    _giaGocChuaGiamController.dispose();
    _thuTuController.dispose();
    _moTaController.dispose();
    _thuongHieuController.dispose();
    _nhaCungCapController.dispose();
    _baoHanhController.dispose();
    super.dispose();
  }

  // (Các hàm _pickImages, _uploadFile giữ nguyên)
  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile> pickedFiles = await picker.pickMultiImage(imageQuality: 80);
      if (pickedFiles.isNotEmpty) {
        setState(() => _newImageFiles.addAll(pickedFiles));
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.show(context, message: 'Lỗi chọn ảnh: $e', backgroundColor: Colors.red[50]!, textColor: Colors.red);
      }
    }
  }

  Future<String> _uploadFile(XFile file, int index) async {
    if (user == null) throw Exception("Người dùng không tồn tại");
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = storageRef.child('website_products/${user!.uid}/${widget.privateProduct.id}/$fileName');
    setState(() => _uploadStatus = 'Đang tải ảnh ${index + 1}/${_newImageFiles.length}...');
    final snapshot = await ref.putFile(File(file.path));
    return await snapshot.ref.getDownloadURL();
  }
  
  // ✨ 3. HÀM LƯU SẢN PHẨM (ĐÃ CẬP NHẬT)
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || user == null) return;
    setState(() { _isSaving = true; _uploadStatus = 'Đang lưu...'; });

    try {
      // (Bước 1: Xóa ảnh cũ)
      if (_urlsToDelete.isNotEmpty) {
        setState(() => _uploadStatus = 'Đang xóa ảnh đã gỡ...');
        List<Future<void>> deleteTasks = _urlsToDelete.map((url) => 
            FirebaseStorage.instance.refFromURL(url).delete().catchError((e) => print('Lỗi xóa ảnh $url: $e'))
        ).toList();
        await Future.wait(deleteTasks);
        _urlsToDelete.clear();
      }
      
      // (Bước 2: Upload ảnh mới)
      List<String> newUrls = [];
      if (_newImageFiles.isNotEmpty) {
        List<Future<String>> uploadTasks = [];
        for (int i = 0; i < _newImageFiles.length; i++) {
          uploadTasks.add(_uploadFile(_newImageFiles[i], i));
        }
        newUrls = await Future.wait(uploadTasks);
      }
      List<String> finalImageUrls = [..._existingImageUrls, ...newUrls];

      setState(() => _uploadStatus = 'Đang chuẩn bị dữ liệu...');
      
      final String productId = widget.privateProduct.id;
      final DatabaseReference publicRef = dbRef.child('website_data/${user!.uid}/products/$productId');

      // ✨ 4. TẠO DỮ LIỆU ĐỂ LƯU (LOGIC MỚI)
      final Map<String, dynamic> publicData = {
        // Dữ liệu đồng bộ từ kho private
        'tenSP': widget.privateProduct.tenSP,
        'maSP': widget.privateProduct.maSP,
        'donVi': widget.privateProduct.donVi,
        'tonKho': widget.privateProduct.tonKho,
        'giaBan': widget.privateProduct.donGia, // Lấy từ privateProduct
        
        // Dữ liệu riêng của Web
        'giaGoc': double.tryParse(_giaGocChuaGiamController.text.trim()) ?? 0.0, // Giá gạch ngang
        'thuTu': int.tryParse(_thuTuController.text.trim()) ?? 999, // Thứ tự
        'moTa': _moTaController.text.trim(),
        'thuongHieu': _thuongHieuController.text.trim(),
        'nhaCungCap': _nhaCungCapController.text.trim(),
        'baoHanh': _baoHanhController.text.trim(),
        'anhWeb': finalImageUrls, 
        'timestamp': widget.publicData?['timestamp'] ?? ServerValue.timestamp, // Giữ timestamp cũ nếu có
        // (Đã xóa slug)
      };

      await publicRef.set(publicData);
      
      if (mounted) {
         CustomNotificationService.show(
          context,
          message: 'Đã cập nhật "${widget.privateProduct.tenSP}"',
          backgroundColor: Colors.green[50]!,
          textColor: Colors.green[700]!,
        );
        Navigator.pop(context);
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
         CustomNotificationService.show(
          context,
          message: 'Lỗi nghiêm trọng khi lưu: $e',
          backgroundColor: Colors.red[50]!,
          textColor: Colors.red,
        );
      }
    }
  }

  // (Hàm _removeProduct giữ nguyên)
  Future<void> _removeProduct() async {
    if (user == null || widget.publicProductId == null) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận gỡ'),
        content: Text('Bạn có chắc muốn gỡ "${widget.privateProduct.tenSP}" khỏi website không? Thao tác này sẽ xóa cả ảnh đã upload.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Gỡ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isSaving = true; _uploadStatus = 'Đang gỡ sản phẩm...'; });
    try {
      await dbRef.child('website_data/${user!.uid}/products/${widget.publicProductId}').remove();
      setState(() => _uploadStatus = 'Đang xóa ảnh cũ...');
      List<Future<void>> deleteTasks = [];
      for (String url in _existingImageUrls) { 
        deleteTasks.add(FirebaseStorage.instance.refFromURL(url).delete().catchError((e) => print('Lỗi xóa ảnh $url: $e')));
      }
      await Future.wait(deleteTasks);
      if (mounted) {
        CustomNotificationService.show(context, message: 'Đã gỡ "${widget.privateProduct.tenSP}" khỏi web', backgroundColor: Colors.orange[50]!, textColor: Colors.orange[800]!);
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
         CustomNotificationService.show(context, message: 'Lỗi khi gỡ: $e', backgroundColor: Colors.red[50]!, textColor: Colors.red);
      }
    }
  }

  // --- ✨ 5. GIAO DIỆN ĐƯỢC THIẾT KẾ LẠI ---
  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.publicData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa sản phẩm Web' : 'Đăng sản phẩm lên Web', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(12.0),
              children: [
                // THÔNG TIN CHUNG (KHÔNG SỬA)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.privateProduct.tenSP, style: GoogleFonts.quicksand(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                      const SizedBox(height: 8),
                      Text(
                        'Tồn kho: ${widget.privateProduct.tonKho ?? 0} ${widget.privateProduct.donVi}',
                        style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Mã SP: ${widget.privateProduct.maSP}',
                        style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // CARD ẢNH (Giữ nguyên)
                Card(
                  elevation: 1, shadowColor: Colors.grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Ảnh sản phẩm Website'),
                        const SizedBox(height: 16),
                        _buildImagePreviewList(),
                        const SizedBox(height: 12),
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Thêm ảnh từ máy'),
                            onPressed: _pickImages,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CARD GIÁ BÁN (LOGIC MỚI)
                Card(
                  elevation: 1, shadowColor: Colors.grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildSectionHeader('Thông tin giá bán & Sắp xếp'),
                         const SizedBox(height: 16),
                         // Giá Bán (Bị khóa)
                        _buildTextField(_giaBanController, 'Giá Bán (Lấy từ kho tổng)', Icons.attach_money, isNumber: true, readOnly: true),
                        const SizedBox(height: 16),
                        // Giá Gốc (Cho phép sửa)
                        _buildTextField(_giaGocChuaGiamController, 'Giá Gốc (Giá gạch ngang, không bắt buộc)', Icons.strikethrough_s_outlined, isNumber: true, isOptional: true),
                        const SizedBox(height: 16),
                        // Thứ Tự (Cho phép sửa)
                        _buildTextField(_thuTuController, 'Thứ tự hiển thị (ví dụ: 1, 2, 3)', Icons.sort_by_alpha_outlined, isNumber: true, isOptional: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // CARD THÔNG TIN CHI TIẾT (UI MỚI)
                Card(
                  elevation: 1, shadowColor: Colors.grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildSectionHeader('Thông tin chi tiết (Hiển thị web)'),
                         const SizedBox(height: 16),
                        _buildTextField(_thuongHieuController, 'Thương hiệu', Icons.branding_watermark_outlined, isOptional: true),
                        const SizedBox(height: 16),
                        _buildTextField(_nhaCungCapController, 'Nhà cung cấp', Icons.business_outlined, isOptional: true),
                        const SizedBox(height: 16),
                        _buildTextField(_baoHanhController, 'Thời hạn bảo hành', Icons.shield_outlined, isOptional: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // ✨ 6. ĐÃ XÓA CARD TỐI ƯU SEO (SLUG)
                
                // CARD MÔ TẢ (UI MỚI)
                Card(
                  elevation: 1, shadowColor: Colors.grey.withOpacity(0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('Mô tả sản phẩm'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _moTaController, 
                          'Mô tả chi tiết', 
                          Icons.description_outlined,
                          maxLines: 10,
                          maxLength: 3500, // ✨ Giới hạn 3500 ký tự
                          isOptional: true,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
          
          // (Nút Lưu/Gỡ - giữ nguyên)
          if (!_isSaving)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Row(
                  children: [
                    if (isEditing)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Gỡ khỏi Web'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: _removeProduct,
                        ),
                      ),
                    if (isEditing) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: Text(isEditing ? 'Lưu thay đổi' : 'Đăng lên Web'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: _saveProduct,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // (Lớp phủ khi đang lưu - giữ nguyên)
          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(_uploadStatus, style: GoogleFonts.roboto(color: Colors.white, fontSize: 16)),
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
    return Text(
      title,
      style: GoogleFonts.quicksand(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade700,
      ),
    );
  }

  // ✨ 7. HÀM BUILD TEXTFIELD ĐÃ NÂNG CẤP (Giao diện + Logic)
 Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumber = false,
    int maxLines = 1,
    int? maxLength,
    bool readOnly = false,
    bool isOptional = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(12))),
        counterText: maxLength != null ? "" : null,
        filled: readOnly,
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      keyboardType: isNumber
          ? TextInputType.number
          : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
      maxLines: maxLines,
      maxLength: maxLength,
      validator: (value) {
        final bool valueIsMissing = value == null || value.isEmpty;

        // 1. Kiểm tra nếu trường là bắt buộc
        if (!isOptional && valueIsMissing) {
          return 'Vui lòng nhập thông tin';
        }

        // 2. Nếu trường là tùy chọn và rỗng -> Hợp lệ
        if (isOptional && valueIsMissing) {
          return null;
        }
        
        // --- Từ điểm này, 'value' chắc chắn KHÔNG null và KHÔNG rỗng ---

        // 3. Kiểm tra định dạng số (nếu cần)
        if (isNumber && double.tryParse(value!) == null) {
          return 'Vui lòng nhập số hợp lệ';
        }

        // 4. ✨ SỬA LỖI: Dùng 'value!' (an toàn)
        if (maxLength != null && value!.length > maxLength) {
          return 'Vượt quá $maxLength ký tự';
        }

        return null;
      },
    );
  }

  // (Hàm _buildImagePreviewList giữ nguyên)
  Widget _buildImagePreviewList() {
    int totalImages = _existingImageUrls.length + _newImageFiles.length;
    if (totalImages == 0) {
      return Container(
        height: 120, width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.image_outlined, size: 40, color: Colors.grey), Text('Chưa có ảnh nào', style: TextStyle(color: Colors.grey))])),
      );
    }
    return Container(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalImages,
        itemBuilder: (context, index) {
          Widget imageWidget;
          bool isExistingImage = index < _existingImageUrls.length;
          if (isExistingImage) {
            final url = _existingImageUrls[index];
            imageWidget = Image.network(url, fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => (progress == null) ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, color: Colors.red),
            );
          } else {
            final file = _newImageFiles[index - _existingImageUrls.length];
            imageWidget = Image.file(File(file.path), fit: BoxFit.cover);
          }
          return Container(
            width: 120, height: 120, margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 120, height: 120, child: imageWidget)),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isExistingImage) {
                          final urlToRemove = _existingImageUrls.removeAt(index);
                          _urlsToDelete.add(urlToRemove);
                        } else {
                          _newImageFiles.removeAt(index - _existingImageUrls.length);
                        }
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}