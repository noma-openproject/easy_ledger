import 'package:hive/hive.dart';

part 'category.g.dart';

/// 사용자 편집 가능한 거래 카테고리.
///
/// Transaction.category 는 이 모델의 id 문자열을 저장한다.
@HiveType(typeId: 3)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String iconEmoji;

  @HiveField(3)
  final int colorHex;

  @HiveField(4)
  final bool isDefault;

  @HiveField(5)
  final String? taxCategory;

  @HiveField(6)
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    required this.iconEmoji,
    required this.colorHex,
    required this.isDefault,
    this.taxCategory,
    this.sortOrder = 0,
  });

  Category copyWith({
    String? id,
    String? name,
    String? iconEmoji,
    int? colorHex,
    bool? isDefault,
    Object? taxCategory = _sentinel,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      colorHex: colorHex ?? this.colorHex,
      isDefault: isDefault ?? this.isDefault,
      taxCategory: identical(taxCategory, _sentinel)
          ? this.taxCategory
          : taxCategory as String?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

const Object _sentinel = Object();

final List<Category> defaultCategories = [
  Category(
    id: 'food',
    name: '식비',
    iconEmoji: '🍔',
    colorHex: 0xFFE57373,
    isDefault: true,
    taxCategory: '복리후생비',
    sortOrder: 0,
  ),
  Category(
    id: 'transport',
    name: '교통',
    iconEmoji: '🚕',
    colorHex: 0xFF64B5F6,
    isDefault: true,
    taxCategory: '여비교통비',
    sortOrder: 1,
  ),
  Category(
    id: 'living',
    name: '생활',
    iconEmoji: '🛒',
    colorHex: 0xFF81C784,
    isDefault: true,
    taxCategory: '소모품비',
    sortOrder: 2,
  ),
  Category(
    id: 'medical',
    name: '의료',
    iconEmoji: '🏥',
    colorHex: 0xFFBA68C8,
    isDefault: true,
    sortOrder: 3,
  ),
  Category(
    id: 'culture',
    name: '문화',
    iconEmoji: '🎬',
    colorHex: 0xFFFFB74D,
    isDefault: true,
    sortOrder: 4,
  ),
  Category(
    id: 'education',
    name: '교육',
    iconEmoji: '📚',
    colorHex: 0xFF4DB6AC,
    isDefault: true,
    taxCategory: '교육훈련비',
    sortOrder: 5,
  ),
  Category(
    id: 'gift',
    name: '경조사',
    iconEmoji: '🎁',
    colorHex: 0xFFF06292,
    isDefault: true,
    taxCategory: '접대비',
    sortOrder: 6,
  ),
  Category(
    id: 'housing',
    name: '주거',
    iconEmoji: '🏠',
    colorHex: 0xFFA1887F,
    isDefault: true,
    sortOrder: 7,
  ),
  Category(
    id: 'communication',
    name: '통신',
    iconEmoji: '📱',
    colorHex: 0xFF7986CB,
    isDefault: true,
    taxCategory: '통신비',
    sortOrder: 8,
  ),
  Category(
    id: 'entertainment',
    name: '접대',
    iconEmoji: '🤝',
    colorHex: 0xFFFF8A65,
    isDefault: true,
    taxCategory: '접대비',
    sortOrder: 9,
  ),
  Category(
    id: 'etc',
    name: '기타',
    iconEmoji: '🧾',
    colorHex: 0xFF90A4AE,
    isDefault: true,
    sortOrder: 10,
  ),
];
