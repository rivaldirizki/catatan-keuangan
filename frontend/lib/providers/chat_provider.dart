import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/constants/api_constants.dart';
import '../models/chat_room_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_invitation_model.dart';

class ChatProvider extends ChangeNotifier {
  final ApiClient apiClient;

  List<ChatRoomModel> _rooms = [];
  List<ChatInvitationModel> _pendingInvitations = [];
  List<ChatMessageModel> _activeRoomMessages = [];
  int? _activeRoomId;
  String? _myChatCode;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _pollingTimer;

  ChatProvider({required this.apiClient});

  List<ChatRoomModel> get rooms => _rooms;
  List<ChatInvitationModel> get pendingInvitations => _pendingInvitations;
  List<ChatMessageModel> get activeRoomMessages => _activeRoomMessages;
  int? get activeRoomId => _activeRoomId;
  String? get myChatCode => _myChatCode;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  int get totalUnreadCount =>
      _rooms.fold(0, (sum, r) => sum + r.unreadCount) + _pendingInvitations.length;

  List<ChatRoomModel> get directRooms =>
      _rooms.where((r) => r.isDirect).toList();

  ChatRoomModel? get familyRoom =>
      _rooms.cast<ChatRoomModel?>().firstWhere((r) => r?.isFamily == true, orElse: () => null);

  ChatRoomModel? get companyRoom =>
      _rooms.cast<ChatRoomModel?>().firstWhere((r) => r?.isCompany == true, orElse: () => null);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchMyChatCode() async {
    try {
      final res = await apiClient.get(ApiConstants.chatMyCode);
      if (res is Map && res['chat_invite_code'] != null) {
        _myChatCode = res['chat_invite_code'].toString();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchRooms() async {
    try {
      final res = await apiClient.get(ApiConstants.chatRooms);
      if (res is List) {
        _rooms = res
            .map((e) => ChatRoomModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> fetchInvitations() async {
    try {
      final res = await apiClient.get(ApiConstants.chatInvitations);
      if (res is List) {
        _pendingInvitations = res
            .map((e) => ChatInvitationModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await Future.wait([
      fetchMyChatCode(),
      fetchRooms(),
      fetchInvitations(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendDirectInvite(String inviteCode) async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await apiClient.post(ApiConstants.chatDirectInvite, body: {
        'invite_code': inviteCode.trim().toUpperCase(),
      });
      await fetchRooms();
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSending = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptInvitation(int invitationId) async {
    try {
      await apiClient.post(ApiConstants.chatInvitationAccept(invitationId));
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectInvitation(int invitationId) async {
    try {
      await apiClient.post(ApiConstants.chatInvitationReject(invitationId));
      await refreshAll();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void openRoom(int roomId) {
    _activeRoomId = roomId;
    _activeRoomMessages = [];
    _isLoading = true;
    notifyListeners();

    fetchRoomMessages(roomId).then((_) {
      markRoomAsRead(roomId);
    });

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_activeRoomId == roomId) {
        fetchRoomMessages(roomId, isPoll: true);
      } else {
        _pollingTimer?.cancel();
      }
    });
  }

  void closeRoom() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activeRoomId = null;
    _activeRoomMessages = [];
    fetchRooms();
  }

  Future<void> fetchRoomMessages(int roomId, {bool isPoll = false}) async {
    try {
      final res = await apiClient.get(ApiConstants.chatRoomMessages(roomId));
      if (res is List) {
        final messages = res
            .map((e) => ChatMessageModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Update messages if list changed or poll
        _activeRoomMessages = messages;
        _isLoading = false;
        notifyListeners();

        // If active room has incoming messages, mark read
        if (!isPoll && messages.isNotEmpty) {
          markRoomAsRead(roomId, messages.last.id);
        }
      }
    } catch (e) {
      if (!isPoll) {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        notifyListeners();
      }
    }
  }

  Future<bool> sendMessage(
    int roomId,
    String text, {
    String messageType = 'text',
    Map<String, dynamic>? metadata,
    required int currentUserId,
    required String currentUserName,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMessage = ChatMessageModel(
      id: tempId,
      roomId: roomId,
      userId: currentUserId,
      senderName: currentUserName,
      message: text,
      messageType: messageType,
      metadata: metadata,
      deliveryStatus: 'pending', // Red Clock initially
      createdAt: DateTime.now().toIso8601String(),
    );

    _activeRoomMessages.add(tempMessage);
    notifyListeners();

    try {
      final res = await apiClient.post(
        ApiConstants.chatRoomMessages(roomId),
        body: {
          'message': text,
          'message_type': messageType,
          if (metadata != null) 'metadata': metadata,
        },
      );

      final realMsg = ChatMessageModel.fromJson(Map<String, dynamic>.from(res as Map));
      final idx = _activeRoomMessages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        _activeRoomMessages[idx] = realMsg;
      }
      notifyListeners();
      return true;
    } catch (e) {
      // Mark as failed/offline (remains red clock pending)
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> markRoomAsRead(int roomId, [int? messageId]) async {
    try {
      await apiClient.post(
        ApiConstants.chatRoomRead(roomId),
        body: messageId != null ? {'message_id': messageId} : null,
      );
      // Decrement unread count locally for responsive UI
      final rIdx = _rooms.indexWhere((r) => r.id == roomId);
      if (rIdx != -1) {
        final r = _rooms[rIdx];
        _rooms[rIdx] = ChatRoomModel(
          id: r.id,
          type: r.type,
          name: r.name,
          otherUserName: r.otherUserName,
          otherUserEmail: r.otherUserEmail,
          otherMemberStatus: r.otherMemberStatus,
          lastMessage: r.lastMessage,
          lastMessageType: r.lastMessageType,
          lastMessageAt: r.lastMessageAt,
          unreadCount: 0,
          createdAt: r.createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
