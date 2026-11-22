import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/chat_message_model.dart';
import '../../../core/theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;
  final bool isGroup;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isGroup = false,
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

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(message.createdAt);
    final isFinancial = message.isFinancialShare;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
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
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && isGroup) ...[
                  Text(
                    message.senderName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.iosBlue,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                if (isFinancial && message.metadata != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_rounded,
                              size: 15,
                              color: isMe ? Colors.white : AppTheme.iosBlue,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Catatan Finansial',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe ? Colors.white70 : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (message.metadata!['amount'] != null)
                          Text(
                            _formatRupiah(int.tryParse(message.metadata!['amount'].toString()) ?? 0),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                            ),
                          ),
                        if (message.metadata!['category'] != null)
                          Text(
                            message.metadata!['category'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isMe ? Colors.white70 : AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.3,
                    color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isMe ? Colors.white70 : Colors.black45,
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
    );
  }
}
