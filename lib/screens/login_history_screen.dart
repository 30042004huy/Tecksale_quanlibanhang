import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/login_entry_model.dart';
import 'dart:async';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late StreamSubscription<DatabaseEvent> _historySubscription;
  final List<LoginEntry> _loginEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLoginHistory();
  }

  @override
  void dispose() {
    _historySubscription.cancel();
    super.dispose();
  }

  void _fetchLoginHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    final historyRef = _dbRef.child('nguoidung/${user.uid}/lichsudangnhap');

    _historySubscription = historyRef.onValue.listen((event) {
      if (mounted) {
        final Map<dynamic, dynamic>? data = event.snapshot.value as Map?;
        _loginEntries.clear();
        if (data != null) {
          data.forEach((key, value) {
            _loginEntries.add(LoginEntry.fromMap(key, value));
          });
          // Sắp xếp để lần đăng nhập mới nhất luôn ở trên cùng
          _loginEntries.sort((a, b) => b.loginTime.compareTo(a.loginTime));
        }
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lịch sử đăng nhập',
          style: GoogleFonts.roboto(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loginEntries.isEmpty
              ? Center(
                  child: Text(
                    'Chưa có lịch sử đăng nhập nào.',
                    style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _loginEntries.length,
                  itemBuilder: (context, index) {
                    final entry = _loginEntries[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.security, color: Colors.blue),
                        ),
                        title: Text(
                          entry.deviceName,
                          style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            _buildInfoRow(Icons.access_time, entry.formattedLoginTime),
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.location_on, entry.address),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.roboto(fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
