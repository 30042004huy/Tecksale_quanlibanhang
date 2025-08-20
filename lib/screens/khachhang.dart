import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Import for TextInputFormatter

// --- Customer Model (Mô hình Khách hàng) ---
// Định nghĩa cấu trúc dữ liệu cho một khách hàng.
class Customer {
  String? id; // ID duy nhất của khách hàng từ Firebase
  String name; // Tên khách hàng
  String phone; // Số điện thoại khách hàng
  String? debt; // Công nợ (String để dễ định dạng và không bắt buộc)
  String? note; // Ghi chú (không bắt buộc)

  Customer({this.id, required this.name, required this.phone, this.debt, this.note});

  // Chuyển đổi đối tượng Customer thành Map để lưu vào Firebase.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'debt': debt, // Thêm công nợ vào JSON
      'note': note, // Thêm ghi chú vào JSON
    };
  }

  // Tạo đối tượng Customer từ dữ liệu Map nhận được từ Firebase.
  factory Customer.fromMap(Map<dynamic, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '', // Lấy tên, nếu không có thì là chuỗi rỗng
      phone: map['phone'] ?? '', // Lấy số điện thoại, nếu không có thì là chuỗi rỗng
      debt: map['debt'] as String?, // Lấy công nợ
      note: map['note'] as String?, // Lấy ghi chú
    );
  }
}

// --- CurrencyInputFormatter (Định dạng tiền tệ tùy chỉnh) ---
// Giúp định dạng số tiền có dấu chấm và đuôi 'đ' khi người dùng nhập.
// Lưu ý: Formatter này chỉ được dùng khi hiển thị trong popup chi tiết,
// không dùng trong TextField nhập liệu khi thêm/sửa để giữ dạng số thường.
class CurrencyInputFormatter extends TextInputFormatter {
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Xóa tất cả các ký tự không phải số
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Định dạng số có dấu chấm
    String formattedText = '';
    int counter = 0;
    for (int i = cleanText.length - 1; i >= 0; i--) {
      formattedText = cleanText[i] + formattedText;
      counter++;
      if (counter % 3 == 0 && i != 0) {
        formattedText = '.' + formattedText;
      }
    }

    // Thêm ký hiệu 'đ'
    formattedText += ' đ';

    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length), // Giữ con trỏ ở cuối
    );
  }
}

// --- KhachHangScreen (Màn hình Khách hàng) ---
// Đây là Widget chính cho màn hình quản lý khách hàng.
class KhachHangScreen extends StatefulWidget {
  @override
  _KhachHangScreenState createState() => _KhachHangScreenState();
}

class _KhachHangScreenState extends State<KhachHangScreen> {
  // Khởi tạo các thể hiện của Firebase Authentication và Database.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<Customer> _customers = []; // Danh sách tất cả khách hàng đã tải
  List<Customer> _filteredCustomers = []; // Danh sách khách hàng sau khi lọc (tìm kiếm)
  String? _selectedCustomerId; // Lưu ID của khách hàng đang được nhấn giữ (để hiển thị tùy chọn sửa/xóa)
  final TextEditingController _searchController = TextEditingController(); // Controller cho thanh tìm kiếm

  User? _currentUser; // Người dùng hiện tại
  DatabaseReference? _customerRef; // Tham chiếu đến đường dẫn Firebase cụ thể của người dùng

  @override
  void initState() {
    super.initState();
    _initFirebaseAndFetchCustomers(); // Khởi tạo Firebase và tải dữ liệu khách hàng
    _searchController.addListener(_filterCustomers); // Lắng nghe thay đổi trên thanh tìm kiếm để lọc danh sách
  }

  // Hàm khởi tạo Firebase và lấy dữ liệu khách hàng.
  Future<void> _initFirebaseAndFetchCustomers() async {
    _currentUser = _auth.currentUser; // Lấy người dùng hiện tại
    if (_currentUser == null) {
      // Nếu chưa có người dùng, thử đăng nhập ẩn danh.
      try {
        await _auth.signInAnonymously();
        _currentUser = _auth.currentUser; // Cập nhật người dùng sau khi đăng nhập
      } catch (e) {
        print("Lỗi đăng nhập ẩn danh: $e");
        // Hiển thị thông báo lỗi nếu không thể đăng nhập ẩn danh.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: Không thể đăng nhập để truy cập dữ liệu')),
        );
        return;
      }
    }

