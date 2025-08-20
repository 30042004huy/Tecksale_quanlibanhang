import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

class SaveImageService {
  /// Yêu cầu quyền truy cập bộ nhớ hoặc ảnh.
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
    return true;
  }

  /// Chụp ảnh widget với chất lượng cao.
  static Future<Uint8List?> captureWidget(GlobalKey key, {double pixelRatio = 5.0}) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }
      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Lỗi khi chụp ảnh widget: $e');
      return null;
    }
  }

  /// Lưu ảnh vào thư viện với chất lượng cao và tên file tùy chỉnh.
  static Future<Map<String, dynamic>> saveImageToGallery(GlobalKey key, {String? fileName}) async {
    try {
      // Yêu cầu quyền
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        return {
          'isSuccess': false,
          'error': 'Không có quyền truy cập thư viện ảnh.',
        };
      }

      // Chụp ảnh widget
      final imageBytes = await captureWidget(key, pixelRatio: 5.0);
      if (imageBytes == null) {
        return {
          'isSuccess': false,
          'error': 'Không thể chụp ảnh hóa đơn.',
        };
      }

      // Lưu ảnh vào thư viện
      final result = await SaverGallery.saveImage(
        imageBytes,
        fileName: fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.png',
        quality: 100,
        androidRelativePath: "Pictures/TeckSale Invoices",
        skipIfExists: false,
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