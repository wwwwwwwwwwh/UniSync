import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PixelCard extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double shadowOffset;

  const PixelCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.shadowOffset = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary, // Wood Frame
          width: 3,
        ),
        boxShadow: [
          // Hard "Pixel" Shadow
          BoxShadow(
            color: AppColors.shadow.withOpacity(0.4),
            offset: const Offset(6, 6),
            blurRadius: 0, 
          ),
          // Inner Bevel (simulated with gradient or just simple flat)
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13), // slightly less than border
        child: Container(
          decoration: BoxDecoration(
            // Subtle texture or inner highlight could go here
            color: backgroundColor ?? AppColors.surface, 
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

