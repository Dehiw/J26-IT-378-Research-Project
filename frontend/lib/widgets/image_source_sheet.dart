import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

/// Bottom sheet that lets the user choose between Camera and Gallery.
class ImageSourceSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const ImageSourceSheet({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCamera,
    required VoidCallback onGallery,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ImageSourceSheet(
        onCamera: onCamera,
        onGallery: onGallery,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Select Image Source',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose how to provide the hive image',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SourceOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  subtitle: 'Take a photo',
                  color: AppColors.accent,
                  onTap: () {
                    Navigator.pop(context);
                    onCamera();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SourceOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  subtitle: 'Pick from library',
                  color: AppColors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    onGallery();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
