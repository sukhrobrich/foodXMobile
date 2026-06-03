class Place {
  final int id;
  final String name;
  final String zone;
  final bool empty;
  final int? activeOrderId;
  final int? activeOrderUserId;
  final String activeOrderUserName;
  final double activeOrderTotal;

  Place({
    required this.id,
    required this.name,
    required this.zone,
    required this.empty,
    this.activeOrderId,
    this.activeOrderUserId,
    required this.activeOrderUserName,
    required this.activeOrderTotal,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        zone: (j['zone'] ?? '').toString(),
        // Aktiv buyurtma yo'q = bo'sh. API dan kelgan empty ni fallback sifatida ishlatamiz.
        empty: j['active_order_id'] == null &&
               (j['empty'] == 'YES' || j['empty'] == true || j['empty'] == null),
        activeOrderId: j['active_order_id'] as int?,
        activeOrderUserId: j['active_order_user_id'] as int?,
        activeOrderUserName: (j['active_order_user_name'] ?? '').toString(),
        activeOrderTotal: (j['active_order_total'] ?? 0).toDouble(),
      );
}