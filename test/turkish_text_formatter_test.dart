import 'package:biomed_serv/utils/turkish_text_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('description text uses Turkish uppercase and clean line starts', () {
    final result = normalizeDescriptionText(
      '  cihaz içi kontrol edildi  \n'
      '\n'
      '\n'
      '   ölçüm işlemi tamamlandı ',
    );

    expect(
      result,
      'CİHAZ İÇİ KONTROL EDİLDİ\n\nÖLÇÜM İŞLEMİ TAMAMLANDI',
    );
  });
}
