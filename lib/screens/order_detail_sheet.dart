import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/api.dart';

class OrderDetailSheet extends StatefulWidget {
  final int orderId;
  const OrderDetailSheet({super.key, required this.orderId});

  static Future<void> show(BuildContext context, {required int orderId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailSheet(orderId: orderId),
    );
  }

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  Map<String, dynamic>? _order;
  List<dynamic>         _items    = [];
  List<dynamic>         _payments = [];
  bool                  _loading  = true;
  bool                  _printing = false;
  String?               _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.get('orders/${widget.orderId}');
      setState(() {
        _order    = data['order'] as Map<String, dynamic>?;
        _items    = (data['items']    as List?) ?? [];
        _payments = (data['payments'] as List?) ?? [];
        _loading  = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await Api.post('orders/${widget.orderId}/print-request', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chop etish so\'rovi yuborildi! Kassada chek chiqadi.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = MediaQuery.of(context).size.height;
    return Container(
      height: sh * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(children: [
              const Icon(Icons.receipt_long,
                  color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text('Buyurtma #${widget.orderId}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textDark)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close,
                    color: AppColors.textMuted, size: 22),
              ),
            ]),
          ),
          Container(height: 1, color: AppColors.border),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.textMuted)))
                    : _buildContent(),
          ),

          // Pastki Pechat tugmasi
          if (!_loading && _error == null)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _printing ? null : _print,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.textMuted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  icon: _printing
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.print_outlined, size: 22),
                  label: Text(
                      _printing ? 'Yuborilmoqda...' : 'Kassadan chek chiqarish',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_order == null) return const SizedBox();

    final o           = _order!;
    final placeName   = (o['place_name'] ?? '').toString();
    final userName    = (o['user_name']  ?? '').toString();
    final paid        = (o['paid']       ?? 'NO').toString();
    final total       = (o['total']      ?? 0.0).toDouble();
    final svcFee      = (o['custom_svc_fee']  ?? 0.0).toDouble();
    final discAmt     = (o['discount_amount'] ?? 0.0).toDouble();
    final createdAt   = DateTime.tryParse(
            o['created_at']?.toString() ?? '')?.toLocal();

    final double itemsSum = _items.fold(
        0.0, (s, i) => s + ((i['subtotal'] ?? 0.0) as num).toDouble());

    final String statusLabel;
    final Color  statusColor;
    if (paid == 'YES') {
      statusLabel = 'To\'langan'; statusColor = AppColors.success;
    } else if (paid == 'CANCELLED') {
      statusLabel = 'Bekor qilingan'; statusColor = AppColors.danger;
    } else {
      statusLabel = 'Ochilgan'; statusColor = AppColors.primary;
    }

    final double svcPct = (svcFee > 0 && itemsSum > 0)
        ? (svcFee / (total - svcFee) * 100)
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stol + sana satri
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (placeName.isNotEmpty)
                    Text(placeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark)),
                  if (createdAt != null)
                    Text(_fmtDate(createdAt),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withAlpha(80)),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: statusColor)),
            ),
          ]),

          const SizedBox(height: 14),
          _divider(),

          // Jadval sarlavhasi
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Expanded(
                  flex: 5,
                  child: Text('Mahsulotlar',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted))),
              const SizedBox(
                  width: 36,
                  child: Text('Miq.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted))),
              const SizedBox(
                  width: 80,
                  child: Text('Narx',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted))),
              const SizedBox(
                  width: 80,
                  child: Text('Jami',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted))),
            ]),
          ),
          _divider(),

          // Taomlar
          ..._items.map((item) {
            final name  = (item['food_name']     ?? '').toString();
            final qty   = (item['quantity']       ?? 0) as int;
            final price = (item['selling_price']  ?? 0.0).toDouble();
            final sub   = (item['subtotal']       ?? 0.0).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(
                  flex: 5,
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark)),
                ),
                SizedBox(
                  width: 36,
                  child: Text('$qty',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textDark))),
                SizedBox(
                  width: 80,
                  child: Text(_fmt(price),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted))),
                SizedBox(
                  width: 80,
                  child: Text(_fmt(sub),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark))),
              ]),
            );
          }),

          _divider(),

          // Oraliq summa
          _summaryRow('Jami:', itemsSum, bold: false),

          // Chegirma
          if (discAmt > 0)
            _summaryRow('Chegirma:', -discAmt,
                bold: false, color: AppColors.success),

          // Xizmat haqi
          if (svcFee > 0)
            _summaryRow(
                'Xizmat haqqi${svcPct > 0 ? ' ${svcPct.toStringAsFixed(1)}%' : ''}:',
                svcFee,
                bold: false,
                color: AppColors.textMuted),

          _divider(),

          // Grand total
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JAMI:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark)),
                Text(_fmt(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppColors.primary)),
              ],
            ),
          ),

          // To'lov turlari
          if (_payments.isNotEmpty) ...[
            _divider(),
            ..._payments.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.payment,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text((p['payment_name'] ?? '').toString(),
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                      ]),
                      Text(_fmt((p['amount'] ?? 0.0).toDouble()),
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],

          _divider(),

          // Qo'shimcha ma'lumotlar
          _infoRow('Ofitsiant', userName.isNotEmpty ? userName : '—'),
          _infoRow('Joy', placeName.isNotEmpty ? placeName : '—'),
          if (createdAt != null)
            _infoRow('Yaratilgan', _fmtDate(createdAt)),
          _infoRow('Holat', statusLabel, valueColor: statusColor),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(color: AppColors.border, height: 1),
      );

  Widget _summaryRow(String label, double amount,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color ?? AppColors.textMuted)),
          Text(_fmt(amount),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                  color: color ?? AppColors.textDark)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textDark)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) {
      return '${v.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} so\'m';
    }
    return '${v.toStringAsFixed(0)} so\'m';
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2,'0')}.'
        '${dt.month.toString().padLeft(2,'0')}.'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }
}