    if (_currentUser != null) {
      // Thiết lập tham chiếu đến vị trí lưu dữ liệu khách hàng của người dùng.
      _customerRef = _databaseRef.child('nguoidung/${_currentUser!.uid}/khachhang');

      // Lắng nghe sự kiện thay đổi dữ liệu từ Firebase Realtime Database.
      _customerRef!.onValue.listen((event) {
        final data = event.snapshot.value; // Lấy dữ liệu từ snapshot
        if (data != null && data is Map) {
          final List<Customer> loadedCustomers = [];
          // Duyệt qua dữ liệu và chuyển đổi thành danh sách Customer.
          data.forEach((key, value) {
            loadedCustomers.add(Customer.fromMap(value, key));
          });
          setState(() {
            _customers = loadedCustomers; // Cập nhật danh sách khách hàng
            _filterCustomers(); // Lọc lại danh sách ngay lập tức sau khi dữ liệu mới đến
          });
        } else {
          // Nếu không có dữ liệu, đặt danh sách khách hàng rỗng.
          setState(() {
            _customers = [];
            _filterCustomers();
          });
        }
      }, onError: (error) {
        print("Lỗi đọc dữ liệu Firebase: $error");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải dữ liệu khách hàng')),
        );
      });
    }
  }

  // Hàm lọc danh sách khách hàng dựa trên từ khóa tìm kiếm.
  void _filterCustomers() {
    String query = _searchController.text.toLowerCase(); // Lấy từ khóa tìm kiếm và chuyển về chữ thường
    setState(() {
      _filteredCustomers = _customers.where((customer) {
        // Kiểm tra xem tên hoặc số điện thoại có chứa từ khóa không.
        return customer.name.toLowerCase().contains(query) ||
            customer.phone.toLowerCase().contains(query);
      }).toList();
    });
  }

  // Hàm thêm khách hàng mới vào Firebase.
  void _addCustomer(Customer customer) async {
    if (_customerRef != null) {
      try {
        await _customerRef!.push().set(customer.toJson()); // 'push()' tạo một ID duy nhất
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã thêm khách hàng ${customer.name}')),
        );
      } catch (e) {
        print("Lỗi thêm khách hàng: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi thêm khách hàng')),
        );
      }
    }
  }

  // Hàm cập nhật thông tin khách hàng hiện có trên Firebase.
  void _updateCustomer(Customer customer) async {
    if (_customerRef != null && customer.id != null) {
      try {
        await _customerRef!.child(customer.id!).update(customer.toJson());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật khách hàng ${customer.name}')),
        );
        _selectedCustomerId = null; // Bỏ chọn khách hàng sau khi cập nhật
      } catch (e) {
        print("Lỗi cập nhật khách hàng: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi cập nhật khách hàng')),
        );
      }
    }
  }

  // Hàm xóa khách hàng khỏi Firebase.
  void _deleteCustomer(String customerId, String customerName) async {
    if (_customerRef != null) {
      try {
        await _customerRef!.child(customerId).remove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa khách hàng $customerName')),
        );
        _selectedCustomerId = null; // Bỏ chọn khách hàng sau khi xóa
      } catch (e) {
        print("Lỗi xóa khách hàng: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa khách hàng')),
        );
      }
    }
  }

  // Hiển thị hộp thoại để thêm hoặc sửa khách hàng.
  void _showAddEditCustomerDialog({Customer? customer}) {
    final _nameController = TextEditingController(text: customer?.name ?? '');
    final _phoneController = TextEditingController(text: customer?.phone ?? '');
    // Hiển thị công nợ dưới dạng số thường trong TextField thêm/sửa
    final _debtController = TextEditingController(text: customer?.debt ?? '');
    final _noteController = TextEditingController(text: customer?.note ?? '');
    final bool isEditing = customer != null; // Kiểm tra xem đang ở chế độ sửa hay thêm mới

    // Define the common border style for text fields
    final OutlineInputBorder defaultInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: Colors.grey.shade400, width: 1.0), // Always show a light gray border
    );

    // Define the focused border style (can be a different color)
    final OutlineInputBorder focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: const Color.fromARGB(255, 30, 154, 255), width: 2.0), // Accent color when focused
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Sửa khách hàng' : 'Thêm khách hàng mới'),
          content: SingleChildScrollView( // Cho phép cuộn nếu nội dung quá dài
            child: Column(
              mainAxisSize: MainAxisSize.min, // Giữ kích thước cột tối thiểu
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên khách hàng',
                    border: defaultInputBorder, // Default border
                    enabledBorder: defaultInputBorder, // Border when not focused but enabled
                    focusedBorder: focusedInputBorder, // Border when focused
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    border: defaultInputBorder,
                    enabledBorder: defaultInputBorder,
                    focusedBorder: focusedInputBorder,
                  ),
                  keyboardType: TextInputType.phone, // Bàn phím số điện thoại
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _debtController,
                  decoration: InputDecoration(
                    labelText: 'Công nợ (không bắt buộc)',
                    hintText: 'VD: 1000000', // Gợi ý nhập dạng số thường
                    border: defaultInputBorder,
                    enabledBorder: defaultInputBorder,
                    focusedBorder: focusedInputBorder,
                  ),
                  keyboardType: TextInputType.number, // Bàn phím số
                  // Bỏ `inputFormatters` để giữ dạng số thường khi nhập
                  // inputFormatters: [CurrencyInputFormatter()],
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                    border: defaultInputBorder,
                    enabledBorder: defaultInputBorder,
                    focusedBorder: focusedInputBorder,
                  ),
                  maxLines: 3, // Cho phép nhiều dòng cho ghi chú
                  keyboardType: TextInputType.multiline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Đóng hộp thoại
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
                  // Tạo đối tượng Customer mới
                  final newCustomer = Customer(
                    id: customer?.id, // Giữ lại ID nếu đang sửa
                    name: _nameController.text,
                    phone: _phoneController.text,
                    // Lưu công nợ dưới dạng số thường (đã loại bỏ dấu chấm từ định dạng tiền tệ nếu có)
                    debt: _debtController.text.replaceAll(' đ', '').replaceAll('.', ''),
                    note: _noteController.text,
                  );
                  if (isEditing) {
                    _updateCustomer(newCustomer); // Gọi hàm cập nhật
                  } else {
                    _addCustomer(newCustomer); // Gọi hàm thêm mới
                  }
                  Navigator.of(context).pop(); // Đóng hộp thoại sau khi thao tác
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vui lòng nhập đầy đủ Tên và Số điện thoại')),
                  );
                }
              },
              child: Text(isEditing ? 'Lưu' : 'Thêm'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color.fromARGB(255, 30, 154, 255), // Màu xanh bạn yêu cầu
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  // Hàm định dạng số tiền cho hiển thị (thêm dấu chấm và 'đ').
  // Hàm này chỉ được gọi khi hiển thị chi tiết công nợ trong popup.
  String _formatCurrencyDisplay(String? amount) {
    if (amount == null || amount.isEmpty) {
      return '';
    }
    // Xóa tất cả các ký tự không phải số
    String cleanText = amount.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) return '';

    String formattedText = '';
    int counter = 0;
    for (int i = cleanText.length - 1; i >= 0; i--) {
      formattedText = cleanText[i] + formattedText;
      counter++;
      if (counter % 3 == 0 && i != 0) {
        formattedText = '.' + formattedText;
      }
    }
    return formattedText + ' đ';
  }

  // Hiển thị popup chi tiết khách hàng khi chạm.
  void _showCustomerDetailDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Chi tiết khách hàng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Tên:', customer.name),
              _buildDetailRow('Số điện thoại:', customer.phone),
              // Hiển thị công nợ đã được định dạng tiền tệ
              _buildDetailRow('Công nợ:', _formatCurrencyDisplay(customer.debt)),
              _buildDetailRow('Ghi chú:', customer.note ?? 'Không có'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // Hàm tiện ích để xây dựng hàng hiển thị chi tiết
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.black87),
          children: [
            TextSpan(text: '$label ', style: TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // Hiển thị popup xác nhận xóa khách hàng
  Future<bool?> _showDeleteConfirmationDialog(String customerName) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Người dùng phải chọn 1 trong 2 nút
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa khách hàng "$customerName" không? Hành động này không thể hoàn tác.',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // Trả về false nếu hủy
              child: Text('Hủy', style: TextStyle(color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true), // Trả về true nếu xác nhận xóa
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red.shade600, // Nút xóa màu đỏ
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Xóa'),
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Bắt sự kiện chạm bên ngoài để bỏ chọn khách hàng.
      onTap: () {
        if (_selectedCustomerId != null) {
          setState(() {
            _selectedCustomerId = null; // Bỏ chọn khách hàng
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Khách hàng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true, // Căn giữa tiêu đề
          leading: IconButton(
            icon: const Icon(Icons.arrow_back), // Icon mũi tên quay lại
            onPressed: () {
              Navigator.of(context).pop(); // Quay lại màn hình trước
            },
          ),
          elevation: 4.0, // Thêm đổ bóng cho AppBar
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên hoặc số điện thoại',
                  prefixIcon: const Icon(Icons.search), // Icon tìm kiếm
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0), // Bo tròn viền
                    borderSide: BorderSide.none, // Không có đường viền
                  ),
                  filled: true,
                  fillColor: Colors.grey[200], // Màu nền cho thanh tìm kiếm
                  contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                ),
              ),
            ),
            // Danh sách khách hàng
            Expanded(
              child: _filteredCustomers.isEmpty && _searchController.text.isEmpty
                  ? Center(child: Text('Chưa có khách hàng nào. Hãy thêm mới!'))
                  : _filteredCustomers.isEmpty && _searchController.text.isNotEmpty
                      ? Center(child: Text('Không tìm thấy khách hàng nào.'))
                      : ListView.builder(
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final isSelected = customer.id == _selectedCustomerId; // Kiểm tra xem khách hàng có đang được nhấn giữ không

                            return GestureDetector(
                              onLongPress: () {
                                // Khi nhấn giữ, chọn hoặc bỏ chọn khách hàng để hiển thị Sửa/Xóa.
                                setState(() {
                                  _selectedCustomerId = isSelected ? null : customer.id;
                                });
                              },
                              onTap: () {
                                // Khi chạm, nếu đang được chọn (long-press), thì bỏ chọn.
                                // Nếu chưa được chọn (chạm bình thường), thì hiển thị popup chi tiết.
                                if (isSelected) {
                                  setState(() {
                                    _selectedCustomerId = null;
                                  });
                                } else {
                                  _showCustomerDetailDialog(customer); // Hiển thị popup chi tiết
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200), // Thời gian chuyển động
                                curve: Curves.easeInOut, // Kiểu chuyển động
                                margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(isSelected ? 16.0 : 8.0), // Bo tròn nhiều hơn khi được chọn
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isSelected ? 0.2 : 0.05),
                                      spreadRadius: isSelected ? 2 : 1,
                                      blurRadius: isSelected ? 10 : 3,
                                      offset: Offset(0, isSelected ? 6 : 2), // Đổ bóng tạo hiệu ứng 3D nâng lên
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                            child: Text(
                                              (index + 1).toString(), // Số thứ tự
                                              style: TextStyle(
                                                color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  customer.name, // Tên khách hàng
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  customer.phone, // Số điện thoại
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected) // Hiển thị icon khi được chọn
                                            Icon(Icons.more_vert, color: Theme.of(context).primaryColor),
                                        ],
                                      ),
                                    ),
                                    // Các nút Sửa/Xóa chỉ hiển thị khi khách hàng được chọn (sau long press)
                                    AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return SizeTransition(
                                          sizeFactor: animation,
                                          axisAlignment: -1.0,
                                          child: child,
                                        );
                                      },
                                      child: isSelected
                                          ? Column(
                                              key: ValueKey('actions_${customer.id}'), // Khóa cho AnimatedSwitcher
                                              children: [
                                                Divider(height: 1, color: Colors.grey[300]),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                    children: [
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          onPressed: () {
                                                            // Không còn pop() nào ở đây, chỉ mở hộp thoại sửa
                                                            _showAddEditCustomerDialog(customer: customer); 
                                                          },
                                                          icon: Icon(Icons.edit),
                                                          label: Text('Sửa'),
                                                          style: ElevatedButton.styleFrom(
                                                            foregroundColor: Colors.white,
                                                            backgroundColor: Colors.blue, // Màu nền của nút
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            padding: EdgeInsets.symmetric(vertical: 12),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 16),
                                                      Expanded(
                                                        child: ElevatedButton.icon(
                                                          onPressed: () async {
                                                            // Hiển thị popup xác nhận xóa
                                                            final bool? confirmDelete = await _showDeleteConfirmationDialog(customer.name);
                                                            if (confirmDelete == true) {
                                                              _deleteCustomer(customer.id!, customer.name); 
                                                            }
                                                          },
                                                          icon: Icon(Icons.delete),
                                                          label: Text('Xóa'),
                                                          style: ElevatedButton.styleFrom(
                                                            foregroundColor: Colors.white,
                                                            backgroundColor: Colors.red, // Màu nền của nút
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            padding: EdgeInsets.symmetric(vertical: 12),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(key: ValueKey('no_actions')), // Ẩn khi không được chọn
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            _showAddEditCustomerDialog(); // Mở hộp thoại thêm khách hàng mới
          },
          label: Text('Thêm khách hàng'),
          icon: Icon(Icons.add),
          backgroundColor: const Color.fromARGB(255, 30, 154, 255), // Màu nền của nút FAB
          foregroundColor: Colors.white, // Màu chữ và icon của nút FAB
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // Bo tròn nút FAB
          ),
          elevation: 8.0, // Nâng nút FAB lên
        ),
        // Đặt nút FAB ở góc dưới bên phải.
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose(); // Giải phóng controller khi màn hình bị hủy
    super.dispose();
  }
}
