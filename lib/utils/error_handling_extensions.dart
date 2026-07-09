import 'package:flutter/material.dart';
import 'app_exception.dart';
import 'app_logger.dart';
import 'ui_helper.dart';

/// Exception'ları işlemek için extension
extension ExceptionHandler on Object {
  /// Exception mesajını Türkçe olarak döndürür
  String getReadableMessage() {
    if (this is AppException) {
      final appException = this as AppException;
      return appException.message;
    }

    final exceptionString = toString();

    if (exceptionString.contains('SocketException')) {
      return 'İnternet bağlantısı kontrol edin';
    }
    if (exceptionString.contains('TimeoutException')) {
      return 'İstek zaman aşımına uğradı. Lütfen tekrar deneyin';
    }
    if (exceptionString.contains('FileSystemException')) {
      return 'Dosya işleminde hata oluştu';
    }
    if (exceptionString.contains('FormatException')) {
      return 'Veri formatı hatalı';
    }

    return 'Beklenmedik bir hata oluştu';
  }

  /// Exception'ı loglar ve kullanıcıya gösterir
  Future<void> handleAndShowError(
    BuildContext context, {
    String? customMessage,
    String title = 'Hata',
  }) async {
    final message = customMessage ?? getReadableMessage();

    if (this is AppException) {
      final appException = this as AppException;
      AppLogger.logAppException(appException);
    } else {
      AppLogger.error(message, exception: this);
    }

    if (context.mounted) {
      await UIHelper.showErrorDialog(
        context,
        title: title,
        message: message,
      );
    }
  }

  /// Exception'ı loglar ve snackbar gösterir
  void handleAndShowSnackbar(
    BuildContext context, {
    String? customMessage,
  }) {
    final message = customMessage ?? getReadableMessage();

    if (this is AppException) {
      final appException = this as AppException;
      AppLogger.logAppException(appException);
    } else {
      AppLogger.error(message, exception: this);
    }

    if (context.mounted) {
      UIHelper.showErrorSnackbar(context, message: message);
    }
  }

  /// Exception'ı loglar ve silent işleme alır
  void logSilently({String? customMessage}) {
    if (this is AppException) {
      final appException = this as AppException;
      AppLogger.logAppException(appException);
    } else {
      AppLogger.error(
        customMessage ?? getReadableMessage(),
        exception: this,
      );
    }
  }
}

/// AsyncValue için error handling helper
class ErrorHandlingHelper {
  static String getErrorMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return error.toString();
  }

  static Future<void> showErrorDialogFromException(
    BuildContext context,
    Object error,
  ) async {
    await error.handleAndShowError(context);
  }

  static void showErrorSnackbarFromException(
    BuildContext context,
    Object error,
  ) {
    error.handleAndShowSnackbar(context);
  }
}

