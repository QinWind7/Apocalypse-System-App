import 'package:flutter/material.dart';

/// 浅色极简主题配色。
class AppColors {
  const AppColors._();

  /// 页面背景：柔和的浅灰偏白。
  static const Color background = Color(0xFFF7F8FA);

  /// 面板与卡片的纯白底色。
  static const Color surface = Color(0xFFFFFFFF);

  /// 次级底色：编号块、已完成标签等。
  static const Color surfaceMuted = Color(0xFFF4F5F8);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textTertiary = Color(0xFFB4B8C2);

  /// 底层数据感的淡蓝灰色，用于等宽英文前缀与编号。
  static const Color techLabel = Color(0xFFA3AFC2);

  /// 主强调色：深邃蓝紫，仅用于高亮，不发光。
  static const Color accent = Color(0xFF4C56B8);
  static const Color accentSoft = Color(0xFFEFF0FA);

  static const Color success = Color(0xFF3FA47A);
  static const Color divider = Color(0xFFEDEFF3);
}

/// 统一的柔和投影：大模糊、极低透明度。
class AppShadows {
  const AppShadows._();

  /// 任务卡片。
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D1A1A1A),
      blurRadius: 28,
      offset: Offset(0, 8),
    ),
  ];

  /// 外层大面板。
  static const List<BoxShadow> panel = [
    BoxShadow(
      color: Color(0x0A1A1A1A),
      blurRadius: 44,
      offset: Offset(0, 14),
    ),
  ];
}
