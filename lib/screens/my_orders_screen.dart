import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/api.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<_Order> _orders = [];
  bool   _loading = true;
  String? _error;
  // 'NO' = ochiq, 'YES' = yopiq
  String _filter = 'NO';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await Api.get('orders/mine?paid=$_filter&pageSize=50') as List;
      setState(() {
        _orders = data.map((j) => _Order.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setFilter(String v) {
    if (_filter == v) return;
    setState(() => _filter = v);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Buyurtmalarim',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textDark)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          // ── Radio filter ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              _RadioBtn(
                label: 'Ochiq',
                icon: Icons.radio_button_checked,
                active: _filter == 'NO',
                color: AppColors.success,
                onTap: () => _setFilter('NO'),
              ),
              const SizedBox(width: 12),
              _RadioBtn(
                label: 'Yopiq',
                icon: Icons.check_circle_outline,
                active: _filter == 'YES',
                color: AppColors.textMuted,
                onTap: () => _setFilter('YES'),
              ),
              const Spacer(),
              if (!_loading)
                Text('${_orders.length} ta',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _error != null
                    ? _buildError()
                    : _orders.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 24),
                              itemCount: _orders.length,
                              itemBuilder: (_, i) =>
                                  _OrderCard(order: _orders[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Qayta urinish'),
            ),
          ]),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              _filter == 'NO'
                  ? Icons.receipt_long_outlined
                  : Icons.check_circle_outline,
              size: 56,
              color: AppColors.border),
          const SizedBox(height: 12),
          Text(
              _filter == 'NO'
                  ? 'Ochiq buyurtma yo\'q'
                  : 'Yopiq buyurtma yo\'q',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 15)),
        ]),
      );
}

// ── Radio tugma ───────────────────────────────────────────────────────────────

class _RadioBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _RadioBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(20) : AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: active ? color : AppColors.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              active ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: active ? color : AppColors.textMuted),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                  color: active ? color : AppColors.textMuted)),
        ]),
      ),
    );
  }
}

// ── Buyurtma kartochkasi ──────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final _Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isOpen = order.paid == 'NO';
    final statusColor = isOpen ? AppColors.primary : AppColors.success;
    final statusBg = isOpen ? AppColors.primaryLight : AppColors.successLight;
    final statusLabel = isOpen ? 'Ochiq' : 'To\'langan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Stol icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: isOpen
                  ? AppColors.primaryLight
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
                order.placeName.isNotEmpty
                    ? Icons.table_restaurant
                    : Icons.delivery_dining,
                color: isOpen ? AppColors.primary : AppColors.textMuted,
                size: 22),
          ),
          const SizedBox(width: 12),

          // Ma'lumot
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                      order.placeName.isNotEmpty
                          ? order.placeName
                          : 'Yetkazib berish',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(
                    '${order.itemsCount} ta taom  •  '
                    '${_formatDate(order.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),

          // Summa
          Text(
              '${order.total.toStringAsFixed(0)} so\'m',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isOpen ? AppColors.primary : AppColors.textDark)),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours < 24) return '${diff.inHours} soat oldin';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ── Order model ───────────────────────────────────────────────────────────────

class _Order {
  final int id;
  final int? placeId;
  final String placeName;
  final DateTime createdAt;
  final String paid;
  final double total;
  final int itemsCount;

  _Order({
    required this.id,
    this.placeId,
    required this.placeName,
    required this.createdAt,
    required this.paid,
    required this.total,
    required this.itemsCount,
  });

  factory _Order.fromJson(Map<String, dynamic> j) => _Order(
        id: j['id'] as int,
        placeId: j['place_id'] as int?,
        placeName: (j['place_name'] ?? '').toString(),
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        paid: (j['paid'] ?? 'NO').toString(),
        total: (j['total'] ?? 0).toDouble(),
        itemsCount: (j['items_count'] ?? 0) as int,
      );
}