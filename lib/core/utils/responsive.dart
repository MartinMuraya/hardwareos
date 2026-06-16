import 'package:flutter/material.dart';

class Responsive {
  static double _width(BuildContext context) => MediaQuery.of(context).size.width;

  static bool isMobile(BuildContext context) => _width(context) < 700;
  static bool isTablet(BuildContext context) => _width(context) >= 700 && _width(context) < 1024;
  static bool isDesktop(BuildContext context) => _width(context) >= 1024;

  static bool isMobileOrTablet(BuildContext context) => _width(context) < 1024;

  static double padding(BuildContext context) {
    final w = _width(context);
    if (w < 400) return 12;
    if (w < 700) return 16;
    if (w < 1024) return 20;
    return 24;
  }

  static double gridColumns(BuildContext context) {
    final w = _width(context);
    if (w >= 1200) return 4;
    if (w >= 900) return 3;
    if (w >= 600) return 2;
    return 1;
  }

  static EdgeInsets screenPadding(BuildContext context) {
    final p = padding(context);
    return EdgeInsets.all(p);
  }

  static EdgeInsets horizontalPadding(BuildContext context) {
    final p = padding(context);
    return EdgeInsets.symmetric(horizontal: p);
  }
}
