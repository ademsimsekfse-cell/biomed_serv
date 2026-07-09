/// Uygulama genelinde kullanılacak özel istisna sınıfları
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalException;

  AppException({
    required this.message,
    this.code,
    this.originalException,
  });

  @override
  String toString() => 'AppException: [$code] $message';
}

/// Veritabanı işlemleri için
class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'DB_ERROR',
  );
}

/// Dosya işlemleri için
class FileException extends AppException {
  FileException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'FILE_ERROR',
  );
}

/// Dışa aktarma işlemleri için
class ExportException extends AppException {
  ExportException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'EXPORT_ERROR',
  );
}

/// İçe aktarma işlemleri için
class ImportException extends AppException {
  ImportException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'IMPORT_ERROR',
  );
}

/// Validation hatası için
class ValidationException extends AppException {
  ValidationException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'VALIDATION_ERROR',
  );
}

/// Kullanıcı tarafından iptal edilen işlem
class CancelledException extends AppException {
  CancelledException({
    required super.message,
    super.code = 'CANCELLED',
    super.originalException,
  });
}

/// İzin/Yetki hatası
class PermissionException extends AppException {
  PermissionException({
    required super.message,
    String? code,
    super.originalException,
  }) : super(
    code: code ?? 'PERMISSION_ERROR',
  );
}

