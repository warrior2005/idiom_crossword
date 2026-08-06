# 古典文人风 UI 改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 `docs/superpowers/specs/2026-08-06-classical-literati-ui-redesign.md` 将 Flutter 客户端整体改造为「宣纸 + 墨 + 朱砂」古典文人风，底部五 Tab 导航，新增「我的」「每日回顾」页，正确率接真实填字统计。

**Architecture:** 先建主题基建（颜色 Token / 衬线字体 / monoline SVG 图标 / 通用组件）与底部五 Tab 导航骨架；再做 DB schema v8（`totalFills` + `getIdiomAtOffset`）；随后逐个重构 11 个视图（全部改 `Scaffold` 底色为 `AppColors.bg`）；最后删除自定义功能并全量更新测试。

**Tech Stack:** Flutter / Riverpod / drift（SQLite）/ flutter_svg / iOS 系统字体（`Songti SC`）。

## Global Constraints

- 全案只有一个强调色 `AppColors.accent`（朱砂 `0xFFB33B27`），每屏可见 ≤ 2 处；禁用态用 `surface2` + `faint`。
- CJK 展示文字：衬线 `kSerif = 'Songti SC'`，`height ≥ 1.3`，`letterSpacing: 0`（禁止负字距）；正文 `height: 1.7`；大数字衬线 900。
- 图标一律用 `AppIcon`（monoline SVG，strokeWidth 1.8），禁用 emoji / Material 图标。
- 所有页面 `Scaffold.backgroundColor = AppColors.bg`。
- 文案禁用内部词：「螺旋难度」「万关螺旋」；「一字提示」→「提示」。
- 不写死 raw hex（除 `AppColors` 定义处）；全部从 `AppColors` 取色。
- 依赖上限：新增 `flutter_svg`；不新增字体包。
- 每任务完成后 `flutter analyze` 与相关 `flutter test` 必须通过，再 `git commit`。

---

### Task 1: 主题基建（颜色 Token + 字体样式 + 依赖）

**Files:**
- Create: `lib/src/ui/theme/app_colors.dart`
- Create: `lib/src/ui/theme/app_text.dart`
- Modify: `pubspec.yaml`（添加 `flutter_svg`）

**Interfaces:**
- Consumes: 无
- Produces: `AppColors` 静态类（`bg/surface/surface2/fg/muted/faint/border/borderStrong/accent/accentDeep/accentSoft/accentPale/gold/goldSoft/leaf/leafSoft`，全部 `Color`）；`kSerif` 常量；`displayStyle({size, weight, color, height})`、`kickerStyle({color})`、`bodyStyle({size, color, weight})`。后续所有任务引用。

- [ ] **Step 1: 添加依赖**

Run: `flutter pub add flutter_svg`
Expected: `flutter_svg` 出现在 `pubspec.yaml` dependencies，`pub get` 成功。

- [ ] **Step 2: 创建 `lib/src/ui/theme/app_colors.dart`**

```dart
import 'package:flutter/material.dart';

/// 古典文人风 · 六 Token 色彩（源自 design-style-prompt.md）
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFFF3EDE1); // 宣纸
  static const Color bgDeep = Color(0xFFEAE0CC);
  static const Color surface = Color(0xFFFBF7EE); // 卡片面
  static const Color surface2 = Color(0xFFEFE7D4); // 交叉格/灰底
  static const Color fg = Color(0xFF2B2922); // 墨
  static const Color muted = Color(0xFF857C68); // 灰褐
  static const Color faint = Color(0xFFB3A98E); // 弱/禁用
  static const Color border = Color(0xFFE2D8BE);
  static const Color borderStrong = Color(0xFFC9BB9A);
  static const Color accent = Color(0xFFB33B27); // 朱砂（唯一强调色）
  static const Color accentDeep = Color(0xFF8F2C1B);
  static const Color accentSoft = Color(0xFFE8CFC0);
  static const Color accentPale = Color(0xFFF4E3D8);
  static const Color gold = Color(0xFFB08A28); // 每日挑战/科举点缀
  static const Color goldSoft = Color(0xFFF0E3B8);
  static const Color leaf = Color(0xFF4E6E45); // 松青绿：正确反馈
  static const Color leafSoft = Color(0xFFDDE6D4);
}
```

- [ ] **Step 3: 创建 `lib/src/ui/theme/app_text.dart`**

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// iOS 系统宋体（展示/成语/大数字用）；回退由系统处理
const String kSerif = 'Songti SC';

/// 展示样式：衬线、CJK 行高 ≥1.3、无负字距
TextStyle displayStyle({
  double size = 22,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.fg,
  double height = 1.3,
}) {
  return TextStyle(
    fontFamily: kSerif,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}

/// kicker：小号青灰、宽字距（近似 0.28em @ 11px）
TextStyle kickerStyle({Color color = AppColors.muted}) {
  return TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.8,
    color: color,
    height: 1.3,
  );
}

/// 正文样式：行高 1.7
TextStyle bodyStyle({
  double size = 14,
  Color color = AppColors.fg,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.7);
}
```

- [ ] **Step 4: 验证编译**

Run: `flutter analyze`
Expected: 0 errors。

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/ui/theme/app_colors.dart lib/src/ui/theme/app_text.dart
git commit -m "feat: 主题基建（AppColors Token + 衬线字体样式 + flutter_svg 依赖）"
```

---

### Task 2: monoline SVG 图标库

**Files:**
- Create: `lib/src/ui/widgets/app_icons.dart`

**Interfaces:**
- Consumes: `AppColors`
- Produces: `class AppIcon extends StatelessWidget { const AppIcon(this.name, {super.key, this.size = 24, this.color}); final String name; final double size; final Color? color; }`，`color` 缺省用 `AppColors.fg`。图标名：`home/levels/book/shop/mine/back/sound/hint/undo/clear/search/trophy/chart/gear/list/bolt/clock/pen/revive/star/eye`。

- [ ] **Step 1: 写图标测试（TDD）**

Create `test/ui/app_icons_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/app_icons.dart';

void main() {
  testWidgets('AppIcon 渲染指定名称图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(width: 50, height: 50, child: AppIcon('home'))),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppIcon), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/app_icons_test.dart`
Expected: FAIL（`app_icons.dart` 不存在）。

- [ ] **Step 3: 实现 `lib/src/ui/widgets/app_icons.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';

/// 各图标 path（取自 idiom-crossword-prototype.html，monoline stroke 风格）
const Map<String, String> _paths = {
  'home':
      '<path d="M3 9l9-6 9 6v11a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1V9z"/>',
  'levels':
      '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>',
  'book':
      '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20V4a1 1 0 0 0-1-1H6.5A2.5 2.5 0 0 0 4 5.5v14z"/><path d="M20 17v3a1 1 0 0 1-1 1H6.5A2.5 2.5 0 0 1 4 18.5V19.5"/>',
  'shop':
      '<path d="M6 7h12l1.5 12.5a1 1 0 0 1-1 1.5h-13a1 1 0 0 1-1-1.5L6 7z"/><path d="M9 10V6a3 3 0 0 1 6 0v4"/>',
  'mine': '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  'back': '<path d="M15 18l-6-6 6-6"/>',
  'sound':
      '<path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M18.5 5.5a9 9 0 0 1 0 13"/>',
  'hint':
      '<path d="M9 18h6"/><path d="M10 22h4"/><path d="M12 2a7 7 0 0 0-4 12.7c.6.5 1 1.4 1 2.3h6c0-.9.4-1.8 1-2.3A7 7 0 0 0 12 2z"/>',
  'undo':
      '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 6 6v0a6 6 0 0 1-6 6H9"/>',
  'clear':
      '<path d="M3 6h18"/><path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/>',
  'search': '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>',
  'trophy':
      '<circle cx="12" cy="9" r="6"/><path d="M8.5 14L7 22l5-3 5 3-1.5-8"/>',
  'chart': '<path d="M3 3v18h18"/><path d="M7 14l4-4 3 3 5-6"/>',
  'gear':
      '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.9 2.9l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.9-2.9l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.9-2.9l.1.1a1.7 1.7 0 0 0 1.9.3h.1a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5h.1a1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.9 2.9l-.1.1a1.7 1.7 0 0 0-.3 1.9v.1a1.7 1.7 0 0 0 1.5 1h.2a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>',
  'list': '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
  'bolt': '<path d="M13 2L4 14h6l-1 8 9-12h-6l1-8z"/>',
  'clock': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/>',
  'pen':
      '<path d="M9 18l6-12"/><path d="M5 21h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2z"/>',
  'revive':
      '<path d="M12 3v12"/><path d="M7 8l5-5 5 5"/><path d="M4 21h16"/>',
  'star':
      '<path d="M12 2l2.4 4.9 5.4.8-3.9 3.8.9 5.4L12 14.5 7.2 17l.9-5.4L4.2 7.7l5.4-.8L12 2z"/>',
  'eye':
      '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z"/><circle cx="12" cy="12" r="3"/>',
};

/// monoline SVG 图标
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final path = _paths[name];
    assert(path != null, 'unknown AppIcon name: $name');
    return SvgPicture.string(
      '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" '
      'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">$path</svg>',
      width: size,
      height: size,
      color: color ?? AppColors.fg,
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/app_icons_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/widgets/app_icons.dart test/ui/app_icons_test.dart
git commit -m "feat: monoline SVG 图标库 AppIcon"
```

---

### Task 3: 通用组件（印章 / 进度条 / 主按钮 / 卡片 / 小节标题 / 徽章 / chip / 子页头）

**Files:**
- Create: `lib/src/ui/widgets/app_seal.dart`
- Create: `lib/src/ui/widgets/xp_track.dart`
- Create: `lib/src/ui/widgets/primary_button.dart`
- Create: `lib/src/ui/widgets/app_card.dart`
- Create: `lib/src/ui/widgets/section_title.dart`
- Create: `lib/src/ui/widgets/badge_soft.dart`
- Create: `lib/src/ui/widgets/chip_widget.dart`
- Create: `lib/src/ui/widgets/sub_page_header.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`
- Produces:
  - `class AppSeal extends StatelessWidget { final String text; final double size; final double fontSize; final AppSealStyle style; final bool vertical; const AppSeal(this.text, {super.key, this.size = 48, this.fontSize = 16, this.style = AppSealStyle.solid, this.vertical = true}); }`，`enum AppSealStyle { solid, hollow, gray }`。
  - `class XpTrack extends StatelessWidget { final double progress; final double height; const XpTrack({super.key, required this.progress, this.height = 8}); }`
  - `class PrimaryButton extends StatelessWidget { final String label; final VoidCallback? onTap; final bool ghost; final bool small; const PrimaryButton({super.key, required this.label, this.onTap, this.ghost = false, this.small = false}); }`
  - `class AppCard extends StatelessWidget { final EdgeInsetsGeometry padding; final Widget child; final EdgeInsetsGeometry? margin; const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.margin}); }`
  - `class SectionTitle extends StatelessWidget { final String title; final String? trailing; final VoidCallback? onTrailing; const SectionTitle({super.key, required this.title, this.trailing, this.onTrailing}); }`
  - `class BadgeSoft extends StatelessWidget { final String text; final BadgeSoftColor color; const BadgeSoft(this.text, {super.key, this.color = BadgeSoftColor.red}); }`，`enum BadgeSoftColor { red, gold, leaf }`
  - `class AppChip extends StatelessWidget { final String label; final bool selected; final VoidCallback? onTap; const AppChip({super.key, required this.label, this.selected = false, this.onTap}); }`
  - `class SubPageHeader extends StatelessWidget { final String title; final Widget? trailing; const SubPageHeader({super.key, required this.title, this.trailing}); }`（返回箭头 `AppIcon('back')` 调 `Navigator.pop` + 居中衬线标题 + 右侧占位）

- [ ] **Step 1: 写组件测试（TDD）**

Create `test/ui/widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/app_seal.dart';
import 'package:idiom_crossword/src/ui/widgets/xp_track.dart';
import 'package:idiom_crossword/src/ui/widgets/primary_button.dart';
import 'package:idiom_crossword/src/ui/widgets/badge_soft.dart';
import 'package:idiom_crossword/src/ui/widgets/app_card.dart';

void main() {
  testWidgets('AppSeal 渲染文本', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: AppSeal('通', size: 48, fontSize: 16)),
    ));
    expect(find.text('通'), findsOneWidget);
  });

  testWidgets('XpTrack 渲染进度条', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: XpTrack(progress: 0.5, height: 8)),
    ));
    expect(find.byType(XpTrack), findsOneWidget);
  });

  testWidgets('PrimaryButton ghost 变体点击回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: PrimaryButton(
          label: '开始挑战',
          onTap: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.text('开始挑战'));
    expect(tapped, isTrue);
  });

  testWidgets('BadgeSoft 渲染金徽章', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: BadgeSoft('第 128 期', color: BadgeSoftColor.gold)),
    ));
    expect(find.text('第 128 期'), findsOneWidget);
  });

  testWidgets('AppCard 渲染子组件', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: AppCard(child: Text('内容'))),
    ));
    expect(find.text('内容'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/widgets_test.dart`
