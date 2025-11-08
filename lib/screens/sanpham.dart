// lib/screens/sanpham.dart
// (NÂNG CẤP: ĐỒNG BỘ donGia -> giaBan)

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/sanpham_model.dart';
import '../utils/format_currency.dart';

class SanPhamScreen extends StatefulWidget {
  const SanPhamScreen({super.key});

  @override
  State<SanPhamScreen> createState() => _SanPhamScreenState();
}

class _SanPhamScreenState extends State<SanPhamScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  User? user = FirebaseAuth.instance.currentUser;
  List<SanPham> dsSanPham = [];
  bool isLoading = true;
  String _searchText = '';
  String? _selectedProductId;

  StreamSubscription<DatabaseEvent>? _sanPhamSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((newUser) {
      setState(() {
        user = newUser;
        isLoading = true;
      });
      _loadSanPham();
    });
    _loadSanPham();
  }

  void _loadSanPham() {
    _sanPhamSubscription?.cancel();

    if (user == null) {
      setState(() {
        dsSanPham = [];
        isLoading = false;
      });
      return;
    }

    final _sanPhamRef = dbRef.child('nguoidung/${user!.uid}/sanpham');
    _sanPhamSubscription = _sanPhamRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data == null) {
        setState(() {
          dsSanPham = [];
          isLoading = false;
        });
        return;
      }

      if (data is! Map<dynamic, dynamic>) {
        print('Dữ liệu Firebase không đúng định dạng Map: $data');
        setState(() {
          dsSanPham = [];
          isLoading = false;
        });
        return;
      }

      List<SanPham> list = [];
      data.forEach((key, value) {
        try {
          if (value is Map<dynamic, dynamic>) {
            list.add(SanPham.fromMap(value, key));
          } else {
            print('Dữ liệu sản phẩm với key "$key" không đúng định dạng Map, bỏ qua: $value');
          }
        } catch (e) {
          print('Lỗi khi xử lý sản phẩm "$key": $e, dữ liệu: $value');
        }
      });

      list.sort((a, b) => a.maSP.compareTo(b.maSP));

      setState(() {
        dsSanPham = list;
        isLoading = false;
      });
    }, onError: (error) {
      print('Lỗi khi tải sản phẩm: $error');
      setState(() {
        isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _sanPhamSubscription?.cancel();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  List<SanPham> get _filteredSanPham {
    if (_searchText.isEmpty) return dsSanPham;
    return dsSanPham.where((sp) =>
        sp.tenSP.toLowerCase().contains(_searchText.toLowerCase()) ||
        sp.maSP.toLowerCase().contains(_searchText.toLowerCase())).toList();
  }

  // (Hàm _showDialogAddOrEdit không đổi, chỉ thay đổi hàm _syncProductToWebsite)
  Future<void> _showDialogAddOrEdit({SanPham? sanPham}) async {
    final formKey = GlobalKey<FormState>();
    final maSPController = TextEditingController(text: sanPham?.maSP ?? '');
    final tenSPController = TextEditingController(text: sanPham?.tenSP ?? '');
    final donGiaController = TextEditingController(text: sanPham?.donGia.toString() ?? '');
    final giaNhapController = TextEditingController(text: sanPham?.giaNhap.toString() ?? '');
    final donViController = TextEditingController(text: sanPham?.donVi ?? '');
    final tonKhoController = TextEditingController(text: sanPham?.tonKho.toString() ?? '');
    bool isSaving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.95,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sanPham == null ? Icons.add_circle : Icons.edit,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sanPham == null ? 'Thêm sản phẩm mới' : 'Chỉnh sửa sản phẩm',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: tenSPController,
                                decoration: InputDecoration(
                                  labelText: 'Tên sản phẩm',
                                  prefixIcon: Icon(Icons.inventory, color: Colors.blue.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Nhập tên sản phẩm' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: maSPController,
                                decoration: InputDecoration(
                                  labelText: 'Mã sản phẩm',
                                  prefixIcon: Icon(Icons.qr_code, color: Colors.orange.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Nhập mã sản phẩm' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: donGiaController,
                                decoration: InputDecoration(
                                  labelText: 'Giá Bán (Đơn giá)', // Sửa label
                                  prefixIcon: Icon(Icons.attach_money, color: Colors.green.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Nhập giá bán';
                                  if (double.tryParse(value) == null) return 'Giá bán phải là số';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: tonKhoController,
                                decoration: InputDecoration(
                                  labelText: 'Tồn kho',
                                  prefixIcon: Icon(Icons.inventory, color: Colors.indigo.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.indigo.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Nhập tồn kho';
                                  if (int.tryParse(value) == null) return 'Tồn kho phải là số nguyên';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: giaNhapController,
                                decoration: InputDecoration(
                                  labelText: 'Giá Vốn (Giá nhập)', // Sửa label
                                  prefixIcon: Icon(Icons.shopping_bag, color: Colors.purple.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.purple.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Nhập giá vốn';
                                  if (double.tryParse(value) == null) return 'Giá vốn phải là số';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: donViController,
                                decoration: InputDecoration(
                                  labelText: 'Đơn vị',
                                  prefixIcon: Icon(Icons.straighten, color: Colors.teal.shade600, size: 20),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                validator: (value) => value == null || value.isEmpty ? 'Nhập đơn vị' : null,
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.grey.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: isSaving ? null : () => Navigator.pop(context),
                            child: const Text('Hủy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 2,
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setDialogState(() => isSaving = true);
                                      try {
                                        final newSP = SanPham(
                                          id: sanPham?.id ?? '',
                                          maSP: maSPController.text.trim(),
                                          tenSP: tenSPController.text.trim(),
                                          donGia: double.parse(donGiaController.text.trim()), // Đây là Giá Bán
                                          giaNhap: double.parse(giaNhapController.text.trim()), // Đây là Giá Vốn
                                          donVi: donViController.text.trim(),
                                          tonKho: int.parse(tonKhoController.text.trim()),
                                        );

                                        if (user == null) {
                                          throw Exception("Vui lòng đăng nhập để thêm/sửa sản phẩm.");
                                        }
                                        
                                        DatabaseReference sanPhamRef;
                                        
                                        if (sanPham == null) {
                                          sanPhamRef = dbRef.child('nguoidung/${user!.uid}/sanpham').push();
                                          await sanPhamRef.set(newSP.toMap());
                                          newSP.id = sanPhamRef.key!;
                                        } else {
                                          sanPhamRef = dbRef.child('nguoidung/${user!.uid}/sanpham').child(newSP.id);
                                          await sanPhamRef.set(newSP.toMap());
                                        }

                                        // ✨ 3. TỰ ĐỘNG ĐỒNG BỘ (LOGIC MỚI) ✨
                                        await _syncProductToWebsite(newSP);
                                        // -------------------------------------

                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text(sanPham == null ? 'Thêm thành công' : 'Cập nhật thành công')),
                                          );
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          setDialogState(() => isSaving = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Lỗi: $e')),
                                          );
                                        }
                                      }
                                    }
                                  },
                            child: isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(sanPham == null ? Icons.add : Icons.save, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        sanPham == null ? 'Thêm' : 'Lưu',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ✨ --- HÀM ĐỒNG BỘ ĐÃ CẬP NHẬT LOGIC GIÁ --- ✨
  Future<void> _syncProductToWebsite(SanPham privateProduct) async {
    if (user == null) return;
    
    final String productId = privateProduct.id;
    if (productId.isEmpty) return;

    final webProductRef = dbRef.child('website_data/${user!.uid}/products/$productId');
    
    final snapshot = await webProductRef.get();
    
    if (snapshot.exists) {
      // Nếu sản phẩm đã có trên web, đồng bộ các trường quan trọng
      await webProductRef.update({
        'tenSP': privateProduct.tenSP,
        'maSP': privateProduct.maSP,
        'donVi': privateProduct.donVi,
        'tonKho': privateProduct.tonKho,
        'giaBan': privateProduct.donGia, // ✨ CẬP NHẬT: Giá Bán (donGia) -> giaBan (web)
        // 'giaGoc' (giá gạch ngang) sẽ được giữ nguyên, người dùng tự sửa
        // 'moTa', 'anhWeb', 'thuTu' ... sẽ được giữ nguyên
      });
    }
    // Nếu chưa tồn tại, hàm này không làm gì cả.
  }
  
  // (Hàm _deleteSanPham không đổi, nó đã đồng bộ xóa)
  Future<void> _deleteSanPham(String id) async {
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để xóa sản phẩm.')),
      );
      return;
    }
    try {
      await dbRef.child('nguoidung/${user!.uid}/sanpham').child(id).remove();
      await dbRef.child('website_data/${user!.uid}/products/$id').remove();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xóa thành công ở cả kho tổng và web')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }

  // (Hàm _showProductDetails và _buildDetailRow đã ẩn Giá vốn)
  void _showProductDetails(SanPham sp) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sp.tenSP,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),

                _buildDetailRow('Mã sản phẩm', sp.maSP, Icons.qr_code, Colors.orange.shade600),
                const SizedBox(height: 12),
                _buildDetailRow('Giá Bán', FormatCurrency.format(sp.donGia, decimalDigits: 0), Icons.attach_money, Colors.green.shade600), // Sửa label
                const SizedBox(height: 12),
                // ✨ ẨN GIÁ VỐN (GIÁ NHẬP)
                // _buildDetailRow('Giá nhập', FormatCurrency.format(sp.giaNhap, decimalDigits: 0), Icons.shopping_bag, Colors.purple.shade600),
                // const SizedBox(height: 12),
                _buildDetailRow('Tồn kho', '${sp.tonKho}', Icons.inventory, Colors.indigo.shade600),
                const SizedBox(height: 12),
                _buildDetailRow('Đơn vị', sp.donVi, Icons.straighten, Colors.teal.shade600),
                const SizedBox(height: 24),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // (Hàm _showSummaryDialog đã ẩn Giá vốn)
  void _showSummaryDialog() {
    final totalProducts = dsSanPham.length;
    final totalStock = dsSanPham.fold<int>(0, (sum, sp) => sum + (sp.tonKho ?? 0));
    final outOfStock = dsSanPham.where((sp) => sp.tonKho == 0).length;

    // ✨ ẨN GIÁ VỐN
    // final totalInventoryValue = dsSanPham.fold<double>(0.0, (sum, sp) {
    //   final tonKho = sp.tonKho ?? 0;
    //   final giaNhap = sp.giaNhap ?? 0.0;
    //   return sum + (tonKho * giaNhap);
    // });

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Tổng quan sản phẩm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 16),

                _buildDetailRow('Tổng sản phẩm', '$totalProducts', Icons.inventory_2, Colors.blue.shade600),
                const SizedBox(height: 12),
                _buildDetailRow('Tổng số tồn kho', '$totalStock', Icons.store, Colors.green.shade600),
                const SizedBox(height: 12),
                _buildDetailRow('Số sản phẩm hết hàng', '$outOfStock', Icons.warning, Colors.red.shade600),
                const SizedBox(height: 12),
                // ✨ ẨN TỔNG TIỀN HÀNG (GIÁ VỐN)
                // _buildDetailRow('Tổng tiền hàng', FormatCurrency.format(totalInventoryValue, decimalDigits: 0), Icons.monetization_on, Colors.purple.shade600),
                // const SizedBox(height: 24),

                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
            overflow: TextOverflow.clip,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  // (Hàm _buildSearchBar giữ nguyên)
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Tìm theo tên hoặc mã sản phẩm...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchText = value.trim();
            _selectedProductId = null;
          });
        },
      ),
    );
  }

  // (Hàm _buildProductItem đã ẩn Giá vốn)
  Widget _buildProductItem(SanPham sp, int index) {
    return GestureDetector(
      onTap: () => _showProductDetails(sp),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50, Colors.white],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, const Color.fromARGB(255, 51, 140, 241)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
                        child: Text(
                          sp.tenSP,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildInfoChip(Icons.qr_code, 'Mã: ${sp.maSP}', Colors.orange),
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.attach_money, 'Giá Bán: ${FormatCurrency.format(sp.donGia, decimalDigits: 0)}', Colors.green), // Sửa label
                      const SizedBox(width: 12),
                      _buildInfoChip(Icons.inventory, 'Tồn kho: ${sp.tonKho}', Colors.indigo),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Icon(Icons.edit, color: Colors.blue.shade600),
                            title: const Text('Chỉnh sửa'),
                            onTap: () {
                              Navigator.pop(context);
                              _showDialogAddOrEdit(sanPham: sp);
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.delete, color: Colors.red.shade600),
                            title: const Text('Xóa sản phẩm'),
                            onTap: () {
                              Navigator.pop(context);
                              _showDeleteConfirmation(sp);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Hàm _showDeleteConfirmation giữ nguyên)
  void _showDeleteConfirmation(SanPham sp) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Xác nhận xóa'),
          ],
        ),
        content: Text('Bạn có chắc muốn xóa sản phẩm "${sp.tenSP}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteSanPham(sp.id);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // (Hàm _buildInfoChip đã được thêm vào từ lần trước)
  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // (Hàm build() giữ nguyên)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 29, 140, 244),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
        ),
        title: const Text(
          'Quản lý Sản phẩm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vui lòng đăng nhập để thêm sản phẩm.')),
                );
                return;
              }
              _showDialogAddOrEdit();
            },
            icon: const Icon(Icons.add_circle_outline, size: 26),
          ),
          IconButton(
            onPressed: _showSummaryDialog,
            icon: const Icon(Icons.assessment, size: 26),
          ),
          const SizedBox(width: 8), 
        ],
      ),

      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user == null ? 'Vui lòng đăng nhập để xem sản phẩm.' : 'Đang tải sản phẩm...',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _filteredSanPham.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              user == null ? 'Bạn chưa đăng nhập.' : 'Chưa có sản phẩm nào',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user == null ? 'Hãy đăng nhập để quản lý sản phẩm của bạn.' : 'Nhấn nút "Thêm" để tạo sản phẩm đầu tiên',
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: _filteredSanPham.length,
                        itemBuilder: (context, index) {
                          final sp = _filteredSanPham[index];
                          return _buildProductItem(sp, index);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}