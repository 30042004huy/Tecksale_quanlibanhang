import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart'; // ✨ Thêm thư viện Google Fonts
import 'package:animate_do/animate_do.dart';     // ✨ Thêm thư viện Animate Do

// --- Customer Model (Không thay đổi) ---
class Customer {
  String? id;
  String name;
  String phone;
  String? debt;
  String? note;

  Customer({this.id, required this.name, required this.phone, this.debt, this.note});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'debt': debt, 'note': note};

  factory Customer.fromMap(Map<dynamic, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      debt: map['debt'] as String?,
      note: map['note'] as String?,
    );
  }
}

// --- Màn hình Khách hàng ---
class KhachHangScreen extends StatefulWidget {
  const KhachHangScreen({super.key});

  @override
  State<KhachHangScreen> createState() => _KhachHangScreenState();
}

class _KhachHangScreenState extends State<KhachHangScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  User? _currentUser;
  DatabaseReference? _customerRef;

  List<Customer> _customers = [];
  List<Customer> _filteredCustomers = [];
  String? _selectedCustomerId;
  final TextEditingController _searchController = TextEditingController();
  
  // ✨ Thêm trạng thái chờ tải dữ liệu
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initFirebaseAndFetchCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initFirebaseAndFetchCustomers() async {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      // Xử lý trường hợp không có người dùng
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomSnackBar('Lỗi: Yêu cầu đăng nhập để xem dữ liệu.', isError: true);
      }
      return;
    }

    _customerRef = _databaseRef.child('nguoidung/${_currentUser!.uid}/khachhang');
    _customerRef!.onValue.listen((event) {
      final data = event.snapshot.value;
      final List<Customer> loadedCustomers = [];
      if (data != null && data is Map) {
        data.forEach((key, value) {
          loadedCustomers.add(Customer.fromMap(value, key));
        });
        // Sắp xếp theo tên
        loadedCustomers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      if (mounted) {
        setState(() {
          _customers = loadedCustomers;
          _filterCustomers();
          _isLoading = false; // ✨ Dừng hiệu ứng chờ tải
        });
      }
    }, onError: (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomSnackBar('Lỗi khi tải dữ liệu khách hàng.', isError: true);
      }
    });
  }

  void _filterCustomers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ✨ HÀM HIỂN THỊ THÔNG BÁO MỚI (SNACKBAR TÙY CHỈNH)
  void _showCustomSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        elevation: 6.0,
      ),
    );
  }

  void _addCustomer(Customer customer) async {
    if (_customerRef == null) return;
    try {
      await _customerRef!.push().set(customer.toJson());
      _showCustomSnackBar('Đã thêm khách hàng ${customer.name}');
    } catch (e) {
      _showCustomSnackBar('Lỗi khi thêm khách hàng', isError: true);
    }
  }

  void _updateCustomer(Customer customer) async {
    if (_customerRef == null || customer.id == null) return;
    try {
      await _customerRef!.child(customer.id!).update(customer.toJson());
      _showCustomSnackBar('Đã cập nhật khách hàng ${customer.name}');
      setState(() => _selectedCustomerId = null);
    } catch (e) {
      _showCustomSnackBar('Lỗi khi cập nhật khách hàng', isError: true);
    }
  }

  void _deleteCustomer(String customerId, String customerName) async {
    if (_customerRef == null) return;
    try {
      await _customerRef!.child(customerId).remove();
      _showCustomSnackBar('Đã xóa khách hàng $customerName');
      setState(() => _selectedCustomerId = null);
    } catch (e) {
      _showCustomSnackBar('Lỗi khi xóa khách hàng', isError: true);
    }
  }

  String _formatCurrencyDisplay(String? amount) {
    if (amount == null || amount.isEmpty) return '0 đ';
    String cleanText = amount.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return '0 đ';
    String formattedText = '';
    int counter = 0;
    for (int i = cleanText.length - 1; i >= 0; i--) {
      formattedText = cleanText[i] + formattedText;
      counter++;
      if (counter % 3 == 0 && i != 0) {
        formattedText = '.' + formattedText;
      }
    }
    return '$formattedText đ';
  }

  void _showAddEditCustomerDialog({Customer? customer}) {
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final debtController = TextEditingController(text: customer?.debt ?? '');
    final noteController = TextEditingController(text: customer?.note ?? '');
    final isEditing = customer != null;

    final inputDecoration = (String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.roboto(),
          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEditing ? 'Sửa thông tin khách hàng' : 'Thêm khách hàng mới',
          style: GoogleFonts.quicksand(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: inputDecoration('Tên khách hàng*', '')),
              const SizedBox(height: 16),
              TextField(controller: phoneController, decoration: inputDecoration('Số điện thoại*', ''), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              TextField(controller: debtController, decoration: inputDecoration('Công nợ', 'VD: 100000'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(controller: noteController, decoration: inputDecoration('Ghi chú', ''), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                final newCustomer = Customer(
                  id: customer?.id,
                  name: nameController.text,
                  phone: phoneController.text,
                  debt: debtController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  note: noteController.text,
                );
                if (isEditing) {
                  _updateCustomer(newCustomer);
                } else {
                  _addCustomer(newCustomer);
                }
                Navigator.of(context).pop();
              } else {
                _showCustomSnackBar('Vui lòng nhập Tên và Số điện thoại.', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isEditing ? 'Lưu thay đổi' : 'Thêm mới'),
          ),
        ],
      ),
    );
  }

  void _showCustomerDetailDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 10),
          Text('Chi tiết khách hàng', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Tên:', customer.name),
            _buildDetailRow('Điện thoại:', customer.phone),
            _buildDetailRow('Công nợ:', _formatCurrencyDisplay(customer.debt)),
            _buildDetailRow('Ghi chú:', customer.note?.isNotEmpty == true ? customer.note! : 'Không có'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng'))],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: RichText(
          text: TextSpan(
            style: GoogleFonts.roboto(fontSize: 16, color: Colors.black87),
            children: [
              TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      );

  Future<bool?> _showDeleteConfirmationDialog(String customerName) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 10),
            Text('Xác nhận xóa', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
          ]),
          content: Text('Bạn có chắc chắn muốn xóa khách hàng "$customerName"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              child: const Text('Xóa'),
            ),
          ],
        ),
      );

  // ✨ Widget hiển thị khi danh sách trống hoặc không có kết quả
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text(message, style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Ẩn bàn phím khi chạm ra ngoài
        if (_selectedCustomerId != null) setState(() => _selectedCustomerId = null);
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        // ✨ AppBar được thiết kế lại với Gradient
appBar: AppBar(
  flexibleSpace: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.blue.shade600, Colors.blue.shade800],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ),
  title: Text('Quản lý Khách hàng', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold, color: Colors.white)),
  centerTitle: true,
  elevation: 4.0,
  systemOverlayStyle: SystemUiOverlayStyle.light,
          iconTheme: const IconThemeData(
    color: Colors.white, // Thêm dòng này
  ),
  // ✨ Thêm nút hành động vào đây
  actions: [
    IconButton(
      icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 28),
      tooltip: 'Thêm khách hàng mới',
      onPressed: () => _showAddEditCustomerDialog(),
    ),
    const SizedBox(width: 8), // Thêm một chút khoảng cách cho đẹp
  ],
),
        body: Column(
          children: [
            // ✨ Thanh tìm kiếm được làm đẹp hơn
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc số điện thoại...',
                  hintStyle: GoogleFonts.roboto(color: Colors.grey.shade600),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
              ),
            ),
            // ✨ Hiển thị hiệu ứng chờ tải hoặc danh sách
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _customers.isEmpty
                      ? _buildEmptyState('Chưa có khách hàng nào.', Icons.people_outline)
                      : _filteredCustomers.isEmpty
                          ? _buildEmptyState('Không tìm thấy khách hàng.', Icons.search_off)
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = _filteredCustomers[index];
                                final isSelected = customer.id == _selectedCustomerId;

                                // ✨ Bọc item trong FadeInUp để có hiệu ứng xuất hiện
                                return FadeInUp(
                                  delay: Duration(milliseconds: 50 * (index < 6 ? index : 6)),
                                  child: _buildCustomerCard(customer, isSelected, index),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ Tách widget Card của khách hàng ra một hàm riêng cho dễ đọc
  Widget _buildCustomerCard(Customer customer, bool isSelected, int index) {
    return GestureDetector(
      onLongPress: () => setState(() => _selectedCustomerId = isSelected ? null : customer.id),
      onTap: () {
        if (isSelected) {
          setState(() => _selectedCustomerId = null);
        } else {
          _showCustomerDetailDialog(customer);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 12 : 6,
              offset: Offset(0, isSelected ? 6 : 3),
            ),
          ],
          border: isSelected ? Border.all(color: Colors.blue.shade400, width: 2) : null,
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(customer.name, style: GoogleFonts.quicksand(fontSize: 17, fontWeight: FontWeight.bold)),
              subtitle: Text(customer.phone, style: GoogleFonts.roboto(fontSize: 15, color: Colors.grey.shade700)),
              trailing: isSelected ? Icon(Icons.check_circle, color: Colors.blue.shade400) : null,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.fastOutSlowIn,
              child: isSelected ? _buildActionButtons(customer) : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
  
  // ✨ Tách các nút Sửa/Xóa ra hàm riêng
  Widget _buildActionButtons(Customer customer) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddEditCustomerDialog(customer: customer),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Sửa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await _showDeleteConfirmationDialog(customer.name);
                  if (confirm == true && mounted) {
                    _deleteCustomer(customer.id!, customer.name);
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Xóa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}