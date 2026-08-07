import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 网格皮肤主题
class GridSkin {
  final String id;
  final String name;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color accent;
  final Color accentPale;
  final Color accentDeep;
  final Color leaf;
  final Color leafSoft;
  final Color foreground;

  const GridSkin({
    required this.id,
    required this.name,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.accent,
    required this.accentPale,
    required this.accentDeep,
    required this.leaf,
    required this.leafSoft,
    required this.foreground,
  });
}

const List<GridSkin> gridSkins = [
  GridSkin(
    id: 'paper',
    name: '宣纸',
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    border: AppColors.border,
    borderStrong: AppColors.borderStrong,
    accent: AppColors.accent,
    accentPale: AppColors.accentPale,
    accentDeep: AppColors.accentDeep,
    leaf: AppColors.leaf,
    leafSoft: AppColors.leafSoft,
    foreground: AppColors.fg,
  ),
  GridSkin(
    id: 'bamboo',
    name: '竹简',
    surface: Color(0xFFF3EBD8),
    surface2: Color(0xFFE3D7B8),
    border: Color(0xFFD4C49A),
    borderStrong: Color(0xFFA99968),
    accent: Color(0xFF6E7F4F),
    accentPale: Color(0xFFE4E8D2),
    accentDeep: Color(0xFF4E5F38),
    leaf: Color(0xFF4E6E45),
    leafSoft: Color(0xFFDDE6D4),
    foreground: Color(0xFF3C3626),
  ),
  GridSkin(
    id: 'qinghua',
    name: '青花',
    surface: Color(0xFFF4F7F9),
    surface2: Color(0xFFDCE8F0),
    border: Color(0xFFB9CDDA),
    borderStrong: Color(0xFF6E8CA3),
    accent: Color(0xFF2F5D7E),
    accentPale: Color(0xFFDCE9F2),
    accentDeep: Color(0xFF1E3F5C),
    leaf: Color(0xFF3E7A7A),
    leafSoft: Color(0xFFD8E8E8),
    foreground: Color(0xFF22303C),
  ),
  GridSkin(
    id: 'gold',
    name: '金箔',
    surface: Color(0xFFFBF3D9),
    surface2: Color(0xFFF0E0AC),
    border: Color(0xFFD9BE67),
    borderStrong: Color(0xFFB08A28),
    accent: Color(0xFFB08A28),
    accentPale: Color(0xFFF6E7B2),
    accentDeep: Color(0xFF7A5D14),
    leaf: Color(0xFF4E6E45),
    leafSoft: Color(0xFFDDE6D4),
    foreground: Color(0xFF4A3B10),
  ),
  GridSkin(
    id: 'emperor',
    name: '九五至尊',
    surface: Color(0xFF2B2720),
    surface2: Color(0xFF403A2C),
    border: Color(0xFF6B5A2E),
    borderStrong: Color(0xFFC9A227),
    accent: Color(0xFFD9B23C),
    accentPale: Color(0xFF4A4128),
    accentDeep: Color(0xFFF0D27A),
    leaf: Color(0xFF9DBB8A),
    leafSoft: Color(0xFF39452F),
    foreground: Color(0xFFF0E7D0),
  ),
];

GridSkin? gridSkinById(String id) {
  for (final skin in gridSkins) {
    if (skin.id == id) return skin;
  }
  // 兼容旧数据：历史“龙纹”皮肤映射到青花
  if (id == 'dragon') return gridSkinById('qinghua');
  return null;
}
