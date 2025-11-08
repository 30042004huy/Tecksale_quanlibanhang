import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tecksale_quanlybanhang/services/printer_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:developer';

class CaiDatMayInScreen extends StatefulWidget {
  const CaiDatMayInScreen({super.key});

  @override
  _CaiDatMayInScreenState createState() => _CaiDatMayInScreenState();
}

class _CaiDatMayInScreenState extends State<CaiDatMayInScreen> {
  final PrinterService _printerService = PrinterService();
  final TextEditingController _printerNameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController(text: '192.168.1.100'); // IP mặc định
  String _connectionType = 'TCP/IP';
  List<Map<String, dynamic>> _savedPrinters = [];
  bool _isScanning = false;
  bool _isLoading = false;
  List<BluetoothDevice> _bluetoothDevices = [];

  @override
  void initState() {
    super.initState();
    _loadSavedPrinters();
    // Bắt sự kiện tìm thấy thiết bị Bluetooth
    _printerService.onDevicesFound = (devices) {
      if (mounted) {
        setState(() {
          _bluetoothDevices = devices;
          _isScanning = false;
        });
        _showSnackBar('Đã tìm thấy ${devices.length} thiết bị Bluetooth.', Colors.green);
      }
    };
    // Bắt sự kiện kết nối thành công
    _printerService.onPrinterConnected = (name) {
      if (mounted) {
        _showSnackBar('Kết nối máy in thành công: $name', Colors.green);
      }
    };
  }

