import 'dart:async';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/config.dart';
import '../core/api.dart';
import 'order_detail_sheet.dart';

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
  String       _filter      = 'NO'; // 'NO' | 'YES'
  DateTime     _selectedDate = DateTime.now();

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
      if (mounted) _silentRefresh();
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

  String get _dateParam {
    final d = _selectedDate;
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
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
      final paid = _filter == 'ALL' ? '' : '&paid=$_filter';
      final data = await Api.get(
          'orders/mine?date=$_dateParam$paid&pageSize=100') as List;
      if (!mounted) return;
      setState(() {
        _orders = data
            .map((j) => _Order.fromJson(j as Map<String, dynamic>))
            .toList();
        _error  = null;
      });
    } on ApiException catch (e) {
      if (mounted && _orders.isEmpty) setState(() => _error = e.message);
    }
  }

  void _setFilter(String v) {
    if (_filter == v) return;
    setState(() => _filter = v);
    _load();
  }

  void _prevDay() {
    setState(() => _selectedDate =
        _selectedDate.subtract(const Duration(days: 1)));
    _load();
  }

  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_selectedDate.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(() => _selectedDate =
          _selectedDate.add(const Duration(days: 1)));
      _load();
    }
  }

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate:   DateTime(now.year - 1),
      lastDate:    now,
      locale: const Locale('uz'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary:   AppColors.primary,
            onPrimary: Colors.white,
            surface:   Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  bool get _isToday {
    final n = DateTime.now();
    return _selectedDate.year  == n.year &&
           _selectedDate.month == n.month &&
           _selectedDate.day   == n.day;
  }

  String get _dateLabel {
    if (_isToday) return 'Bugun';
    final n = DateTime.now().subtract(const Duration(days: 1));
    if (_selectedDate.year  == n.year &&
        _selectedDate.month == n.month &&
        _selectedDate.day   == n.day)   return 'Kecha';
    final d = _selectedDate;
    return '${d.day.toString().padLeft(2,'0')}.'
        '${d.month.toString().padLeft(2,'0')}.'
        '${d.year}';
  }

  bool get _canPay =>
      _userRole == 'admin' || _userRole == 'kassir' || _anyoneClose;

  // ── Receipt ───────────────────────────────────────────────────────────────

  Future<void> _showReceipt(_Order order) async {
    if (!mounted) return;
    await OrderDetailSheet.show(context, orderId: order.id);
    // Detail sheet to'landi deb refresh qilamiz (yopilgan bo'lishi mumkin)
    _silentRefresh();
  }

  // ── Pay ───────────────────────────────────────────────────────────────────

  Future<void> _payOrder(_Order order) async {
    List<_PayMethod> methods = [];
    try {
      final data = await Api.get('payments') as List;
      methods = data
          .map((j) => _PayMethod(id: j['id'] as int,
                                  name: (j['name'] ?? '').toString()))
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
          // ── Sana tanlash ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(children: [
              // Oldingi kun
              _NavBtn(
                icon: Icons.chevron_left,
                onTap: _prevDay,
              ),
              const SizedBox(width: 4),

              // Sana - taqvim ochadi
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isToday
                          ? AppColors.primaryLight
                          : AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _isToday
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_month,
                            size: 16,
                            color: _isToday
                                ? AppColors.primary
                                : AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _isToday
                                ? AppColors.primary
                                : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down,
                            size: 18,
                            color: _isToday
                                ? AppColors.primary
                                : AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 4),
              // Keyingi kun (bugundan o'tib bo'lmaydi)
              _NavBtn(
                icon: Icons.chevron_right,
                onTap: _isToday ? null : _nextDay,
              ),
            ]),
          ),

          // ── Status filter ────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              _FilterChip(
                label: 'Barchasi',
                active: _filter == 'ALL',
                color: AppColors.textDark,
                onTap: () => _setFilter('ALL'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Ochiq',
                active: _filter == 'NO',
                color: AppColors.primary,
                onTap: () => _setFilter('NO'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
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

          Container(height: 1, color: AppColors.border),

          // ── Ro'yxat ──────────────────────────────────────────────────
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
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 24),
                              itemCount: _orders.length,
                              itemBuilder: (_, i) => _OrderCard(
                                order: _orders[i],
                                canPay: _canPay && _orders[i].paid == 'NO',
                                onPay: () => _payOrder(_orders[i]),
                                onReceipt: () => _showReceipt(_orders[i]),
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
              _filter == 'YES'
                  ? Icons.check_circle_outline
                  : Icons.receipt_long_outlined,
              size: 56,
              color: AppColors.border),
          const SizedBox(height: 12),
          Text(
              '$_dateLabel kuni buyurtma yo\'q',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 15)),
        ]),
      );
}

// ── Kichik navigatsiya tugmasi ────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: onTap == null ? AppColors.bg : AppColors.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon,
              size: 22,
              color: onTap == null
                  ? AppColors.border
                  : AppColors.textDark),
        ),
      );
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? color.withAlpha(20) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? color : AppColors.border, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                  color: active ? color : AppColors.textMuted)),
        ),
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

  @override
  void initState() {
    super.initState();
    if (widget.methods.isNotEmpty) {
      _selectedMethodId = widget.methods.first.id;
    }
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
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: widget.methods.map((m) {
                  final sel = _selectedMethodId == m.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethodId = m.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(m.name,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textDark)),
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
                ? [{'paymentId': _selectedMethodId!, 'amount': widget.order.total}]
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
    final timeStr = _time(order.createdAt);

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
                      '${order.itemsCount} ta taom  •  $timeStr',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text('${order.total.toStringAsFixed(0)} so\'m',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOpen ? AppColors.primary : AppColors.textDark)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
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
                icon: const Icon(Icons.info_outline, size: 15),
                label: const Text('Batafsil', style: TextStyle(fontSize: 13)),
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

  String _time(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2,'0')}:'
        '${local.minute.toString().padLeft(2,'0')}';
  }
}

// ── Modellar ──────────────────────────────────────────────────────────────────

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