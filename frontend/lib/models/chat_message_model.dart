class ChatMessageModel {
  final int id;
  final int roomId;
  final int userId;
  final String senderName;
  final String message;
  final String messageType; // 'text', 'system', 'financial_share'
  final Map<String, dynamic>? metadata;
  final String? deliveryStatus; // 'pending', 'sent', 'partially_read', 'read'
  final String createdAt;

  const ChatMessageModel({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.senderName,
    required this.message,
    this.messageType = 'text',
    this.metadata,
    this.deliveryStatus,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? meta;
    if (json['metadata'] != null) {
      if (json['metadata'] is Map<String, dynamic>) {
        meta = json['metadata'] as Map<String, dynamic>;
      } else if (json['metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['metadata'] as Map);
      }
    }
    return ChatMessageModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      roomId: json['room_id'] is int ? json['room_id'] as int : int.tryParse(json['room_id'].toString()) ?? 0,
      userId: json['user_id'] is int ? json['user_id'] as int : int.tryParse(json['user_id'].toString()) ?? 0,
      senderName: (json['sender_name'] as String?) ?? 'Pengguna',
      message: (json['message'] as String?) ?? '',
      messageType: (json['message_type'] as String?) ?? 'text',
      metadata: meta,
      deliveryStatus: json['delivery_status'] as String?,
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }

  ChatMessageModel copyWith({
    int? id,
    int? roomId,
    int? userId,
    String? senderName,
    String? message,
    String? messageType,
    Map<String, dynamic>? metadata,
    String? deliveryStatus,
    String? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      messageType: messageType ?? this.messageType,
      metadata: metadata ?? this.metadata,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isFinancialShare => messageType == 'financial_share';
}
