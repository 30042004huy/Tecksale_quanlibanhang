class Validator {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    
    // Basic email regex pattern
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    
    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng xác nhận mật khẩu';
    }
    
    if (value != password) {
      return 'Mật khẩu xác nhận không khớp';
    }
    
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    
    return null;
  }

  // Phone number validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }
    
    // Remove spaces and special characters
    final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanPhone.length < 10 || cleanPhone.length > 11) {
      return 'Số điện thoại không hợp lệ';
    }
    
    return null;
  }

  // Price validation
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập giá';
    }
    
    final price = double.tryParse(value.replaceAll(',', ''));
    if (price == null || price < 0) {
      return 'Giá không hợp lệ';
    }
    
    return null;
  }

  // Quantity validation
  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số lượng';
    }
    
    final quantity = int.tryParse(value);
    if (quantity == null || quantity <= 0) {
      return 'Số lượng phải lớn hơn 0';
    }
    
    return null;
  }

  // Product code validation
  static String? validateProductCode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mã sản phẩm';
    }
    
    if (value.length < 3) {
      return 'Mã sản phẩm phải có ít nhất 3 ký tự';
    }
    
    return null;
  }

  // Customer name validation
  static String? validateCustomerName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập tên khách hàng';
    }
    
    if (value.trim().length < 2) {
      return 'Tên khách hàng phải có ít nhất 2 ký tự';
    }
    
    return null;
  }

  // Address validation
  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ';
    }
    
    if (value.trim().length < 10) {
      return 'Địa chỉ phải có ít nhất 10 ký tự';
    }
    
    return null;
  }

  // Discount validation
  static String? validateDiscount(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Discount is optional
    }
    
    final discount = double.tryParse(value);
    if (discount == null || discount < 0 || discount > 100) {
      return 'Giảm giá phải từ 0% đến 100%';
    }
    
    return null;
  }

  // Order note validation
  static String? validateOrderNote(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Note is optional
    }
    
    if (value.length > 500) {
      return 'Ghi chú không được quá 500 ký tự';
    }
    
    return null;
  }

  // Date validation
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng chọn ngày';
    }
    
    try {
      DateTime.parse(value);
      return null;
    } catch (e) {
      return 'Ngày không hợp lệ';
    }
  }

  // Future date validation
  static String? validateFutureDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng chọn ngày';
    }
    
    try {
      final date = DateTime.parse(value);
      if (date.isBefore(DateTime.now())) {
        return 'Ngày phải là ngày trong tương lai';
      }
      return null;
    } catch (e) {
      return 'Ngày không hợp lệ';
    }
  }

  // URL validation
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }
    
    try {
      Uri.parse(value);
      return null;
    } catch (e) {
      return 'URL không hợp lệ';
    }
  }

  // Number validation
  static String? validateNumber(String? value, {double? min, double? max}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số';
    }
    
    final number = double.tryParse(value);
    if (number == null) {
      return 'Giá trị phải là số';
    }
    
    if (min != null && number < min) {
      return 'Giá trị phải lớn hơn hoặc bằng $min';
    }
    
    if (max != null && number > max) {
      return 'Giá trị phải nhỏ hơn hoặc bằng $max';
    }
    
    return null;
  }

  // Integer validation
  static String? validateInteger(String? value, {int? min, int? max}) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập số nguyên';
    }
    
    final number = int.tryParse(value);
    if (number == null) {
      return 'Giá trị phải là số nguyên';
    }
    
    if (min != null && number < min) {
      return 'Giá trị phải lớn hơn hoặc bằng $min';
    }
    
    if (max != null && number > max) {
      return 'Giá trị phải nhỏ hơn hoặc bằng $max';
    }
    
    return null;
  }
} 