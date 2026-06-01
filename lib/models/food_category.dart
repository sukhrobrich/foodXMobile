class FoodCategory {
  final int id;
  final String name;

  FoodCategory({required this.id, required this.name});

  factory FoodCategory.fromJson(Map<String, dynamic> j) => FoodCategory(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
      );
}