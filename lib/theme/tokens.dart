import 'package:flutter/material.dart';

/// Design tokens — Batch 1 Design System 2.61.0+164.
/// Satu sumber kebenaran untuk spacing, radius, durasi, elevasi.
/// Pakai token ini, jangan hardcode angka di widget baru.

class GlassSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class GlassRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double full = 999;
}

class GlassDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Curve curve = Curves.easeOutCubic;
  static const Curve spring = Curves.easeOutBack;
}

class GlassElevation {
  /// Kartu standar: bayangan halus satu level.
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// Hero / panel terangkat: sedikit lebih dalam.
  static List<BoxShadow> get hero => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  /// Tombol: glow halus di bawah.
  static List<BoxShadow> get button => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.22),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Sheet / dialog: bayangan atas.
  static List<BoxShadow> get sheet => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.32),
          blurRadius: 40,
          offset: const Offset(0, -8),
        ),
      ];
}

/// Warna kaca untuk dark mode (Noir) — background harus cukup gelap
/// agar efek blur + border putih terlihat.
class GlassColors {
  /// Overlay gelap di belakang kartu kaca (untuk light mode fallback).
  static const scrim = Color(0x99000000);

  /// Tint aksen untuk highlight kaca.
  static Color tint(Color base, double alpha) =>
      base.withValues(alpha: alpha);
}
