// lib/services/saveimage_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

// ✨ 1. IMPORT CÁC THƯ VIỆN MỚI
import 'package:flutter/foundation.dart' show kIsWeb; // Để kiểm tra web
import 'package:file_saver/file_saver.dart'; // Plugin mới

class SaveImageService {
  
  // ✨ SỬA LỖI 2: Thêm 'return true;' ở cuối
  static Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      if (!status.isGranted && await Permission.storage.isGranted) {
        return await Permission.storage.request().isGranted;
      }
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return status.isGranted;
    } else if (Platform.isIOS) {
      final photoStatus = await Permission.photos.request();
      if (photoStatus.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      return photoStatus.isGranted;
    }
    return true; // ✨ THÊM DÒNG NÀY ĐỂ SỬA LỖI BUILD
  }

  // (Hàm captureWidget giữ nguyên, không thay đổi)
  static Future<Uint8List?> captureWidget(GlobalKey key, {double pixelRatio = 5.0}) async {
    // ... (giữ nguyên code cũ) ...
  }


  // ✨ 2. SỬA LẠI HÀM saveImageToGallery
  static Future<Map<String, dynamic>> saveImageToGallery(GlobalKey key, {String? fileName}) async {
    // Tự động kiểm tra nền tảng
    if (kIsWeb) {
      // Nếu là WEB, chạy logic tải file (không dùng saver_gallery)
      return await _saveImageForWeb(key, fileName: fileName);
    } else {
      // Nếu là Mobile (Android/iOS), chạy logic lưu vào thư viện ảnh
      return await _saveImageForMobile(key, fileName: fileName);
    }
  }


  // ✨ 3. HÀM MỚI CHO WEB (Dùng file_saver)
  static Future<Map<String, dynamic>> _saveImageForWeb(GlobalKey key, {String? fileName}) async {
    try {
      final imageBytes = await captureWidget(key, pixelRatio: 5.0);
      if (imageBytes == null) {
        return {'isSuccess': false, 'error': 'Không thể chụp ảnh hóa đơn.'};
      }

      String finalFileName = fileName ?? 'hoadon_${DateTime.now().millisecondsSinceEpoch}.png';

      await FileSaver.instance.saveFile(
        name: finalFileName,
        bytes: imageBytes,
        mimeType: MimeType.png,
      );

      return {
        'isSuccess': true,
        'message': 'Đã bắt đầu tải ảnh hóa đơn!',
      };

    } catch (e) {
      return {'isSuccess': false, 'error': 'Lỗi khi lưu ảnh web: $e'};
    }
  }


  // ✨ 4. HÀM CŨ CHO MOBILE (ĐÃ SỬA LỖI 1)
  static Future<Map<String, dynamic>> _saveImageForMobile(GlobalKey key, {String? fileName}) async {
    try {
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        return {
          'isSuccess': false,
          'error': 'Không có quyền truy cập thư viện ảnh.',
        };
      }

      final imageBytes = await captureWidget(key, pixelRatio: 5.0);
      if (imageBytes == null) {
        return {
          'isSuccess': false,
          'error': 'Không thể chụp ảnh hóa đơn.',
        };
      }

      final result = await SaverGallery.saveImage(
        imageBytes,
        fileName: fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.png',
        quality: 100,
        androidRelativePath: "Pictures/TeckSale Invoices",
        skipIfExists: false, // ✨ THÊM DÒNG NÀY ĐỂ SỬA LỖI BUILD
      );

      if (result.isSuccess) {
        return {
          'isSuccess': true,
          'message': 'Đã lưu ảnh hóa đơn vào thư viện ảnh!',
        };
      } else {
        return {
          'isSuccess': false,
          'error': 'Không thể lưu ảnh vào thư viện.',
        };
      }
    } catch (e) {
      return {
        'isSuccess': false,
        'error': 'Lỗi khi lưu ảnh: $e',
      };
    }
  }
}