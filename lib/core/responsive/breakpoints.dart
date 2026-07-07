import 'package:flutter/material.dart';

abstract final class Breakpoints {
  static const compact = 600.0;
  static const medium = 1024.0;
}

enum LayoutSize { compact, medium, expanded }

LayoutSize layoutSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.medium) return LayoutSize.expanded;
  if (width >= Breakpoints.compact) return LayoutSize.medium;
  return LayoutSize.compact;
}
