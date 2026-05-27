import 'package:flutter/material.dart';

class ParishGradients {
  // Header/Hero Gradients
  static const LinearGradient blueHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E40AF), // Blue-700
      Color(0xFF1E3A8A), // Blue-800
      Color(0xFF1E3A8A), // Blue-800
    ],
  );

  // Button Gradients
  static const LinearGradient primaryButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF2563EB), // Blue-600
      Color(0xFF1E40AF), // Blue-700
    ],
  );

  // Background Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEFF6FF), // Blue-50
      Color(0xFFFFFFFF), // White
      Color(0xFFEFF6FF), // Blue-50
    ],
  );

  // Sacrament Card Gradients
  static const LinearGradient baptismGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1E40AF)], // Blue-600 to Blue-700
  );

  static const LinearGradient confirmationGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEA580C)], // Amber to Orange
  );

  static const LinearGradient weddingGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)], // Blue-500 to Blue-600
  );

  static const LinearGradient funeralGradient = LinearGradient(
    colors: [Color(0xFF6B7280), Color(0xFF4B5563)], // Gray-500 to Gray-600
  );

  static const LinearGradient houseBlessingGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)], // Green-500 to Green-600
  );

  static const LinearGradient anointingGradient = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Purple-500 to Purple-600
  );

  static const LinearGradient massIntentionGradient = LinearGradient(
    colors: [Color(0xFFEC4899), Color(0xFFDB2777)], // Pink-500 to Pink-600
  );

  static const LinearGradient firstCommunionGradient = LinearGradient(
    colors: [
      Color(0xFFFCD34D),
      Color(0xFFF59E0B),
    ], // Amber-300 to Amber-500 (gold tones for Eucharist)
  );
}
