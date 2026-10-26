import 'package:lpinyin/lpinyin.dart';

/// 为填入棋盘的候选字提供单字读音，不依赖格子的正确答案。
String characterPinyin(String character) => PinyinHelper.getPinyinE(
  character,
  format: PinyinFormat.WITHOUT_TONE,
  defPinyin: '',
);
