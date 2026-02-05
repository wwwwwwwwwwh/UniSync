import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PixelInput extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  const PixelInput({
    super.key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface, // Paper
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary, // Ink/Wood border
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000), // Subtle inner-like drop
            offset: Offset(0, 4),
            blurRadius: 0,
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        style: AppTextStyles.pixelBody,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.subtle),
          // isDense: true, 
          contentPadding: const EdgeInsets.symmetric(vertical: 14), // Center text vertically
        ),
      ),
    );
  }
}

