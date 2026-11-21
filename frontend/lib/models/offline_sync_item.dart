import 'dart:convert';

class OfflineSyncItem {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> body;
  final String idempotencyKey;
  final DateTime timestamp;
  final String description;

  OfflineSyncItem({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.idempotencyKey,
    required this.timestamp,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'endpoint': endpoint,
      'method': method,
      'body': body,
      'idempotency_key': idempotencyKey,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
    };
  }

  factory OfflineSyncItem.fromJson(Map<String, dynamic> json) {
    return OfflineSyncItem(
      id: json['id'] as String? ?? '',
      endpoint: json['endpoint'] as String? ?? '',
      method: json['method'] as String? ?? 'POST',
      body: json['body'] is Map<String, dynamic> ? json['body'] as Map<String, dynamic> : {},
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'] as String? ?? '',
    );
  }

  static String encodeList(List<OfflineSyncItem> items) {
    return jsonEncode(items.map((i) => i.toJson()).toList());
  }

  static List<OfflineSyncItem> decodeList(String rawJson) {
    if (rawJson.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => OfflineSyncItem.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