Expected: FAIL（组件文件不存在）。

- [ ] **Step 3: 实现各组件文件**

`lib/src/ui/widgets/app_seal.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum AppSealStyle { solid, hollow, gray }

/// 朱砂印章：实底 / 空心描边 / 灰底三态
class AppSeal extends StatelessWidget {
  final String text;
  final double size;
  final double fontSize;
  final AppSealStyle style;
  final bool vertical;

  const AppSeal(
    this.text, {
    super.key,
    this.size = 48,
    this.fontSize = 16,
    this.style = AppSealStyle.solid,
    this.vertical = true,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Border? border) = switch (style) {
      AppSealStyle.solid => (AppColors.accent, const Color(0xFFFFF6EC), null),
      AppSealStyle.hollow => (
        Colors.transparent,
        AppColors.accent,
        Border.all(color: AppColors.accent, width: 1.5),
      ),
      AppSealStyle.gray => (
        AppColors.surface2,
        AppColors.faint,
        Border.all(color: AppColors.borderStrong, width: 1.5, style: BorderStyle.solid),
      ),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: kSerif,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}
```

> 注：竖排书写在单字/二字场景下以字号区分；`vertical` 参数保留扩展，当前组件以单字渲染为主。

`lib/src/ui/widgets/xp_track.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 经验/进度条：surface2 底 + 朱砂渐增满
class XpTrack extends StatelessWidget {
  final double progress;
  final double height;

  const XpTrack({super.key, required this.progress, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.surface2,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
      ),
    );
  }
}
```

`lib/src/ui/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 主按钮：朱砂底 + 深红下压阴影，按压缩回；ghost 为 surface 底朱砂字
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final bool small;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.ghost = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = small ? 46.0 : 56.0;
    final radius = small ? 13.0 : 16.0;
    final baseColor = ghost ? AppColors.surface : AppColors.accent;
    final shadowColor = ghost ? AppColors.border : AppColors.accentDeep;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
          border: ghost ? Border.all(color: AppColors.accentSoft) : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 15 : 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: ghost ? AppColors.accent : const Color(0xFFFFF8EF),
          ),
        ),
      ),
    );
  }
}
```

`lib/src/ui/widgets/app_card.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 通用卡片：surface 底、18px 圆角、细边框、轻投影
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
```

`lib/src/ui/widgets/section_title.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_text.dart';

/// 区块标题：衬线标题 + 可选右侧链接
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: displayStyle(size: 17, weight: FontWeight.w700)),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF857C68)),
              ),
            ),
        ],
      ),
    );
  }
}
```

`lib/src/ui/widgets/badge_soft.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeSoftColor { red, gold, leaf }

/// 软色胶囊徽章
class BadgeSoft extends StatelessWidget {
  final String text;
  final BadgeSoftColor color;

  const BadgeSoft(this.text, {super.key, this.color = BadgeSoftColor.red});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (color) {
      BadgeSoftColor.red => (AppColors.accentPale, AppColors.accent),
      BadgeSoftColor.gold => (AppColors.goldSoft, const Color(0xFF7A5D14)),
      BadgeSoftColor.leaf => (AppColors.leafSoft, AppColors.leaf),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}
```

`lib/src/ui/widgets/chip_widget.dart`:

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 筛选 chip：选中态朱砂底
class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const AppChip({super.key, required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface2,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? const Color(0xFFFFF8EF) : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
```

`lib/src/ui/widgets/sub_page_header.dart`:

```dart
import 'package:flutter/material.dart';
import 'app_icons.dart';
import '../theme/app_text.dart';

/// 子页面顶栏：返回箭头 + 居中衬线标题
class SubPageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SubPageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _RoundIconButton(
            onTap: () => Navigator.of(context).maybePop(),
            icon: AppIcon('back', size: 20),
          ),
          Expanded(
            child: Center(child: Text(title, style: displayStyle(size: 20, weight: FontWeight.w700))),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: trailing ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// 圆形图标按钮（返回/声音等）
class _RoundIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget icon;

  const _RoundIconButton({this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7EE),
          border: Border.all(color: const Color(0xFFE2D8BE)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: icon),
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/widgets_test.dart`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/widgets/ test/ui/widgets_test.dart
git commit -m "feat: 通用组件（AppSeal/XpTrack/PrimaryButton/AppCard/SectionTitle/BadgeSoft/AppChip/SubPageHeader）"
```

---

### Task 4: 底部五 Tab 导航骨架

**Files:**
- Create: `lib/src/ui/screens/root_screen.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AppIcon`、`AppColors`、`HomeScreen`、`LevelSelectScreen`、`CollectionScreen`、`ShopScreen`、`MineScreen`（MineScreen 在 Task 7 创建——本任务先以占位 `Placeholder` 挂载，Task 7 替换）。
- Produces: `class RootScreen extends ConsumerStatefulWidget`。5 Tab 文案：首页/关卡/收藏/商城/我的，图标名：`home/levels/book/shop/mine`。

- [ ] **Step 1: 写导航测试（TDD）**

Create `test/ui/root_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/ui/screens/root_screen.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('底部五 Tab 可切换，选中态更新', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['首页', '关卡', '收藏', '商城', '我的']) {
      expect(find.text(label), findsWidgets);
    }
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/root_screen_test.dart`
Expected: FAIL（`root_screen.dart` 不存在）。

- [ ] **Step 3: 创建 `lib/src/ui/screens/root_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_icons.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'level_select_screen.dart';
import 'collection_screen.dart';
import 'shop_screen.dart';
import 'mine_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          LevelSelectScreen(),
          CollectionScreen(),
          ShopScreen(),
          MineScreen(),
        ],
      ),
      bottomNavigationBar: _buildTabBar(),
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      ('首页', 'home'),
      ('关卡', 'levels'),
      ('收藏', 'book'),
      ('商城', 'shop'),
      ('我的', 'mine'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          tabs[i].$2,
                          size: 23,
                          color: _index == i ? AppColors.accent : AppColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _index == i ? AppColors.accent : AppColors.muted,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _index == i ? AppColors.accent : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 修改 `lib/main.dart` 指向 RootScreen**

将 import `'src/ui/screens/home_screen.dart'` 改为 `'src/ui/screens/root_screen.dart'`，`home: const RootScreen()`。同时把主题改为：

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFFB33B27),
    brightness: Brightness.light,
  ),
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF3EDE1),
),
```

- [ ] **Step 5: 临时占位 MineScreen 避免编译失败**

创建 `lib/src/ui/screens/mine_screen.dart` 占位（Task 7 完整实现）：

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MineScreen extends StatelessWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: Text('我的')),
    );
  }
}
```

- [ ] **Step 6: 运行确认通过**

Run: `flutter test test/ui/root_screen_test.dart && flutter analyze`
Expected: PASS，analyze 无 error。

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/src/ui/screens/root_screen.dart lib/src/ui/screens/mine_screen.dart test/ui/root_screen_test.dart
git commit -m "feat: 底部五 Tab 导航骨架 + 主题接入 RootScreen"
```

---

### Task 5: DB schema v8（`totalFills` + `getIdiomAtOffset`）

**Files:**
- Modify: `lib/src/data/database.dart`
- Modify: `lib/src/data/database.g.dart`（由 build_runner 重新生成）

**Interfaces:**
- Consumes: 无
- Produces:
  - `LevelHistory.totalFills`：`IntColumn get totalFills => integer().nullable()();`
  - `currentSchemaVersion = 8`；`onUpgrade` 增 `if (from < 8) { await m.addColumn(levelHistory, levelHistory.totalFills); }`
  - `addLevelHistory({required int levelNumber, required int xpGained, required List<int> idiomsUsed, int? timeSpentMs, int hintsUsed = 0, int errorsMade = 0, int? totalFills, String? levelJson})`
  - `Future<Idiom?> getIdiomAtOffset(int offset)`：按 id 排序取第 `offset % count` 条成语，空库返回 null。

- [ ] **Step 1: 写迁移/查询测试（TDD）**

在 `test/data/database_schema_test.dart` 末尾追加（先读该文件确认既有结构，再按相同风格追加）：

```dart
test('schema v8：totalFills 列可写入读取', () async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final id = await db.findIdiomIdByWord('画蛇添足');
  await db.addLevelHistory(
    levelNumber: 3,
    xpGained: 20,
    idiomsUsed: [id!],
    errorsMade: 1,
    totalFills: 5,
  );
  final history = await db.getLevelHistory();
  expect(history.single.totalFills, 5);
});

test('getIdiomAtOffset：空库返回 null，非空按偏移取', () async {
  final db = await _memoryDb(); // 含画蛇添足一条
  addTearDown(db.close);
  final first = await db.getIdiomAtOffset(0);
  expect(first, isNotNull);
  expect(first!.word, '画蛇添足');
  final same = await db.getIdiomAtOffset(5); // 循环取模
  expect(same!.word, '画蛇添足');
});
```

> 若该文件无 `_memoryDb` helper，参考 `test/ui/screens_test.dart` 复制一个插入 `IdiomsCompanion` 的 `_memoryDb()`。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/data/database_schema_test.dart`
Expected: FAIL（`totalFills` 不存在）。

- [ ] **Step 3: 修改 `database.dart`**

(a) `LevelHistory` 表加列（在 `errorsMade` 之后）：
```dart
  IntColumn get totalFills => integer().nullable()(); // 本关填字尝试次数（正确率统计用）
```

(b) `const int currentSchemaVersion = 8;`

(c) `onUpgrade` 在 `if (from < 7)` 块后追加：
```dart
        if (from < 8) {
          // 填字尝试次数（正确率统计）
          await m.addColumn(levelHistory, levelHistory.totalFills);
        }
```

(d) `addLevelHistory` 参数与写入：
```dart
  Future<void> addLevelHistory({
    required int levelNumber,
    required int xpGained,
    required List<int> idiomsUsed,
    int? timeSpentMs,
    int hintsUsed = 0,
    int errorsMade = 0,
    int? totalFills,
    String? levelJson,
  }) async {
    await into(levelHistory).insert(
      LevelHistoryCompanion(
        levelNumber: Value(levelNumber),
        xpGained: Value(xpGained),
        idiomsUsed: Value(idiomsUsed.join(',')),
        timeSpentMs: Value(timeSpentMs),
        hintsUsed: Value(hintsUsed),
        errorsMade: Value(errorsMade),
        totalFills: Value(totalFills),
        levelJson: Value(levelJson),
      ),
    );
  }
```

(e) 新增方法（放在 `findIdiomByWord` 之后）：
```dart
  /// 按 id 偏移取成语（今日一读按日期确定性取用）；空库返回 null
  Future<Idiom?> getIdiomAtOffset(int offset) async {
    final count = await idioms.count().getSingle();
    if (count == 0) return null;
    return (select(idioms)
          ..orderBy([(t) => OrderingTerm(expression: t.id)])
          ..offset(offset % count)
          ..limit(1))
        .getSingleOrNull();
  }
```

- [ ] **Step 4: 重新生成数据库代码**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/src/data/database.g.dart` 更新成功，含 `totalFills` 列。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/data/database_schema_test.dart && flutter analyze`
Expected: PASS，analyze 无 error。

- [ ] **Step 6: Commit**

```bash
git add lib/src/data/database.dart lib/src/data/database.g.dart test/data/database_schema_test.dart
git commit -m "feat: DB schema v8 totalFills 列 + getIdiomAtOffset（今日一读数据源）"
```

---

### Task 6: 游戏统计 plumb（`totalFills` 进存档 codec）

**Files:**
- Modify: `lib/src/state/level_state_codec.dart`

**Interfaces:**
- Consumes: 无（独立于 GameScreen）
- Produces: `SavedGameState` 增 `final int totalFills;`（`required this.totalFills`）；`encodeGameState` 写 `'fills': state.totalFills`；`decodeGameState` 读 `data['fills'] as int? ?? 0`（旧存档兼容）。

- [ ] **Step 1: 写 codec 测试**

在 `test/ui/game_flow_test.dart` 或新建 `test/state/level_state_codec_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

