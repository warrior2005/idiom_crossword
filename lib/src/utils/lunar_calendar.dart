/// 农历换算（1900–2100）与二十四节气，数据表/算法采用公历农历互转的经典实现。
library;

class LunarDate {
  /// 农历年（与公历年基本对应，正月初一前属上一年）
  final int year;

  /// 农历月 1–12
  final int month;

  /// 农历日 1–30
  final int day;

  /// 是否闰月
  final bool isLeap;

  const LunarDate(this.year, this.month, this.day, [this.isLeap = false]);

  /// 中文月名：正月、二月……冬月、腊月（闰月前缀「闰」）
  String get monthName {
    final base = _monthCn[month];
    return isLeap ? '闰$base' : base;
  }

  /// 中文日名：初一、初二……三十
  String get dayName {
    if (day == 10) return '初十';
    if (day == 20) return '二十';
    if (day == 30) return '三十';
    final tens = day ~/ 10;
    final units = day % 10;
    final tensCn = tens == 0 ? '初' : (tens == 1 ? '十' : '廿');
    return '$tensCn${_digitCn[units]}';
  }
}

const _monthCn = ['', '正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月'];
const _digitCn = ['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

/// 1900–2100 农历数据表：低 4 位为闰月，第 4 位为闰月大小月，5–16 位为各月大小月
const _lunarInfo = <int>[
  0x04bd8, 0x04ae0, 0x0a570, 0x054d5, 0x0d260, 0x0d950, 0x16554, 0x056a0, 0x09ad0, 0x055d2,
  0x04ae0, 0x0a5b6, 0x0a4d0, 0x0d250, 0x1d255, 0x0b540, 0x0d6a0, 0x0ada2, 0x095b0, 0x14977,
  0x04970, 0x0a4b0, 0x0b4b5, 0x06a50, 0x06d40, 0x1ab54, 0x02b60, 0x09570, 0x052f2, 0x04970,
  0x06566, 0x0d4a0, 0x0ea50, 0x06e95, 0x05ad0, 0x02b60, 0x186e3, 0x092e0, 0x1c8d7, 0x0c950,
  0x0d4a0, 0x1d8a6, 0x0b550, 0x056a0, 0x1a5b4, 0x025d0, 0x092d0, 0x0d2b2, 0x0a950, 0x0b557,
  0x06ca0, 0x0b550, 0x15355, 0x04da0, 0x0a5b0, 0x14573, 0x052b0, 0x0a9a8, 0x0e950, 0x06aa0,
  0x0aea6, 0x0ab50, 0x04b60, 0x0aae4, 0x0a570, 0x05260, 0x0f263, 0x0d950, 0x05b57, 0x056a0,
  0x096d0, 0x04dd5, 0x04ad0, 0x0a4d0, 0x0d4d4, 0x0d250, 0x0d558, 0x0b540, 0x0b6a0, 0x195a6,
  0x095b0, 0x049b0, 0x0a974, 0x0a4b0, 0x0b27a, 0x06a50, 0x06d40, 0x0af46, 0x0ab60, 0x09570,
  0x04af5, 0x04970, 0x064b0, 0x074a3, 0x0ea50, 0x06b58, 0x055c0, 0x0ab60, 0x096d5, 0x092e0,
  0x0c960, 0x0d954, 0x0d4a0, 0x0da50, 0x07552, 0x056a0, 0x0abb7, 0x025d0, 0x092d0, 0x0cab5,
  0x0a950, 0x0b4a0, 0x0baa4, 0x0ad50, 0x055d9, 0x04ba0, 0x0a5b0, 0x15176, 0x052b0, 0x0a930,
  0x07954, 0x06aa0, 0x0ad50, 0x05b52, 0x04b60, 0x0a6e6, 0x0a4e0, 0x0d260, 0x0ea65, 0x0d530,
  0x05aa0, 0x076a3, 0x096d0, 0x04afb, 0x04ad0, 0x0a4d0, 0x1d0b6, 0x0d250, 0x0d520, 0x0dd45,
  0x0b5a0, 0x056d0, 0x055b2, 0x049b0, 0x0a577, 0x0a4b0, 0x0aa50, 0x1b255, 0x06d20, 0x0ada0,
  0x14b63, 0x09370, 0x049f8, 0x04970, 0x064b0, 0x168a6, 0x0ea50, 0x06b20, 0x1a6c4, 0x0aae0,
  0x092e0, 0x0d2e3, 0x0c960, 0x0d557, 0x0d4a0, 0x0da50, 0x05d55, 0x056a0, 0x0a6d0, 0x055d4,
  0x052d0, 0x0a9b8, 0x0a950, 0x0b4a0, 0x0b6a6, 0x0ad50, 0x055a0, 0x0aba4, 0x0a5b0, 0x052b0,
  0x0b273, 0x06930, 0x07337, 0x06aa0, 0x0ad50, 0x14b55, 0x04b60, 0x0a570, 0x054e4, 0x0d160,
  0x0e968, 0x0d520, 0x0daa0, 0x16aa6, 0x056d0, 0x04ae0, 0x0a9d4, 0x0a2d0, 0x0d150, 0x0f252,
  0x0d520,
];

int _leapMonth(int y) => _lunarInfo[y - 1900] & 0xF;

int _leapDays(int y) {
  if (_leapMonth(y) == 0) return 0;
  return (_lunarInfo[y - 1900] & 0x10000) != 0 ? 30 : 29;
}

int _monthDays(int y, int m) =>
    (_lunarInfo[y - 1900] & (0x10000 >> m)) != 0 ? 30 : 29;

int _yearDays(int y) {
  var sum = 348;
  var bit = 0x8000;
  while (bit > 0x8) {
    if ((_lunarInfo[y - 1900] & bit) != 0) sum++;
    bit >>= 1;
  }
  return sum + _leapDays(y);
}

/// 公历转农历
LunarDate solarToLunar(DateTime solar) {
  final target = DateTime.utc(solar.year, solar.month, solar.day);
  final base = DateTime.utc(1900, 1, 31); // 农历 1900 年正月初一
  var offset = target.difference(base).inDays;

  var temp = 0;
  var i = 1900;
  while (i < 2101 && offset > 0) {
    temp = _yearDays(i);
    offset -= temp;
    i++;
  }
  if (offset < 0) {
    offset += temp;
    i--;
  }

  final year = i;
  final leap = _leapMonth(year);
  var isAdd = false;
  i = 1;
  while (i < 13 && offset > 0) {
    if (leap > 0 && i == leap + 1 && !isAdd) {
      i--;
      isAdd = true;
      temp = _leapDays(year);
    } else {
      temp = _monthDays(year, i);
    }
    offset -= temp;
    i++;
  }
  if (offset == 0 && leap > 0 && i == leap + 1) {
    if (isAdd) {
      isAdd = false;
    } else {
      isAdd = true;
      i--;
    }
  }
  if (offset < 0) {
    offset += temp;
    i--;
  }
  return LunarDate(year, i, offset + 1, isAdd);
}

const _solarTermNames = [
  '小寒', '大寒', '立春', '雨水', '惊蛰', '春分', '清明', '谷雨',
  '立夏', '小满', '芒种', '夏至', '小暑', '大暑', '立秋', '处暑',
  '白露', '秋分', '寒露', '霜降', '立冬', '小雪', '大雪', '冬至',
];

const _solarTermInfo = <int>[
  0, 21208, 42467, 63836, 85337, 107014, 128867, 150921, 173149, 195551,
  218072, 240693, 263343, 285989, 308563, 331033, 353350, 375494, 397447,
  419210, 440795, 462224, 483532, 504758,
];

int _solarTermDay(int year, int n) {
  final base = DateTime.utc(1900, 1, 6, 2, 5);
  final ms =
      base.millisecondsSinceEpoch +
      (31556925974.7 * (year - 1900) + _solarTermInfo[n] * 60000).round();
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).day;
}

/// 当日所处的二十四节气（最近一个已开始的节气名），无则不返回
String? currentSolarTerm(DateTime date) {
  String? term;
  for (var n = 0; n < 24; n++) {
    final termDate = DateTime(date.year, (n ~/ 2) + 1, _solarTermDay(date.year, n));
    if (!termDate.isAfter(date)) term = _solarTermNames[n];
  }
  return term;
}
