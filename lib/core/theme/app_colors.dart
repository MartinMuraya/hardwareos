import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand (Same for both)
  static const accent      = Color(0xFFFFB300); // Amber 700
  static const accentLight = Color(0xFFFFD54F); // Amber 300
  static const accentDark  = Color(0xFFF57F17); // Amber 900

  // ── Semantic (Same for both)
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

  // ── Dark Mode Colors
  static const bgDark         = Color(0xFF0D0F14); 
  static const surfaceDark    = Color(0xFF161A23); 
  static const cardDark       = Color(0xFF1C2130); 
  static const borderDark     = Color(0xFF252C3F);
  static const textPrimaryDark= Color(0xFFF0F2F8);
  static const textSecondaryDark = Color(0xFF8B95A8);

  // ── Light Mode Colors
  static const bgLight         = Color(0xFFF8FAFC); 
  static const surfaceLight    = Color(0xFFFFFFFF); 
  static const cardLight       = Color(0xFFFFFFFF); 
  static const borderLight     = Color(0xFFE2E8F0);
  static const textPrimaryLight= Color(0xFF0F172A);
  static const textSecondaryLight = Color(0xFF64748B);
  static const inputFillLight  = Color(0xFFF1F5F9);

  // Keep old constants for backward compatibility but marked as deprecated or just update them
  // to return based on brightness if possible, but better to use Theme.of(context).colorScheme
  @Deprecated('Use Theme.of(context).colorScheme.surface instead')
  static const background  = bgDark;
  @Deprecated('Use Theme.of(context).colorScheme.surface instead')
  static const surface     = surfaceDark;
  @Deprecated('Use Theme.of(context).cardColor instead')
  static const card        = cardDark;
  @Deprecated('Use Theme.of(context).dividerColor instead')
  static const border      = borderDark;
  static const textPrimary   = textPrimaryDark;
  static const textSecondary = textSecondaryDark;
  static const textHint      = Color(0xFF4F5869);
  static const inputFill   = Color(0xFF1A1F2E);
  static const surfaceLightAlt = Color(0xFF232A3B); // Renamed to avoid conflict
}
