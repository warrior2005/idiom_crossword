import 'package:flutter/material.dart';

/// 头像框定义
class AvatarFrameDef {
  final String id;
  final String name;
  final int unlockLevel;
  final Color color;
  final Color glow;
  final double width;

  const AvatarFrameDef({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.color,
    required this.glow,
    required this.width,
  });
}

/// 称号特效定义
class TitleEffectDef {
  final String id;
  final String name;
  final int unlockLevel;
  final Color textColor;
  final Color glow;

  const TitleEffectDef({
    required this.id,
    required this.name,
    required this.unlockLevel,
    required this.textColor,
    required this.glow,
  });
}

/// 头像框目录（升级奖励解锁）
const List<AvatarFrameDef> avatarFrames = [
  AvatarFrameDef(
    id: 'wusha',
    name: '乌纱帽',
    unlockLevel: 5,
    color: Color(0xFF4A4A5E),
    glow: Color(0x334A4A5E),
    width: 2.5,
  ),
  AvatarFrameDef(
    id: 'xiezhi',
    name: '獬豸冠',
    unlockLevel: 13,
    color: Color(0xFF8A5A2B),
    glow: Color(0x338A5A2B),
    width: 3,
  ),
  AvatarFrameDef(
    id: 'sangong',
    name: '三公',
    unlockLevel: 18,
    color: Color(0xFFC9A227),
    glow: Color(0x55D9B23C),
    width: 3.5,
  ),
];

/// 称号特效目录（升级奖励解锁）
const List<TitleEffectDef> titleEffects = [
  TitleEffectDef(
    id: 'jinbang',
    name: '金榜题名',
    unlockLevel: 9,
    textColor: Color(0xFF8A5A14),
    glow: Color(0xFFE8C87A),
  ),
  TitleEffectDef(
    id: 'tianzi',
    name: '天子门生',
    unlockLevel: 17,
    textColor: Color(0xFF9E2B1C),
    glow: Color(0xFFD9B23C),
  ),
];

AvatarFrameDef? avatarFrameById(String id) {
  for (final def in avatarFrames) {
    if (def.id == id) return def;
  }
  return null;
}

TitleEffectDef? titleEffectById(String id) {
  for (final def in titleEffects) {
    if (def.id == id) return def;
  }
  return null;
}

/// 装饰条目显示名（升级奖励弹框、商城等）
String decorationName(String item) {
  return switch (item) {
    'grid_skin_bamboo' => '网格皮肤·竹简',
    'grid_skin_paper' => '网格皮肤·宣纸',
    'grid_skin_qinghua' => '网格皮肤·青花',
    'grid_skin_gold' => '网格皮肤·金箔',
    'grid_skin_emperor' => '网格皮肤·九五至尊',
    'avatar_frame_wusha' => '头像框·乌纱帽',
    'avatar_frame_xiezhi' => '头像框·獬豸冠',
    'avatar_frame_sangong' => '头像框·三公',
    'title_effect_jinbang' => '称号特效·金榜题名',
    'title_effect_tianzi' => '称号特效·天子门生',
    'custom_title_unlock' => '自定义称号解锁',
    _ => item,
  };
}

/// 称号文字应用特效（光晕/颜色），未激活或未知特效时原样返回
TextStyle applyTitleEffect(String? effectId, TextStyle base) {
  if (effectId == null) return base;
  final def = titleEffectById(effectId);
  if (def == null) return base;
  return base.copyWith(
    color: def.textColor,
    shadows: [
      Shadow(color: def.glow.withValues(alpha: 0.75), blurRadius: 10),
      Shadow(color: def.glow.withValues(alpha: 0.4), blurRadius: 22),
    ],
  );
}
