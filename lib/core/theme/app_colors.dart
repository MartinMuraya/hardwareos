import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand
  static const accent      = Color(0xFFFFB300); // Amber 700
  static const accentLight = Color(0xFFFFD54F); // Amber 300
  static const accentDark  = Color(0xFFF57F17); // Amber 900

  // ── Backgrounds
  static const background  = Color(0xFF0D0F14); // Deep navy-black
  static const surface     = Color(0xFF161A23); // Slightly lighter
  static const card        = Color(0xFF1C2130); // Card background
  static const surfaceLight= Color(0xFF232A3B); // Hover / selected
  static const inputFill   = Color(0xFF1A1F2E); // Input background

  // ── Text
  static const textPrimary   = Color(0xFFF0F2F8);
  static const textSecondary = Color(0xFF8B95A8);
  static const textHint      = Color(0xFF4F5869);

  // ── Borders
  static const border      = Color(0xFF252C3F);

  // ── Semantic
  static const success     = Color(0xFF22C55E);
  static const warning     = Color(0xFFF59E0B);
  static const error       = Color(0xFFEF4444);
  static const info        = Color(0xFF3B82F6);

  // ── Chart palette
  static const chartBlue    = Color(0xFF3B82F6);
  static const chartGreen   = Color(0xFF22C55E);
  static const chartAmber   = Color(0xFFFFB300);
  static const chartRed     = Color(0xFFEF4444);
  static const chartPurple  = Color(0xFFA855F7);
  static const chartCyan    = Color(0xFF06B6D4);

  // ── Plan badge colors
  static const planFree     = Color(0xFF4F5869);
  static const planStarter  = Color(0xFF3B82F6);
  static const planPro      = Color(0xFFFFB300);

  // ── Stock status
  static const stockCritical = Color(0xFFEF4444);
  static const stockLow      = Color(0xFFF59E0B);
  static const stockGood     = Color(0xFF22C55E);
}
