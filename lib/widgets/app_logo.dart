import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius = 12,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: Colors.black,
        alignment: Alignment.center,
        child: Icon(
          Icons.local_pizza,
          color: const Color(0xFFFFC107),
          size: size * 0.62,
        ),
      ),
    ),
  );
}