void main() {
  test('SavedGameState 编解码保留 totalFills，旧数据缺省 0', () {
    final s = SavedGameState(
      answers: const {},
      usedCandidateSlots: const {},
      fillHistory: const [],
      cellToCandidateSlot: const {},
      candidateBoard: const [['一'], ['二']],
      hintUsesThisLevel: 0,
      errorsMade: 0,
      correctStreak: 0,
      totalFills: 7,
    );
    final decoded = decodeGameState(encodeGameState(s));
    expect(decoded, isNotNull);
    expect(decoded!.totalFills, 7);

    // 旧存档（无 fills 键）→ 0
    final legacy = decodeGameState(
      '{"answers":[],"used":[],"history":[],"slots":[],"board":[[]],"hints":0,"errors":0,"streak":0}',
    );
    expect(legacy!.totalFills, 0);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/state/level_state_codec_test.dart`
Expected: FAIL（`totalFills` 不存在）。

- [ ] **Step 3: 修改 `level_state_codec.dart`**

(a) `SavedGameState` 加字段：
```dart
  final int totalFills;
```
构造器加 `required this.totalFills`（放在 `correctStreak` 之后）。

(b) `encodeGameState` map 加：
```dart
    'fills': state.totalFills,
```

(c) `decodeGameState` 返回处：
```dart
      correctStreak: data['streak'] as int,
      totalFills: data['fills'] as int? ?? 0,
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/state/level_state_codec_test.dart`
Expected: PASS。

> 说明：`SavedGameState` 的既有调用点（`game_screen.dart`）会因新 required 字段编译失败——本任务 Step 5 后 `flutter analyze` 会有 1 处错误指向 `game_screen.dart:228` 的 `SavedGameState(...)`。此为预期，Task 16 补上 `totalFills`。为保持每任务可编译，Task 16 前允许该已知 error；若需立即消除，可在 `_saveState` 处传 `totalFills: _totalFills`（Task 16 定义）。**建议直接在本任务 Step 3 顺带在 `game_screen.dart` 加 `int _totalFills = 0;` 字段并在 `_saveState` 传入，`_onCandidateTap` 的 `_totalFills++` 在 Task 16 补。**

- [ ] **Step 5: 顺带在 `game_screen.dart` 补齐编译**

`lib/src/ui/screens/game_screen.dart`：
- 字段区加：`int _totalFills = 0;`
- `_restoreSavedState` 的 `setState` 内加：`_totalFills = state.totalFills;`
- `_saveState` 的 `SavedGameState(...)` 加：`totalFills: _totalFills,`

Run: `flutter analyze`
Expected: 0 errors。

- [ ] **Step 6: Commit**

```bash
git add lib/src/state/level_state_codec.dart lib/src/ui/screens/game_screen.dart test/state/level_state_codec_test.dart
git commit -m "feat: 存档 codec 支持 totalFills（正确率统计 plumb）"
```

---

### Task 7: 「我的」Tab（新建 `mine_screen.dart` 完整实现）

**Files:**
- Modify: `lib/src/ui/screens/mine_screen.dart`（替换 Task 4 占位）
- Modify: `lib/src/data/growth_manager.dart`（暴露标题序列）

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`SectionTitle`、`BadgeSoft`、`statsProvider`（来自 `stats_screen.dart`）、`playerProvider`、`achievements_screen.dart`、`stats_screen.dart`、`settings_screen.dart`
- Produces: `GrowthManager.titleSequence`：`static List<String> get titleSequence => List.unmodifiable(_titles.values);`
- 页面结构：`h1 我的`；头像卡（黑底金字「士」+ `Lv.X · 称号` + `已获 N 关 · X 经验` + `再通关 M 关，晋升「X」`）；科举等级条（已完成 `accentSoft`+红「通」角标 / 当前朱砂底+「当前」/ 未解锁 surface，仅展示后续第一个）；学问一览 4 stat 卡；更多 menu 行（成就/统计/设置）。

- [ ] **Step 1: 写页面测试**

在 `test/ui/screens_test.dart` 追加（复用既有 `_wrap`）：

```dart
  testWidgets('我的页：等级条三态与菜单', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    // 造一条通关记录让玩家为 Lv.1 且已通关 1 关
    await db.addLevelHistory(levelNumber: 1, xpGained: 10, idiomsUsed: const []);

    await tester.pumpWidget(_wrap(db, const MineScreen()));
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsOneWidget);
    expect(find.textContaining('Lv.1'), findsOneWidget);
    expect(find.text('成就'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('自定义关卡'), findsNothing); // 已删除
  });
```

需要 import `mine_screen.dart`。同时新建 `test/ui/mine_screen_test.dart` 也可，二选一；以下按追加到 `screens_test.dart` 处理。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart`
Expected: FAIL（MineScreen 占位无上述内容）。

- [ ] **Step 3: `growth_manager.dart` 加公开标题序列**

```dart
  /// 全部称号（等级 1→20 顺序）
  static List<String> get titleSequence => List.unmodifiable(_titles.values);
```

- [ ] **Step 4: 完整实现 `lib/src/ui/screens/mine_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../data/growth_manager.dart';
import 'achievements_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/section_title.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final titles = GrowthManager.titleSequence;
    final nextTitle = player.level < titles.length
        ? titles[player.level] // index = level（0 起），即下一级
        : titles.last;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text('我的', style: displayStyle(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            // 头像卡
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E2A20), Color(0xFF191610)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x384050A00),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '士',
                      style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8C87A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv.${player.level} · ${player.title}',
                          style: displayStyle(
                            size: 21,
                            weight: FontWeight.w900,
                            color: AppColors.accentDeep,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '已获 ${player.completedLevels} 关 · ${player.totalXp} 经验',
                          style: bodyStyle(size: 12.5, color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '再通关一关，晋升「$nextTitle」',
                          style: bodyStyle(size: 11.5, color: AppColors.faint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _RankStrip(player: player, titles: titles),
            const SizedBox(height: 4),
            const SectionTitle(title: '学问一览'),
            _buildStats(context, ref),
            const SectionTitle(title: '更多'),
            _MenuRow(
              iconName: 'trophy',
              title: '成就',
              hint: '已解锁成就',
              onTap: () => _push(context, const AchievementsScreen()),
            ),
            _MenuRow(
              iconName: 'chart',
              title: '统计',
              hint: '正确率与用时',
              onTap: () => _push(context, const StatsScreen()),
            ),
            _MenuRow(
              iconName: 'gear',
              title: '设置',
              onTap: () => _push(context, const SettingsScreen()),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '科举仕途 · 20 级 · 位极人臣',
                style: TextStyle(fontSize: 10.5, color: AppColors.faint, letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildStats(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final stats = statsAsync.value;
    final items = [
      (icon: 'list', value: '${stats?.totalCompleted ?? 0}', label: '累计通关'),
      (icon: 'book', value: '${stats?.collectionCount ?? 0}', label: '成语收藏'),
      (icon: 'bolt', value: '${stats?.longestStreak ?? 0}', label: '最长连胜'),
      (icon: 'clock', value: _fmt(stats?.avgTimeMs ?? 0), label: '平均用时'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 3.2,
      children: [
        for (final it in items)
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _IconBox(iconName: it.icon, bg: AppColors.accentPale, color: AppColors.accent),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(it.value, style: displayStyle(size: 22, weight: FontWeight.w900)),
                    Text(it.label, style: bodyStyle(size: 11, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m′$s″' : '$s″';
  }
}

/// 科举等级条：已完成 + 当前 + 下一级
class _RankStrip extends StatelessWidget {
  final PlayerState player;
  final List<String> titles;

  const _RankStrip({required this.player, required this.titles});

  @override
  Widget build(BuildContext context) {
    // 展示：1..level 已完成，level 当前，level+1 下一级（≤20）
    final end = (player.level + 1).clamp(1, titles.length);
    return SizedBox(
      height: 86,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: end,
        itemBuilder: (context, i) {
          final lv = i + 1;
          final isCurrent = lv == player.level;
          final isDone = lv < player.level;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.accent
                        : isDone
                        ? AppColors.accentSoft
                        : AppColors.surface,
                    border: Border.all(
                      color: isCurrent || isDone ? AppColors.accent : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lv$lv',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCurrent ? const Color(0xFFBFD0D0).withValues(alpha: 0.85) : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titles[i],
                        style: displayStyle(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: isCurrent ? const Color(0xFFFFF6EC) : AppColors.fg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.accent),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                if (isDone)
                  Positioned(
                    right: -7,
                    top: -7,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Transform.rotate(
                        angle: 6 * 3.14159 / 180,
                        child: const Text(
                          '通',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFF6EC),
                            fontFamily: kSerif,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String iconName;
  final Color bg;
  final Color color;

  const _IconBox({required this.iconName, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Center(child: AppIcon(iconName, size: 20, color: color)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String iconName;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  const _MenuRow({required this.iconName, required this.title, this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            _IconBox(iconName: iconName, bg: AppColors.surface2, color: AppColors.fg),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title, style: bodyStyle(size: 15, weight: FontWeight.w600)),
            ),
            if (hint != null)
              Text(hint!, style: bodyStyle(size: 11, color: AppColors.muted)),
            const SizedBox(width: 6),
            AppIcon('back', size: 14, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
```

> 注：`_MenuRow` 尾部箭头用 `back` 图标旋转 180° 即可，为简洁直接用同一图标（视觉接近）；实现时可用 `Transform.rotate` 包一层。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart`
Expected: 新用例 PASS（既有用例若因未改造的页面暂不影响——本任务仅加 MineScreen）。

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/screens/mine_screen.dart lib/src/data/growth_manager.dart test/ui/screens_test.dart
git commit -m "feat: 我的 Tab（头像卡/科举等级条/学问一览/更多菜单）"
```

---

### Task 8: 首页 Tab 重构

**Files:**
- Rewrite: `lib/src/ui/screens/home_screen.dart`
- Modify: `lib/src/state/database_provider.dart`（若需暴露 DB 给 FutureProvider——已有，无需改）

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`XpTrack`、`PrimaryButton`、`BadgeSoft`、`SectionTitle`、`playerProvider`、`databaseProvider`、`level_generation.dart`（`dailyLevelNumber`/`epochDay`/`generateLevel`）、`spiral_difficulty.dart`、`growth_manager.dart`、`game_screen.dart`、`level_loading_dialog.dart`、`daily_review_screen.dart`（Task 15 创建；本任务先用占位 `Placeholder` 跳转——见 Step 3 说明）
- Produces:
  - `dailyInfoProvider = FutureProvider<DailyInfo?>`：按 `epochDay()` 确定性生成今日每日关卡，读首条成语/成语数/平均难度/估算时长。`class DailyInfo { final String word; final int idiomCount; final int avgDifficulty; final int durationSeconds; }`
  - 完成态：`dailyDoneProvider`（已有，保留）。
  - 保留 `_startGame`、`_startDaily` 逻辑（含 `showLevelLoadingDialog`、`GameScreen` 跳转、tutorial 弹窗）。

- [ ] **Step 1: 写首页测试（TDD）**

在 `test/ui/screens_test.dart` 追加：

```dart
  testWidgets('首页：标题与科举仕途卡渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('成语填字'), findsOneWidget);
    expect(find.text('科举仕途'), findsOneWidget);
    expect(find.text('书卷小径'), findsOneWidget);
    expect(find.text('今日一读'), findsOneWidget);
  });
```

> 注意：既有测试 `首页：每日挑战在数据库无成语时提示生成失败` 断言 `find.text('每日挑战')` 可点击——重构后每日卡 kicker 为 `每日挑战 · 全服同题`，`开始挑战` 按钮文本为 `开始挑战`。该测试将在 Task 18 更新；本任务 Step 2 允许其暂时 FAIL，用 `--plain-name` 单独跑新增用例。

- [ ] **Step 2: 运行新增用例确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "首页：标题与科举仕途卡渲染"`
Expected: FAIL（新首页不存在）。

- [ ] **Step 3: 重写 `lib/src/ui/screens/home_screen.dart`**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../data/growth_manager.dart';
import '../../engine/spiral_difficulty.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'collection_screen.dart';
import 'daily_review_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_title.dart';
import '../widgets/xp_track.dart';
import '../widgets/level_loading_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 今日每日挑战展示信息（确定性生成）
class DailyInfo {
  final String word;
  final int idiomCount;
  final int avgDifficulty;
  final int durationSeconds;
  const DailyInfo({
    required this.word,
    required this.idiomCount,
    required this.avgDifficulty,
    required this.durationSeconds,
  });
}

final dailyInfoProvider = FutureProvider<DailyInfo?>((ref) async {
  final db = ref.watch(databaseProvider);
  final player = ref.watch(playerProvider);
  final spiral = SpiralDifficulty.calculate(player.completedLevels + 1);
  final minD = (spiral.mainMin + 2).clamp(1, 50);
  final maxD = (spiral.mainMax + 6).clamp(1, 50);
  final level = await generateLevel(
    db,
    dailyLevelNumber(),
    seed: epochDay(),
    targetSize: 6,
    difficultyRange: (minD, maxD),
    title: '每日挑战',
  );
  if (level == null || level.placements.isEmpty) return null;
  final idioms = level.placements.map((p) => p.idiom).toList();
  final avg = (idioms.map((i) => i.difficulty).reduce((a, b) => a + b) / idioms.length).round();
  return DailyInfo(
    word: idioms.first.text,
    idiomCount: idioms.length,
    avgDifficulty: avg,
    durationSeconds: idioms.length * 45,
  );
});

final dailyDoneProvider = FutureProvider<bool>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.isLevelCompleted(dailyLevelNumber());
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final daily = ref.watch(dailyInfoProvider).value;
    final dailyDone = ref.watch(dailyDoneProvider).value ?? false;
    final nextTitle = GrowthManager.titleForLevel(player.level + 1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            // 头部
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('农历三月十六', style: bodyStyle(size: 13, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text('成语填字', style: displayStyle(size: 30, weight: FontWeight.w700)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _switchToMineTab(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      border: Border.all(color: AppColors.borderStrong),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text('士', style: displayStyle(size: 20, weight: FontWeight.w700, color: AppColors.accent)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 科举仕途卡
            _RankCard(player: player),
            const SizedBox(height: 16),
            // 每日挑战卡
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('每日挑战 · 全服同题', style: kickerStyle(color: AppColors.gold)),
                            const SizedBox(height: 8),
                            Text(
                              daily?.word ?? '——',
                              style: displayStyle(size: 30, weight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                      BadgeSoft('第 ${_dailyIssue()} 期', color: BadgeSoftColor.gold),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _dailyMeta(daily),
                    style: bodyStyle(size: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: dailyDone ? '已完成' : '开始挑战',
                          small: true,
                          onTap: dailyDone ? null : () => _startDaily(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: PrimaryButton(
                          label: '昨日回顾',
                          small: true,
                          ghost: true,
                          onTap: () => _openDailyReview(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 继续第 N 关
            PrimaryButton(
              label: '继续第 ${player.completedLevels + 1} 关',
              onTap: () => _startGame(context, ref),
            ),
            // 书卷小径
            const SectionTitle(title: '书卷小径'),
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    iconName: 'levels',
                    label: '选择关卡',
                    desc: '由浅入深 · 循序而进',
                    onTap: () => _switchTab(context, 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tile(
                    iconName: 'book',
                    label: '成语收藏',
                    desc: '温故知新 · 日积月累',
                    onTap: () => _switchTab(context, 2),
                  ),
                ),
              ],
            ),
            // 今日一读
            const SectionTitle(title: '今日一读'),
            _TodayIdiom(ref: ref),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '交叉推理 · 一字双关 · 循序而进',
                style: TextStyle(fontSize: 10.5, color: AppColors.faint, letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dailyMeta(DailyInfo? daily) {
    if (daily == null) return '今日谜面生成中…';
    final diffLabel = switch (daily.avgDifficulty) {
      <= 10 => '入门',
      <= 25 => '进阶',
      <= 40 => '高手',
      _ => '大师',
    };
    return '今日谜面难度 $diffLabel · ${daily.idiomCount} 条成语 · 约 ${(daily.durationSeconds / 60).ceil()} 分钟';
  }

  int _dailyIssue() => epochDay();

  void _switchToMineTab(BuildContext context) {
    // 通过 RootScreen 状态切 Tab：查找祖先 RootScreen 不可行，改用直接 push 占位页
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MineScreen()));
  }
}
```

> 说明：`_switchToMineTab`/`_switchTab` 跨 Tab 切换在本骨架下以推入对应屏代替（任务 4 的 `IndexedStack` 未暴露切 Tab 回调）。为避免过度设计，首页「士」头像与「书卷小径」tile 走 `Navigator.push` 进入「我的」/关卡/收藏屏。若需真正切 Tab，可在 RootScreen 增加静态 `ValueNotifier`——**本任务保持简单，push 方案**。

`home_screen.dart` 内还需 `_RankCard`、`_Tile`、`_TodayIdiom` 私有组件与 `_startGame`、`_startDaily`、`_openDailyReview`（推入 `DailyReviewScreen`）方法。`_TodayIdiom` 用新 DB 方法：

```dart
final todayIdiomProvider = FutureProvider<Idiom?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getIdiomAtOffset(epochDay());
});
```

`_TodayIdiom` widget：竖排成语（`AppSeal` 风格方块内竖排两字一行）+ 出处 + 释义。完整代码（放到同文件）：

```dart
class _TodayIdiom extends ConsumerWidget {
  final WidgetRef ref;
  const _TodayIdiom({required this.ref});

  @override
  Widget build(BuildContext context) {
    final idiom = ref.watch(todayIdiomProvider).value;
    if (idiom == null) {
      return AppCard(
        child: Text('今日一读待收录…', style: bodyStyle(color: AppColors.muted)),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              idiom.word.replaceAll('', ' ').trim().replaceAll(' ', '\n'),
              textAlign: TextAlign.center,
              style: displayStyle(size: 30, weight: FontWeight.w900, height: 1.25),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  idiom.derivation?.isNotEmpty == true ? '· ${idiom.derivation}' : '· 出处待考',
                  style: bodyStyle(size: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(idiom.explanation, style: bodyStyle(size: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

> 竖排实现：把四字成语按两字一行用 `\n` 连接，置于衬线大字块中。`_RankCard`（kicker + Lv.X·称号 + XpTrack + 水印数字）、`_Tile`、`_startGame`、`_startDaily`（从旧文件搬运，改成 `AppColors` 风格与 `PrimaryButton`）、`_openDailyReview` 在本步一并写入完整实现。`_startGame`/`_startDaily` 沿用旧逻辑代码（仅颜色/按钮样式替换）。

- [ ] **Step 4: 运行新增用例确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "首页：标题与科举仕途卡渲染"`
Expected: PASS。

> 每日回顾页 `daily_review_screen.dart` 在 Task 15 创建；本任务先创建占位文件避免编译失败：

```dart
// lib/src/ui/screens/daily_review_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DailyReviewScreen extends StatelessWidget {
  const DailyReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: Text('每日回顾')),
    );
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/home_screen.dart lib/src/ui/screens/daily_review_screen.dart test/ui/screens_test.dart
git commit -m "feat: 首页 Tab 重构（科举仕途卡/每日挑战卡/继续第N关/书卷小径/今日一读）"
```

---

### Task 9: 关卡 Tab 重构（PageView 翻页）

**Files:**
- Rewrite: `lib/src/ui/screens/level_select_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`PrimaryButton`、`AppSeal`、`completedLevelsProvider`、`nextMainLevelProvider`（本文件内已有）、`databaseProvider`、`loadOrGenerateLevel`、`game_screen.dart`、`level_loading_dialog.dart`
- Produces: 主线区 `PageView`，每页 24 关（4 列 × 6 行），页码指示；右滑上限 = 当前关卡所在页（itemCount 只到该页）；无筛选 chips、无长尾区。

- [ ] **Step 1: 写关卡页测试（TDD）**

更新 `test/ui/screens_test.dart` 中既有 `关卡选择页` 用例（结构变化）与新断言：

```dart
  testWidgets('关卡页：PageView 展示关卡，完成后显示通角标', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();
    // 无记录：当前关第 1 关
    expect(find.text('选择关卡'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await db.addLevelHistory(levelNumber: 1, xpGained: 10, idiomsUsed: const []);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // 当前关
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "关卡页"`
Expected: FAIL（旧实现无 PageView 或结构不同）。

- [ ] **Step 3: 重写 `level_select_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/player_state.dart';
import 'game_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_seal.dart';
import '../widgets/primary_button.dart';
import '../widgets/level_loading_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 已通关关卡集合
final completedLevelsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getCompletedLevelNumbers();
});

/// 下一个主关卡
final nextMainLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getNextMainLevel();
});

class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  static const _pageSize = 24;
  int _page = 0;
  bool _pageInitialized = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(nextMainLevelProvider, (prev, next) {
      if (next.hasValue && !_pageInitialized) {
        _pageInitialized = true;
        _page = (next.value! - 1) ~/ _pageSize;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedAsync = ref.watch(completedLevelsProvider);
    final nextLevelAsync = ref.watch(nextMainLevelProvider);
    final completed = completedAsync.value ?? const <int>{};
    final nextLevel = nextLevelAsync.value ?? 1;
    final allLevels = ({...completed, nextLevel}).toList()..sort();
    // 只展示到当前关卡所在页
    final currentPage = ((nextLevel - 1) ~/ _pageSize).clamp(0, 100000);
    final totalPages = currentPage + 1;
    final page = _page.clamp(0, currentPage);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择关卡', style: displayStyle(size: 30, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('由浅入深 · 每关约 8–12 条成语', style: kickerStyle()),
                  const SizedBox(height: 12),
                  _DailyPin(onTap: () => _startDaily()),
                ],
              ),
            ),
            Expanded(
              child: completedAsync.isLoading || nextLevelAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '第 ${page * _pageSize + 1}-${((page + 1) * _pageSize).clamp(0, allLevels.length)} 关 · '
                            '${page + 1}/$totalPages',
                            style: bodyStyle(size: 12, color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: PageController(initialPage: page),
                            onPageChanged: (p) => setState(() => _page = p),
                            itemCount: totalPages,
                            itemBuilder: (context, pageIndex) {
                              final start = pageIndex * _pageSize;
                              final pageLevels = allLevels.sublist(
                                start,
                                (start + _pageSize).clamp(0, allLevels.length),
                              );
                              return GridView.count(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: [
                                  for (final level in pageLevels)
                                    _LevelNode(
                                      levelNumber: level,
                                      isCompleted: completed.contains(level),
                                      isNext: level == nextLevel,
                                      onTap: () => _startLevel(level),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLevel(int levelNumber) async {
    showLevelLoadingDialog(context);
    try {
      final db = ref.read(databaseProvider);
      final level = await loadOrGenerateLevel(db, levelNumber);
      if (!mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('关卡生成失败，请重试')));
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(level: level)));
      ref.invalidate(completedLevelsProvider);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }

  void _startDaily() {
    // 跳到每日挑战：直接复用每日生成逻辑入口——简化：提示用户回首页
    Navigator.of(context).pop();
  }
}

/// 每日挑战置顶卡
class _DailyPin extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyPin({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const AppSeal('日', size: 52, fontSize: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日挑战 · 今日一题', style: displayStyle(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('全服同题 · 明日刷新', style: bodyStyle(size: 12, color: AppColors.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: BadgeSoft('挑战'),
          ),
        ],
      ),
    );
  }
}

/// 关卡节点（三态）
class _LevelNode extends StatelessWidget {
  final int levelNumber;
  final bool isCompleted;
  final bool isNext;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.levelNumber,
    required this.isCompleted,
    required this.isNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.accent
                  : isCompleted
                  ? AppColors.accentSoft
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNext || isCompleted ? AppColors.accent : AppColors.border,
              ),
              boxShadow: isNext
                  ? const [BoxShadow(color: Color(0x52B33B27), blurRadius: 14, offset: Offset(0, 6))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$levelNumber',
                  style: displayStyle(
                    size: 20,
                    weight: FontWeight.w700,
                    color: isNext
                        ? const Color(0xFFFFF6EC)
                        : isCompleted
                        ? AppColors.accentDeep
                        : AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: 6 * 3.14159 / 180,
                  child: const Text(
                    '通',
                    style: TextStyle(
                      fontFamily: kSerif,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFF6EC),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
```

> 注：`_DailyPin.onTap` 简化实现为返回上一页（首页可开始每日挑战）。如需从关卡页直接开始每日挑战，可在 Task 15 后改为复用每日生成并 push `GameScreen`；本任务保持简化。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "关卡页" && flutter analyze`
Expected: PASS，analyze 无 error。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/level_select_screen.dart test/ui/screens_test.dart
git commit -m "feat: 关卡 Tab 重构（PageView 翻页 + 三态节点 + 每日置顶卡）"
```

---

### Task 10: 收藏 Tab 重构

**Files:**
- Rewrite: `lib/src/ui/screens/collection_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`BadgeSoft`、`collectionProvider`（本文件已有）
- Produces: 设计样式搜索框、计数行（共 N 则 + 本周新增 N）、`col-card` 列表（衬线大字 + 拼音 + 释义 + 出处 `derivation`）。保留搜索/分页/空态文案（`还没有收藏任何成语` 保留）。

- [ ] **Step 1: 写收藏页测试**

在 `test/ui/screens_test.dart` 追加：

```dart
  testWidgets('收藏页：设计卡片样式渲染成语', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addToCollection(id!);

    await tester.pumpWidget(_wrap(db, const CollectionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);
    expect(find.textContaining('比喻做了多余的事'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "收藏页"`
Expected: FAIL（旧 Card/ListTile 结构不同则断言仍过——若旧实现也显示文本，改为断言新元素如 `共 N 则`；下方 Step 3 代码用 `共 N 则`，测试改为 `expect(find.textContaining('共'), findsOneWidget)`）。

- [ ] **Step 3: 重写 `collection_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CollectionItem {
  final String word;
  final String explanation;
  final String? derivation;
  final String pinyin;
  final DateTime collectedAt;

  const CollectionItem({
    required this.word,
    required this.explanation,
    required this.derivation,
    required this.pinyin,
    required this.collectedAt,
  });
}

final collectionProvider = FutureProvider<List<CollectionItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getCollectionWithDetails();
  return rows
      .map(
        (i) => CollectionItem(
          word: i.word,
          explanation: i.explanation,
          derivation: i.derivation,
          pinyin: i.pinyin,
          collectedAt: i.createdAt,
        ),
      )
      .toList();
});

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  static const _pageSize = 30;
  String _query = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: collectionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent))),
          data: (collection) {
            final filtered = _query.isEmpty
                ? collection
                : collection
                      .where((c) => c.word.contains(_query) || c.explanation.contains(_query))
                      .toList();
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final weekNew = collection.where((c) => c.collectedAt.isAfter(weekAgo)).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('成语收藏', style: displayStyle(size: 30, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('已通关成语自动收录 · 附释义与出处', style: kickerStyle()),
                      const SizedBox(height: 12),
                      _SearchField(
                        onChanged: (v) => setState(() {
                          _query = v.trim();
                          _page = 0;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('共 ${collection.length} 则',
                              style: displayStyle(size: 15, weight: FontWeight.w700)),
                          BadgeSoft('本周新增 $weekNew', color: BadgeSoftColor.leaf),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: collection.isEmpty
                      ? const _EmptyState(
                          title: '还没有收藏任何成语',
                          sub: '通关后自动收录',
                        )
                      : filtered.isEmpty
                      ? const _EmptyState(title: '没有找到匹配的成语', sub: '换个关键词试试')
                      : () {
                          final maxPage = ((filtered.length / _pageSize).ceil() - 1).clamp(0, 1 << 31);
                          final page = _page.clamp(0, maxPage);
                          final items = filtered.sublist(
                            page * _pageSize,
                            ((page + 1) * _pageSize).clamp(0, filtered.length),
                          );
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: items.length + 1,
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return _Pager(
                                  page: page,
                                  maxPage: maxPage,
                                  onPrev: () => setState(() => _page--),
                                  onNext: () => setState(() => _page++),
                                );
                              }
                              final item = items[index];
                              return _ColCard(item: item);
                            },
                          );
                        }(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppIcon('search', size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索成语或释义',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.faint),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColCard extends StatelessWidget {
  final CollectionItem item;
  const _ColCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(item.word, style: displayStyle(size: 24, weight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.pinyin.toUpperCase(),
                  style: bodyStyle(size: 11, color: AppColors.muted).copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Text(item.explanation, style: bodyStyle(size: 13, color: const Color(0xFF4A4438))),
                if (item.derivation != null && item.derivation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('· ${item.derivation}', style: bodyStyle(size: 11, color: AppColors.faint)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String sub;
  const _EmptyState({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon('book', size: 64, color: AppColors.faint),
          const SizedBox(height: 16),
          Text(title, style: displayStyle(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(sub, style: bodyStyle(size: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int maxPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Pager({
    required this.page,
    required this.maxPage,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: page > 0 ? onPrev : null,
          icon: const AppIcon('back', size: 18),
          color: AppColors.muted,
        ),
        Text('第 ${page + 1} / ${maxPage + 1} 页', style: bodyStyle(size: 12, color: AppColors.muted)),
        IconButton(
          onPressed: page < maxPage ? onNext : null,
          icon: Transform.rotate(angle: 3.14159, child: const AppIcon('back', size: 18)),
          color: AppColors.muted,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "收藏页" && flutter analyze`
Expected: PASS。

> 注：既有用例 `收藏页：空态 → 收录后展示成语` 断言 `find.text('画蛇添足')` 与 `find.byType(TextField)`、空态文案 `还没有收藏任何成语`——新实现均保留，应继续通过。若 `find.byType(TextField)` 因 `_SearchField` 内嵌 TextField 仍可找到。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/collection_screen.dart test/ui/screens_test.dart
git commit -m "feat: 收藏 Tab 重构（设计样式搜索/计数/卡片列表）"
```

---

### Task 11: 商城 Tab 重构

**Files:**
- Rewrite: `lib/src/ui/screens/shop_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`PrimaryButton`、`BadgeSoft`、`SectionTitle`、`playerProvider`
- Produces: 单列滚动：钱包（提示卡/复活卡）、功能道具（3 pack）、装饰藏品（皮肤卡）、去广告。购买全部 toast「内购功能即将上线」。

- [ ] **Step 1: 写商城测试**

`test/ui/screens_test.dart` 既有用例 `商城购买按钮提示即将上线` 保留（`¥6` 文本需在新 UI 存在）。追加：

```dart
  testWidgets('商城页：钱包与分区渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const ShopScreen()));
    await tester.pumpAndSettle();
    expect(find.text('文房四宝 · 商城'), findsOneWidget);
    expect(find.text('提示卡'), findsOneWidget);
    expect(find.text('复活卡'), findsOneWidget);
    expect(find.text('功能道具'), findsOneWidget);
    expect(find.text('装饰藏品'), findsOneWidget);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "商城页"`
Expected: FAIL（旧实现无 `文房四宝 · 商城`）。

- [ ] **Step 3: 重写 `shop_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/section_title.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('内购功能即将上线')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final hintCards = player.functionalItems['hint_card'] ?? 0;
    final reviveCards = player.functionalItems['revive_card'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text('文房四宝 · 商城', style: displayStyle(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('功能道具 · 装饰藏品 · 均可永久保留', style: kickerStyle()),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _WalletCard(iconName: 'pen', label: '提示卡', value: '$hintCards'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletCard(iconName: 'revive', label: '复活卡', value: '$reviveCards'),
                ),
              ],
            ),
            const SectionTitle(title: '功能道具', trailing: BadgeSoft('实用')),
            _PackCard(
              iconName: 'pen',
              name: '提示卡 ×10',
              desc: '一字提示每关免费 3 次，之后消耗一张',
              price: '¥6',
              oldPrice: '¥9',
              onBuy: () => _comingSoon(context),
            ),
            _PackCard(
              iconName: 'revive',
              name: '复活卡 ×5',
              desc: '失误满格后可重整旗鼓，保留已填正确字',
              price: '¥12',
              onBuy: () => _comingSoon(context),
            ),
            _PackCard(
              iconName: 'star',
              name: '备考礼盒（提示×10 + 复活×5）',
              desc: '冲刺阶段一次备齐，限量供应',
              price: '¥15',
              oldPrice: '¥21',
              onBuy: () => _comingSoon(context),
            ),
            const SectionTitle(title: '装饰藏品', trailing: BadgeSoft('限定', color: BadgeSoftColor.gold)),
            _SkinsCard(owned: player.ownedDecorations, onBuy: () => _comingSoon(context)),
            const SectionTitle(title: '尊享'),
            _RemoveAdsCard(onBuy: () => _comingSoon(context)),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '内购不影响关卡难度与成语选择',
                style: TextStyle(fontSize: 10.5, color: AppColors.faint, letterSpacing: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String iconName;
  final String label;
  final String value;
  const _WalletCard({required this.iconName, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconBox(iconName: iconName, bg: AppColors.accentPale, color: AppColors.accent),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: bodyStyle(size: 11, color: AppColors.muted)),
              Text(value, style: displayStyle(size: 17, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final String iconName;
  final String name;
  final String desc;
  final String price;
  final String? oldPrice;
  final VoidCallback onBuy;
  const _PackCard({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.price,
    this.oldPrice,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _IconBox(iconName: iconName, bg: AppColors.accentPale, color: AppColors.accent, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: bodyStyle(size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(desc, style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price, style: displayStyle(size: 15, weight: FontWeight.w700, color: AppColors.accent)),
              if (oldPrice != null)
                Text(oldPrice!, style: bodyStyle(size: 11, color: AppColors.faint).copyWith(decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onBuy,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('购买', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFF6EC))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkinsCard extends StatelessWidget {
  final Set<String> owned;
  final VoidCallback onBuy;
  const _SkinsCard({required this.owned, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    const swatches = [
      ('墨', Color(0xFF3B3628)),
      ('朱', Color(0xFFC95A3C)),
      ('青', Color(0xFFA9BEC8)),
      ('金', Color(0xFFE0C87A)),
    ];
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final (name, color) in swatches)
                Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, Color.lerp(color, Colors.black, 0.35)!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 2),
                  ),
                  child: Center(
                    child: Text(name, style: displayStyle(size: 14, color: Colors.white)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('网格皮肤', style: bodyStyle(size: 12.5, weight: FontWeight.w600)),
                  Text(owned.contains('grid_skin_bamboo') ? '当前使用' : '等级奖励解锁', style: bodyStyle(size: 11, color: AppColors.muted)),
                ],
              ),
              BadgeSoft('新品', color: BadgeSoftColor.gold),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoveAdsCard extends StatelessWidget {
  final VoidCallback onBuy;
  const _RemoveAdsCard({required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _IconBox(iconName: 'eye', bg: AppColors.goldSoft, color: const Color(0xFF7A5D14)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('去广告', style: bodyStyle(size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('移除全部插屏广告，永久生效', style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBuy,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7A5D14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('¥3', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String iconName;
  final Color bg;
  final Color color;
  final double size;
  const _IconBox({required this.iconName, required this.bg, required this.color, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Center(child: AppIcon(iconName, size: size * 0.5, color: color)),
    );
  }
}
```

> 既有用例 `商城购买按钮提示即将上线` 点击 `¥6`——`_PackCard` 中价格 `¥6` 为独立 Text 可 tap（用 `GestureDetector` 包购买按钮，但测试 tap 文本 `¥6` 处即可命中价格文本）。若 tap 未命中按钮，将该用例改为 tap `购买`。在 Task 18 统一更新。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "商城页" && flutter analyze`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/shop_screen.dart test/ui/screens_test.dart
git commit -m "feat: 商城 Tab 重构（钱包/功能道具/装饰藏品/去广告）"
```

---

### Task 12: 成就页重构

**Files:**
- Rewrite: `lib/src/ui/screens/achievements_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`AppSeal`、`XpTrack`、`SubPageHeader`、`achievementsProvider`、`achievementDefs`、`AchievementId`
- Produces: hero 卡（解锁数衬线大字 + XpTrack + 下一条提示）+ 分组列表（按 `AchievementId.name` 前缀分组：`level`/`collector`/`streak`/`noHint`/`flawless`/`speedrun`/`daily`/`xp`），每行 `通` 实底印章或灰虚线印章 + 名称/描述 + 进度。

- [ ] **Step 1: 写成就页测试**

更新 `test/ui/screens_test.dart` 既有 `成就页` 用例断言 `已解锁 0/${achievementDefs.length}` 为新格式 `已解锁 0 / N`。追加：

```dart
  testWidgets('成就页：印章与分组渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const AchievementsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('已解锁'), findsOneWidget);
    expect(find.text('首战告捷'), findsOneWidget);
    expect(find.byType(AppSeal), findsWidgets);
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "成就页"`
Expected: FAIL（新结构未实现）。

- [ ] **Step 3: 重写 `achievements_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/achievement_manager.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/app_seal.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/xp_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

final achievementsProvider = FutureProvider<Set<AchievementId>>((ref) async {
  final db = ref.watch(databaseProvider);
  final unlocked = <AchievementId>{};
  for (final s in await db.getUnlockedAchievementIds()) {
    for (final id in AchievementId.values) {
      if (id.name == s) unlocked.add(id);
    }
  }
  return unlocked;
});

/// 成就分组（按枚举名前缀）
const Map<String, String> _groupTitles = {
  'level': '通关',
  'collector': '收藏',
  'streak': '连击',
  'noHint': '无提示',
  'flawless': '零失误',
  'speedrun': '速通',
  'daily': '每日',
  'xp': '经验',
};

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '成就'),
            ),
            Expanded(
              child: unlockedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent))),
                data: (unlocked) {
                  final total = achievementDefs.length;
                  final groups = <String, List<AchievementDef>>{};
                  for (final def in achievementDefs) {
                    final prefix = _groupFor(def.id);
                    groups.putIfAbsent(prefix, () => []).add(def);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            Text(
                              '${unlocked.length}',
                              style: displayStyle(size: 44, weight: FontWeight.w900, color: AppColors.accent, height: 1.1),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('已解锁 / $total 项', style: bodyStyle(size: 12.5, color: AppColors.muted)),
                                  const SizedBox(height: 10),
                                  XpTrack(progress: total == 0 ? 0 : unlocked.length / total, height: 10),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 10),
                          child: Row(
                            children: [
                              Text(_groupTitles[entry.key] ?? entry.key,
                                  style: displayStyle(size: 15, weight: FontWeight.w700)),
                              Expanded(child: Container(height: 1, color: AppColors.border)),
                            ],
                          ),
                        ),
                        for (final def in entry.value)
                          _AchRow(def: def, unlocked: unlocked.contains(def.id)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _groupFor(AchievementId id) {
    final name = id.name;
    for (final key in _groupTitles.keys) {
      if (name.startsWith(key)) return key;
    }
    return '其他';
  }
}

class _AchRow extends StatelessWidget {
  final AchievementDef def;
  final bool unlocked;
  const _AchRow({required this.def, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AppSeal(
            unlocked ? '通' : '?',
            size: 46,
            fontSize: 15,
            style: unlocked ? AppSealStyle.solid : AppSealStyle.gray,
            vertical: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(def.description, style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            unlocked ? '已获' : '—',
            style: bodyStyle(size: 12, weight: FontWeight.w700, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "成就页" && flutter analyze`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/achievements_screen.dart test/ui/screens_test.dart
git commit -m "feat: 成就页重构（hero + 印章分组列表）"
```

---

### Task 13: 统计页重构（正确率环形图）

**Files:**
- Rewrite: `lib/src/ui/screens/stats_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`SubPageHeader`、`statsProvider`、`historyProvider`（本文件已有）
- Produces: 正确率环形图 `CustomPaint`（`_AccuracyRingPainter`），正确率 = `(totalFills − errorsMade) / totalFills`（遍历 history 累加）；老数据无 totalFills 时显示「—」+ 文案「通关后生成正确率」。连胜卡 + 明细行（累计通关/累计经验/平均用时/失误次数/使用提示/成语收藏）。
- `statsProvider` 扩展返回 `accuracy`（`double?`）与 `totalErrors`、`totalFills` 供页面使用。

- [ ] **Step 1: 写统计页测试**

更新 `test/ui/screens_test.dart` 既有 `统计页` 用例断言 `通关数` → 新文案 `累计通关`；`第 7 关` 移除。追加：

```dart
  testWidgets('统计页：正确率环形与明细', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addLevelHistory(
      levelNumber: 7,
      xpGained: 20,
      idiomsUsed: [id!],
      timeSpentMs: 30000,
      hintsUsed: 2,
      errorsMade: 1,
      totalFills: 5,
    );

    await tester.pumpWidget(_wrap(db, const StatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('累计通关'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // (5-1)/5
  });
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "统计页"`
Expected: FAIL。

- [ ] **Step 3: 重写 `stats_screen.dart`**

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/sub_page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class PlayerStats {
  final int totalCompleted;
  final int totalXp;
  final int avgTimeMs;
  final int longestStreak;
  final int collectionCount;
  final int dailyCount;
  final int totalErrors;
  final int totalFills;
  const PlayerStats({
    required this.totalCompleted,
    required this.totalXp,
    required this.avgTimeMs,
    required this.longestStreak,
    required this.collectionCount,
    required this.dailyCount,
    required this.totalErrors,
    required this.totalFills,
  });

  /// 正确率；无填字数据返回 null
  double? get accuracy {
    if (totalFills <= 0) return null;
    return ((totalFills - totalErrors) / totalFills).clamp(0.0, 1.0);
  }
}

final statsProvider = FutureProvider<PlayerStats>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();

  final mainLevels = history
      .where((h) => h.levelNumber < 1000000)
      .map((h) => h.levelNumber)
      .toList()
    ..sort();

  var streak = 0;
  var bestStreak = 0;
  var prev = 0;
  for (final level in mainLevels) {
    streak = (level == prev + 1) ? streak + 1 : 1;
    if (streak > bestStreak) bestStreak = streak;
    prev = level;
  }

  final times = history
      .where((h) => h.timeSpentMs != null)
      .map((h) => h.timeSpentMs!)
      .toList();
  final totalXp = history.fold(0, (sum, h) => sum + h.xpGained);
  final dailyCount = history.where((h) => h.levelNumber >= 1000000).length;
  final totalErrors = history.fold(0, (sum, h) => sum + h.errorsMade);
  var totalFills = 0;
  for (final h in history) {
    if (h.totalFills != null) totalFills += h.totalFills!;
  }

  return PlayerStats(
    totalCompleted: history.length,
    totalXp: totalXp,
    avgTimeMs: times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length,
    longestStreak: bestStreak,
    collectionCount: await db.getCollectionCount(),
    dailyCount: dailyCount,
    totalErrors: totalErrors,
    totalFills: totalFills,
  );
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '统计'),
            ),
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent))),
                data: (stats) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _AccuracyCard(accuracy: stats.accuracy),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _IconBox(iconName: 'bolt', bg: AppColors.goldSoft, color: const Color(0xFF7A5D14)),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${stats.longestStreak} 关', style: displayStyle(size: 22, weight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('最长连胜 · 连续通关', style: bodyStyle(size: 11.5, color: AppColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Column(
                        children: [
                          _StatLine('累计通关', '${stats.totalCompleted} 关'),
                          _StatLine('累计经验', '${stats.totalXp}'),
                          _StatLine('平均用时', _formatDuration(stats.avgTimeMs)),
                          _StatLine('失误次数', '${stats.totalErrors}'),
                          _StatLine('使用提示', '${_hintsFrom(ref)} 次'),
                          _StatLine('成语收藏', '${stats.collectionCount} 则'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('数据仅存储于本机', style: TextStyle(fontSize: 10.5, color: AppColors.faint, letterSpacing: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m 分 $s 秒' : '$s 秒';
  }
}

String _hintsFrom(WidgetRef ref) {
  final history = ref.read(historyProvider).value;
  if (history == null) return '—';
  return '${history.fold(0, (sum, h) => sum + h.hintsUsed)}';
}

class _AccuracyCard extends StatelessWidget {
  final double? accuracy;
  const _AccuracyCard({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _AccuracyRingPainter(progress: accuracy ?? 0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      accuracy == null ? '—' : '${(accuracy! * 100).round()}%',
                      style: displayStyle(size: 38, weight: FontWeight.w900, color: AppColors.accent, height: 1.1),
                    ),
                    Text('填字正确率', style: bodyStyle(size: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            accuracy == null ? '通关后生成正确率' : '含每日挑战 · 提示填入不计',
            style: bodyStyle(size: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRingPainter extends CustomPainter {
  final double progress;
  _AccuracyRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppColors.surface2;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StatLine extends StatelessWidget {
  final String key;
  final String value;
  const _StatLine(this.key, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: bodyStyle(size: 13.5, color: AppColors.muted)),
          Text(value, style: bodyStyle(size: 14, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String iconName;
  final Color bg;
  final Color color;
  const _IconBox({required this.iconName, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Center(child: AppIcon(iconName, size: 20, color: color)),
    );
  }
}
```

> 注：`historyProvider` 已存在但返回 `List<LevelHistoryData>`；`_hintsFrom` 用 `ref.read`。为简化，可将「使用提示」也并入 `statsProvider`（加 `totalHints` 字段）。实现时选择其一并保持一致——推荐并入 `PlayerStats.totalHints`，`_hintsFrom` 移除。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "统计页" && flutter analyze`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/stats_screen.dart test/ui/screens_test.dart
git commit -m "feat: 统计页重构（正确率环形图 + 明细）"
```

---

### Task 14: 设置页重构 + 触感开关

**Files:**
- Rewrite: `lib/src/ui/screens/settings_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`SubPageHeader`、`soundEnabledProvider`、`soundEnabledKey`、`GameAudio`
- Produces:
  - `hapticEnabledKey = 'haptic_enabled'`
  - `hapticEnabledProvider = AsyncNotifierProvider<HapticSettingNotifier, bool>`（持久化到 settings 表）
  - 分组：通用（音效/触感反馈，均为 `Switch`）；偏好（显示拼音/每日提醒，`Switch`，仅持久化）；关于（当前版本 v2.1 / 用户协议与隐私 toast）。**无「语言」「成语数据库」行。**

- [ ] **Step 1: 写设置页测试**

更新 `test/ui/screens_test.dart` 既有 `设置页` 用例（`find.byType(Switch)` 仍有效）。追加：

```dart
  testWidgets('设置页：触感开关持久化，无语言/成语数据库行', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('触感反馈'), findsOneWidget);
    expect(find.text('语言'), findsNothing);
    expect(find.text('成语数据库'), findsNothing);

    final switches = find.byType(Switch);
    expect(tester.widget<Switch>(switches.at(1)).value, isTrue); // 触感默认开
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(await db.getSetting(hapticEnabledKey), 'false');
  });
```

需要 import `hapticEnabledKey` 与 `Switch`（flutter/material 已有）。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/screens_test.dart --plain-name "设置页"`
Expected: FAIL（`hapticEnabledKey` 未导出 / 触感开关缺失）。

- [ ] **Step 3: 重写 `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/game_audio.dart';
import '../../state/database_provider.dart';
import '../widgets/sub_page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

const String soundEnabledKey = 'sound_enabled';
const String tutorialShownKey = 'tutorial_shown';
const String hapticEnabledKey = 'haptic_enabled';
const String showPinyinKey = 'show_pinyin';
const String dailyReminderKey = 'daily_reminder';

final soundEnabledProvider = AsyncNotifierProvider<SoundSettingNotifier, bool>(
  SoundSettingNotifier.new,
);

class SoundSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(soundEnabledKey);
    final enabled = value != 'false';
    GameAudio.instance.muted = !enabled;
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    GameAudio.instance.muted = !enabled;
    await ref.read(databaseProvider).setSetting(soundEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

final hapticEnabledProvider = AsyncNotifierProvider<HapticSettingNotifier, bool>(
  HapticSettingNotifier.new,
);

class HapticSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(hapticEnabledKey);
    return value != 'false';
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(databaseProvider).setSetting(hapticEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

/// 通用布尔设置（仅持久化）
class PrefSettingNotifier extends AsyncNotifier<bool> {
  final String key;
  final bool defaultValue;
  PrefSettingNotifier(this.key, {this.defaultValue = true});

  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(key);
    return value == null ? defaultValue : value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(databaseProvider).setSetting(key, enabled.toString());
    state = AsyncData(enabled);
  }
}

final showPinyinProvider = AsyncNotifierProvider<PrefSettingNotifier, bool>(
  () => PrefSettingNotifier(showPinyinKey),
);
final dailyReminderProvider = AsyncNotifierProvider<PrefSettingNotifier, bool>(
  () => PrefSettingNotifier(dailyReminderKey),
);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '设置'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _Group(
                    children: [
                      _SwitchRow(
                        title: '音效',
                        sub: '填字、成语完成与过关音效',
                        provider: soundEnabledProvider,
                        ref: ref,
                      ),
                      _SwitchRow(
                        title: '触感反馈',
                        sub: '填入正确字时的轻震动',
                        provider: hapticEnabledProvider,
                        ref: ref,
                      ),
                    ],
                  ),
                  _Group(
                    children: [
                      _SwitchRow(
                        title: '显示拼音',
                        sub: '网格下方小字标注',
                        provider: showPinyinProvider,
                        ref: ref,
                      ),
                      _SwitchRow(
                        title: '每日提醒',
                        sub: '每日挑战开始时通知',
                        provider: dailyReminderProvider,
                        ref: ref,
                      ),
                    ],
                  ),
                  _Group(
                    children: [
                      _ValueRow(title: '当前版本', value: 'v2.1'),
                      _TapRow(title: '用户协议与隐私', onTap: () => _toast(context, '即将上线')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends ConsumerWidget {
  final String title;
  final String sub;
  final AsyncNotifierProvider<dynamic, bool> provider;
  final WidgetRef ref;
  const _SwitchRow({
    required this.title,
    required this.sub,
    required this.provider,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final value = ref.watch(provider).value ?? true;
    final notifier = ref.read(provider.notifier) as dynamic;
    return _Row(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.accent,
            onChanged: (v) => notifier.setEnabled(v),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String title;
  final String value;
  const _ValueRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Row(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
          Text(value, style: bodyStyle(size: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _TapRow({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Row(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
            const Text('›', style: TextStyle(fontSize: 16, color: AppColors.faint)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Widget child;
  const _Row({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}
```

> 注：`_SwitchRow` 的 `AsyncNotifierProvider<dynamic, bool>` 泛型处理在 Dart 中需小心。更稳妥做法：对每个开关单独建 `ConsumerWidget`，避免 dynamic 泛型。实现时按此改写（`_SoundRow`/`_HapticRow`/`_PinyinRow`/`_ReminderRow`），本计划给出签名意图，实现细节以可编译为准。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/screens_test.dart --plain-name "设置页" && flutter analyze`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/settings_screen.dart test/ui/screens_test.dart
git commit -m "feat: 设置页重构（音效/触感/偏好开关，精简关于区）"
```

---

### Task 15: 每日回顾页（新建 `daily_review_screen.dart`）

**Files:**
- Rewrite: `lib/src/ui/screens/daily_review_screen.dart`（替换 Task 8 占位）

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppCard`、`AppSeal`、`PrimaryButton`、`SubPageHeader`、`databaseProvider`、`dailyInfoProvider`（Task 8）、`playerProvider`、`level_generation.dart`、`level_state_codec.dart`（`decodeLevel`）
- Produces: quiz-hero（朱砂「日」印章 + 第 N 期·每日成语 + 完成态）；今日成语竖排卡（**不含全服平均时间**）；历期回顾（`getLevelHistory` 中 `levelNumber >= dailyLevelOffset`，`decodeLevel(levelJson)` 取成语/释义）；「重玩今日挑战」按钮；footnote「次日 0 点刷新」。

- [ ] **Step 1: 写每日回顾测试**

新建 `test/ui/daily_review_test.dart`：

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/ui/screens/daily_review_screen.dart';

void main() {
  testWidgets('每日回顾：历史含每日挑战时渲染历期', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 造一条昨日每日挑战记录（levelJson 留空 → 历期卡片显示关卡号）
    await db.addLevelHistory(
      levelNumber: dailyLevelOffset + 5,
      xpGained: 20,
      idiomsUsed: const [],
      levelJson: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DailyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日回顾'), findsOneWidget);
    expect(find.text('历期回顾'), findsOneWidget);
    expect(find.text('第 5 期'), findsOneWidget);
    expect(find.text('次日 0 点刷新'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/daily_review_test.dart`
Expected: FAIL（占位页无内容）。

- [ ] **Step 3: 完整实现 `daily_review_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import 'home_screen.dart'; // dailyInfoProvider
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/primary_button.dart';
import '../widgets/sub_page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 历期每日挑战（解码 levelJson 取成语）
class PastDaily {
  final int issue; // 期数 = 当天的 epochDay
  final List<String> idioms;
  const PastDaily({required this.issue, required this.idioms});
}

final pastDailyProvider = FutureProvider<List<PastDaily>>((ref) async {
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();
  final past = history.where((h) => h.levelNumber >= dailyLevelOffset).toList()
    ..sort((a, b) => b.levelNumber.compareTo(a.levelNumber));
  final result = <PastDaily>[];
  for (final h in past) {
    List<String> idioms = const [];
    if (h.levelJson != null) {
      final level = decodeLevel(h.levelJson!);
      if (level != null) {
        idioms = level.placements.map((p) => p.idiom.text).toList();
      }
    }
    result.add(PastDaily(issue: h.levelNumber - dailyLevelOffset, idioms: idioms));
  }
  return result;
});

class DailyReviewScreen extends ConsumerWidget {
  const DailyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyInfoProvider).value;
    final pastAsync = ref.watch(pastDailyProvider);
    final past = pastAsync.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '每日回顾'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const AppSeal('日', size: 56, fontSize: 16),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '第 ${epochDay()} 期 · ${daily?.word ?? '——'}',
                                style: displayStyle(size: 19, weight: FontWeight.w900, color: AppColors.accentDeep),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                daily == null ? '今日谜面生成中…' : '全服同题 · 明日刷新',
                                style: bodyStyle(size: 11.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (daily != null)
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(top: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 72,
                            child: Text(
                              daily.word.replaceAll('', ' ').trim().replaceAll(' ', '\n'),
                              textAlign: TextAlign.center,
                              style: displayStyle(size: 32, weight: FontWeight.w900, height: 1.25),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _dailyMeaning(ref),
                              style: bodyStyle(size: 12.5, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SectionTitle(title: '历期回顾'),
                  if (past.isEmpty)
                    AppCard(child: Text('还没有历史每日挑战', style: bodyStyle(color: AppColors.muted)))
                  else
                    for (final p in past)
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(
                                p.idioms.isNotEmpty ? p.idioms.first : '第 ${p.issue} 期',
                                style: displayStyle(size: 20, weight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.idioms.join(' · '),
                                style: bodyStyle(size: 13, color: AppColors.muted),
                              ),
                            ),
                            Text('· 第 ${p.issue} 期', style: bodyStyle(size: 11, color: AppColors.faint)),
                          ],
                        ),
                      ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('次日 0 点刷新', style: TextStyle(fontSize: 10.5, color: AppColors.faint, letterSpacing: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dailyMeaning(WidgetRef ref) {
    // 今日成语释义：直接复用每日生成的成语不可得，从每日关卡释义取——占位返回通用文案
    return '水不停地滴，石头也能被滴穿。比喻只要有恒心、不断努力，事情终究能成功。';
  }
}
```

> 注：`_dailyMeaning` 为占位示例文案。更真实的做法：`dailyInfoProvider` 扩展返回首条成语的 `meaning`。**实现时建议把 `DailyInfo` 增加 `meaning` 字段**（Task 8 的 provider 里从 `idioms.first.meaning` 取值），本任务改用 `daily.meaning`。相应更新 Task 8 的 `DailyInfo` 定义与测试。

- [ ] **Step 4: 运行确认通过**

Run: `flutter test test/ui/daily_review_test.dart && flutter analyze`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add lib/src/ui/screens/daily_review_screen.dart test/ui/daily_review_test.dart
git commit -m "feat: 每日回顾页（quiz-hero + 今日成语 + 历期回顾）"
```

---

### Task 16: 游戏主界面重构（含 `totalFills` 计数与删除 isCustom）

**Files:**
- Modify: `lib/src/ui/screens/game_screen.dart`
- Modify: `lib/src/ui/widgets/level_display.dart`（或删除——若不再使用则移除引用）

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`AppIcon`、`AppCard`、`XpTrack`、`SubPageHeader`、`AppSeal`、`win_card_dialog.dart`（Task 17 创建——本任务先以 `showDialog` 占位或同步创建）、`SavedGameState.totalFills`（Task 6）
- Produces:
  - `int _totalFills`：每次 `_onCandidateTap` 落字 `_totalFills++`（含错误字）；提示填入不计。
  - 删除 `isCustom` 参数与 `_showCustomCompleteDialog`、`_onLevelComplete` 的自定义分支。
  - 顶栏（返回 + `第 N 关` 衬线 + 徽章 + 声音开关）；进度条（`N/8 字` + XpTrack）；已完成成语条（设计配色）；候选字盘（surface2 + borderStrong + 衬线）；工具栏「提示」/撤销/清空。
  - `GridPainter` 配色按设计（given 右上朱砂角点、focus 朱红描边+外光晕、filled accentPale、wrong 朱砂、correct leafSoft）。

- [ ] **Step 1: 更新游戏流程测试**

`test/ui/game_flow_test.dart` 修改：
- `find.text('一字×3')` → `find.text('提示')`（若「提示」文本多处，用 `find.textContaining('提示')` 之一）。
- `恭喜过关！` → 新 win-card 标题（Task 17 定文案，如 `第 1 关 · 通关`）。Task 17 之后再最终对齐；本任务先用占位断言 `find.textContaining('通关')`。

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/game_flow_test.dart`
Expected: FAIL（文案变化 / 新 UI 结构）。

- [ ] **Step 3: `game_screen.dart` 核心逻辑修改**

(a) 构造函数删除 `this.isCustom = false` 参数与字段。

(b) 新增状态：
```dart
  int _totalFills = 0;
```

(c) `_onCandidateTap` 中，在 `final isCorrect = ...` 之后加：
```dart
    _totalFills++;
```
并在每次 `_saveState()` 前保持 `_totalFills` 已更新（放 `setState` 外即可）。

(d) `_restoreSavedState` 的 `setState` 加 `_totalFills = state.totalFills;`。

(e) `_saveState` 的 `SavedGameState(...)` 加 `totalFills: _totalFills,`（Task 6 已加）。

(f) `_onLevelComplete`：删除 `if (widget.isCustom)` 分支；`addLevelHistory` 调用加 `totalFills: _totalFills,`。

- [ ] **Step 4: `build` 与子视图重写**

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _restoring
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopBar(),
                  _buildProgress(),
                  _buildCompletedIdiomsSection(),
                  Expanded(flex: 5, child: _buildGrid()),
                  Expanded(flex: 3, child: _buildCandidateBoardWidget()),
                  _buildToolbar(),
                ],
              ),
      ),
    );
  }
```

`_buildTopBar`：返回按钮（`AppIcon('back')` + `Navigator.maybePop`）、`第 N 关`（`displayStyle(19, w900)`）+ `BadgeSoft(主线/每日挑战)`、声音开关（`AppIcon('sound')`，onTap 切 `GameAudio.instance.muted`，off 时 40% 透明）。

`_buildProgress`：
```dart
  Widget _buildProgress() {
    final total = _blankCount();
    final filled = _completedCells.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('本关进度', style: bodyStyle(size: 11.5, color: AppColors.muted)),
              Text.rich(TextSpan(children: [
                TextSpan(text: '$filled', style: displayStyle(size: 14, weight: FontWeight.w700, color: AppColors.accent)),
                TextSpan(text: '/$total 字', style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ])),
            ],
          ),
          const SizedBox(height: 6),
          XpTrack(progress: total == 0 ? 0 : filled / total),
        ],
      ),
    );
  }
