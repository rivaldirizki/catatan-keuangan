import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import '../../../models/chat_message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool isGroup;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
    this.onDelete,
  });

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  String _formatRupiah(int val) {
    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return currency.format(val);
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _hasLocalFile(String? path) {
    if (kIsWeb || path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  Widget _buildStatusReceipt() {
    final status = message.deliveryStatus ?? 'sent';
    switch (status) {
      case 'pending':
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.access_time_rounded, size: 13, color: Color(0xFFFF3B30)), // Jam Merah
        );
      case 'sent':
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.check_rounded, size: 14, color: Colors.white70), // Centang 1
        );
      case 'partially_read':
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.done_all_rounded, size: 15, color: Colors.white70), // Centang 2 Abu-abu
        );
      case 'read':
        return const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF34B7F1)), // Centang 2 Biru
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showActionSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF007AFF)),
                title: const Text('Salin Pesan', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: message.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pesan disalin ke papan klip'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              if (isMe && onDelete != null)
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.expenseRed),
                  title: const Text(
                    'Hapus Pesan & Berkas Lokal',
                    style: TextStyle(color: AppTheme.expenseRed, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(context);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Pesan?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Pesan ini akan dihapus dari obrolan, dan berkas media terkait akan langsung dihapus dari memori penyimpanan perangkat Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.expenseRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus Permanen'),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    final meta = message.metadata;
    final localPath = meta?['local_path'] as String?;
    final fileUrl = meta?['file_url'] as String?;
    final fileName = meta?['file_name'] as String? ?? 'Berkas';
    final fileSize = int.tryParse(meta?['file_size']?.toString() ?? '0');

    final serverHost = ApiConstants.baseUrl.replaceAll('/api/v1', '');
    final fullRemoteUrl = fileUrl != null ? '$serverHost$fileUrl' : null;
    final hasLocal = _hasLocalFile(localPath);

    if (message.messageType == 'image') {
      Widget imageWidget;
      if (hasLocal) {
        imageWidget = Image.file(
          File(localPath!),
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        );
      } else if (fullRemoteUrl != null) {
        imageWidget = Image.network(
          fullRemoteUrl,
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 48),
        );
      } else {
        imageWidget = const Icon(Icons.image_rounded, size: 48);
      }

      return GestureDetector(
        onTap: () {
          if (hasLocal) {
            OpenFilex.open(localPath!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: imageWidget,
        ),
      );
    }

    if (message.messageType == 'video') {
      return GestureDetector(
        onTap: () {
          if (hasLocal) {
            OpenFilex.open(localPath!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white : const Color(0xFFFF9500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 24,
                  color: isMe ? const Color(0xFF007AFF) : const Color(0xFFFF9500),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.messageType == 'file') {
      return GestureDetector(
        onTap: () {
          if (hasLocal) {
            OpenFilex.open(localPath!);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white : const Color(0xFF5856D6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  size: 22,
                  color: isMe ? const Color(0xFF007AFF) : const Color(0xFF5856D6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatFileSize(fileSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white70 : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);
    final isFinancial = message.isFinancialShare;
    final isMedia = ['image', 'video', 'file'].contains(message.messageType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          child: GestureDetector(
            onLongPress: () => _showActionSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF007AFF) : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isGroup && !isMe) ...[
                    Text(
                      message.senderName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5856D6),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (isMedia) _buildMediaContent(context),
                  if (isFinancial) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white.withValues(alpha: 0.15) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isMe ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFD1D1D6),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_rounded,
                                size: 16,
                                color: isMe ? Colors.white : const Color(0xFF007AFF),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (message.metadata?['category'] ?? 'Finansial').toString(),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isMe ? Colors.white70 : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatRupiah(message.metadata?['amount'] is int
                                ? message.metadata!['amount'] as int
                                : int.tryParse(message.metadata?['amount']?.toString() ?? '0') ?? 0),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isMedia || (message.message != 'Foto' && message.message != 'Video' && message.message != 'Dokumen'))
                    Text(
                      message.message,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : const Color(0xFF8E8E93),
                        ),
                      ),
                      if (isMe) _buildStatusReceipt(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
