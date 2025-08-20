import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/donhang_model.dart' as donhang;
import '../models/khachhang_model.dart' as khachhang;
import '../models/sanpham_model.dart' as sanpham;

import '../utils/format_currency.dart';
import '../services/invoice_number_service.dart';
import 'taohoadon.dart';

enum CustomerSelection { newCustomer, savedCustomer }

class ProductWithQuantity {
  final sanpham.SanPham product;
  int quantity;

  ProductWithQuantity({
    required this.product,
    required this.quantity,
  });
}

class TaoDonScreen extends StatefulWidget {
  final donhang.OrderData? orderToEdit;

  const TaoDonScreen({
    Key? key,
    this.orderToEdit,
  }) : super(key: key);

  @override
  State<TaoDonScreen> createState() => _TaoDonScreenState();
}

class _TaoDonScreenState extends State<TaoDonScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  final user = FirebaseAuth.instance.currentUser;
  late final String _userId;

  final TextEditingController _invoiceNumberController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  List<khachhang.CustomerForInvoice> _dsKhachHang = [];
  List<sanpham.SanPham> _dsSanPham = [];

  CustomerSelection _customerSelection = CustomerSelection.newCustomer;
  khachhang.CustomerForInvoice? _selectedKhachHang;
  List<ProductWithQuantity> _selectedProducts = [];
  bool _isLoading = true;
  bool _isSaving = false;

  StreamSubscription<DatabaseEvent>? _khachHangSubscription;
  StreamSubscription<DatabaseEvent>? _sanPhamSubscription;

  @override
  void initState() {
    super.initState();
    if (user == null) {
      _userId = 'anonymous';
      setState(() => _isLoading = false);
    } else {
      _userId = user!.uid;
      _loadInitialData();
      _loadInvoiceNumber();
    }
    _shippingCostController.addListener(_updateTotalCost);
    _discountController.addListener(_updateTotalCost);
  }

  @override
  void dispose() {
    _khachHangSubscription?.cancel();
    _sanPhamSubscription?.cancel();
    _invoiceNumberController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _shippingCostController.removeListener(_updateTotalCost);
    _shippingCostController.dispose();
    _discountController.removeListener(_updateTotalCost);
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateTotalCost() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInvoiceNumber() async {
    try {
      final invoiceNumber = await InvoiceNumberService.getCurrentInvoiceNumber();
      if (mounted) {
        setState(() {
          _invoiceNumberController.text = invoiceNumber;
        });
      }
    } catch (e) {
      print('Lỗi khi tải số hóa đơn: $e');
    }
  }

  Future<void> _loadInitialData() async {
    final khachHangRef = dbRef.child('nguoidung/$_userId/khachhang');
    _khachHangSubscription = khachHangRef.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _dsKhachHang = data.values
              .map((e) => khachhang.CustomerForInvoice.fromMap(e))
              .toList();
        });
      }
    });

    final sanPhamRef = dbRef.child('nguoidung/$_userId/sanpham');
    _sanPhamSubscription = sanPhamRef.onValue.listen((event) {
      if (mounted && event.snapshot.value != null) {
        final Map<dynamic, dynamic> data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _dsSanPham = data.entries
              .map((e) => sanpham.SanPham.fromMap(e.value, e.key))
              .toList();
        });
      }
    });

    if (mounted) {
      setState(() => _isLoading = false);
    }

    if (widget.orderToEdit != null) {
      _loadOrderDataForEditing();
    }
  }

  void _loadOrderDataForEditing() {
    if (widget.orderToEdit == null) return;

    final order = widget.orderToEdit!;
    
    _invoiceNumberController.text = order.orderId;
    _customerNameController.text = order.customerName;
    _customerPhoneController.text = order.customerPhone;
    _shippingCostController.text = order.shippingCost > 0 ? order.shippingCost.toString() : '';
    _discountController.text = order.discount > 0 ? order.discount.toString() : '';
    _notesController.text = order.notes;

    _selectedProducts = order.items.map((item) {
      final product = _dsSanPham.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => sanpham.SanPham(
          id: item.productId,
          maSP: '',
          tenSP: item.name,
          donGia: item.unitPrice,
          donVi: item.unit,
        ),
      );
      
      return ProductWithQuantity(
        product: product,
        quantity: item.quantity,
      );
    }).toList();

    _customerSelection = CustomerSelection.newCustomer;
    
    if (mounted) {
      setState(() {});
    }
  }

  void _resetForm() {
    setState(() {
      _customerSelection = CustomerSelection.newCustomer;
      _selectedKhachHang = null;
      _customerNameController.clear();
      _customerPhoneController.clear();
      _shippingCostController.clear();
      _discountController.clear();
      _notesController.clear();
      _selectedProducts.clear();
    });
    _loadInvoiceNumber();
  }

  void _addProductToOrder(sanpham.SanPham product, int quantity) {
    setState(() {
      final existingIndex = _selectedProducts.indexWhere((p) => p.product.id == product.id);
      if (existingIndex != -1) {
        _selectedProducts[existingIndex].quantity += quantity;
      } else {
        _selectedProducts.add(ProductWithQuantity(
          product: product,
          quantity: quantity,
        ));
      }
    });
  }

  void _removeProductFromOrder(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
    });
  }

  double _calculateTotalProductCost() {
    return _selectedProducts.fold(
        0.0, (sum, item) => sum + (item.product.donGia * item.quantity));
  }

  double _calculateTotalOrderCost() {
    final totalProductCost = _calculateTotalProductCost();
    final shippingCost = double.tryParse(_shippingCostController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    return totalProductCost + shippingCost - discount;
  }

  Future<bool> _updateInventory() async {
    try {
      for (var item in _selectedProducts) {
        final productRef = dbRef.child('nguoidung/$_userId/sanpham/${item.product.id}');
        final snapshot = await productRef.get();
        if (snapshot.exists) {
          final productData = Map<String, dynamic>.from(snapshot.value as Map);
          final currentStock = (productData['tonKho'] as int?) ?? 0;
          if (currentStock < item.quantity) {
            _showAlertDialog('Lỗi', 'Sản phẩm ${item.product.tenSP} không đủ tồn kho.');
            return false;
          }
          await productRef.update({
            'tonKho': currentStock - item.quantity,
          });
        }
      }
      return true;
    } catch (e) {
      _showAlertDialog('Lỗi', 'Không thể cập nhật tồn kho: $e');
      return false;
    }
  }

  Future<void> _saveOrder(donhang.OrderStatus status) async {
    if (_selectedProducts.isEmpty) {
      _showAlertDialog('Lỗi', 'Vui lòng thêm ít nhất một sản phẩm vào đơn hàng.');
      return;
    }

    if (status == donhang.OrderStatus.saved) {
      final canUpdateInventory = await _updateInventory();
      if (!canUpdateInventory) {
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      if (widget.orderToEdit != null) {
        final oldOrder = widget.orderToEdit!;
        final oldStatusPath = oldOrder.status.toString().split('.').last;
        await dbRef.child('nguoidung/$_userId/donhang/$oldStatusPath/${oldOrder.orderId}').remove();
      } else if (status == donhang.OrderStatus.saved) {
        await InvoiceNumberService.incrementInvoiceCounter();
      }

      final orderData = _createOrderData(status);
      final orderId = orderData.orderId;
      final orderRef = dbRef.child('nguoidung/$_userId/donhang/${status.toString().split('.').last}/$orderId');
      final orderMap = orderData.toMap();
      await orderRef.set(orderMap);

      if (widget.orderToEdit == null && status == donhang.OrderStatus.saved) {
        await _loadInvoiceNumber();
      }

      String message = '';
      if (widget.orderToEdit != null) {
        switch (status) {
          case donhang.OrderStatus.draft:
            message = 'Đã cập nhật đơn hàng nháp thành công!';
            break;
          case donhang.OrderStatus.saved:
            message = 'Đã cập nhật đơn hàng thành công!';
            break;
          case donhang.OrderStatus.completed:
            message = 'Đã hoàn tất đơn hàng thành công!';
            break;
        }
      } else {
        switch (status) {
          case donhang.OrderStatus.draft:
            message = 'Đã lưu nháp đơn hàng thành công!';
            break;
          case donhang.OrderStatus.saved:
            message = 'Đã lưu đơn hàng thành công!';
            break;
          case donhang.OrderStatus.completed:
            message = 'Đã hoàn tất đơn hàng thành công!';
            break;
        }
      }
      _showAlertDialog('Thành công', message);
      if (status == donhang.OrderStatus.saved) {
        _resetForm();
      }
    } catch (e) {
      _showAlertDialog('Lỗi', 'Không thể lưu đơn hàng: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  donhang.OrderData _createOrderData(donhang.OrderStatus status) {
    String customerName;
    String customerPhone;
    if (_customerSelection == CustomerSelection.newCustomer) {
      customerName = _customerNameController.text.trim();
      customerPhone = _customerPhoneController.text.trim();
    } else {
      customerName = _selectedKhachHang?.name ?? '';
      customerPhone = _selectedKhachHang?.phone ?? '';
    }

    final List<donhang.OrderItem> orderItems = _selectedProducts.map((p) {
      return donhang.OrderItem(
        productId: p.product.id,
        name: p.product.tenSP,
        quantity: p.quantity,
        unit: p.product.donVi,
        unitPrice: p.product.donGia,
      );
    }).toList();

    return donhang.OrderData(
      orderId: _invoiceNumberController.text.trim(),
      orderDate: DateTime.now(),
      customerName: customerName,
      customerPhone: customerPhone,
      items: orderItems,
      shippingCost: double.tryParse(_shippingCostController.text) ?? 0.0,
      discount: double.tryParse(_discountController.text) ?? 0.0,
      notes: _notesController.text.trim(),
      status: status,
    );
  }

  void _showInvoicePreview() {
    if (_selectedProducts.isEmpty) {
      _showAlertDialog('Lỗi', 'Vui lòng thêm ít nhất một sản phẩm vào đơn hàng.');
      return;
    }

    final orderData = _createOrderData(donhang.OrderStatus.draft);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaoHoaDonScreen(orderData: orderData),
      ),
    ).then((value) {
      if (value == true && mounted) {
        _resetForm();
      }
    });
  }

  void _createInvoice() {
    if (_selectedProducts.isEmpty) {
      _showAlertDialog('Lỗi', 'Vui lòng thêm ít nhất một sản phẩm vào đơn hàng.');
      return;
    }

    final orderData = _createOrderData(donhang.OrderStatus.draft);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaoHoaDonScreen(orderData: orderData),
      ),
    ).then((value) {
      if (value == true && mounted) {
        _resetForm();
      }
    });
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.85,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    title == 'Thành công' ? Icons.check_circle : Icons.error,
                    color: title == 'Thành công' ? Colors.green.shade600 : Colors.red.shade600,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCustomerSelectionDialog() async {
    TextEditingController _searchController = TextEditingController();
    List<khachhang.CustomerForInvoice> filteredList = List.from(_dsKhachHang);

  // Thêm dòng code này để sắp xếp danh sách theo tên từ A-Z
  filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final result = await showDialog<khachhang.CustomerForInvoice>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterList(String keyword) {
              keyword = keyword.toLowerCase();
              setState(() {
                filteredList = _dsKhachHang.where((kh) {
                  return kh.name.toLowerCase().contains(keyword) ||
                      kh.phone.toLowerCase().contains(keyword);
                }).toList();
               // Thêm dòng code sắp xếp vào đây để danh sách sau khi lọc cũng được sắp xếp
              filteredList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            });
          }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_search, color: Colors.blue, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Chọn khách hàng',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm khách hàng...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.black, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: _filterList,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(child: Text('Không tìm thấy khách hàng'))
                          : ListView.builder(
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final khachHang = filteredList[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pop(khachHang);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            spreadRadius: 1,
                                            blurRadius: 5,
                                            offset: const Offset(2, 3),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        title: Text(
                                          khachHang.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        subtitle: Text(khachHang.phone),
                                        trailing: const Icon(Icons.person_outline),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedKhachHang = result;
        _customerSelection = CustomerSelection.savedCustomer;
        _customerNameController.text = result.name;
        _customerPhoneController.text = result.phone;
      });
    }
  }

  Future<void> _showProductSelectionDialog() async {
    final TextEditingController searchController = TextEditingController();
    List<sanpham.SanPham> filteredProducts = List.from(_dsSanPham)
      ..sort((a, b) => a.maSP.compareTo(b.maSP));

    final result = await showDialog<sanpham.SanPham>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shopping_cart, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Chọn sản phẩm',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                            tooltip: 'Quét mã barcode',
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _scanBarcode();
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm sản phẩm...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.black, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value.isEmpty) {
                              filteredProducts = List.from(_dsSanPham)
                                ..sort((a, b) => a.maSP.compareTo(b.maSP));
                            } else {
                              filteredProducts = _dsSanPham
                                  .where((product) =>
                                      product.tenSP.toLowerCase().contains(value.toLowerCase()) ||
                                      product.maSP.toLowerCase().contains(value.toLowerCase()))
                                  .toList()
                                ..sort((a, b) => a.maSP.compareTo(b.maSP));
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'Không tìm thấy sản phẩm',
                                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                ),
                              )
                            :  ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final sanPham = filteredProducts[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                  elevation: 2,
                                  color: const Color.fromARGB(255, 255, 255, 255), // Thêm dòng này để đổi màu nền
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: const Color.fromARGB(255, 144, 144, 144), // Thêm viền màu xám đậm
                                          width: 0.5, // Độ dày của viền
                                        ),
                                      ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column( // Sử dụng Column bên ngoài
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Hàng 1: Tên sản phẩm
                                        Text(
                                          sanPham.tenSP,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                          softWrap: true,
                                        ),
                                        const SizedBox(height: 8), // Khoảng cách giữa tên và các thông tin khác

                                        // Hàng 2: Mã, giá và nút thêm
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Thông tin mã và giá
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Mã: ${sanPham.maSP}',
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Giá: ${FormatCurrency.format(sanPham.donGia)}',
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Nút thêm sản phẩm, được căn giữa theo chiều dọc
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: IconButton(
                                                icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                                onPressed: () {
                                                  Navigator.of(context).pop(sanPham);
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Hủy',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      _addProductToOrder(result, 1);
    }
  }

  Future<void> _scanBarcode() async {
    try {
      // Kiểm tra quyền camera
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          _showAlertDialog('Lỗi', 'Quyền truy cập camera bị từ chối. Vui lòng cấp quyền trong cài đặt.');
          return;
        }
      }

      // Tải trạng thái tự động thêm từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final bool isAutoAdd = prefs.getBool('autoAddProduct') ?? false;

      // Tạo controller cho MobileScanner
      final controller = MobileScannerController(
        formats: [BarcodeFormat.all],
        torchEnabled: false,
        facing: CameraFacing.back,
        autoStart: true,
      );

      // Biến trạng thái flash và tự động thêm
      bool isTorchOn = false;
      bool autoAdd = isAutoAdd;
      bool canScan = true; // Control scan availability

      // Mở dialog quét barcode
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.height * 0.6,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Quét mã barcode',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isTorchOn ? Icons.flashlight_on : Icons.flashlight_off,
                                  color: isTorchOn ? Colors.green : Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isTorchOn = !isTorchOn;
                                    controller.toggleTorch();
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.blue),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            controller: controller,
                            onDetect: (capture) async {
                              if (!canScan) return;
                              setState(() => canScan = false);

                              final List<Barcode> barcodes = capture.barcodes;
                              if (barcodes.isNotEmpty && mounted) {
                                final barcode = barcodes.first.rawValue;
                                if (barcode != null && barcode.isNotEmpty) {
                                  final product = _dsSanPham.firstWhere(
                                    (p) => p.maSP == barcode,
                                    orElse: () => sanpham.SanPham(
                                      id: '',
                                      maSP: '',
                                      tenSP: '',
                                      donGia: 0,
                                      donVi: '',
                                    ),
                                  );

                                  if (product.id.isNotEmpty) {
                                    if (autoAdd) {
                                      // Thêm tự động với delay 2 giây
                                      _addProductToOrder(product, 1);
                                      _showAlertDialog('Thành công', 'Đã thêm sản phẩm ${product.tenSP} vào đơn hàng.');
                                      await Future.delayed(const Duration(seconds: 2));
                                      if (mounted) {
                                        setState(() => canScan = true);
                                      }
                                    } else {
                                      // Hiển thị dialog xác nhận
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => Dialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.85,
                                              maxHeight: MediaQuery.of(context).size.height * 0.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.qr_code, color: Colors.blue.shade600, size: 28),
                                                    const SizedBox(width: 12),
                                                    const Text(
                                                      'Xác nhận sản phẩm',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Card(
                                                  elevation: 2,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    side: BorderSide(color: Colors.grey.shade200),
                                                  ),
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          product.tenSP,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          'Mã SP: ${product.maSP}',
                                                          style: TextStyle(color: Colors.grey.shade600),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          'Giá: ${FormatCurrency.format(product.donGia)}',
                                                          style: TextStyle(color: Colors.green.shade600),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        Text(
                                                          'Đơn vị: ${product.donVi}',
                                                          style: TextStyle(color: Colors.grey.shade600),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.end,
                                                  children: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(false),
                                                      child: const Text(
                                                        'Hủy',
                                                        style: TextStyle(color: Colors.grey),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.of(context).pop(true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.blue.shade600,
                                                        foregroundColor: Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                      child: const Text('Thêm sản phẩm'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );

                                      if (confirm == true && mounted) {
                                        _addProductToOrder(product, 1);
                                        _showAlertDialog('Thành công', 'Đã thêm sản phẩm ${product.tenSP} vào đơn hàng.');
                                        await Future.delayed(const Duration(seconds: 2));
                                        if (mounted) {
                                          setState(() => canScan = true);
                                        }
                                      } else {
                                        if (mounted) {
                                          setState(() => canScan = true);
                                        }
                                      }
                                    }
                                  } else {
                                    _showAlertDialog('Lỗi', 'Không tìm thấy sản phẩm với mã barcode: $barcode');
                                    await Future.delayed(const Duration(seconds: 2));
                                    if (mounted) {
                                      setState(() => canScan = true);
                                    }
                                  }
                                } else {
                                  if (mounted) {
                                    setState(() => canScan = true);
                                  }
                                }
                              } else {
                                if (mounted) {
                                  setState(() => canScan = true);
                                }
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Tự động thêm',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: autoAdd,
                                onChanged: (value) async {
                                  setState(() {
                                    autoAdd = value;
                                  });
                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.setBool('autoAddProduct', value);
                                },
                                activeColor: Colors.blue,
                                inactiveThumbColor: Colors.grey,
                                inactiveTrackColor: Colors.grey.shade300,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      // Giải phóng controller
      controller.dispose();
    } catch (e) {
      _showAlertDialog('Lỗi', 'Không thể quét mã barcode: $e');
    }
  }

  Future<void> _editProductQuantity(int index) async {
    final productWithQuantity = _selectedProducts[index];
    final TextEditingController quantityController = TextEditingController(
      text: productWithQuantity.quantity.toString(),
    );

    final newQuantity = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue.shade600, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sửa số lượng cho ${productWithQuantity.product.tenSP}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final quantity = int.tryParse(quantityController.text);
                        if (quantity != null && quantity > 0) {
                          Navigator.of(context).pop(quantity);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (newQuantity != null && newQuantity > 0 && mounted) {
      setState(() {
        _selectedProducts[index] = ProductWithQuantity(
          product: productWithQuantity.product,
          quantity: newQuantity,
        );
      });
    }
  }

  Widget _buildInvoiceNumberSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color.fromARGB(255, 176, 176, 176), width: 0.3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Số hóa đơn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceNumberController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: Icon(Icons.receipt),
              ),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thông tin khách hàng',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<CustomerSelection>(
                    title: const Text('Khách mới', style: TextStyle(fontSize: 14)),
                    value: CustomerSelection.newCustomer,
                    groupValue: _customerSelection,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _customerSelection = value!;
                          _selectedKhachHang = null;
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<CustomerSelection>(
                    title: const Text('Khách đã lưu', style: TextStyle(fontSize: 14)),
                    value: CustomerSelection.savedCustomer,
                    groupValue: _customerSelection,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      if (mounted) {
                        setState(() {
                          _customerSelection = value!;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_customerSelection == CustomerSelection.newCustomer) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Tên khách hàng',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customerPhoneController,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
            if (_customerSelection == CustomerSelection.savedCustomer) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _showCustomerSelectionDialog,
                icon: const Icon(Icons.person_search, size: 18),
                label: const Text('Chọn khách hàng'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedKhachHang != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedKhachHang!.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _selectedKhachHang!.phone,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          if (mounted) {
                            setState(() {
                              _selectedKhachHang = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Vui lòng chọn khách hàng',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: Color.fromARGB(255, 125, 125, 125), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sản phẩm',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showProductSelectionDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Thêm sản phẩm', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedProducts.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'Chưa có sản phẩm nào được chọn',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              )
            else
              ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedProducts.length,
            itemBuilder: (context, index) {
              final item = _selectedProducts[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                elevation: 2,
                color: const Color.fromARGB(255, 255, 255, 255), // Thêm dòng này để đổi màu nền
                shape: RoundedRectangleBorder(
                 borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: const Color.fromARGB(255, 144, 144, 144), // Thêm viền màu xám đậm
                        width: 0.5, // Độ dày của viền
                      ),
                    ),
                  
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column( // Sử dụng Column để sắp xếp tên sản phẩm riêng
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hàng 1: Tên sản phẩm
                      Text(
                        item.product.tenSP,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        softWrap: true,
                      ),
                      const SizedBox(height: 6), // Khoảng cách giữa tên và các thông tin khác
                      
                      // Hàng 2: Số lượng, giá và các nút hành động
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Thông tin số lượng và giá
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Số lượng: ${item.quantity}',
                                style: TextStyle(color: const Color.fromARGB(255, 101, 101, 101)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Giá: ${FormatCurrency.format(item.product.donGia)}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          
                          // Các nút chỉnh sửa và xóa
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editProductQuantity(index),
                                tooltip: 'Sửa số lượng',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeProductFromOrder(index),
                                tooltip: 'Xóa',
                              ),
                            ],
                          ),
                        ],
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
    );
  }

  Widget _buildCostSummarySection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tổng hợp chi phí',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _shippingCostController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Phí vận chuyển',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giảm giá',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng tiền hàng:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  FormatCurrency.format(_calculateTotalProductCost()),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng thanh toán:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                Text(
                  FormatCurrency.format(_calculateTotalOrderCost()),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.grey, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ghi chú',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onEditingComplete: () => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                hintText: 'Nhập ghi chú cho đơn hàng...',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.black),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveOrder(donhang.OrderStatus.draft),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Lưu nháp'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _saveOrder(donhang.OrderStatus.saved),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Lưu đơn'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _showInvoicePreview,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Xem hóa đơn'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.orderToEdit != null ? 'Sửa đơn hàng' : 'Tạo đơn hàng mới'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInvoiceNumberSection(),
                        const SizedBox(height: 20),
                        _buildCustomerSection(),
                        const SizedBox(height: 20),
                        _buildProductSection(),
                        const SizedBox(height: 20),
                        _buildCostSummarySection(),
                        const SizedBox(height: 20),
                        _buildNotesSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildFixedActionButtons(),
              ],
            ),
    );
  }
}