// lib/screens/website_products_screen.dart
// (NÂNG CẤP: THÊM SẮP XẾP)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sanpham_model.dart';
import '../utils/format_currency.dart';
import 'website_product_edit_screen.dart';
import 'add_website_product_screen.dart'; 

class WebsiteProductsScreen extends StatefulWidget {
  const WebsiteProductsScreen({super.key});

  @override
  State<WebsiteProductsScreen> createState() => _WebsiteProductsScreenState();
}

class _WebsiteProductsScreenState extends State<WebsiteProductsScreen> {
  final dbRef = FirebaseDatabase.instance.ref();
  User? user = FirebaseAuth.instance.currentUser;

  Map<String, dynamic> _publicProducts = {};
  Map<String, SanPham> _privateProductsMap = {};
  
  bool _isLoading = true;
  String _searchText = '';
  // ✨ 1. THÊM STATE SẮP XẾP
  String _sortOrder = 'timestamp'; // 'timestamp' hoặc 'thuTu'

  StreamSubscription? _privateSub;
  StreamSubscription? _publicSub;

  @override
  void initState() {
    super.initState();
    if (user != null) {
      _listenToPrivateProducts();
      _listenToPublicProducts();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _privateSub?.cancel();
    _publicSub?.cancel();
    super.dispose();
  }

  void _listenToPrivateProducts() {
    _privateSub = dbRef
        .child('nguoidung/${user!.uid}/sanpham')
        .onValue
        .listen((event) {
      final Map<String, SanPham> tempMap = {};
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          try {
            tempMap[key] = SanPham.fromMap(value, key);
          } catch (e) { print('Lỗi parse sản phẩm: $key, $e'); }
        });
      }
      setStateIfMounted(() => _privateProductsMap = tempMap);
      _checkLoading();
    });
  }

  void _listenToPublicProducts() {
    _publicSub = dbRef
        .child('website_data/${user!.uid}/products')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final Map<dynamic, dynamic> rawData = event.snapshot.value as Map<dynamic, dynamic>;
        final Map<String, dynamic> correctlyTypedMap = {};
        rawData.forEach((key, value) {
          if (key is String && value is Map) {
            correctlyTypedMap[key] = Map<String, dynamic>.from(value);
          }
        });
        setStateIfMounted(() => _publicProducts = correctlyTypedMap);
      } else {
        setStateIfMounted(() => _publicProducts = {});
      }
      _checkLoading();
    });
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  void _checkLoading() {
    if (_privateSub != null && _publicSub != null && _isLoading) {
      setStateIfMounted(() => _isLoading = false);
    }
  }

  // ✨ 2. CẬP NHẬT HÀM LỌC VÀ SẮP XẾP
  List<MapEntry<String, dynamic>> get _filteredPublicProducts {
    List<MapEntry<String, dynamic>> list = _publicProducts.entries.toList();
    
    // Sắp xếp
    list.sort((a, b) {
      if (_sortOrder == 'thuTu') {
        // Sắp xếp theo Thứ Tự (nhỏ lên trước)
        final num orderA = (a.value['thuTu'] as num?) ?? 9999;
        final num orderB = (b.value['thuTu'] as num?) ?? 9999;
        return orderA.compareTo(orderB);
      } else {
        // Sắp xếp theo Timestamp (mới lên trước)
        final num timeA = (a.value['timestamp'] as num?) ?? 0;
        final num timeB = (b.value['timestamp'] as num?) ?? 0;
        return timeB.compareTo(timeA);
      }
    });

    if (_searchText.isEmpty) return list;
    
    return list.where((entry) {
        final data = entry.value;
        final String tenSP = data['tenSP']?.toString().toLowerCase() ?? '';
        final String maSP = data['maSP']?.toString().toLowerCase() ?? '';
        return tenSP.contains(_searchText.toLowerCase()) || 
               maSP.contains(_searchText.toLowerCase());
      }).toList();
  }
  
  void _navigateToAddProduct() {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddWebsiteProductScreen(
          privateProductsMap: _privateProductsMap,
          publicProductIds: _publicProducts.keys.toSet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sản phẩm Website', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Thêm sản phẩm lên web',
            onPressed: _navigateToAddProduct,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ✨ 3. THANH TÌM KIẾM VÀ SẮP XẾP
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm sản phẩm...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _searchText = value),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortOrder,
                      icon: const Icon(Icons.sort),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(value: 'timestamp', child: Text('Mới nhất')),
                        DropdownMenuItem(value: 'thuTu', child: Text('Thứ tự Web')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _sortOrder = value);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _publicProducts.isEmpty
                    ? Center(child: Text('Chưa có sản phẩm nào được đăng lên web.', style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _filteredPublicProducts.length,
                        itemBuilder: (context, index) {
                          final entry = _filteredPublicProducts[index];
                          final String publicProductId = entry.key;
                          final Map<String, dynamic> publicData = entry.value;
                          final SanPham? privateData = _privateProductsMap[publicProductId];
                          
                          final int tonKho = privateData?.tonKho ?? 0;
                          final double giaBan = (publicData['giaBan'] as num?)?.toDouble() ?? 0.0;
                          final int thuTu = (publicData['thuTu'] as num?)?.toInt() ?? 999;

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              // ✨ 4. HIỂN THỊ THỨ TỰ
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  thuTu == 999 ? 'N/A' : thuTu.toString(),
                                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                ),
                              ),
                              title: Text(publicData['tenSP'] ?? 'Lỗi tên', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Tồn kho: $tonKho - Giá web: ${FormatCurrency.format(giaBan)}',
                                style: GoogleFonts.roboto(color: Colors.grey.shade600),
                              ),
                              trailing: const Icon(Icons.edit, color: Colors.blue),
                              onTap: () {
                                if(privateData == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Lỗi: Không tìm thấy sản phẩm gốc!'), backgroundColor: Colors.red,)
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WebsiteProductEditScreen(
                                      privateProduct: privateData,
                                      publicData: publicData,
                                      publicProductId: publicProductId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}