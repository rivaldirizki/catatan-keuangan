class ChatInvitationModel {
  final int id;
  final int roomId;
  final int? inviterId;
  final String inviterName;
  final String inviterEmail;
  final String createdAt;

  String get senderName => inviterName;
  String get senderEmail => inviterEmail;

  const ChatInvitationModel({
    required this.id,
    required this.roomId,
    this.inviterId,
    required this.inviterName,
    required this.inviterEmail,
    required this.createdAt,
  });

  factory ChatInvitationModel.fromJson(Map<String, dynamic> json) {
    return ChatInvitationModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      roomId: json['room_id'] is int ? json['room_id'] as int : int.tryParse(json['room_id'].toString()) ?? 0,
      inviterId: json['inviter_id'] != null
          ? (json['inviter_id'] is int
              ? json['inviter_id'] as int
              : int.tryParse(json['inviter_id'].toString()))
          : null,
      inviterName: (json['inviter_name'] as String?) ?? 'Pengguna',
      inviterEmail: (json['inviter_email'] as String?) ?? '',
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toIso8601String(),
    );
  }
}
