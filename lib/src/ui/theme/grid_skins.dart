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
  final String source; // 'level' 等级皮肤 / 'ads' 广告兑换

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
    required this.source,
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
    source: 'level',
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
    source: 'level',
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
    source: 'level',
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
    source: 'level',
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
    source: 'level',
  ),
  GridSkin(
    id: 'moyu',
    name: '墨玉',
    surface: Color(0xFF2F4A3E),
    surface2: Color(0xFF3E5C4E),
    border: Color(0xFF597563),
    borderStrong: Color(0xFF9DB8A4),
    accent: Color(0xFFB7D3BF),
    accentPale: Color(0xFF415A4C),
    accentDeep: Color(0xFFE3EFE5),
    leaf: Color(0xFF9DBB8A),
    leafSoft: Color(0xFF39452F),
    foreground: Color(0xFFF0F4EC),
    source: 'ads',
  ),
  GridSkin(
    id: 'jiangzi',
    name: '绛紫',
    surface: Color(0xFFEDE3EF),
    surface2: Color(0xFFD6BFDB),
    border: Color(0xFFBE9CC6),
    borderStrong: Color(0xFF74417F),
    accent: Color(0xFF4A2B5C),
    accentPale: Color(0xFFE0CDE4),
    accentDeep: Color(0xFF331A40),
    leaf: Color(0xFF5D4878),
    leafSoft: Color(0xFFDCCFE8),
    foreground: Color(0xFF241526),
    source: 'ads',
  ),
  GridSkin(
    id: 'dailan',
    name: '黛蓝',
    surface: Color(0xFF274B6D),
    surface2: Color(0xFF345F82),
    border: Color(0xFF55809F),
    borderStrong: Color(0xFFA9C4D6),
    accent: Color(0xFFBFD9EA),
    accentPale: Color(0xFF3D6484),
    accentDeep: Color(0xFFE5F1F8),
    leaf: Color(0xFF9DBB8A),
    leafSoft: Color(0xFF39452F),
    foreground: Color(0xFFF0F5F8),
    source: 'ads',
  ),
  GridSkin(
    id: 'zhusha',
    name: '朱砂',
    surface: Color(0xFFF7EBE2),
    surface2: Color(0xFFEDCFBE),
    border: Color(0xFFDCA28C),
    borderStrong: Color(0xFF9E2B1C),
    accent: Color(0xFF9E2B1C),
    accentPale: Color(0xFFF0D8CC),
    accentDeep: Color(0xFF771F12),
    leaf: Color(0xFF4E6E45),
    leafSoft: Color(0xFFDDE6D4),
    foreground: Color(0xFF351E15),
    source: 'ads',
  ),
  GridSkin(
    id: 'qiuxiang',
    name: '秋香',
    surface: Color(0xFFF5F0DC),
    surface2: Color(0xFFE7DCB4),
    border: Color(0xFFD0C084),
    borderStrong: Color(0xFF8A7A3A),
    accent: Color(0xFF8A7A3A),
    accentPale: Color(0xFFEFE4BC),
    accentDeep: Color(0xFF5F521F),
    leaf: Color(0xFF4E6E45),
    leafSoft: Color(0xFFDDE6D4),
    foreground: Color(0xFF3D3518),
    source: 'ads',
  ),
  GridSkin(
    id: 'ouhe',
    name: '藕荷',
    surface: Color(0xFFFBF1F3),
    surface2: Color(0xFFF2DCE2),
    border: Color(0xFFE0BCC8),
    borderStrong: Color(0xFFC88CA0),
    accent: Color(0xFFC96F8B),
    accentPale: Color(0xFFF3E0E6),
    accentDeep: Color(0xFF8A3F5A),
    leaf: Color(0xFF6E8A6A),
    leafSoft: Color(0xFFDDE6D4),
    foreground: Color(0xFF4A2835),
    source: 'ads',
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
