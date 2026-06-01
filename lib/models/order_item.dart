class OrderItem {
  final int foodId;
  final String foodName;
  final double price;
  int quantity;

  OrderItem({
    required this.foodId,
    required this.foodName,
    required this.price,
    required this.quantity,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'quantity': quantity,
        'note': '',
      };
}