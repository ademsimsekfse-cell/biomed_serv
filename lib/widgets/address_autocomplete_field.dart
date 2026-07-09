import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/address_search_service.dart';

/// 🗺️ Adres Otomatik Tamamlama Alanı
/// OpenStreetMap Nominatim API kullanır (ücretsiz, API key gerektirmez)
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool required;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 2,
    this.validator,
    this.required = false,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  List<AddressSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _selectedFromMap = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results = await AddressSearchService.searchAddress(query, limit: 5);

    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ana TextField
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          maxLines: widget.maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label + (widget.required ? ' *' : ''),
            hintText: widget.hint ?? 'Adres ara (örn: Ankara Kavaklıdere)',
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _suggestions.isNotEmpty
                    ? const Icon(Icons.map, color: Colors.green)
                    : null,
            border: const OutlineInputBorder(),
          ),
          validator: widget.validator,
          onChanged: (value) {
            if (_selectedFromMap) {
              setState(() => _selectedFromMap = false);
            }
            // Debounce arama
            Future.delayed(const Duration(milliseconds: 500), () {
              if (value == widget.controller.text) {
                _searchAddress(value);
              }
            });
          },
        ),

        // 🗺️ Öneri Listesi
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Haritadan Öneriler',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const Spacer(),
                      // Kapat butonu
                      GestureDetector(
                        onTap: () => setState(() => _showSuggestions = false),
                        child: Icon(Icons.close,
                            size: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Öneriler
                ..._suggestions.take(4).map((suggestion) => InkWell(
                      onTap: () {
                        widget.controller.text = suggestion.displayName;
                        setState(() {
                          _showSuggestions = false;
                          _selectedFromMap = true;
                        });
                        // 🔊 Ses efekti
                        // SoundService().playSuccess();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getIconForType(suggestion.type),
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.shortName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (suggestion.displayName !=
                                      suggestion.shortName)
                                    Text(
                                      suggestion.displayName
                                          .split(',')
                                          .skip(3)
                                          .join(', '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        if (widget.controller.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _selectedFromMap ? Icons.verified : Icons.info_outline,
                size: 18,
                color: _selectedFromMap ? Colors.green : Colors.blueGrey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFromMap
                      ? 'Adres harita sonucundan seçildi.'
                      : 'Adresi kaydetmeden önce haritada doğrulayın.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton.icon(
                onPressed: _openInGoogleMaps,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Google Haritalar'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _openInGoogleMaps() async {
    final query = widget.controller.text.trim();
    if (query.isEmpty) return;
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {'api': '1', 'query': query},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Haritalar açılamadı.')),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'house':
      case 'residential':
        return Icons.home;
      case 'apartments':
        return Icons.apartment;
      case 'commercial':
      case 'retail':
        return Icons.store;
      case 'industrial':
        return Icons.factory;
      case 'hospital':
        return Icons.local_hospital;
      case 'school':
      case 'university':
        return Icons.school;
      default:
        return Icons.location_on;
    }
  }
}
