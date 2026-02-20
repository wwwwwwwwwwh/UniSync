import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class CurrencyInput extends StatefulWidget {
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<double>? onChanged;

  const CurrencyInput({
    super.key,
    required this.hintText,
    required this.controller,
    this.onChanged,
  });

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  // We keep track of the raw integer value (e.g., 1234 -> 12.34)
  int _rawValue = 0;

  @override
  void initState() {
    super.initState();
    // Initialize _rawValue from controller text if it exists
    if (widget.controller.text.isNotEmpty) {
      try {
        final double val = double.parse(widget.controller.text);
        _rawValue = (val * 100).round();
      } catch (_) {
        _rawValue = 0;
      }
    }
    
    // Ensure the controller text matches the initial raw value
    _updateControllerText();
  }

  void _updateControllerText() {
    final double value = _rawValue / 100.0;
    final formatter = NumberFormat.currency(locale: 'en_US', symbol: '', decimalDigits: 2);
    // This formats it as "0.00", "12.34", "1,234.56"
    // We might want to remove grouping separators if that annoys parsing later, 
    // but the user requirement is mainly visual.
    // However, the controller is often read as `double.parse`.
    // So we should store valid double string in controller?
    // OR we just use the controller for display?
    
    // The previous code in AddExpensePage uses `num.tryParse(amountCtrl.text.trim())`.
    // `NumberFormat` adds commas. `1,234.56` causes `double.parse` to fail.
    
    // Let's use a non-grouping format for the controller text so the logic remains simple.
    // Or we format it nicely for display, but then we need to strip commas before parsing.
    
    // Wait, the user wants: "input holder will be 8.50"
    // So let's store "8.50" in the controller.
    
    widget.controller.text = value.toStringAsFixed(2);
    if (widget.onChanged != null) {
      widget.onChanged!(value);
    }
  }

  void _handleInput(String value) {
    // Value is the new character typed, or backspace check
    // Actually, since we want to control the input completely, 
    // it's better to intercept the input or just use an Invisible TextField with `keyboardType: number`
    // nicely handling the "push left" logic.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), offset: Offset(0, 4), blurRadius: 0)
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      alignment: Alignment.centerRight, // "first input will appear on the very right"
      child: TextField(
        controller: widget.controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
        style: AppTextStyles.pixelBody.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.right,
        showCursor: false, // Hide flashing indicator
        enableInteractiveSelection: false, // Disable selection/copy/paste
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.hintText,
          prefixText: 'RM ',
          prefixStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.subtle),
          hintStyle: AppTextStyles.pixelBody.copyWith(color: AppColors.subtle),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onTap: () {
          // Force cursor to end on tap
          final text = widget.controller.text;
          widget.controller.selection = TextSelection.collapsed(offset: text.length);
        },
        onChanged: (newText) {
           // Remove all non-digits
           String digits = newText.replaceAll(RegExp(r'\D'), '');
           
           if (digits.isEmpty) {
             _rawValue = 0;
           } else {
             _rawValue = int.parse(digits);
           }
           
           // Update Text and Cursor
           final double value = _rawValue / 100.0;
           final String newString = value.toStringAsFixed(2);
           
           // Set text and FORCE cursor to end
           widget.controller.value = TextEditingValue(
             text: newString,
             selection: TextSelection.collapsed(offset: newString.length),
           );
           
           if (widget.onChanged != null) {
              widget.onChanged!(value);
           }
        },
      ),
    );
  }
}
