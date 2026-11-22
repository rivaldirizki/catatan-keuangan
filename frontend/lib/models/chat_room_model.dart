class ChatRoomModel {
  final int id;
  final String type; // 'family', 'company', 'direct'
  final String name;
  final String? otherUserName;
  final String? otherUserEmail;
  final String otherMemberStatus; // 'accepted', 'pending', 'rejected'
  final String? lastMessage;
  final String? lastMessageType;
  final String? lastMessageAt;
  final int unreadCount;
  final String? createdAt;

  const ChatRoomModel({
    required this.id,
    required this.type,
    required this.name,
    this.otherUserName,
    this.otherUserEmail,
    this.otherMemberStatus = 'accepted',
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.createdAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      type: (json['type'] as String?) ?? 'direct',
      name: (json['name'] as String?) ?? 'Obrolan',
      otherUserName: json['other_user_name'] as String?,
      otherUserEmail: json['other_user_email'] as String?,
      otherMemberStatus: (json['other_member_status'] as String?) ?? 'accepted',
      lastMessage: json['last_message'] as String?,
      lastMessageType: json['last_message_type'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      unreadCount: json['unread_count'] is int ? json['unread_count'] as int : int.tryParse(json['unread_count'].toString()) ?? 0,
      createdAt: json['created_at'] as String?,
    );
  }

  bool get isDirect => type == 'direct';
  bool get isFamily => type == 'family';
  bool get isCompany => type == 'company';
  bool get isPendingApproval => isDirect && otherMemberStatus == 'pending';
}
