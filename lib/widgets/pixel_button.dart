import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PixelButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? color;
  final Color? textColor;
  final double width;
  final double height;

  const PixelButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color,
    this.textColor,
    this.width = double.infinity,
    this.height = 50,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.color ?? AppColors.secondary;
    final borderColor = AppColors.primary; // Wood frame for everything
    
    // Press offset
    final double offset = _isPressed ? 0 : 4;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 50),
        width: widget.width,
        height: widget.height,
        margin: EdgeInsets.only(top: _isPressed ? 4 : 0, bottom: _isPressed ? 0 : 4), // Physical movement
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 3,
          ),
          boxShadow: [
            if (!_isPressed)
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.5),
                offset: const Offset(0, 4), // 3D depth
                blurRadius: 0,
              ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: AppTextStyles.pixelButton.copyWith(
              color: widget.textColor ?? Colors.white, // Chalk text
              fontSize: 18,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
