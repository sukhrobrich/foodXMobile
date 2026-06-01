class Food {
  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final double sellingPrice;
  final bool isUnlimited;
  final double count;
  final String unit;

  Food({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.sellingPrice,
    required this.isUnlimited,
    required this.count,
    required this.unit,
  });

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        categoryId: (j['food_category_id'] ?? 0) as int,
        categoryName: (j['category_name'] ?? '').toString(),
        sellingPrice: (j['selling_price'] ?? 0).toDouble(),
        isUnlimited: j['is_unlimited'] == true || j['is_unlimited'] == 1,
        count: (j['count'] ?? 0).toDouble(),
        unit: (j['unit'] ?? 'dona').toString(),
      );

  bool get available => isUnlimited || count > 0;
}