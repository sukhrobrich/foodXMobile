class Place {
  final int id;
  final String name;
  final String zone;
  final bool empty;
  final int? activeOrderId;
  final double activeOrderTotal;

  Place({
    required this.id,
    required this.name,
    required this.zone,
    required this.empty,
    this.activeOrderId,
    required this.activeOrderTotal,
  });

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        id: j['id'] as int,
        name: (j['name'] ?? '').toString(),
        zone: (j['zone'] ?? '').toString(),
        empty: j['empty'] == 'YES' || j['empty'] == true,
        activeOrderId: j['active_order_id'] as int?,
        activeOrderTotal:
            (j['active_order_total'] ?? 0).toDouble(),
      );
}