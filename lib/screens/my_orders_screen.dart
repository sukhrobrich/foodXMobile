import 'dart:async';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  // TablesScreen bu metodni chaqiradi (tab o'zgarganda refresh)
  static final _key = GlobalKey<_MyOrdersScreenState>();
  static void refreshIfMounted() => _key.currentState?._load();

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with AutomaticKeepAliveClientMixin {
  List<_Order> _orders       = [];
  bool         _loading      = true;
  String?      _error;
  String       _filter       = 'NO'; // 'NO'=ochiq, 'YES'=yopiq

  String       _userRole     = '';
  bool         _anyoneClose  = false; // order_anyone_close setting

  Timer?       _refreshTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _init();
    // Har 30 soniyada avtomatik yangilash
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) { if (mounted && _filter == 'NO') _load(); },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _userRole = (await AppConfig.getUserRole()) ?? '';
    // Sozlamani API dan olish
    try {
      final res = await Api.get('settings/value?key=order_anyone_close');
      _anyoneClose = (res['value'] ?? '') == '1';
    } catch (_) {}
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data =
          await Api.get('orders/mine?paid=$_filter&pageSize=50') as List;
      if (!mounted) return;
      setState(() {
        _orders  = data
            .map((j) => _Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    }
  }

  void _setFilter(String v) {
    if (_filter == v) return;
    setState(() => _filter = v);
    _load();
  }

  bool get _canPay =>
      _userRole == 'admin' ||
      _userRole == 'kassir' ||
      _anyoneClose;

  // Buyurtmani yopish (to'lash)
  Future<void> _payOrder(_Order order) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Buyurtmani yopish',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (order.placeName.isNotEmpty)
              Text('Stol: ${order.placeName}',
                  style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jami:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    '${order.total.toStringAsFixed(0)} so\'m',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                'To\'lov usuli kassir tomonidan belgilanadi.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('To\'landi',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await Api.put('orders/${order.id}/pay', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Buyurtma yopildi!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: AppColors.textMuted, size: 22),
            onPressed: _load,
            tooltip: 'Yangilash',
          ),
        ],
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
                active: _filter == 'NO',
                color: AppColors.primary,
                onTap: () => _setFilter('NO'),
              ),
              const SizedBox(width: 10),
              _RadioBtn(
                label: 'Yopiq',
                active: _filter == 'YES',
                color: AppColors.success,
                onTap: () => _setFilter('YES'),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textMuted))
                    : Text('${_orders.length} ta',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
              ),
            ]),
          ),

          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: _error != null
                ? _buildError()
                : _orders.isEmpty && !_loading
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) => _OrderCard(
                            order: _orders[i],
                            canPay: _canPay && _orders[i].paid == 'NO',
                            onPay: () => _payOrder(_orders[i]),
                          ),
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
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _RadioBtn({
    required this.label,
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(20) : AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          border:
              Border.all(color: active ? color : AppColors.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
              active
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
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
  final bool canPay;
  final VoidCallback onPay;

  const _OrderCard({
    required this.order,
    required this.canPay,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen   = order.paid == 'NO';
    final sColor   = isOpen ? AppColors.primary : AppColors.success;
    final sBg      = isOpen ? AppColors.primaryLight : AppColors.successLight;
    final sLabel   = isOpen ? 'Ochiq' : 'To\'langan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              // Icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.primaryLight : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                    order.placeName.isNotEmpty
                        ? Icons.table_restaurant
                        : Icons.delivery_dining,
                    color: isOpen
                        ? AppColors.primary
                        : AppColors.textMuted,
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
                          color: sBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(sLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sColor)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        '${order.itemsCount} ta taom  •  '
                        '${_fmt(order.createdAt)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),

              // Summa
              Text('${order.total.toStringAsFixed(0)} so\'m',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isOpen
                          ? AppColors.primary
                          : AppColors.textDark)),
            ]),

            // To'lash tugmasi (ochiq + ruxsat bo'lsa)
            if (canPay) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: const Text('Buyurtmani yopish',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    // toLocal() — server UTC vaqtini lokal vaqtga o'tkazish
    final local = dt.toLocal();
    final now   = DateTime.now();
    final diff  = now.difference(local);
    if (diff.inMinutes < 1)  return 'Hozir';
    if (diff.inMinutes < 60) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inHours   < 24) return '${diff.inHours} soat oldin';
    return '${local.day.toString().padLeft(2,'0')}.'
        '${local.month.toString().padLeft(2,'0')} '
        '${local.hour.toString().padLeft(2,'0')}:'
        '${local.minute.toString().padLeft(2,'0')}';
  }
}

// ── Order model ───────────────────────────────────────────────────────────────

class _Order {
  final int      id;
  final int?     placeId;
  final String   placeName;
  final DateTime createdAt;
  final String   paid;
  final double   total;
  final int      itemsCount;

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
        id:         j['id'] as int,
        placeId:    j['place_id'] as int?,
        placeName:  (j['place_name'] ?? '').toString(),
        createdAt:  DateTime.tryParse(
                        j['created_at']?.toString() ?? '')
                    ?.toLocal() ??
                    DateTime.now(),
        paid:       (j['paid'] ?? 'NO').toString(),
        total:      (j['total'] ?? 0).toDouble(),
        itemsCount: (j['items_count'] ?? 0) as int,
      );
}