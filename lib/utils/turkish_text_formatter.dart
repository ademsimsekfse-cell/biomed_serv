import 'package:flutter/services.dart';

String turkishUpperCase(String value) {
  return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}

String normalizeDescriptionText(String value) {
  final normalizedLines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.trim())
      .toList();

  final result = <String>[];
  var previousWasEmpty = false;
  for (final line in normalizedLines) {
    final isEmpty = line.isEmpty;
    if (isEmpty && previousWasEmpty) continue;
    result.add(isEmpty ? '' : turkishUpperCase(line));
    previousWasEmpty = isEmpty;
  }

  return result.join('\n').trim();
}

class TurkishUpperCaseTextFormatter extends TextInputFormatter {
  const TurkishUpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = newValue.text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[ \t]+'), ''))
        .join('\n');
    final upper = turkishUpperCase(normalized);
    final safeOffset = newValue.selection.end.clamp(0, upper.length);

    return newValue.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: safeOffset),
      composing: TextRange.empty,
    );
  }
}
