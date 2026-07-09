import 'package:flutter/material.dart';

class UnitConverterScreen extends StatefulWidget {
  const UnitConverterScreen({super.key});

  @override
  State<UnitConverterScreen> createState() => _UnitConverterScreenState();
}

class _UnitConverterScreenState extends State<UnitConverterScreen> {
  final _valueController = TextEditingController(text: '1');
  String _fromUnit = 'mg';
  String _toUnit = 'ng';

  static const _massUnits = <String, double>{
    'ng': 0.000001,
    'µg': 0.001,
    'mg': 1,
    'g': 1000,
    'kg': 1000000,
  };

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  double? get _result {
    final value = double.tryParse(_valueController.text.replaceAll(',', '.'));
    if (value == null) return null;
    final from = _massUnits[_fromUnit] ?? 1;
    final to = _massUnits[_toUnit] ?? 1;
    return value * from / to;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesaplayıcı')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFEFFAF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB7E5D8)),
            ),
            child: const Row(
              children: [
                Icon(Icons.science, color: Color(0xFF0F766E), size: 30),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kütle birimleri arasında hızlı dönüşüm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _valueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Değer',
              prefixIcon: Icon(Icons.calculate),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildUnitDropdown(
                  label: 'Kaynak',
                  value: _fromUnit,
                  onChanged: (value) => setState(() => _fromUnit = value),
                ),
              ),
              IconButton(
                tooltip: 'Birimleri değiştir',
                onPressed: () {
                  setState(() {
                    final temp = _fromUnit;
                    _fromUnit = _toUnit;
                    _toUnit = temp;
                  });
                },
                icon: const Icon(Icons.swap_horiz),
              ),
              Expanded(
                child: _buildUnitDropdown(
                  label: 'Hedef',
                  value: _toUnit,
                  onChanged: (value) => setState(() => _toUnit = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            elevation: 0,
            color: Colors.blue.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sonuç',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result == null
                        ? 'Geçerli bir değer girin'
                        : '${_format(result)} $_toUnit',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final unit in _massUnits.keys)
          DropdownMenuItem(value: unit, child: Text(unit)),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  String _format(double value) {
    if (value == 0) return '0';
    if (value.abs() >= 1000000 || value.abs() < 0.001) {
      return value.toStringAsExponential(4);
    }
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
