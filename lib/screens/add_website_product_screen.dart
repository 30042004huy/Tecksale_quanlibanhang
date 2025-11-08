// lib/screens/add_website_product_screen.dart
// (NÂNG CẤP: SẮP XẾP A-Z, ẨN GIÁ VỐN)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/sanpham_model.dart';
import '../utils/format_currency.dart';
import 'website_product_edit_screen.dart';

class AddWebsiteProductScreen extends StatefulWidget {
  final Map<String, SanPham> privateProductsMap;
  final Set<String> publicProductIds; // Set các ID đã có trên web

  const AddWebsiteProductScreen({
    super.key,
    required this.privateProductsMap,
    required this.publicProductIds,
  });

  @override
  State<AddWebsiteProductScreen> createState() => _AddWebsiteProductScreenState();
}

class _AddWebsiteProductScreenState extends State<AddWebsiteProductScreen> {
  String _searchText = '';

  List<SanPham> get _availableProducts {
    var list = widget.privateProductsMap.values.where((sp) {
      return !widget.publicProductIds.contains(sp.id);
    }).toList();

    // ✨ 1. SẮP XẾP THEO MÃ SP (A-Z)
    list.sort((a, b) => a.maSP.toLowerCase().compareTo(b.maSP.toLowerCase()));

    if (_searchText.isEmpty) return list;
    return list
        .where((sp) =>
            sp.tenSP.toLowerCase().contains(_searchText.toLowerCase()) ||
            sp.maSP.toLowerCase().contains(_searchText.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thêm sản phẩm lên Web', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm theo Tên hoặc Mã SP...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),
          ),
          Expanded(
            child: _availableProducts.isEmpty
                ? Center(
                    child: Text(
                      _searchText.isEmpty
                          ? 'Tất cả sản phẩm đã ở trên web.'
                          : 'Không tìm thấy sản phẩm nào.',
                      style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _availableProducts.length,
                    itemBuilder: (context, index) {
                      final product = _availableProducts[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(product.tenSP, style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
                          // ✨ 2. CHỈ HIỂN THỊ GIÁ BÁN (donGia) VÀ TỒN KHO
                          subtitle: Text(
                            'Mã: ${product.maSP}\nGiá Bán: ${FormatCurrency.format(product.donGia)} - Tồn kho: ${product.tonKho ?? 0}',
                            style: GoogleFonts.roboto(color: Colors.grey.shade600, height: 1.4),
                          ),
                          trailing: const Icon(Icons.add_circle, color: Colors.green, size: 28),
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WebsiteProductEditScreen(
                                  privateProduct: product,
                                  publicData: null,
                                  publicProductId: null,
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