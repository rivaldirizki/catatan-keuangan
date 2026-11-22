import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/chat_room_model.dart';
import '../../models/chat_invitation_model.dart';
import '../../models/chat_message_model.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../services/offline_sync_service.dart';
import '../../services/local_storage_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiClient apiClient;

  List<ChatRoomModel> _rooms = [];
  List<ChatInvitationModel> _pendingInvitations = [];
  String? _myChatCode;
  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;

  // Active room state
  int? _activeRoomId;
  List<ChatMessageModel> _activeRoomMessages = [];
  Timer? _pollingTimer;

  ChatProvider({required this.apiClient});

  List<ChatRoomModel> get rooms => _rooms;
  List<ChatInvitationModel> get pendingInvitations => _pendingInvitations;
  String? get myChatCode => _myChatCode;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;

  int? get activeRoomId => _activeRoomId;
  List<ChatMessageModel> get activeRoomMessages => _activeRoomMessages;

  List<ChatRoomModel> get familyRooms =>
      _rooms.where((r) => r.isFamily).toList();

  ChatRoomModel? get familyRoom {
    try {
      return _rooms.firstWhere((r) => r.isFamily);
    } catch (_) {
      return null;
    }
  }

  List<ChatRoomModel> get companyRooms =>
      _rooms.where((r) => r.isCompany).toList();

  ChatRoomModel? get companyRoom {
    try {
      return _rooms.firstWhere((r) => r.isCompany);
    } catch (_) {
      return null;
    }
  }

  List<ChatRoomModel> get directRooms =>
      _rooms.where((r) => r.isDirect).toList();

  int get totalUnreadCount =>
      _rooms.fold(0, (sum, room) => sum + room.unreadCount);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchMyChatCode([String? fallbackCode]) async {
    if (fallbackCode != null && fallbackCode.isNotEmpty && _myChatCode == null) {
      _myChatCode = fallbackCode;
      notifyListeners();
    }
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
      deliveryStatus: 'pending', // Red Clock ⏱️
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
      await OfflineSyncService.enqueueChatMessage(currentUserId.toString(), {
        'temp_id': tempId,
        'room_id': roomId,
        'message': text,
        'message_type': messageType,
        'metadata': metadata,
        'user_id': currentUserId,
        'sender_name': currentUserName,
      });
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendMediaMessage(
    int roomId,
    File sourceFile, {
    required String mediaType, // 'image', 'video', 'file'
    String? caption,
    required int currentUserId,
    required String currentUserName,
    String? customFileName,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;

    // 1. Immediately save media locally in user's phone storage (on native platforms)
    final localPath = await LocalStorageService.saveMediaLocally(
      sourceFile,
      mediaType,
      customFileName: customFileName,
    );

    final initialMetadata = {
      'local_path': localPath,
      'file_name': customFileName ?? sourceFile.path.split(RegExp(r'[/\\]')).last,
      'file_size': await sourceFile.length(),
      'mime_type': mediaType == 'image' ? 'image/jpeg' : (mediaType == 'video' ? 'video/mp4' : 'application/octet-stream'),
    };

    final tempMessage = ChatMessageModel(
      id: tempId,
      roomId: roomId,
      userId: currentUserId,
      senderName: currentUserName,
      message: (caption != null && caption.trim().isNotEmpty)
          ? caption.trim()
          : (mediaType == 'image' ? 'Foto' : (mediaType == 'video' ? 'Video' : 'Dokumen')),
      messageType: mediaType,
      metadata: initialMetadata,
      deliveryStatus: 'pending', // Red Clock ⏱️
      createdAt: DateTime.now().toIso8601String(),
    );

    _activeRoomMessages.add(tempMessage);
    notifyListeners();

    try {
      // 2. Upload file to backend
      final uploadRes = await apiClient.postMultipart(
        ApiConstants.chatUpload,
        File(localPath),
      );

      final combinedMetadata = {
        ...initialMetadata,
        if (uploadRes is Map) ...Map<String, dynamic>.from(uploadRes),
      };

      // 3. Send message payload to room
      final res = await apiClient.post(
        ApiConstants.chatRoomMessages(roomId),
        body: {
          'message': tempMessage.message,
          'message_type': mediaType,
          'metadata': combinedMetadata,
        },
      );

      final realMsg = ChatMessageModel.fromJson(Map<String, dynamic>.from(res as Map));
      final idx = _activeRoomMessages.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        _activeRoomMessages[idx] = realMsg.copyWith(
          metadata: {
            ...realMsg.metadata ?? {},
            'local_path': localPath,
          },
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      await OfflineSyncService.enqueueChatMessage(currentUserId.toString(), {
        'temp_id': tempId,
        'room_id': roomId,
        'message': tempMessage.message,
        'message_type': mediaType,
        'metadata': initialMetadata,
        'user_id': currentUserId,
        'sender_name': currentUserName,
        'local_path': localPath,
      });
      notifyListeners();
      return false;
    }
  }

  Future<void> syncOfflineMessages(int currentUserId, String currentUserName) async {
    final queue = await OfflineSyncService.getChatQueue(currentUserId.toString());
    if (queue.isEmpty) return;

    for (final item in queue) {
      final tempId = item['temp_id'] as int;
      final roomId = item['room_id'] as int;
      final text = item['message'] as String;
      final messageType = (item['message_type'] as String?) ?? 'text';
      final metadata = item['metadata'] != null ? Map<String, dynamic>.from(item['metadata'] as Map) : null;
      final localPath = item['local_path'] as String?;

      try {
        Map<String, dynamic> finalMeta = metadata ?? {};
        if (!kIsWeb && localPath != null && await File(localPath).exists()) {
          final uploadRes = await apiClient.postMultipart(ApiConstants.chatUpload, File(localPath));
          if (uploadRes is Map) {
            finalMeta.addAll(Map<String, dynamic>.from(uploadRes));
          }
        }

        final res = await apiClient.post(
          ApiConstants.chatRoomMessages(roomId),
          body: {
            'message': text,
            'message_type': messageType,
            if (finalMeta.isNotEmpty) 'metadata': finalMeta,
          },
        );

        final realMsg = ChatMessageModel.fromJson(Map<String, dynamic>.from(res as Map));
        final idx = _activeRoomMessages.indexWhere((m) => m.id == tempId);
        if (idx != -1) {
          _activeRoomMessages[idx] = realMsg;
        }
        await OfflineSyncService.removeChatMessage(currentUserId.toString(), tempId);
      } catch (_) {
        // Still offline or failed, keep in queue
        break;
      }
    }
    notifyListeners();
  }

  Future<bool> deleteMessage(int roomId, int messageId, String? localPath) async {
    // 1. Physically delete file from device local storage
    if (localPath != null) {
      await LocalStorageService.deleteLocalFile(localPath);
    }

    // 2. Remove from active messages list
    _activeRoomMessages.removeWhere((m) => m.id == messageId);
    notifyListeners();

    // 3. If online message, delete from server database
    if (messageId > 0) {
      try {
        await apiClient.delete(ApiConstants.chatMessageDelete(messageId));
        return true;
      } catch (e) {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        notifyListeners();
        return false;
      }
    }
    return true;
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
