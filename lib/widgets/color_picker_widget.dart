// lib/widgets/color_picker_widget.dart

import 'package:flutter/material.dart';

class ColorPickerWidget extends StatefulWidget {
  final Color selectedColor;
  final Function(Color) onColorSelected;
  final String label;

  const ColorPickerWidget({
    Key? key,
    required this.selectedColor,
    required this.onColorSelected,
    this.label = 'Couleur',
  }) : super(key: key);

  @override
  State<ColorPickerWidget> createState() => _ColorPickerWidgetState();
}

class _ColorPickerWidgetState extends State<ColorPickerWidget> {
  final List<Color> _colors = [
    const Color(0xFF1E3A8A), // Bleu foncé
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFDC2626), // Rouge
    const Color(0xFF059669), // Vert
    const Color(0xFFD97706), // Orange
    const Color(0xFF7C3AED), // Pourpre
    const Color(0xFF0891B2), // Cyan
    const Color(0xFFBE185D), // Rose
    const Color(0xFF4B5563), // Gris
    const Color(0xFF0D9488), // Teal
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _colors.map((color) {
            final isSelected = color.value == widget.selectedColor.value;
            return GestureDetector(
              onTap: () => widget.onColorSelected(color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}