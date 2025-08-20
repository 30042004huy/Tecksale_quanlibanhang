import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tecksale_quanlybanhang/services/printer_service.dart';

class CaiDatMayInScreen extends StatefulWidget {
  const CaiDatMayInScreen({super.key});

  @override
  _CaiDatMayInScreenState createState() => _CaiDatMayInScreenState();
}

class _CaiDatMayInScreenState extends State<CaiDatMayInScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _connectedDevices = [];
  bool _isLoading = false;
  String? _connectedPrinter;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadLastPrinter();
    _printerService.onPrinterConnected = (printerName) {
      if (mounted) {
        setState(() {
          _connectedPrinter = printerName;
          _connectedDevices = []; // Hide other devices after connection
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kết nối thiết bị $printerName thành công')),
        );
      }
    };
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    final statuses = await permissions.request();
    List<String> missingPermissions = [];
    if (statuses[Permission.bluetooth] != PermissionStatus.granted) {
      missingPermissions.add('Bluetooth');
    }
    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted) {
      missingPermissions.add('Quét Bluetooth');
    }
    if (statuses[Permission.bluetoothConnect] != PermissionStatus.granted) {
      missingPermissions.add('Kết nối Bluetooth');
    }
    if (statuses[Permission.locationWhenInUse] != PermissionStatus.granted) {
      missingPermissions.add('Vị trí');
    }

    if (missingPermissions.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vui lòng cấp quyền: ${missingPermissions.join(', ')}'),
          action: SnackBarAction(
            label: 'Mở cài đặt',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } else {
      _loadConnectedDevices();
    }
  }

  Future<void> _loadLastPrinter() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/mayin');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (mounted) {
          setState(() {
            _connectedPrinter = data['name'];
          });
        }
        if (_connectedPrinter != null) {
          try {
            await _printerService.reconnectBluetoothPrinter(_connectedPrinter!);
          } catch (e) {
            // Silent error to avoid disrupting UI
          }
        }
      }
    }
  }

  Future<void> _savePrinterToFirebase(String? name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref = FirebaseDatabase.instance.ref('nguoidung/${user.uid}/mayin');
      await ref.set({
        'name': name,
      });
    }
  }

  Future<void> _loadConnectedDevices() async {
    setState(() {
      _isLoading = true;
      _connectedDevices = [];
    });
    try {
      // Ensure Bluetooth is enabled
      if (!(await FlutterBluePlus.isAvailable)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bluetooth chưa được bật'),
              action: SnackBarAction(
                label: 'Bật Bluetooth',
                onPressed: () => FlutterBluePlus.turnOn(),
              ),
            ),
          );
        }
        return;
      }

      final devices = await FlutterBluePlus.connectedDevices;
      if (mounted) {
        setState(() {
          _connectedDevices = devices;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lấy danh sách thiết bị: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _connectBluetoothPrinter(BluetoothDevice device) async {
    try {
      await _printerService.connectBluetoothPrinter(device);
      if (mounted) {
        setState(() {
          _connectedPrinter = device.name.isNotEmpty ? device.name : device.id.toString();
          _connectedDevices = []; // Hide other devices
        });
        _savePrinterToFirebase(_connectedPrinter);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối thiết bị: $e')),
        );
      }
    }
  }

  void _testPrint() async {
    if (_connectedPrinter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thiết bị trước')),
      );
      return;
    }
    try {
      await _printerService.testPrintLogo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi dữ liệu ảnh thành công')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi dữ liệu ảnh: $e')),
        );
      }
    }
  }

  void _refreshDevices() async {
    await _loadConnectedDevices();
    if (mounted) {
      setState(() {
        _connectedPrinter = null; // Reset selected device to show list
      });
    }
  }

  @override
  void dispose() {
    _printerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Cài đặt máy in',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 2,
        shadowColor: Colors.black26,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F0FE), Color(0xFFF5F7FA)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_connectedPrinter != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.bluetooth, color: Theme.of(context).primaryColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Thiết bị hiện tại: $_connectedPrinter',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _testPrint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'In thử',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
                            onPressed: _refreshDevices,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (_connectedPrinter == null) ...[
                const Text(
                  'Thiết bị Bluetooth đang kết nối',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text(
                          'Danh sách thiết bị',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        trailing: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
                                onPressed: _loadConnectedDevices,
                              ),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      if (!_isLoading && _connectedDevices.isEmpty)
                        const ListTile(
                          title: Text(
                            'Không có thiết bị Bluetooth nào đang kết nối',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      if (!_isLoading && _connectedDevices.isNotEmpty) ...[
                        const Divider(height: 1),
                        ..._connectedDevices.map((device) => ListTile(
                              title: Text(
                                device.name.isNotEmpty ? device.name : device.id.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                device.id.toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              onTap: () => _connectBluetoothPrinter(device),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}