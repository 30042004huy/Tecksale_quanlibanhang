// VỊ TRÍ: lib/widgets/calculator_popup.dart

import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

class CalculatorPopup extends StatefulWidget {
  const CalculatorPopup({Key? key}) : super(key: key);

  @override
  State<CalculatorPopup> createState() => _CalculatorPopupState();
}

class _CalculatorPopupState extends State<CalculatorPopup> {
  String _history = '';
  String _expression = '';

  void _numClick(String text) {
    setState(() {
      _expression += text;
    });
  }

  void _allClear(String text) {
    setState(() {
      _history = '';
      _expression = '';
    });
  }

  // BỎ HÀM _clear CŨ, KHÔNG CÒN DÙNG
  // void _clear(String text) { ... }

  // === 1. TẠO HÀM _backspace MỚI CHO NÚT 'C' ===
  // Hàm này chỉ xóa ký tự cuối cùng của chuỗi biểu thức.
  void _backspace(String text) {
    setState(() {
      if (_expression.isNotEmpty) {
        _expression = _expression.substring(0, _expression.length - 1);
      }
    });
  }

  void _evaluate(String text) {
    if (_expression.isEmpty) return;
    
    try {
      String finalExpression = _expression.replaceAll('x', '*').replaceAll('÷', '/');
      Parser p = Parser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);
      setState(() {
        _history = _expression;
        _expression = eval.toStringAsFixed(eval.truncateToDouble() == eval ? 0 : 2);
      });
    } catch (e) {
      setState(() {
        _expression = 'Lỗi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Máy tính'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        // === 2. BỌC TOÀN BỘ NỘI DUNG TRONG SingleChildScrollView ===
        // Widget này sẽ tự động cho phép cuộn khi chiều cao không đủ (ví dụ: khi xoay ngang).
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // KHU VỰC HIỂN THỊ (Không đổi)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: double.infinity,
                      child: Text(
                        _history,
                        style: const TextStyle(fontSize: 18, color: Colors.black54),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _expression.isEmpty ? '0' : _expression,
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // BÀN PHÍM MÁY TÍNH
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildCalcButton('AC', _allClear, textColor: Colors.deepOrange),
                  // THAY ĐỔI HÀM GỌI TỪ _clear -> _backspace CHO NÚT 'C'
                  _buildCalcButton('C', _backspace, textColor: Colors.deepOrange),
                  _buildCalcButton('%', _numClick, textColor: Colors.green),
                  _buildCalcButton('÷', _numClick, textColor: Colors.green),
                ],
              ),
              // Các hàng nút còn lại không thay đổi
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildCalcButton('7', _numClick),
                  _buildCalcButton('8', _numClick),
                  _buildCalcButton('9', _numClick),
                  _buildCalcButton('x', _numClick, textColor: Colors.green),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildCalcButton('4', _numClick),
                  _buildCalcButton('5', _numClick),
                  _buildCalcButton('6', _numClick),
                  _buildCalcButton('-', _numClick, textColor: Colors.green),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildCalcButton('1', _numClick),
                  _buildCalcButton('2', _numClick),
                  _buildCalcButton('3', _numClick),
                  _buildCalcButton('+', _numClick, textColor: Colors.green),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _buildCalcButton('00', _numClick),
                  _buildCalcButton('0', _numClick),
                  _buildCalcButton('.', _numClick),
                  _buildCalcButton('=', _evaluate, backgroundColor: Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        )
      ],
    );
  }

  Widget _buildCalcButton(String text, Function callback, {Color textColor = Colors.black87, Color? backgroundColor}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(3.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(vertical: 14.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
          ),
          onPressed: () => callback(text),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}