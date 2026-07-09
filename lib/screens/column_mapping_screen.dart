import 'package:flutter/material.dart';

class ColumnMappingScreen extends StatefulWidget {
  final List<String> fileHeaders;
  final List<String> requiredFields;
  final String filePath;

  const ColumnMappingScreen({
    super.key,
    required this.fileHeaders,
    required this.requiredFields,
    required this.filePath,
  });

  @override
  State<ColumnMappingScreen> createState() => _ColumnMappingScreenState();
}

class _ColumnMappingScreenState extends State<ColumnMappingScreen> {
  late Map<String, String?> _mapping;

  @override
  void initState() {
    super.initState();
    _mapping = {for (final field in widget.requiredFields) field: null};

    for (final field in widget.requiredFields) {
      final match = widget.fileHeaders.cast<String?>().firstWhere(
            (header) =>
                header != null &&
                header.toLowerCase().trim() == field.toLowerCase().trim(),
            orElse: () => null,
          );
      if (match != null) {
        _mapping[field] = match;
      }
    }
  }

  void _startImport() {
    if (_mapping['name'] == null || _mapping['quantity'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '"name" ve "quantity" alanlarini eslestirmek zorunludur.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context, _mapping);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sutunlari Eslestir'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'CSV dosyasindaki sutunlari uygulama alanlariyla eslestirin. * isaretli alanlar zorunludur.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: widget.requiredFields.length,
                itemBuilder: (context, index) {
                  final field = widget.requiredFields[index];
                  final isRequired = field == 'name' || field == 'quantity';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    field,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isRequired)
                                  const Text(
                                    ' *',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _mapping[field],
                              hint: const Text('Sutun Sec'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'Bos Birak',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                ...widget.fileHeaders.map(
                                  (header) => DropdownMenuItem<String?>(
                                    value: header,
                                    child: Text(
                                      header,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _mapping[field] = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: _startImport,
              icon: const Icon(Icons.download_done),
              label: const Text('Ice Aktarmayi Baslat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