  // HÀM HIỂN THỊ CẢNH BÁO DƯỚI DẠNG POPUP (SnackBar)
  void _showSnackBar(String message, Color color) {
    if (mounted) {
      // Loại bỏ tiền tố 'Exception: ' cho tin nhắn lỗi
      final cleanMessage = message.replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cleanMessage),
          backgroundColor: color,
        ),
      );
    }
  }

  Future<void> _loadSavedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() => _isLoading = true);
    
    try {
      // Tải từ Firebase (nếu có)
      if (user != null) {
        final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/printers');
        final snapshot = await ref.get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          _savedPrinters = data.values.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      // Tải từ Local (nếu có)
      final savedPrintersJson = prefs.getString('saved_printers');
      if (savedPrintersJson != null) {
        _savedPrinters = (jsonDecode(savedPrintersJson) as List<dynamic>).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      _showSnackBar('Lỗi tải máy in: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePrinter() async {
    if (_printerNameController.text.isEmpty || (_connectionType == 'TCP/IP' && _ipController.text.isEmpty)) {
      _showSnackBar('Vui lòng nhập tên và thông tin máy in', Colors.orange);
      return;
    }
    
    // Kiểm tra xem đã kết nối Bluetooth chưa nếu chọn loại Bluetooth
    if (_connectionType == 'Bluetooth' && _printerService.getConnectedBluetoothId() == null) {
       _showSnackBar('Vui lòng kết nối với thiết bị Bluetooth trước khi lưu.', Colors.orange);
       return;
    }

    setState(() => _isLoading = true);
    try {
      final printer = {
        'printerName': _printerNameController.text,
        'connectionType': _connectionType,
        'ip': _connectionType == 'TCP/IP' ? _ipController.text : null,
        'bluetoothId': _connectionType == 'Bluetooth' ? await _printerService.getConnectedBluetoothId() : null,
        'isDefault': _savedPrinters.isEmpty,
      };
      _savedPrinters.add(printer);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_printers', jsonEncode(_savedPrinters));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/printers/${printer['printerName']}');
        await ref.set(printer);
      }

      _showSnackBar('Lưu máy in thành công', Colors.green);
      _printerNameController.clear();
      _ipController.clear();
    } catch (e) {
      _showSnackBar('Lỗi lưu máy in: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

Future<void> _testPrint(String printerName, String connectionType, {String? ip, String? bluetoothId}) async {
  setState(() => _isLoading = true);
  try {
    // 1. Thực hiện kết nối lại/kết nối nếu chưa kết nối
    if (connectionType == 'TCP/IP') {
      if (ip == null || ip.isEmpty) {
        throw Exception('Địa chỉ IP không hợp lệ');
      }
      await _printerService.connectTcpIpPrinter(ip);
    } else if (connectionType == 'Bluetooth' && bluetoothId != null) {
      final device = await _printerService.reconnectBluetoothPrinter(bluetoothId);
      await _printerService.connectBluetoothPrinter(device);
    } else {
      throw Exception('Không có thông tin kết nối máy in.');
    }
    
    // 2. In thử
    await _printerService.testPrint();
    _showSnackBar('In thử ảnh logo thành công!', Colors.green);
  } catch (e) {
    _showSnackBar('Thất bại: $e', Colors.red);
  } finally {
    setState(() => _isLoading = false);
  }
}
  Future<void> _startBluetoothScan() async {
    setState(() {
      _isScanning = true;
      _bluetoothDevices = [];
    });
    try {
      await _printerService.startBluetoothScan();
    } catch (e) {
      _showSnackBar('Lỗi quét Bluetooth: $e', Colors.red);
      setState(() => _isScanning = false);
    }
  }

  Future<void> _setDefaultPrinter(int index) async {
    setState(() {
      for (var i = 0; i < _savedPrinters.length; i++) {
        _savedPrinters[i]['isDefault'] = i == index;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_printers', jsonEncode(_savedPrinters));
    _showSnackBar('Đã đặt ${_savedPrinters[index]['printerName']} làm máy in mặc định.', Colors.blue);
    
    // Đồng bộ lên Firebase (giống _savePrinter)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/printers');
      await ref.set({for (var p in _savedPrinters) p['printerName']: p});
    }
  }

  Future<void> _deletePrinter(int index) async {
    setState(() => _isLoading = true);
    try {
      final printer = _savedPrinters[index];
      _savedPrinters.removeAt(index);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_printers', jsonEncode(_savedPrinters));

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/printers/${printer['printerName']}');
        await ref.remove();
      }

      _showSnackBar('Đã xóa máy in', Colors.blueGrey);
    } catch (e) {
      _showSnackBar('Lỗi xóa máy in: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _printerService.dispose();
    _printerNameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt máy in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thêm máy in mới', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8)]),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: _connectionType,
                    isExpanded: true,
                    items: ['Bluetooth', 'TCP/IP'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _connectionType = value!;
                        if (value == 'Bluetooth') {
                          _startBluetoothScan();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _printerNameController,
                    decoration: const InputDecoration(labelText: 'Tên máy in', border: OutlineInputBorder()),
                  ),
                  if (_connectionType == 'TCP/IP') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(labelText: 'Địa chỉ IP (Ví dụ: 192.168.1.100)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ],
                  if (_connectionType == 'Bluetooth') ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startBluetoothScan,
                      child: Text(_isScanning ? 'Đang quét...' : 'Quét Bluetooth (${_bluetoothDevices.length} thiết bị)'),
                    ),
                    if (_bluetoothDevices.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _bluetoothDevices.length,
                        itemBuilder: (context, index) {
                          final device = _bluetoothDevices[index];
                          return ListTile(
                            dense: true,
                            title: Text(device.name.isNotEmpty ? device.name : 'Thiết bị ẩn danh'),
                            subtitle: Text(device.id.toString()),
                            trailing: ElevatedButton(
                              onPressed: () => _testPrint(
                                device.name.isNotEmpty ? device.name : device.id.toString(),
                                'Bluetooth',
                                bluetoothId: device.id.toString(),
                              ),
                              child: const Text('Kết nối & Test'),
                            ),
                          );
                        },
                      ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePrinter,
                      child: Text(_isLoading ? 'Đang lưu...' : 'Lưu máy in'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Danh sách máy in đã lưu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedPrinters.isEmpty
                    ? const Text('Chưa có máy in nào được lưu', style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _savedPrinters.length,
                        itemBuilder: (context, index) {
                          final printer = _savedPrinters[index];
                          return ListTile(
                            tileColor: printer['isDefault'] ? Colors.blue.withOpacity(0.1) : null,
                            title: Text(printer['printerName'], style: TextStyle(fontWeight: printer['isDefault'] ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text('${printer['connectionType']} ${printer['ip'] != null ? '- IP: ${printer['ip']}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.print),
                                  onPressed: () => _testPrint(
                                    printer['printerName'],
                                    printer['connectionType'],
                                    ip: printer['ip'],
                                    bluetoothId: printer['bluetoothId'],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deletePrinter(index),
                                  color: Colors.red,
                                ),
                                Tooltip(
                                  message: 'Đặt làm mặc định',
                                  child: Checkbox(
                                    value: printer['isDefault'],
                                    onChanged: (value) => _setDefaultPrinter(index),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}