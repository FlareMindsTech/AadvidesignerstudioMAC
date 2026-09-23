import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'skeleton_loader.dart';

class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;
  final double size;
  final bool isGroup;
  final bool hasUnread;
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    this.photoUrl,
    required this.displayName,
    this.size = 56,
    this.isGroup = false,
    this.hasUnread = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Robust check for invalid URLs
    final hasValidUrl = photoUrl != null &&
        photoUrl!.trim().isNotEmpty &&
        photoUrl != 'null' &&
        photoUrl != 'undefined';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasUnread
            ? Border.all(
                color: const Color(0xFF5a189a),
                width: 2.5,
              )
            : null,
      ),
      child: ClipOval(
        child: Container(
          color: backgroundColor ?? Colors.grey[300], // Standard WhatsApp style grey
          child: hasValidUrl
              ? Image.network(
                  ApiConfig.getImageUrl(photoUrl),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  headers: const {
                    'Accept': 'image/webp,image/jpeg,image/png,image/gif;q=0.8,*/*;q=0.5',
                  },
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SkeletonLoader.circle(size: size);
                  },
                )
              : _buildPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        isGroup ? Icons.group_rounded : Icons.person_rounded,
        color: Colors.white,
        size: size * 0.75, // Slightly larger icon, WhatsApp style
      ),
    );
  }
}