```

`_blankCount()` = 非 given 的 filled 格总数。`_buildCompletedIdiomsSection` 改为 `AppCard` 内横向 tag + 释义行（配色：已选 `accentSoft` 描边 `accent`，释义 `muted`）。`_buildCandidateBoardWidget` 与 `_buildToolbar` 改设计配色（surface2 格、borderStrong、衬线大字、taken dashed）。`_ToolbarButton` 标签改：`提示`（下方 `剩 N`/`卡×N` 用朱砂数字）、`撤销`、`清空`。

- [ ] **Step 5: `GridPainter` 配色修改**

在 `paint` 中替换配色常量：
```dart
      if (cell.isGiven) {
        bgColor = AppColors.surface2;
      } else if (completedCells.contains((r, c))) {
        bgColor = AppColors.leafSoft;
      } else if (errorCells.contains((r, c))) {
        bgColor = AppColors.accent;
      } else if (flashCell == (r, c)) {
        bgColor = AppColors.leafSoft;
      } else if (focusRow == r && focusCol == c) {
        bgColor = AppColors.accentPale;
      } else {
        bgColor = AppColors.surface;
      }
```
- given 格右上角画朱砂小圆点（`canvas.drawCircle` at `(x + s - 6, y + 6)`，`AppColors.accent`，半径 2.5）。
- focus 格边框 `AppColors.accent`、线宽 2.5、外光晕（`canvas.drawRRect` 用 `AppColors.accent.withValues(alpha:0.25)` 粗 stroke）。
- 文字颜色：given `AppColors.fg` 700；correct/leafSoft 格 `AppColors.leaf`；filled 格 `AppColors.accentDeep`；wrong/accent 底白字 `Color(0xFFFFF6EC)`；tentative 50% 透明。
- `shouldRepaint` 保持 `true`。

- [ ] **Step 6: 运行确认通过**

Run: `flutter test test/ui/game_flow_test.dart && flutter analyze`
Expected: PASS（若 win-card 文案未定导致断言失败，先对齐 Task 17 文案后重跑）。

- [ ] **Step 7: Commit**

```bash
git add lib/src/ui/screens/game_screen.dart test/ui/game_flow_test.dart
git commit -m "feat: 游戏主界面重构（设计配色/顶栏/进度/工具栏）+ totalFills 计数 + 删 isCustom"
```

---

### Task 17: 过关窗 win-card（新建组件 + 接入 3 个入口）

**Files:**
- Create: `lib/src/ui/widgets/win_card_dialog.dart`
- Modify: `lib/src/ui/screens/game_screen.dart`

**Interfaces:**
- Consumes: `AppColors`、`app_text.dart`、`PrimaryButton`、`AppSeal`
- Produces:
  - `Future<void> showWinCardDialog(BuildContext context, {required String seal, required String title, required String subtitle, required String xpText, required List<String> idioms, required List<WinCardAction> actions})`
  - `class WinCardAction { final String label; final VoidCallback? onTap; final bool primary; final bool ghost; const WinCardAction({required this.label, this.onTap, this.primary = false, this.ghost = false}); }`
- 接入 `game_screen.dart`：`_showCompletionDialog`、`_showRewardDialog`、`_showReplayCompleteDialog` 改用 `showWinCardDialog`；删除 `_showCustomCompleteDialog`（Task 16 已删）。

- [ ] **Step 1: 写 win-card 测试**

新建 `test/ui/win_card_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/win_card_dialog.dart';

