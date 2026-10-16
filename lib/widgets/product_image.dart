import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

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
      child: url.isEmpty
          ? Container(
              color: const Color(0xFFFFE9C7),
              child: const Icon(
                Icons.local_pizza,
                color: AppTheme.red,
                size: 34,
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image),
            ),
    ),
  );
}
