// VỊ TRÍ: lib/screens/table_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/custom_notification_service.dart';
import 'cuahang.dart'; // Import class 'Ban'

class TableSetupScreen extends StatefulWidget {
  final String uid;
  final List<Ban> currentTables;

  const TableSetupScreen({
    super.key,
    required this.uid,
    required this.currentTables,
  });

  @override
  State<TableSetupScreen> createState() => _TableSetupScreenState();
}

class _TableSetupScreenState extends State<TableSetupScreen> {
  late List<TextEditingController> _controllers;
  late int _tableCount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tableCount = widget.currentTables.length;
    _controllers = List.generate(
      _tableCount,
      (index) => TextEditingController(text: widget.currentTables[index].ten),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addTable() {
    setState(() {
      _tableCount++;
      _controllers.add(TextEditingController(text: 'Bàn $_tableCount'));
    });
  }

  void _removeTable() {
    if (_tableCount > 0) {
      // Kiểm tra xem bàn cuối có khách không
      if (widget.currentTables.length >= _tableCount &&
          widget.currentTables[_tableCount - 1].trangThai == 'co_khach') {
        CustomNotificationService.show(
          context,
          message: 'Không thể xóa bàn đang có khách!',
          textColor: Colors.red,
        );
        return;
      }

      setState(() {
        _tableCount--;
        _controllers.removeLast().dispose();
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    try {
      final DatabaseReference cuaHangRef =
          FirebaseDatabase.instance.ref('nguoidung/${widget.uid}/cuahang');

      List<Map<String, dynamic>> newTableList = [];
      for (int i = 0; i < _tableCount; i++) {
        // Giữ lại thông tin của bàn cũ nếu nó còn tồn tại
        if (i < widget.currentTables.length) {
          final oldTable = widget.currentTables[i];
          final updatedTable = Ban(
            id: oldTable.id,
            ten: _controllers[i].text.trim(),
            trangThai: oldTable.trangThai,
            gioVao: oldTable.gioVao,
            soKhach: oldTable.soKhach,
            orderId: oldTable.orderId,
            totalAmount: oldTable.totalAmount,
          );
          newTableList.add(updatedTable.toJson());
        } else {
          // Tạo bàn mới hoàn toàn
          final newTable = Ban(id: i, ten: _controllers[i].text.trim());
          newTableList.add(newTable.toJson());
        }
      }

      await cuaHangRef.child('ban_list').set(newTableList);

      if (mounted) {
        CustomNotificationService.show(context, message: 'Đã lưu cài đặt bàn thành công!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomNotificationService.show(context, message: 'Lỗi: $e', textColor: Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cài đặt Bàn', style: GoogleFonts.quicksand(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _tableCount,
                    itemBuilder: (context, index) {
                      return _buildTableInputField(index);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  const Text('Tổng số bàn', style: TextStyle(fontSize: 16, color: Colors.black54)),
                  Text(
                    '$_tableCount',
                    style: GoogleFonts.roboto(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton.filled(
                    onPressed: _removeTable,
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: _addTable,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableInputField(int index) {
    bool isOccupied = index < widget.currentTables.length &&
                      widget.currentTables[index].trangThai == 'co_khach';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: _controllers[index],
        readOnly: isOccupied,
        decoration: InputDecoration(
          labelText: 'Tên Bàn ${index + 1}',
          prefixIcon: Icon(
            isOccupied ? Icons.lock_outline_rounded : Icons.edit_outlined,
            color: isOccupied ? Colors.orange : Colors.grey,
          ),
          suffixText: isOccupied ? 'Đang có khách' : null,
          suffixStyle: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isOccupied ? Colors.grey.shade200 : Colors.white,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _saveSettings,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Lưu cài đặt'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}