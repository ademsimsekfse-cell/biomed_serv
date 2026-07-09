// SyncService for biomed_serv Flutter app

import 'dart:convert';
import 'package:http/http.dart' as http;

class SyncService {
  final String baseUrl;
  final String token;

  SyncService({required this.baseUrl, required this.token});

  Future<Map<String, dynamic>> pushChanges(List<Map<String, dynamic>> changes, String clientId, String? lastKnownServerTs) async {
    final url = Uri.parse('$baseUrl/sync/push');
    final body = jsonEncode({
      'client_id': clientId,
      'last_known_server_ts': lastKnownServerTs,
      'changes': changes,
    });

    final resp = await http.post(url, headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    }, body: body);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Sync push failed: ${resp.statusCode} ${resp.body}');
    }

    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pullChanges(String? since) async {
    final uri = Uri.parse('$baseUrl/sync/pull${since != null ? '?since=$since' : ''}');
    final resp = await http.get(uri, headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });
    if (resp.statusCode != 200) throw Exception('Sync pull failed');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
