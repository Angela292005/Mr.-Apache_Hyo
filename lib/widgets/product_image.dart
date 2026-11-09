import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../utils/drive_image_url.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: size,
      width: size,
      child: url.trim().isEmpty
          ? _placeholder()
          : CachedNetworkImage(
              imageUrl: displayImageUrl(url),
              fit: BoxFit.cover,
              placeholder: (context, url) => _placeholder(),
              errorWidget: (context, url, error) =>
                  _placeholder(icon: Icons.broken_image_outlined),
            ),
    ),
  );

  Widget _placeholder({IconData icon = Icons.local_pizza_outlined}) =>
      Container(
        color: const Color(0xFFFEF1ED),
        alignment: Alignment.center,
        child: Icon(icon, color: AppTheme.red, size: size * 0.48),
      );
}
