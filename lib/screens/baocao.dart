import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/donhang_model.dart' hide FormatCurrency;
import '../models/sanpham_model.dart';
import '../utils/format_currency.dart';

class BaoCaoScreen extends StatefulWidget {
  const BaoCaoScreen({Key? key}) : super(key: key);

  @override
  _BaoCaoScreenState createState() => _BaoCaoScreenState();
}

class _BaoCaoScreenState extends State<BaoCaoScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  DateTime? _startDate; // For date range
  DateTime? _endDate; // For date range
  String _selectedPeriod = 'Ngày'; // Ngày, Tuần, Tháng, Khoảng
  bool _isLoading = false;
  bool _showProfit = false;
  
  List<OrderData> _completedOrders = [];
  List<SanPham> _allProducts = [];
  Map<String, double> _revenueByInvoice = {};
  Map<String, double> _profitByInvoice = {};
  
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      
      final userId = user.uid;
      
      print('DEBUG: Loading data for user: $userId');
      
      await _loadCompletedOrders(userId);
      await _loadAllProducts(userId);
      _calculateRevenueAndProfit();
      
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadCompletedOrders(String userId) async {
    try {
      print('DEBUG: Loading completed orders from: nguoidung/$userId/donhang/completed');
      final snapshot = await _dbRef.child('nguoidung/$userId/donhang/completed').get();
      
      if (snapshot.exists) {
        final Map<dynamic, dynamic> ordersMap = snapshot.value as Map<dynamic, dynamic>;
        final List<OrderData> orders = [];
        
        print('DEBUG: Found ${ordersMap.length} completed orders');
        
        ordersMap.forEach((key, value) {
          try {
            print('DEBUG: Processing order key: $key');
            final orderData = OrderData.fromMap(Map<String, dynamic>.from(value));
            orders.add(orderData);
            print('DEBUG: Successfully parsed order: ${orderData.orderId}');
          } catch (e) {
            print('Error parsing order $key: $e');
            print('Raw value: $value');
          }
        });
        
        setState(() {
          _completedOrders = orders;
        });
        
        print('DEBUG: Loaded ${orders.length} completed orders successfully');
      } else {
        print('DEBUG: No completed orders found');
        setState(() {
          _completedOrders = [];
        });
      }
    } catch (e) {
      print('Error loading completed orders: $e');
      setState(() {
        _completedOrders = [];
      });
    }
  }
  
  Future<void> _loadAllProducts(String userId) async {
    try {
      print('DEBUG: Loading products from: nguoidung/$userId/sanpham');
      final snapshot = await _dbRef.child('nguoidung/$userId/sanpham').get();
      
      if (snapshot.exists) {
        final Map<dynamic, dynamic> productsMap = snapshot.value as Map<dynamic, dynamic>;
        final List<SanPham> products = [];
        
        print('DEBUG: Found ${productsMap.length} products');
        
        productsMap.forEach((key, value) {
          try {
            print('DEBUG: Processing product key: $key');
            final product = SanPham.fromMap(Map<String, dynamic>.from(value), key.toString());
            products.add(product);
            print('DEBUG: Successfully parsed product: ${product.tenSP} with giaNhap: ${product.giaNhap}');
          } catch (e) {
            print('Error parsing product $key: $e');
            print('Raw value: $value');
          }
        });
        
        setState(() {
          _allProducts = products;
        });
        
        print('DEBUG: Loaded ${products.length} products successfully');
      } else {
        print('DEBUG: No products found');
        setState(() {
          _allProducts = [];
        });
      }
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _allProducts = [];
      });
    }
  }
  
  void _calculateRevenueAndProfit() {
    _revenueByInvoice.clear();
    _profitByInvoice.clear();
    
    print('DEBUG: Calculating revenue and profit for ${_completedOrders.length} orders');
    print('DEBUG: Available products: ${_allProducts.length}');
    
    for (final order in _completedOrders) {
      print('DEBUG: Processing order: ${order.orderId}');
      
      final revenue = order.totalAmount - order.shippingCost;
      _revenueByInvoice[order.orderId] = revenue;
      print('DEBUG: Order ${order.orderId} - Total: ${order.totalAmount}, Shipping: ${order.shippingCost}, Revenue: $revenue');
      
      double costOfGoodsSold = 0.0;
      for (final item in order.items) {
        print('DEBUG: Processing item: ${item.name} (ID: ${item.productId})');
        
        final product = _allProducts.firstWhere(
          (p) => p.id == item.productId,
          orElse: () {
            print('DEBUG: Product not found for ID: ${item.productId}, creating fallback');
            return SanPham(
              id: item.productId,
              maSP: '',
              tenSP: item.name,
              donGia: item.unitPrice,
              donVi: item.unit,
              giaNhap: 0.0,
            );
          },
        );
        
        final costPerUnit = product.giaNhap ?? 0.0;
        final itemCost = costPerUnit * item.quantity;
        costOfGoodsSold += itemCost;
        
        print('DEBUG: Item ${item.name} - Quantity: ${item.quantity}, Cost per unit: $costPerUnit, Total cost: $itemCost');
      }
      
      final profit = revenue - costOfGoodsSold;
      _profitByInvoice[order.orderId] = profit;
      
      print('DEBUG: Order ${order.orderId} - Cost of goods sold: $costOfGoodsSold, Profit: $profit');
    }
    
    print('DEBUG: Revenue map: $_revenueByInvoice');
    print('DEBUG: Profit map: $_profitByInvoice');
  }
  
  List<OrderData> _getFilteredOrders() {
    print('DEBUG: Filtering orders - Total completed orders: ${_completedOrders.length}');
    print('DEBUG: Selected period: $_selectedPeriod, Selected date: $_selectedDate');
    
    final filteredOrders = _completedOrders.where((order) {
      final orderDate = order.orderDate;
      print('DEBUG: Checking order ${order.orderId} with date: $orderDate');
      
      bool matches = false;
      switch (_selectedPeriod) {
        case 'Ngày':
          matches = orderDate.year == _selectedDate.year &&
                   orderDate.month == _selectedDate.month &&
                   orderDate.day == _selectedDate.day;
          print('DEBUG: Day filter - Order date: ${orderDate.day}/${orderDate.month}/${orderDate.year}, Selected: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}, Matches: $matches');
          break;
        case 'Tuần':
          final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
          final endOfWeek = startOfWeek.add(Duration(days: 6));
          matches = orderDate.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
                   orderDate.isBefore(endOfWeek.add(Duration(days: 1)));
          print('DEBUG: Week filter - Start: $startOfWeek, End: $endOfWeek, Order date: $orderDate, Matches: $matches');
          break;
        case 'Tháng':
          matches = orderDate.year == _selectedDate.year &&
                   orderDate.month == _selectedDate.month;
          print('DEBUG: Month filter - Order date: ${orderDate.month}/${orderDate.year}, Selected: ${_selectedDate.month}/${_selectedDate.year}, Matches: $matches');
          break;
        case 'Khoảng':
          if (_startDate != null && _endDate != null) {
            matches = orderDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                     orderDate.isBefore(_endDate!.add(Duration(days: 1)));
            print('DEBUG: Range filter - Start: $_startDate, End: $_endDate, Order date: $orderDate, Matches: $matches');
          }
          break;
        default:
          matches = false;
      }
      
      return matches;
    }).toList();
    
    print('DEBUG: Filtered orders count: ${filteredOrders.length}');
    return filteredOrders;
  }
  
  Future<void> _selectDate() async {
    if (_selectedPeriod == 'Khoảng') {
      await _selectDateRange();
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      
      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
  
  void _showOrderDetails(OrderData order) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final revenue = _revenueByInvoice[order.orderId] ?? 0;
        final profit = _profitByInvoice[order.orderId] ?? 0;
        
        return AlertDialog(
          titlePadding: const EdgeInsets.all(20),
          title: Text(
            'Chi tiết đơn hàng: ${order.orderId}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Khách hàng', order.customerName, Icons.person),
                  _buildDetailRow('SĐT', order.customerPhone, Icons.phone),
                  _buildDetailRow(
                    'Ngày tạo',
                    DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate),
                    Icons.calendar_today,
                  ),
                  _buildDetailRow('Trạng thái', 'Hoàn tất', Icons.check_circle, color: Colors.green),
                  
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Sản phẩm:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Divider(height: 10, thickness: 1),
                  
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildItemRow(item),
                  )),
                  
                  const Divider(height: 20, thickness: 1),
                  
                  _buildSummaryRow('Tổng tiền', order.totalAmount),
                  _buildSummaryRow('Giảm giá', order.discount, isNegative: true),
                  _buildSummaryRow('Phí vận chuyển', order.shippingCost, isNegative: true),
                  
                  const Divider(height: 20, thickness: 2),
                  
                  _buildFinalSummaryRow(
                    'Doanh thu',
                    revenue,
                    color: Colors.green.shade700,
                  ),
                  _buildFinalSummaryRow(
                    'Lợi nhuận',
                    profit,
                    color: profit >= 0 ? Colors.orange.shade700 : Colors.red,
                  ),
                ],
              ),
            ),
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

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15, color: color ?? Colors.black),
              overflow: TextOverflow.clip,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, double amount, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          Text(
            isNegative
              ? '- ${FormatCurrency.format(amount.abs())}'
              : FormatCurrency.format(amount.abs()),
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSummaryRow(String label, double amount, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            FormatCurrency.format(amount),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.shopping_basket, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                overflow: TextOverflow.clip,
                softWrap: true,
              ),
              Text(
                '${item.quantity} ${item.unit} x ${FormatCurrency.format(item.unitPrice)}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Text(
          FormatCurrency.format(item.unitPrice * item.quantity),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _getFilteredOrders();
    final totalRevenue = filteredOrders.fold<double>(
      0.0, (sum, order) => sum + (_revenueByInvoice[order.orderId] ?? 0)
    );
    final totalProfit = filteredOrders.fold<double>(
      0.0, (sum, order) => sum + (_profitByInvoice[order.orderId] ?? 0)
    );
    
    print('DEBUG: Build - Filtered orders: ${filteredOrders.length}');
    print('DEBUG: Build - Total revenue: $totalRevenue');
    print('DEBUG: Build - Total profit: $totalProfit');
    print('DEBUG: Build - Revenue map keys: ${_revenueByInvoice.keys.toList()}');
    print('DEBUG: Build - Profit map keys: ${_profitByInvoice.keys.toList()}');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color.fromARGB(255, 30, 154, 255),
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          tabs: const [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Doanh thu'),
            Tab(text: 'Lợi nhuận'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Chọn kỳ báo cáo',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Ngày', 'Tuần', 'Tháng', 'Khoảng'].map((period) {
                      return DropdownMenuItem(
                        value: period,
                        child: Text(period),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriod = value!;
                        if (_selectedPeriod != 'Khoảng') {
                          _startDate = null;
                          _endDate = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Text(
                                _selectedPeriod == 'Ngày' 
                                  ? DateFormat('dd/MM/yyyy').format(_selectedDate)
                                  : _selectedPeriod == 'Tuần'
                                    ? 'Tuần từ ngày ${DateFormat('dd/MM').format(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)))}'
                                    : _selectedPeriod == 'Tháng'
                                      ? DateFormat('MM/yyyy').format(_selectedDate)
                                      : _startDate != null && _endDate != null
                                        ? 'Từ ${DateFormat('dd/MM/yyyy').format(_startDate!)} - Đến ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                                        : 'Chọn khoảng thời gian',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(filteredOrders, totalRevenue, totalProfit),
                    _buildRevenueTab(filteredOrders),
                    _buildProfitTab(filteredOrders),
                  ],
                ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isProfitCard = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            isProfitCard && !_showProfit
                ? Icon(Icons.visibility_off_outlined, color: Colors.grey)
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(List<OrderData> filteredOrders, double totalRevenue, double totalProfit) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
            title: 'Tổng đơn hàng',
            value: '${filteredOrders.length}',
            icon: Icons.shopping_bag_outlined,
            color: Colors.blue.shade400,
          ),
          _buildSummaryCard(
            title: 'Doanh thu',
            value: FormatCurrency.format(totalRevenue),
            icon: Icons.attach_money,
            color: Colors.green.shade400,
          ),
          _buildSummaryCard(
            title: 'Lợi nhuận',
            value: FormatCurrency.format(totalProfit),
            icon: Icons.trending_up,
            color: Colors.orange.shade400,
            isProfitCard: true,
            onTap: () {
              setState(() {
                _showProfit = !_showProfit;
              });
            }
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Danh sách đơn hàng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (filteredOrders.isEmpty)
            Center(
              child: Column(
                children: [
                  const Text(
                    'Không có đơn hàng nào trong kỳ này',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tổng đơn hàng hoàn tất: ${_completedOrders.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  Text(
                    'Tổng sản phẩm: ${_allProducts.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.receipt_long, color: Colors.white),
                    ),
                    title: Text('Đơn hàng: ${order.orderId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Khách hàng: ${order.customerName}'),
                        Text('Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(order.orderDate)}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Doanh thu:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          FormatCurrency.format(_revenueByInvoice[order.orderId] ?? 0),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueTab(List<OrderData> filteredOrders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Báo cáo doanh thu',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (filteredOrders.isEmpty)
            Center(
              child: Column(
                children: [
                  const Text(
                    'Không có đơn hàng nào trong kỳ này',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tổng đơn hàng hoàn tất: ${_completedOrders.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  Text(
                    'Tổng sản phẩm: ${_allProducts.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                final revenue = _revenueByInvoice[order.orderId] ?? 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.attach_money, color: Colors.white),
                    ),
                    title: Text('Hóa đơn: ${order.orderId}'),
                    subtitle: Text('Khách hàng: ${order.customerName}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatCurrency.format(revenue),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(order.orderDate),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildProfitTab(List<OrderData> filteredOrders) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Báo cáo lợi nhuận',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (filteredOrders.isEmpty)
            Center(
              child: Column(
                children: [
                  const Text(
                    'Không có đơn hàng nào trong kỳ này',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tổng đơn hàng hoàn tất: ${_completedOrders.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                  Text(
                    'Tổng sản phẩm: ${_allProducts.length}',
                    style: const TextStyle(color: Colors.blue, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                final profit = _profitByInvoice[order.orderId] ?? 0;
                final revenue = _revenueByInvoice[order.orderId] ?? 0;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: profit >= 0 ? Colors.orange : Colors.red,
                      child: Icon(
                        profit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: Colors.white,
                      ),
                    ),
                    title: Text('Hóa đơn: ${order.orderId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Khách hàng: ${order.customerName}'),
                        Text('Doanh thu: ${FormatCurrency.format(revenue)}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          FormatCurrency.format(profit),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: profit >= 0 ? Colors.orange : Colors.red,
                          ),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(order.orderDate),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}