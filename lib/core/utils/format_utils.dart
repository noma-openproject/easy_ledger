import 'package:intl/intl.dart';

const List<String> kPaymentMethods = ['card', 'cash', 'transfer', 'other'];
const List<String> kCategories = [
  'food',
  'transport',
  'living',
  'medical',
  'culture',
  'education',
  'gift',
  'housing',
  'communication',
  'entertainment',
  'etc',
];
const List<String> kExpenseTypes = ['personal', 'business'];
const List<String> kTaxCategories = [
  '복리후생비',
  '접대비',
  '소모품비',
  '차량유지비',
  '통신비',
  '교육훈련비',
  '여비교통비',
  '지급수수료',
  '광고선전비',
  '기타',
];

String formatWon(int amount) {
  return '${NumberFormat.decimalPattern('ko_KR').format(amount)}원';
}

String formatCompactDate(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mm-$dd';
}

String formatKoreanDate(DateTime date) {
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = weekdays[date.weekday - 1];
  return '${date.month}월 ${date.day}일 ($weekday)';
}

String formatMonthTitle(DateTime date) {
  return '${date.year}년 ${date.month}월';
}

String categoryLabel(String value) {
  return switch (value) {
    'food' => '식비',
    'transport' => '교통',
    'living' => '생활',
    'medical' => '의료',
    'culture' => '문화',
    'education' => '교육',
    'gift' => '경조사',
    'housing' => '주거',
    'communication' => '통신',
    'entertainment' => '접대',
    _ => '기타',
  };
}

String paymentMethodLabel(String value) {
  return switch (value) {
    'card' => '카드',
    'cash' => '현금',
    'transfer' => '이체',
    _ => '기타',
  };
}

String expenseTypeLabel(String value) {
  return switch (value) {
    'business' => '사업경비',
    _ => '개인지출',
  };
}

DateTime? parseCompactDate(String value) {
  final parts = value.trim().split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}

int? parseWon(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9-]'), '');
  if (digits.isEmpty || digits == '-') return null;
  return int.tryParse(digits);
}