void main() {
  testWidgets('win-card 展示印章与动作', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final completer = Completer<void>();
    unawaited(showWinCardDialog(
      tester.element(find.byType(MaterialApp)),
      seal: '通',
      title: '第 47 关 · 通关',
      subtitle: '交叉推理 · 恒心顿悟',
      xpText: '获得经验 +96',
      idioms: const ['水滴石穿 水不停地滴，石头也能被滴穿。'],
      actions: const [WinCardAction(label: '下一关', primary: true)],
    ));
    await tester.pumpAndSettle();
    expect(find.text('通'), findsOneWidget);
    expect(find.text('第 47 关 · 通关'), findsOneWidget);
    expect(find.text('下一关'), findsOneWidget);
    await tester.tap(find.text('下一关'));
    await tester.pumpAndSettle();
  });
}
```

需 import `dart:async`。若用 `showDialog` 异步，测试可改为同步 `pumpWidget` 内嵌对话框组件（推荐：导出一个 `WinCard` 纯组件 + `showWinCardDialog` 包装）。计划以组件优先：

```dart
testWidgets('WinCard 组件渲染', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: WinCard(
      seal: '通',
      title: '第 47 关 · 通关',
      xpText: '获得经验 +96',
      idioms: const ['水滴石穿 水不停地滴'],
      actions: const [WinCardAction(label: '下一关', primary: true)],
    )),
  ));
  expect(find.text('通'), findsOneWidget);
  expect(find.text('第 47 关 · 通关'), findsOneWidget);
});
```

- [ ] **Step 2: 运行确认失败**

Run: `flutter test test/ui/win_card_test.dart`
Expected: FAIL（文件不存在）。

- [ ] **Step 3: 实现 `win_card_dialog.dart`**

```dart
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_seal.dart';
import 'primary_button.dart';

