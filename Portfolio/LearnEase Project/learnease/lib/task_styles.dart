import 'package:flutter/material.dart';

class TaskColors {
  static const yellow = Color(0xFFFFE082);
  static const yellowDark = Color(0xFFFFC107);
  static const blue = Color(0xFF64B5F6);
  static const red = Color(0xFFE57373);
}

BoxDecoration cardBorder(Color c) => BoxDecoration(
  color: Colors.white,
  border: Border.all(color: c, width: 2),
  borderRadius: BorderRadius.circular(14),
  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
);

const double dateBubbleOffset = -6;
const double cardSpacing = 12;
