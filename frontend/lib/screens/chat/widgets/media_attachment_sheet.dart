import 'package:flutter/material.dart';

enum MediaAttachmentType {
  camera,
  gallery,
  video,
  document,
}

class MediaAttachmentSheet extends StatelessWidget {
  const MediaAttachmentSheet({super.key});

  static Future<MediaAttachmentType?> show(BuildContext context) async {
    return showModalBottomSheet<MediaAttachmentType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MediaAttachmentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kirim Lampiran Media',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildOption(
                  context,
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF007AFF),
                  label: 'Kamera',
                  onTap: () => Navigator.pop(context, MediaAttachmentType.camera),
                ),
                _buildOption(
                  context,
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF34C759),
                  label: 'Galeri',
                  onTap: () => Navigator.pop(context, MediaAttachmentType.gallery),
                ),
                _buildOption(
                  context,
                  icon: Icons.videocam_rounded,
                  color: const Color(0xFFFF9500),
                  label: 'Video',
                  onTap: () => Navigator.pop(context, MediaAttachmentType.video),
                ),
                _buildOption(
                  context,
                  icon: Icons.insert_drive_file_rounded,
                  color: const Color(0xFF5856D6),
                  label: 'Dokumen',
                  onTap: () => Navigator.pop(context, MediaAttachmentType.document),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
        ],
      ),
    );
  }
}
