/// Form ve input validasyonları için yardımcı sınıf
class Validators {
  // Private constructor - utility sınıf olarak kullan
  Validators._();

  /// Boş String kontrolü
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName boş bırakılamaz';
    }
    return null;
  }

  /// Minimum uzunluk kontrolü
  static String? validateMinLength(String? value, int minLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName boş bırakılamaz';
    }
    if (value.length < minLength) {
      return '$fieldName en az $minLength karakter olmalıdır';
    }
    return null;
  }

  /// Maksimum uzunluk kontrolü
  static String? validateMaxLength(String? value, int maxLength, String fieldName) {
    if (value != null && value.length > maxLength) {
      return '$fieldName en fazla $maxLength karakter olmalıdır';
    }
    return null;
  }

  /// Email validasyonu
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-posta adresi boş bırakılamaz';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Geçersiz e-posta adresi';
    }
    return null;
  }

  /// Telefon numarası validasyonu (TR formatı)
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Telefon numarası boş bırakılamaz';
    }

    final phoneRegex = RegExp(r'^([0-9]{10,11})$');
    final cleanedPhone = value.replaceAll(RegExp(r'[^\d]'), '');

    if (!phoneRegex.hasMatch(cleanedPhone)) {
      return 'Telefon numarası geçersiz (10-11 rakam)';
    }
    return null;
  }

  /// Sayı validasyonu
  static String? validateNumber(String? value, String fieldName, {int? min, int? max}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName boş bırakılamaz';
    }

    final number = int.tryParse(value);
    if (number == null) {
      return '$fieldName sadece sayı olmalıdır';
    }

    if (min != null && number < min) {
      return '$fieldName minimum $min olmalıdır';
    }

    if (max != null && number > max) {
      return '$fieldName maksimum $max olmalıdır';
    }

    return null;
  }

  /// Ondalıklı sayı validasyonu
  static String? validateDouble(String? value, String fieldName, {double? min, double? max}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName boş bırakılamaz';
    }

    final number = double.tryParse(value);
    if (number == null) {
      return '$fieldName geçersiz sayı formatı';
    }

    if (min != null && number < min) {
      return '$fieldName minimum $min olmalıdır';
    }

    if (max != null && number > max) {
      return '$fieldName maksimum $max olmalıdır';
    }

    return null;
  }

  /// URL validasyonu
  static String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'URL boş bırakılamaz';
    }

    try {
      Uri.parse(value);
      return null;
    } catch (e) {
      return 'Geçersiz URL formatı';
    }
  }

  /// Tarih validasyonu (DateTime)
  static String? validateDate(DateTime? value, String fieldName) {
    if (value == null) {
      return '$fieldName seçilmelidir';
    }
    return null;
  }

  /// İki tarih arasındaki ilişki kontrol etme
  static String? validateDateRange(DateTime? startDate, DateTime? endDate, String startFieldName, String endFieldName) {
    if (startDate == null || endDate == null) {
      return 'Her iki tarih de seçilmelidir';
    }

    if (startDate.isAfter(endDate)) {
      return '$startFieldName, $endFieldName\'den sonra olamaz';
    }
    return null;
  }

  /// Barkod validasyonu
  static String? validateBarcode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Barkod boş bırakılamaz';
    }

    if (value.length < 6) {
      return 'Barkod en az 6 karakter olmalıdır';
    }

    return null;
  }

  /// Seri numarası validasyonu
  static String? validateSerialNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Seri numarası boş bırakılamaz';
    }

    if (value.length < 3) {
      return 'Seri numarası en az 3 karakter olmalıdır';
    }

    return null;
  }

  /// Kurum adı validasyonu
  static String? validateOrganizationName(String? value) {
    return validateMinLength(value, 2, 'Kurum adı');
  }

  /// Cihaz adı validasyonu
  static String? validateDeviceName(String? value) {
    return validateMinLength(value, 2, 'Cihaz adı');
  }

  /// Marka adı validasyonu
  static String? validateBrand(String? value) {
    return validateMinLength(value, 2, 'Marka adı');
  }

  /// Form numarası validasyonu
  static String? validateFormNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Form numarası boş bırakılamaz';
    }

    final formRegex = RegExp(r'^[A-Z0-9\-]{4,20}$');
    if (!formRegex.hasMatch(value)) {
      return 'Form numarası geçersiz format (A-Z, 0-9, -)';
    }

    return null;
  }
}

