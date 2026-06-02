import 'dart:async';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import '../models/order_item.dart';
import 'receipt_dialog.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  static final instanceKey = GlobalKey<_MyOrdersScreenState>();
  static void refreshIfMounted() => instanceKey.currentState?._silentRefresh();

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {

  List<_Order> _orders      = [];
  bool         _loading     = true;
  bool         _refreshing  = false;
  String?      _error;
  String       _filter      = 'NO';

  String       _userRole    = '';
  bool         _anyoneClose = false;

  Timer?       _timer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted && _filter == 'NO') _silentRefresh();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _silentRefresh();
  }

  Future<void> _init() async {
    _userRole = (await AppConfig.getUserRole()) ?? '';
    try {
      final res = await Api.get('settings/value?key=order_anyone_close');
      _anyoneClose = (res['value'] ?? '') == '1';
    } catch (_) {}
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    await _fetch();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _silentRefresh() async {
    if (_refreshing || !mounted) return;
    setState(() => _refreshing = true);
    await _fetch();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _fetch() async {
    try {
      final data =
          await Api.get('orders/mine?paid=$_filter&pageSize=50') as List;
      if (!mounted) return;
      setState(() {
        _orders = data
            .map((j) => _Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _error  = null;
      });
    } on ApiException catch (e) {
      if (mounted && _orders.isEmpty) {
        setState(() => _error = e.message);
      }
    }
  }

  void _setFilter(String v) {
    if (_filter == v) return;
    setState(() => _filter = v);
    _load();
  }

  bool get _canPay =>
      _userRole == 'admin' || _userRole == 'kassir' || _anyoneClose;

  Future<void> _showReceipt(_Order order) async {
    // Buyurtma itemlarini API dan yuklaymiz
    List<OrderItem> items = [];
    try {
      final data = await Api.get('orders/${order.id}');
      final raw  = (data['items'] as List?) ?? [];
      items = raw.map((j) {
        final m = j as Map<String, dynamic>;
        return OrderItem(
          foodId:   m['food_id'] as int,
          foodName: (m['food_name'] ?? '').toString(),
          price:    (m['selling_price'] ?? 0).toDouble(),
          quantity: (m['quantity'] as num).toInt(),
        );
      }).toList();
    } catch (_) {}

    if (!mounted) return;
    ReceiptDialog.show(
      context,
      placeName: order.placeName,
      orderId:   order.id,
      items:     items,
      total:     order.total,
    );
  }

  Future<void> _payOrder(_Order order) async {
    // To'lov turlarini olish
    List<_PayMethod> methods = [];
    try {
      final data = await Api.get('payments') as List;
      methods = data
          .map((j) => _PayMethod(
                id: j['id'] as int,
                name: (j['name'] ?? '').toString(),
              ))
          .toList();
    } catch (_) {}

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _PayDialog(order: order, methods: methods),
    );
    if (result == null) return;

    try {
      final payments = result['payments'] as List<Map<String, dynamic>>;
      await Api.put('orders/${order.id}/pay',
          {'payments': payments.isEmpty ? null : payments});
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
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
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
              if (!_loading)
                Text('${_orders.length} ta',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _error != null && _orders.isEmpty
                    ? _buildError()
                    : _orders.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppColors.primary,
                            onRefresh: _load,
                            child: _buildGroupedList(),
                          ),
          ),
        ],
      ),
    );
  }

  // Buyurtmalarni sana bo'yicha guruhlash
  Widget _buildGroupedList() {
    // { 'dateKey': [orders] }
    final Map<String, List<_Order>> groups = {};
    for (final o in _orders) {
      final key = _dateKey(o.createdAt);
      groups.putIfAbsent(key, () => []).add(o);
    }

    // Kalitlarni tartiblab olamiz (yangi birinchi)
    final keys = groups.keys.toList();

    // Umumiy item soni: har bir guruh uchun 1 header + N karta
    final totalItems = keys.fold<int>(
        0, (sum, k) => sum + 1 + (groups[k]?.length ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: totalItems,
      itemBuilder: (_, idx) {
        // idx → qaysi guruh, qaysi karta
        int cursor = 0;
        for (final key in keys) {
          final list = groups[key]!;
          if (idx == cursor) {
            // Sana sarlavhasi
            return _DateHeader(label: key);
          }
          cursor++;
          if (idx < cursor + list.length) {
            final order = list[idx - cursor];
            return _OrderCard(
              order: order,
              canPay: _canPay && order.paid == 'NO',
              onPay: () => _payOrder(order),
              onReceipt: () => _showReceipt(order),
            );
          }
          cursor += list.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  // Sana kalitini hosil qiladi: "Bugun", "Kecha", "02.06.2026"
  String _dateKey(DateTime dt) {
    final local = dt.toLocal();
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(local.year, local.month, local.day);
    final diff  = today.difference(d).inDays;
    if (diff == 0) return 'Bugun';
    if (diff == 1) return 'Kecha';
    return '${d.day.toString().padLeft(2,'0')}.'
        '${d.month.toString().padLeft(2,'0')}.'
        '${d.year}';
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

// ── To'lov dialogi ────────────────────────────────────────────────────────────

class _PayDialog extends StatefulWidget {
  final _Order order;
  final List<_PayMethod> methods;

  const _PayDialog({required this.order, required this.methods});

  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  int? _selectedMethodId;
  final _amountCtrl = TextEditingController();
  bool _splitPay = false;

  @override
  void initState() {
    super.initState();
    if (widget.methods.isNotEmpty) {
      _selectedMethodId = widget.methods.first.id;
    }
    _amountCtrl.text = widget.order.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('To\'lov',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.order.placeName.isNotEmpty)
              Text('Stol: ${widget.order.placeName}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jami:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${widget.order.total.toStringAsFixed(0)} so\'m',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('To\'lov turi',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted)),
            const SizedBox(height: 8),
            if (widget.methods.isEmpty)
              const Text('To\'lov turlari topilmadi',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.methods.map((m) {
                  final sel = _selectedMethodId == m.id;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedMethodId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primary
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel
                                ? AppColors.primary
                                : AppColors.border),
                      ),
                      child: Text(m.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : AppColors.textDark)),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton.icon(
          onPressed: () {
            final payments = _selectedMethodId != null
                ? [
                    {
                      'paymentId': _selectedMethodId!,
                      'amount': widget.order.total,
                    }
                  ]
                : <Map<String, dynamic>>[];
            Navigator.pop(context, {'payments': payments});
          },
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
    );
  }
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withAlpha(20) : AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: active ? color : AppColors.border, width: 1.5),
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
  final VoidCallback onReceipt;

  const _OrderCard({
    required this.order,
    required this.canPay,
    required this.onPay,
    required this.onReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = order.paid == 'NO';
    final sColor = isOpen ? AppColors.primary : AppColors.success;
    final sBg    = isOpen ? AppColors.primaryLight : AppColors.successLight;
    final sLabel = isOpen ? 'Ochiq' : 'To\'langan';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
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
                  color: isOpen ? AppColors.primary : AppColors.textMuted,
                  size: 22),
            ),
            const SizedBox(width: 12),
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
                      '${order.itemsCount} ta taom  •  ${_fmt(order.createdAt)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text('${order.total.toStringAsFixed(0)} so\'m',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOpen
                        ? AppColors.primary
                        : AppColors.textDark)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            // Shot tugmasi — doim ko'rinadi
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReceipt,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textDark,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.receipt_outlined, size: 15),
                label: const Text('Shot',
                    style: TextStyle(fontSize: 13)),
              ),
            ),
            if (canPay) ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 15),
                  label: const Text('Yopish',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ]),
        ]),
      ),
    );
  }

  // Faqat soat:daqiqa ko'rsatadi (sana header da ko'rsatiladi)
  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2,'0')}:'
        '${local.minute.toString().padLeft(2,'0')}';
  }
}

// ── Yordamchi modellar ────────────────────────────────────────────────────────

class _PayMethod {
  final int id;
  final String name;
  _PayMethod({required this.id, required this.name});
}

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
// ── Sana sarlavhasi ───────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.textDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ]),
    );
  }
}
