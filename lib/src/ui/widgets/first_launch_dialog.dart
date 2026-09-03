import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/cloud_save_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'app_seal.dart';
import 'primary_button.dart';
import 'theme_dialog.dart';

enum FirstLaunchChoice { restored, newGame }

typedef CloudSaveDownloader = Future<CloudSaveDownloadResult> Function();
typedef CloudSaveImporter = Future<void> Function(String data);
typedef NewGameStarter = Future<void> Function();

class FirstLaunchDialog extends ConsumerStatefulWidget {
  final CloudSaveDownloader downloadCloudSave;
  final CloudSaveImporter importCloudSave;
  final NewGameStarter startNewGame;
  final Duration restoreTimeout;

  const FirstLaunchDialog({
    super.key,
    required this.downloadCloudSave,
    required this.importCloudSave,
    required this.startNewGame,
    this.restoreTimeout = const Duration(seconds: 30),
  });

  @override
  ConsumerState<FirstLaunchDialog> createState() => _FirstLaunchDialogState();
}

class _FirstLaunchDialogState extends ConsumerState<FirstLaunchDialog> {
  Timer? _countdownTimer;
  var _attempt = 0;
  var _busy = false;
  var _restoring = false;
  var _remainingSeconds = 30;
  String? _error;

  @override
  void dispose() {
    _attempt++;
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreCloudSave() async {
    if (_busy) return;
    final attempt = ++_attempt;
    final deadline = DateTime.now().add(widget.restoreTimeout);
    _countdownTimer?.cancel();
    setState(() {
      _busy = true;
      _restoring = true;
      _error = null;
      _remainingSeconds = _secondsUntil(deadline);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || attempt != _attempt) return;
      final remainingSeconds = _secondsUntil(deadline);
      if (remainingSeconds == 0) {
        _finishAttempt(attempt, '连接超时，请检查网络后重试。', invalidate: true);
        return;
      }
      setState(() => _remainingSeconds = remainingSeconds);
    });

    try {
      final result = await widget.downloadCloudSave().timeout(
        widget.restoreTimeout,
      );
      if (!mounted || attempt != _attempt) return;

      switch (result.status) {
        case CloudSaveDownloadStatus.available:
          await widget.importCloudSave(result.data!);
          if (!mounted || attempt != _attempt) return;
          Navigator.of(context).pop(FirstLaunchChoice.restored);
          return;
        case CloudSaveDownloadStatus.noCloudSave:
          _finishAttempt(attempt, '没有找到可恢复的云存档，你可以重试或开始新游戏。');
          return;
        case CloudSaveDownloadStatus.gameCenterUnavailable:
          _finishAttempt(
            attempt,
            '无法登录 Game Center。请先在“设置”中登录 Game Center，'
            '再返回重试。',
          );
          return;
        case CloudSaveDownloadStatus.timedOut:
          _finishAttempt(attempt, '云存档连接超时，请检查网络后重试。');
          return;
        case CloudSaveDownloadStatus.unavailable:
          _finishAttempt(
            attempt,
            'iCloud 云存档暂不可用。请确认已登录 iCloud '
            '并开启 iCloud 云盘后重试。',
          );
          return;
      }
    } on TimeoutException {
      _finishAttempt(attempt, '连接超时，请检查网络后重试。');
    } catch (_) {
      _finishAttempt(attempt, '云存档恢复失败，请稍后重试。');
    }
  }

  Future<void> _startNewGame() async {
    if (_busy) return;
    final attempt = ++_attempt;
    setState(() {
      _busy = true;
      _restoring = false;
      _error = null;
    });
    try {
      await widget.startNewGame();
      if (!mounted || attempt != _attempt) return;
      Navigator.of(context).pop(FirstLaunchChoice.newGame);
    } catch (_) {
      _finishAttempt(attempt, '新游戏初始化失败，请重试。');
    }
  }

  void _finishAttempt(int attempt, String error, {bool invalidate = false}) {
    if (!mounted || attempt != _attempt) return;
    if (invalidate) _attempt++;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _busy = false;
      _restoring = false;
      _error = error;
    });
  }

  int _secondsUntil(DateTime deadline) {
    final milliseconds = deadline.difference(DateTime.now()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: ThemeDialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSeal('学', size: 64, fontSize: 24),
              const SizedBox(height: 16),
              Text(
                '欢迎来到成语接龙',
                style: displayStyle(size: 24, weight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Text(
                '1. 点击下方候选字，填入选中空格\n'
                '2. 一个字可能同时属于横、纵两个成语\n'
                '3. 交叉点同时满足两条线索才是正确解\n\n'
                '填满所有空格即可过关！',
                style: bodyStyle(size: 13, color: AppColors.fg),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 14),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: bodyStyle(size: 12.5, color: AppColors.accentDeep),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _restoring ? '正在恢复（$_remainingSeconds 秒）' : '恢复云存档',
                  small: true,
                  onTap: _busy ? null : _restoreCloudSave,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: '开始新游戏',
                  small: true,
                  ghost: true,
                  onTap: _busy ? null : _startNewGame,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