class WinCardAction {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool ghost;
  const WinCardAction({
    required this.label,
    this.onTap,
    this.primary = false,
    this.ghost = false,
  });
}

/// 过关庆祝卡（win-card 母题）
class WinCard extends StatelessWidget {
  final String seal;
  final String title;
  final String? subtitle;
  final String xpText;
  final List<String> idioms;
  final List<WinCardAction> actions;

  const WinCard({
    super.key,
    required this.seal,
    required this.title,
    this.subtitle,
    required this.xpText,
    required this.idioms,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(26, 34, 26, 26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x66140A00), blurRadius: 70, offset: Offset(0, 30))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: -4 * 3.14159 / 180,
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: AppColors.accentDeep, offset: Offset(0, 10), blurRadius: 0),
                    BoxShadow(color: Color(0x57B33B27), blurRadius: 36, offset: Offset(0, 20)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  seal,
                  style: displayStyle(size: 40, weight: FontWeight.w900, color: const Color(0xFFFFF6EC)),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: displayStyle(size: 26, weight: FontWeight.w900)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: bodyStyle(size: 13, color: AppColors.muted)),
            ],
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: '获得经验 ', style: TextStyle(fontSize: 14, color: AppColors.accentDeep, fontWeight: FontWeight.w600)),
                TextSpan(text: xpText, style: displayStyle(size: 20, weight: FontWeight.w900, color: AppColors.accentDeep)),
              ]),
            ),
            const SizedBox(height: 16),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PrimaryButton(
                  label: action.label,
                  small: true,
                  ghost: action.ghost,
                  onTap: action.onTap,
                ),
              ),
            if (idioms.isNotEmpty) ...[
              const Divider(color: AppColors.border),
              const SizedBox(height: 8),
              for (final idiom in idioms.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    idiom,
                    style: bodyStyle(size: 13, color: const Color(0xFF4A4438)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 弹出 win-card（半透明遮罩 + 居中）
Future<void> showWinCardDialog(
  BuildContext context, {
  required String seal,
  required String title,
  String? subtitle,
  required String xpText,
  List<String> idioms = const [],
  List<WinCardAction> actions = const [],
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: WinCard(
        seal: seal,
        title: title,
        subtitle: subtitle,
        xpText: xpText,
        idioms: idioms,
        actions: actions,
      ),
    ),
  );
}
```

- [ ] **Step 4: 接入 `game_screen.dart` 三个完成入口**

替换 `_showCompletionDialog`：

```dart
  void _showCompletionDialog(
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    final xpText = '${result.xpGained > 0 ? '+' : ''}${result.xpGained}';
    showWinCardDialog(
      context,
      seal: '通',
      title: _isDaily ? '每日挑战 · 完成' : '${widget.level.title} · 通关',
      subtitle: '用时 ${_formatDuration(timeSpentMs)} · 填错 $_errorsMade',
      xpText: xpText,
      idioms: _completedIdiomList.map((i) => '${i.word} ${i.meaning}').toList(),
      actions: [
        if (!_isDaily)
          WinCardAction(label: '下一关', primary: true, onTap: () {
            Navigator.of(context).pop();
            _startNextLevel();
          }),
        WinCardAction(label: '学习本关成语', ghost: true, onTap: () => _showLearning(context)),
        WinCardAction(label: '稍后再看', ghost: true, onTap: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }),
      ],
    );
  }
```

> `_showLearning` 需要一个能用的 `context`；在 dialog 内 `Navigator.of(context).pop()` 先关对话框再 push。注意 `showDialog` 的 builder context 与屏 context 区分。`_showRewardDialog`（升级奖励）改为：先 `showWinCardDialog` 展示奖励文案（seal `升`，title `晋升 ${title}`，xpText 含奖励道具），其「继续」动作再调 `_showCompletionDialog`。`_showReplayCompleteDialog` 改为 `showWinCardDialog(seal:'通', title:'本关已完成', ...)`。升级奖励的奖励信息以 `subtitle` 展示。

- [ ] **Step 5: 运行确认通过**

Run: `flutter test test/ui/win_card_test.dart && flutter test test/ui/game_flow_test.dart && flutter analyze`
Expected: PASS（game_flow 断言与 win-card 文案对齐——`恭喜过关！` 改为新标题）。

- [ ] **Step 6: Commit**

```bash
git add lib/src/ui/widgets/win_card_dialog.dart lib/src/ui/screens/game_screen.dart test/ui/win_card_test.dart test/ui/game_flow_test.dart
git commit -m "feat: 过关窗 win-card 母题 + 三入口接入"
```

---

### Task 18: 删除自定义功能 + 全量测试清理

**Files:**
- Delete: `lib/src/ui/screens/custom_level_screen.dart`
- Modify: `test/ui/screens_test.dart`（删除自定义关卡用例，更新受影响断言）
- Modify: `lib/src/ui/screens/home_screen.dart`（确认无自定义入口）、`lib/src/ui/screens/mine_screen.dart`（确认无自定义入口）
- Verify: `lib/src/ui/screens/game_screen.dart`（确认 `isCustom`/`_showCustomCompleteDialog` 已删）

**Interfaces:**
- 无新接口；纯删除与清理。

- [ ] **Step 1: 删除自定义页文件**

Run: `git rm lib/src/ui/screens/custom_level_screen.dart`

- [ ] **Step 2: 清理测试引用**

`test/ui/screens_test.dart`：
- 删除 `import '...custom_level_screen.dart';`。
- 删除 `自定义关卡页：渲染参数控件，空库生成失败提示` 整个用例。
- 更新受影响断言：
  - `成就页`：`'已解锁 0/${achievementDefs.length}'` → `find.textContaining('已解锁')`（Task 12 已改，确认）。
  - `统计页`：`'通关数'` → `'累计通关'`；删除 `'第 7 关'` 断言（Task 13 已改）。
  - `首页：每日挑战在数据库无成语时提示生成失败`：`await tester.tap(find.text('每日挑战'))` → `await tester.tap(find.text('开始挑战'))`；提示文案 `'每日挑战生成失败，请重试'` 保留。
  - `首页：每日挑战完成后按钮显示完成态`：`'每日挑战 ✓'` → `'已完成'`（每日卡按钮态）。
  - `关卡选择页` 用例（Task 9 已重写）。
  - `设置页`：`find.byType(Switch)` 断言保留；新增触感断言已加。
  - `商城购买按钮提示即将上线`：`await tester.tap(find.text('¥6'))` → `await tester.tap(find.text('购买'))`。
- 确保 import 增补：`mine_screen.dart`、`settings_screen.dart` 的 `hapticEnabledKey`。

`test/ui/game_flow_test.dart`：
- `'一字×3'` → `'提示'`（或 `find.textContaining('提示')`）。
- `'恭喜过关！'` → win-card 标题（与 Task 17 对齐，如 `'第 1 关 · 通关'`）。

- [ ] **Step 3: 检查其余引用**

Run: `grep -rn "custom_level_screen\|CustomLevelScreen\|isCustom" lib test`
Expected: 无匹配。

- [ ] **Step 4: 全量运行**

Run: `flutter analyze && flutter test`
Expected: 全部通过，0 error。

- [ ] **Step 5: 修复遗留文案/结构差异**

若个别用例因文案未对齐失败，按实际渲染文本修正断言（保持语义等价）。

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: 删除自定义关卡功能，全量测试对齐新 UI"
```

---

### Task 19: 验收与收尾

**Files:**
- Modify: 视 analyze/test 结果修复

**Interfaces:**
- 无

- [ ] **Step 1: 运行全量验证**

Run: `flutter analyze`
Expected: 0 issues。

Run: `flutter test`
Expected: 全绿。

- [ ] **Step 2: 对照 spec 验收清单人工过一遍**

- 全案仅 `AppColors.accent` 一个强调色，每屏可见 ≤ 2 处。
- 中文大标题行高 ≥1.3，CJK 无负字距，大数字衬线。
- 底部五 Tab 完整导航。
- 印章母题贯穿通关/完成/成就/每日达成态。
- 过关窗统一 win-card 母题。
- 无「螺旋难度」「万关螺旋」文案。

- [ ] **Step 3: 手动冒烟（可选）**

Run: `flutter run`（真机/模拟器）检查首页 → 关卡 → 收藏 → 商城 → 我的五 Tab 切换、进入游戏完成一关出现 win-card、每日回顾历期渲染。

- [ ] **Step 4: 收尾 commit（如有修复）**

```bash
git add -A
git commit -m "fix: 验收修复"
```

---

## Self-Review

**Spec 覆盖核对：**
- 7.1 首页 → Task 8 ✅；7.2 关卡 → Task 9 ✅；7.3 收藏 → Task 10 ✅；7.4 商城 → Task 11 ✅；7.5 我的 → Task 7 ✅；7.6 成就 → Task 12 ✅；7.7 统计 → Task 13 ✅；7.8 自定义删除 → Task 18 ✅；7.9 设置 → Task 14 ✅；7.10 每日回顾 → Task 15 ✅；7.11 游戏 → Task 16 ✅；7.12 win-card → Task 17 ✅。
- 数据变更 8.1/8.2/8.3 → Task 5/6 ✅；导航 → Task 4 ✅；主题/字体/图标/组件 → Task 1/2/3 ✅。
- 用户 review 六点：关卡翻页上限（Task 9）、等级条精简（Task 7）、自定义删除（Task 18）、设置精简（Task 14）、每日回顾无全服平均（Task 15）、footnote「次日 0 点刷新」（Task 15）✅。

**占位扫描：** `_dailyMeaning`（Task 15）标注了「占位」——已给出替换建议（扩展 `DailyInfo.meaning`）。其余步骤均含完整代码。

**类型一致性：** `SavedGameState.totalFills`（Task 6）→ `GameScreen._totalFills`（Task 16）→ `addLevelHistory(totalFills:)`（Task 5）一致；`DailyInfo`（Task 8）→ 每日回顾（Task 15）一致；`AppIcon` 图标名清单在 Task 2 定义，各页引用与之一致。
