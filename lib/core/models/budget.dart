import 'package:hive/hive.dart';

part 'budget.g.dart';

@HiveType(typeId: 5)
class Budget extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String categoryId;

  @HiveField(2)
  final int monthlyAmount;

  @HiveField(3)
  final int year;

  @HiveField(4)
  final int month;

  Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyAmount,
    required this.year,
    required this.month,
  });

  Budget copyWith({
    String? id,
    String? categoryId,
    int? monthlyAmount,
    int? year,
    int? month,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }
}
