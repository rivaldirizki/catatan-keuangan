import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../models/chat_room_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../services/permission_service.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/media_attachment_sheet.dart';

class ChatRoomScreen extends StatefulWidget {
  final ChatRoomModel room;

  const ChatRoomScreen({super.key, required this.room});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final hasText = _textController.text.trim().isNotEmpty;
      if (hasText != _canSend) {
        setState(() => _canSend = hasText);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      final chat = context.read<ChatProvider>();
      chat.openRoom(widget.room.id);
      if (user != null) {
        chat.syncOfflineMessages(user.id, user.name);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    HapticFeedback.lightImpact();
    _textController.clear();

    context.read<ChatProvider>().sendMessage(
      widget.room.id,
      text,
      currentUserId: user.id,
      currentUserName: user.name,
    );
  }

  Future<void> _openCameraDirectly() async {
    final granted = await PermissionService.requestCameraPermission();
    if (!granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin kamera diperlukan untuk mengambil foto langsung.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo == null || !mounted) return;

      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user == null) return;

      HapticFeedback.mediumImpact();
      await context.read<ChatProvider>().sendMediaMessage(
        widget.room.id,
        File(photo.path),
        mediaType: 'image',
        currentUserId: user.id,
        currentUserName: user.name,
        customFileName: photo.name,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showAttachmentMenu() async {
    final option = await MediaAttachmentSheet.show(context);
    if (option == null || !mounted) return;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final chat = context.read<ChatProvider>();

    switch (option) {
      case MediaAttachmentType.camera:
        await _openCameraDirectly();
        break;

      case MediaAttachmentType.gallery:
        await PermissionService.requestStoragePermission();
        try {
          final picker = ImagePicker();
          final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
          if (photo == null || !mounted) return;

          HapticFeedback.mediumImpact();
          await chat.sendMediaMessage(
            widget.room.id,
            File(photo.path),
            mediaType: 'image',
            currentUserId: user.id,
            currentUserName: user.name,
            customFileName: photo.name,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memilih foto: $e'), behavior: SnackBarBehavior.floating),
          );
        }
        break;

      case MediaAttachmentType.video:
        await PermissionService.requestStoragePermission();
        try {
          final picker = ImagePicker();
          final video = await picker.pickVideo(source: ImageSource.gallery);
          if (video == null || !mounted) return;

          HapticFeedback.mediumImpact();
          await chat.sendMediaMessage(
            widget.room.id,
            File(video.path),
            mediaType: 'video',
            currentUserId: user.id,
            currentUserName: user.name,
            customFileName: video.name,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memilih video: $e'), behavior: SnackBarBehavior.floating),
          );
        }
        break;

      case MediaAttachmentType.document:
        await PermissionService.requestStoragePermission();
        try {
          final file = await FilePicker.pickFile();
          if (file == null || file.path == null || !mounted) return;

          HapticFeedback.mediumImpact();
          await chat.sendMediaMessage(
            widget.room.id,
            File(file.path!),
            mediaType: 'file',
            currentUserId: user.id,
            currentUserName: user.name,
            customFileName: file.name,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memilih berkas: $e'), behavior: SnackBarBehavior.floating),
          );
        }
        break;
    }
  }

  void _showFinancialShareDialog() {
    final amountController = TextEditingController();
    final categoryController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bagikan Catatan Finansial',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: 'Contoh: 150000',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: InputDecoration(
                  labelText: 'Kategori / Keperluan',
                  hintText: 'Contoh: Belanja Bulanan / Kas Operasional',
                  prefixIcon: const Icon(Icons.category_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'Keterangan Pesan',
                  hintText: 'Contoh: Ini rincian belanja kemarin ya',
                  prefixIcon: const Icon(Icons.note_alt_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final amount = int.tryParse(amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    if (amount <= 0) return;

                    final auth = context.read<AuthProvider>();
                    final user = auth.currentUser;
                    if (user == null) return;

                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();

                    context.read<ChatProvider>().sendMessage(
                      widget.room.id,
                      notesController.text.trim().isNotEmpty
                          ? notesController.text.trim()
                          : 'Catatan Finansial: Rp $amount',
                      messageType: 'financial_share',
                      metadata: {
                        'amount': amount,
                        'category': categoryController.text.trim().isNotEmpty
                            ? categoryController.text.trim()
                            : 'Umum',
                      },
                      currentUserId: user.id,
                      currentUserName: user.name,
                    );
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  label: const Text('Kirim ke Obrolan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? 0;
    final isGroup = widget.room.isFamily || widget.room.isCompany;
    final isPending = widget.room.isPendingApproval;

    final messages = chat.activeRoomMessages;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1C1C1E), size: 20),
          onPressed: () {
            chat.closeRoom();
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: widget.room.isFamily
                  ? const Color(0xFFEE4D2D).withValues(alpha: 0.15)
                  : (widget.room.isCompany
                      ? const Color(0xFF1C1C1E).withValues(alpha: 0.1)
                      : const Color(0xFF007AFF).withValues(alpha: 0.12)),
              child: Icon(
                widget.room.isFamily
                    ? Icons.family_restroom_rounded
                    : (widget.room.isCompany ? Icons.business_rounded : Icons.person_rounded),
                size: 20,
                color: widget.room.isFamily
                    ? const Color(0xFFEE4D2D)
                    : (widget.room.isCompany ? const Color(0xFF1C1C1E) : const Color(0xFF007AFF)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.room.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.room.isFamily
                        ? 'Grup Keluarga'
                        : (widget.room.isCompany
                            ? 'Grup Perusahaan'
                            : (isPending ? 'Menunggu Konfirmasi' : 'Obrolan Pribadi')),
                    style: TextStyle(
                      fontSize: 11,
                      color: isPending ? AppTheme.expenseRed : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (isPending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFF3CD),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Undangan obrolan masih menunggu konfirmasi dari lawan bicara. Anda baru dapat mengirim pesan setelah undangan disetujui.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chat.isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'Belum ada pesan',
                              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Mulai percakapan dengan menyapa di sini',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (ctx, index) {
                          final msg = messages[messages.length - 1 - index];
                          final isMe = msg.userId == currentUserId;
                          return ChatBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            isMe: isMe,
                            isGroup: isGroup,
                            onDelete: isMe
                                ? () {
                                    chat.deleteMessage(
                                      widget.room.id,
                                      msg.id,
                                      msg.metadata?['local_path'] as String?,
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
          ),
          // Input bar
          Container(
            padding: EdgeInsets.only(
              left: 6,
              right: 10,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E5EA), width: 0.8)),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Row(
                children: [
                  // Financial Card Share Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_card_rounded, color: Color(0xFF007AFF), size: 19),
                    ),
                    tooltip: 'Bagikan Catatan Finansial',
                    onPressed: isPending ? null : _showFinancialShareDialog,
                  ),
                  // Direct Camera Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF34C759), size: 19),
                    ),
                    tooltip: 'Ambil Foto dari Kamera',
                    onPressed: isPending ? null : _openCameraDirectly,
                  ),
                  // Media Attachment (Gallery, Video, Document) Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E8E93).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.attach_file_rounded, color: Color(0xFF636366), size: 19),
                    ),
                    tooltip: 'Kirim Lampiran Media',
                    onPressed: isPending ? null : _showAttachmentMenu,
                  ),
                  // Text field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _textController,
                        enabled: !isPending,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: isPending ? 'Menunggu konfirmasi...' : 'Tulis pesan...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  Container(
                    decoration: BoxDecoration(
                      color: _canSend && !isPending ? const Color(0xFF007AFF) : Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      onPressed: _canSend && !isPending ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
