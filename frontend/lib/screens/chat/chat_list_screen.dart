import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/chat_room_model.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/invitation_card.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  final bool isEmbedded;

  const ChatListScreen({super.key, this.isEmbedded = true});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();
      if (auth.currentUser?.chatInviteCode != null) {
        chat.fetchMyChatCode(auth.currentUser!.chatInviteCode);
      }
      chat.refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyCode(String code) {
    if (code.isEmpty || code == '...' || code == 'Memuat...') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode chat sedang dimuat, silakan tunggu sebentar...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Kode chat $code berhasil disalin!'),
          ],
        ),
        backgroundColor: AppTheme.incomeGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInviteDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF007AFF)),
            SizedBox(width: 10),
            Text('Mulai Chat Pribadi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan kode chat teman Anda untuk mengirimkan permohonan obrolan pribadi.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Kode Chat Teman',
                hintText: 'Contoh: CHAT-4B9F1E2A',
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.isEmpty) return;

              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();

              final chat = context.read<ChatProvider>();
              final success = await chat.sendDirectInvite(code);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Undangan obrolan berhasil dikirim! Menunggu konfirmasi.'),
                      backgroundColor: AppTheme.incomeGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (chat.errorMessage != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(chat.errorMessage!),
                      backgroundColor: AppTheme.expenseRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Kirim Undangan'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat('HH:mm').format(dt);
      }
      return DateFormat('dd/MM').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildRoomItem(ChatRoomModel room, {required VoidCallback onTap}) {
    final hasUnread = room.unreadCount > 0;
    final isPending = room.isPendingApproval;

    Color avatarBg;
    IconData avatarIcon;
    Color iconColor;

    if (room.isFamily) {
      avatarBg = const Color(0xFFEE4D2D).withValues(alpha: 0.12);
      avatarIcon = Icons.family_restroom_rounded;
      iconColor = const Color(0xFFEE4D2D);
    } else if (room.isCompany) {
      avatarBg = const Color(0xFF1C1C1E).withValues(alpha: 0.1);
      avatarIcon = Icons.business_rounded;
      iconColor = const Color(0xFF1C1C1E);
    } else {
      avatarBg = const Color(0xFF007AFF).withValues(alpha: 0.12);
      avatarIcon = Icons.person_rounded;
      iconColor = const Color(0xFF007AFF);
    }

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarBg,
                child: Icon(avatarIcon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: const Color(0xFF1C1C1E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (room.lastMessageAt != null)
                          Text(
                            _formatDate(room.lastMessageAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                              color: hasUnread ? const Color(0xFF007AFF) : AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isPending
                                ? 'Menunggu konfirmasi undangan obrolan...'
                                : (room.lastMessage ?? 'Belum ada pesan'),
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: isPending ? FontStyle.italic : FontStyle.normal,
                              color: isPending
                                  ? const Color(0xFFD97706)
                                  : (hasUnread ? const Color(0xFF1C1C1E) : AppTheme.textSecondary),
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF007AFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${room.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
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
    final myCode = chat.myChatCode ?? auth.currentUser?.chatInviteCode ?? 'Memuat...';

    final directRooms = chat.directRooms;
    final familyRoom = chat.familyRoom;
    final companyRoom = chat.companyRoom;
    final invitations = chat.pendingInvitations;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'Pesan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF1C1C1E)),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF007AFF)),
            tooltip: 'Undang Teman',
            onPressed: _showInviteDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF1C1C1E)),
            tooltip: 'Segarkan',
            onPressed: () => chat.refreshAll(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 2.5,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Pribadi'),
                  if (directRooms.any((r) => r.unreadCount > 0) || invitations.isNotEmpty) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF007AFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Keluarga'),
                  if (familyRoom != null && familyRoom.unreadCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEE4D2D),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Perusahaan'),
                  if (companyRoom != null && companyRoom.unreadCount > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1C1E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => chat.refreshAll(),
        child: Column(
          children: [
            // My Code Banner
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.iosDivider, width: 0.8),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.qr_code_rounded, size: 20, color: Color(0xFF007AFF)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kode Chat Saya',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
                        ),
                        Text(
                          myCode,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Color(0xFF1C1C1E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _copyCode(myCode),
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    label: const Text('Salin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Pribadi
                  ListView(
                    children: [
                      if (invitations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 16, top: 6, bottom: 4),
                          child: Text(
                            'Permintaan Obrolan Masuk (${invitations.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF007AFF),
                            ),
                          ),
                        ),
                        ...invitations.map((inv) => InvitationCard(invitation: inv)),
                        const Divider(height: 20, thickness: 0.8),
                      ],
                      if (directRooms.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum Ada Obrolan Pribadi',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Tekan ikon tambah di atas untuk mengundang teman dengan kode chat mereka.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else
                        ...directRooms.map(
                          (room) => _buildRoomItem(
                            room,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ChatRoomScreen(room: room)),
                              );
                            },
                          ),
                        ),
                    ],
                  ),

                  // Tab 2: Keluarga
                  ListView(
                    children: [
                      if (auth.currentUser?.familyId == null)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.family_restroom_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum Terhubung ke Keluarga',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Buat atau gabung ke grup keluarga di menu utama untuk mengaktifkan ruang obrolan keluarga otomatis.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else if (familyRoom != null)
                        _buildRoomItem(
                          familyRoom,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatRoomScreen(room: familyRoom)),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),

                  // Tab 3: Perusahaan
                  ListView(
                    children: [
                      if (auth.currentUser?.companyId == null)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Belum Terhubung ke Perusahaan',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Daftarkan atau gabung ke entitas bisnis di menu utama untuk mengaktifkan ruang obrolan perusahaan otomatis.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      else if (companyRoom != null)
                        _buildRoomItem(
                          companyRoom,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatRoomScreen(room: companyRoom)),
                            );
                          },
                        )
                      else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
