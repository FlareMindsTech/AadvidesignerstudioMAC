import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import 'skeleton_loader.dart';

class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData errorIcon;
  final Widget? placeholder;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorIcon = Icons.image_not_supported_outlined,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = ApiConfig.getImageUrl(imageUrl);

    if (cleanUrl.isEmpty) {
      return _buildErrorWidget();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: cleanUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: const {
        // Request JPEG/PNG/WebP explicitly — prevent CDNs from auto-serving AVIF
        'Accept': 'image/jpeg,image/png,image/webp,image/gif;q=0.8,*/*;q=0.5',
      },
      placeholder: (context, url) =>
          placeholder ??
          SkeletonLoader(
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            borderRadius: borderRadius,
          ),
      errorWidget: (context, url, error) => _buildErrorWidget(),
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          errorIcon,
          color: Colors.grey[400],
          size: (width != null && height != null && width!.isFinite && height!.isFinite) 
              ? (width! < height! ? width! : height!) * 0.4 
              : 30,
        ),
      ),
    );
  }
}
