import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ReportFileService {
  const ReportFileService._();

  static Future<Directory> reportsDirectory({String? category}) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final separator = Platform.pathSeparator;
    final parts = <String>[baseDir.path, 'BiomedServ', 'Reports'];

    if (category != null && category.trim().isNotEmpty) {
      parts.add(_sanitizeSegment(category));
    }

    final directory = Directory(parts.join(separator));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<File> savePdfBytes(
    Uint8List bytes, {
    required String fileName,
    String? category,
  }) async {
    final directory = await reportsDirectory(category: category);
    final normalizedFileName = normalizePdfFileName(fileName);
    final file =
        File('${directory.path}${Platform.pathSeparator}$normalizedFileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static String normalizePdfFileName(String fileName) {
    final trimmed = fileName.trim().isEmpty ? 'rapor.pdf' : fileName.trim();
    final withExtension =
        trimmed.toLowerCase().endsWith('.pdf') ? trimmed : '$trimmed.pdf';
    return _sanitizeFileName(withExtension);
  }

  static String _sanitizeSegment(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'Genel' : sanitized;
  }

  static String _sanitizeFileName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return sanitized.isEmpty ? 'rapor.pdf' : sanitized;
  }
}
