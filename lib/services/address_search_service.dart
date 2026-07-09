import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 🗺️ Ücretsiz Adres Arama Servisi
/// OpenStreetMap Nominatim API kullanır - API Key gerektirmez
class AddressSearchService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  
  /// Adres ara ( autocomplete benzeri )
  static Future<List<AddressSuggestion>> searchAddress(
    String query, {
    String countryCode = 'tr', // Türkiye için 'tr'
    int limit = 5,
  }) async {
    if (query.length < 3) return []; // En az 3 karakter
    
    try {
      final url = Uri.parse(
        '$_baseUrl/search?format=json&q=$query&countrycodes=$countryCode&limit=$limit&accept-language=tr',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BiomedServApp/1.0', // Nominatim requires User-Agent
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        return data.map((item) => AddressSuggestion(
          displayName: item['display_name'] as String,
          latitude: double.parse(item['lat'] as String),
          longitude: double.parse(item['lon'] as String),
          type: item['type'] as String? ?? 'unknown',
        )).toList();
      } else {
        debugPrint('🚨 Adres arama hatası: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('🚨 Adres arama hatası: $e');
      return [];
    }
  }
  
  /// Koordinatlardan adres bul (Reverse Geocoding)
  static Future<AddressSuggestion?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=tr',
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'BiomedServApp/1.0',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return AddressSuggestion(
          displayName: data['display_name'] as String? ?? 'Bilinmeyen Adres',
          latitude: latitude,
          longitude: longitude,
          type: data['type'] as String? ?? 'unknown',
        );
      }
      return null;
    } catch (e) {
      debugPrint('🚨 Reverse geocoding hatası: $e');
      return null;
    }
  }
}

/// 🏠 Adres Öneri Modeli
class AddressSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String type;
  
  AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });
  
  /// Görünen adı kısalt (uzun adresler için)
  String get shortName {
    final parts = displayName.split(',');
    if (parts.length > 3) {
      // İlk 3 parçayı al (sokak, mahalle, ilçe)
      return parts.take(3).join(', ');
    }
    return displayName;
  }
  
  @override
  String toString() => displayName;
}
