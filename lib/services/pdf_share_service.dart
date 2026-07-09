import 'dart:io';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'report_file_service.dart';

class PdfShareService {
  const PdfShareService._();

  static Future<void> sharePdfFile(
    String filePath, {
    String? subject,
    String? shareText,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('PDF dosyası bulunamadı.');
    }

    final fileName = _resolvePdfFileName(filePath);
    await _shareFile(
      file,
      fileName: fileName,
      subject: subject,
      shareText: shareText,
    );
  }

  static Future<void> sharePdfBytes(
    Uint8List bytes, {
    required String fileName,
    String? subject,
    String? shareText,
  }) async {
    final normalizedFileName = _normalizePdfFileName(fileName);
    final file = await ReportFileService.savePdfBytes(
      bytes,
      fileName: normalizedFileName,
      category: 'Paylasim',
    );
    await _shareFile(
      file,
      fileName: normalizedFileName,
      subject: subject,
      shareText: shareText,
    );
  }

  static Future<void> _shareFile(
    File file, {
    required String fileName,
    String? subject,
    String? shareText,
  }) async {
    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Paylaşılacak PDF dosyası hazır değil.');
    }

    final result = await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'application/pdf',
          name: fileName,
        ),
      ],
      subject: subject ?? shareText ?? 'PDF Raporu',
      text: shareText,
    );

    if (result.status == ShareResultStatus.unavailable) {
      throw Exception('Bu cihazda PDF paylaşım hedefi bulunamadı.');
    }
  }

  static String _resolvePdfFileName(String filePath) {
    final parts = filePath.split(RegExp(r'[\\/]'));
    final raw = parts.isEmpty ? 'rapor.pdf' : parts.last;
    return _normalizePdfFileName(raw);
  }

  static String _normalizePdfFileName(String fileName) {
    return ReportFileService.normalizePdfFileName(fileName);
  }
}
