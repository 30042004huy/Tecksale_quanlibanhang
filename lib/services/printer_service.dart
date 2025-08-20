import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart' show rootBundle;

class PrinterService {
  Function(List<BluetoothDevice>)? onDevicesFound;
  Function(String)? onPrinterConnected;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;

  void startBluetoothScan(Function(List<BluetoothDevice>) onDevicesFound) async {
    this.onDevicesFound = onDevicesFound;
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      FlutterBluePlus.scanResults.listen((results) {
        final devices = results.map((r) => r.device).toList();
        onDevicesFound(devices);
      });
    } catch (e) {
      rethrow;
    } finally {
      await FlutterBluePlus.stopScan();
    }
  }

  Future<void> connectBluetoothPrinter(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;

      // Discover services and find a writable characteristic
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
        throw Exception('Không tìm thấy characteristic để ghi dữ liệu');
      }

      onPrinterConnected?.call(device.name.isNotEmpty ? device.name : device.id.toString());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reconnectBluetoothPrinter(String printerName) async {
    try {
      final devices = await FlutterBluePlus.connectedDevices;
      final device = devices.firstWhere(
        (d) => d.name == printerName || d.id.toString() == printerName,
        orElse: () => throw Exception('Máy in không tìm thấy'),
      );
      await connectBluetoothPrinter(device);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> testPrintLogo() async {
    if (_connectedDevice == null || _writeCharacteristic == null) {
      throw Exception('Chưa kết nối máy in hoặc không tìm thấy characteristic');
    }

    try {
      final imageBytes = await rootBundle.load('assets/images/logoapp.png');
      final bytes = imageBytes.buffer.asUint8List();

      // Send raw PNG bytes to the printer (driver handles formatting)
      const chunkSize = 512; // Split into chunks to avoid overflow
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await _writeCharacteristic!.write(chunk, withoutResponse: true);
      }
    } catch (e) {
      rethrow;
    }
  }

  void dispose() {
    _connectedDevice?.disconnect();
    FlutterBluePlus.stopScan();
    _writeCharacteristic = null;
  }
}