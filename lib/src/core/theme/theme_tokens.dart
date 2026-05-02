import 'package:flutter/material.dart';

class AppRadii {
  static const double xs = 8;
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

class AppSizes {
  static const double minTapTarget = 40;
  static const double inputHeight = 44;
  static const double buttonHeight = 44;
  static const double borderWidth = 1;
}

class AppMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOutCubic;
}

class AppTypography {
  static const TextStyle title = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
  static const TextStyle body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
  static const TextStyle helper = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
}

class AppElevation {
  static const double card = 1.0;
  static const double dialog = 4.0;
  static const double fab = 3.0;
}

