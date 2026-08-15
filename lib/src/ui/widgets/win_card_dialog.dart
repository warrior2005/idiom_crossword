import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
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

typedef WinCardIdiom = ({String word, String meaning});

/// 过关庆祝卡（win-card 母题）
class WinCard extends StatelessWidget {
  final String seal;
  final String title;
  final String? subtitle;
  final String xpText;
  final List<WinCardIdiom> idioms;
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
          boxShadow: const [
            BoxShadow(
              color: Color(0x66140A00),
              blurRadius: 70,
              offset: Offset(0, 30),
            ),
          ],
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
                    BoxShadow(
                      color: AppColors.accentDeep,
                      offset: Offset(0, 10),
                      blurRadius: 0,
                    ),
                    BoxShadow(
                      color: Color(0x57B33B27),
                      blurRadius: 36,
                      offset: Offset(0, 20),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  seal,
                  style: displayStyle(
                    size: 40,
                    weight: FontWeight.w900,
                    color: const Color(0xFFFFF6EC),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: displayStyle(size: 26, weight: FontWeight.w900)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: bodyStyle(size: 13, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '经验 ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.accentDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: xpText,
                    style: displayStyle(
                      size: 20,
                      weight: FontWeight.w900,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ],
              ),
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
              for (final idiom in idioms.take(3))
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          key: ValueKey('win-card-idiom-${idiom.word}'),
                          child: Text(
                            idiom.word,
                            style: displayStyle(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.accentDeep,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: idiom.meaning,
                                  style: bodyStyle(
                                    size: 13,
                                    color: const Color(0xFF4A4438),
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
  List<WinCardIdiom> idioms = const [],
  List<WinCardAction> actions = const [],
  bool dismissible = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          WinCard(
            seal: seal,
            title: title,
            subtitle: subtitle,
            xpText: xpText,
            idioms: idioms,
            actions: actions,
          ),
          if (dismissible)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: AppColors.muted),
              ),
            ),
        ],
      ),
    ),
  );
}
