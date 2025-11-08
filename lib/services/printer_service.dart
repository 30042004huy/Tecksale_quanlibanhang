import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img_lib;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:typed_data';
import 'dart:developer';

class PrinterService {
  Function(List<BluetoothDevice>)? onDevicesFound;
  Function(String)? onPrinterConnected;
  NetworkPrinter? _networkPrinter;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  static const int _defaultPort = 9100;

  Future<bool> _checkNetwork() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Không có kết nối mạng');
      }
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (e) {
      log('Lỗi kiểm tra mạng: $e');
      return false;
    }
  }

  Future<void> startBluetoothScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        final devices = results.map((r) => r.device).toList();
        onDevicesFound?.call(devices);
      });
    } catch (e) {
      throw Exception('Lỗi quét Bluetooth: $e');
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> connectBluetoothPrinter(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;
      final services = await device.discoverServices();
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _writeCharacteristic = characteristic;
            break;
          }
        }
        if (_writeCharacteristic != null) break;
      }
      if (_writeCharacteristic == null) {
        throw Exception('Không tìm thấy characteristic để ghi dữ liệu. Kiểm tra quyền và máy in.');
      }
      onPrinterConnected?.call(device.name.isNotEmpty ? device.name : device.id.toString());
    } catch (e) {
      throw Exception('Kết nối Bluetooth thất bại: $e');
    }
  }

  Future<void> connectTcpIpPrinter(String ip) async {
    if (!await _checkNetwork()) {
      throw Exception('Không có kết nối mạng. Vui lòng kiểm tra Wi-Fi.');
    }

    final PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    _networkPrinter = NetworkPrinter(paper, profile);

    try {
      log('Thử kết nối TCP/IP đến $ip:$_defaultPort (RAW)');
      final PosPrintResult res = await _networkPrinter!.connect(ip, port: _defaultPort, timeout: const Duration(seconds: 10));
if (res == PosPrintResult.success) {
  onPrinterConnected?.call('$ip:$_defaultPort');
  log('Kết nối thành công đến $ip:$_defaultPort');
} else {
  log('Kết nối thất bại: ${res.msg}'); // Sử dụng res.msg để log chi tiết hơn thay vì toString()
  // Không throw, chỉ return để không block
}
    } catch (e) {
      log('Lỗi kết nối TCP/IP: $e');
      throw Exception('Không thể kết nối đến máy in tại $ip:$_defaultPort. Lỗi: $e');
    }
  }

  Future<void> printImage(Uint8List imageBytes) async {
    if (_networkPrinter == null && (_connectedDevice == null || _writeCharacteristic == null)) {
      throw Exception('Chưa kết nối máy in. Vui lòng kết nối máy in trước.');
    }
    try {
      log('Bắt đầu xử lý ảnh để in...');
      final img_lib.Image? image = img_lib.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Không thể giải mã ảnh hóa đơn.');
      }
      log('Đã giải mã ảnh, kích thước gốc: ${image.width}x${image.height}');
      final img_lib.Image grayscaleImage = img_lib.grayscale(image);
      final img_lib.Image resizedImage = img_lib.copyResize(grayscaleImage, width: 384); // Giảm kích thước để tối ưu
      log('Đã xử lý ảnh, kích thước mới: ${resizedImage.width}x${resizedImage.height}');

      if (_networkPrinter != null) {
        log('Gửi lệnh in qua TCP/IP...');
        _networkPrinter!.reset();
        _networkPrinter!.text('--- HOA DON ---', styles: const PosStyles(align: PosAlign.center, bold: true));
        _networkPrinter!.imageRaster(resizedImage, imageFn: PosImageFn.graphics);
        _networkPrinter!.text('--- KET THUC ---', styles: const PosStyles(align: PosAlign.center));
        _networkPrinter!.cut();
        log('Đã gửi lệnh in qua TCP/IP');
        await Future.delayed(const Duration(seconds: 2)); // Đợi máy in xử lý
      } else if (_writeCharacteristic != null) {
        log('Gửi lệnh in qua Bluetooth...');
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm80, profile);
        List<int> ticket = [];
        
        ticket += generator.reset();
        ticket += generator.text('--- HOA DON ---', styles: const PosStyles(align: PosAlign.center, bold: true));
        ticket += generator.imageRaster(resizedImage, imageFn: PosImageFn.graphics);
        ticket += generator.text('--- KET THUC ---', styles: const PosStyles(align: PosAlign.center));
        ticket += generator.cut();

        log('Tổng kích thước lệnh in: ${ticket.length} bytes');
        const chunkSize = 512;
        for (var i = 0; i < ticket.length; i += chunkSize) {
          final end = (i + chunkSize < ticket.length) ? i + chunkSize : ticket.length;
          final chunk = ticket.sublist(i, end);
          log('Gửi gói dữ liệu ${i ~/ chunkSize + 1}, kích thước: ${chunk.length} bytes');
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        log('Đã gửi lệnh in qua Bluetooth');
      } else {
        throw Exception('Kết nối máy in đã bị mất.');
      }
    } catch (e) {
      log('Lỗi in ảnh hóa đơn: $e');
      throw Exception('Lỗi in ảnh hóa đơn: $e');
    }
  }

  Future<void> testPrint() async {
    if (_networkPrinter == null && (_connectedDevice == null || _writeCharacteristic == null)) {
      throw Exception('Chưa kết nối máy in. Vui lòng kết nối máy in trước.');
    }
    try {
      log('Bắt đầu in thử ảnh...');
      final ByteData data = await rootBundle.load('assets/images/logoapp.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final img_lib.Image? image = img_lib.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Không thể giải mã ảnh logoapp.png. Kiểm tra đường dẫn.');
      }
      log('Đã giải mã ảnh logo, kích thước gốc: ${image.width}x${image.height}');
      
      final img_lib.Image grayscaleImage = img_lib.grayscale(image);
      final img_lib.Image resizedImage = img_lib.copyResize(grayscaleImage, width: 384);
      log('Đã xử lý ảnh logo, kích thước mới: ${resizedImage.width}x${resizedImage.height}');

      if (_networkPrinter != null) {
        log('Gửi lệnh in thử qua TCP/IP...');
        _networkPrinter!.reset();
        _networkPrinter!.text('--- IN THỬ ẢNH ---', styles: const PosStyles(align: PosAlign.center, bold: true));
        _networkPrinter!.imageRaster(resizedImage, imageFn: PosImageFn.graphics);
        _networkPrinter!.text('--- KET THUC ---', styles: const PosStyles(align: PosAlign.center));
        _networkPrinter!.cut();
        log('Đã gửi lệnh in thử qua TCP/IP');
        await Future.delayed(const Duration(seconds: 2));
      } else if (_writeCharacteristic != null) {
        log('Gửi lệnh in thử qua Bluetooth...');
        final profile = await CapabilityProfile.load();
        final generator = Generator(PaperSize.mm80, profile);
        List<int> ticket = [];
        
        ticket += generator.reset();
        ticket += generator.text('--- IN THỬ ẢNH ---', styles: const PosStyles(align: PosAlign.center, bold: true));
        ticket += generator.imageRaster(resizedImage, imageFn: PosImageFn.graphics);
        ticket += generator.text('--- KET THUC ---', styles: const PosStyles(align: PosAlign.center));
        ticket += generator.cut();

        log('Tổng kích thước lệnh in thử: ${ticket.length} bytes');
        const chunkSize = 512;
        for (var i = 0; i < ticket.length; i += chunkSize) {
          final end = (i + chunkSize < ticket.length) ? i + chunkSize : ticket.length;
          final chunk = ticket.sublist(i, end);
          log('Gửi gói dữ liệu in thử ${i ~/ chunkSize + 1}, kích thước: ${chunk.length} bytes');
          await _writeCharacteristic!.write(chunk, withoutResponse: true);
          await Future.delayed(const Duration(milliseconds: 100));
        }
        log('Đã gửi lệnh in thử qua Bluetooth');
      } else {
        throw Exception('Kết nối máy in đã bị mất.');
      }
    } catch (e) {
      log('Lỗi in thử ảnh: $e');
      throw Exception('Lỗi in thử ảnh: $e');
    }
  }

  Future<String?> getConnectedBluetoothId() async {
    return _connectedDevice?.id.toString();
  }

  Future<BluetoothDevice> reconnectBluetoothPrinter(String id) async {
    try {
      final targetGuid = Guid(id);
      final connectedDevices = await FlutterBluePlus.connectedSystemDevices;
      
      final device = connectedDevices.firstWhere(
        (d) => d.id == targetGuid,
        orElse: () => throw Exception('Không tìm thấy thiết bị $id đang kết nối/ghép đôi.'),
      );
      return device;
    } catch (e) {
      log('Lỗi tìm thiết bị đang kết nối: $e. Bắt đầu quét ngắn...');
      
      final targetGuid = Guid(id);
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      
      BluetoothDevice? foundDevice;
      await for (final results in FlutterBluePlus.scanResults) {
        for (final result in results) {
          if (result.device.id == targetGuid) {
            foundDevice = result.device;
            await FlutterBluePlus.stopScan();
            break;
          }
        }
        if (foundDevice != null) break;
      }
      
      if (foundDevice != null) {
        return foundDevice;
      } else {
        await FlutterBluePlus.stopScan();
        throw Exception('Thiết bị Bluetooth $id không được tìm thấy sau khi quét.');
      }
    }
  }

void dispose() {
  try {
    _networkPrinter?.disconnect();
  } catch (e) {
    log('Lỗi disconnect network printer: $e');
  }
  try {
    _connectedDevice?.disconnect();
  } catch (e) {
    log('Lỗi disconnect Bluetooth: $e');
  }
  _networkPrinter = null;
  _connectedDevice = null;
  _writeCharacteristic = null;
  log('Đã ngắt kết nối máy in và giải phóng tài nguyên');
}
}