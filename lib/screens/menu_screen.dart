import 'dart:async';
import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/api.dart';
import '../models/place.dart';
import '../models/food.dart';
import '../models/food_category.dart';
import '../models/order_item.dart';
import 'receipt_dialog.dart';

class MenuScreen extends StatefulWidget {
  final Place place;
  const MenuScreen({super.key, required this.place});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with WidgetsBindingObserver {
  List<FoodCategory> _categories   = [];
  List<Food>         _foods        = [];
  List<OrderItem>    _order        = [];
  int?               _selectedCat;
  int?               _existingOrderId;

  bool    _loading    = true;
  bool    _refreshing = false;
  bool    _saving     = false;
  String? _error;
  String  _search     = '';

  Timer?  _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // Har 30 soniyada mavjud buyurtma itemlarini yangilaydi
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _existingOrderId != null) _refreshOrderItems();
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
    if (state == AppLifecycleState.resumed && mounted) {
      if (_existingOrderId != null) _refreshOrderItems();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final catData  = await Api.get('foods/categories') as List;
      final foodData = await Api.get('foods') as List;

      final cats  = catData
          .map((j) => FoodCategory.fromJson(j as Map<String, dynamic>))
          .toList();
      final foods = foodData
          .map((j) => Food.fromJson(j as Map<String, dynamic>))
          .toList();

      if (widget.place.activeOrderId != null) {
        _existingOrderId = widget.place.activeOrderId;
        await _fetchOrderItems();
      }

      setState(() {
        _categories = cats;
        _foods      = foods;
        _loading    = false;
      });
    } on ApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    }
  }

  // Faqat mavjud buyurtma itemlarini yangilaydi (foods ni qayta yuklamaydi)
  Future<void> _refreshOrderItems() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _fetchOrderItems();
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _fetchOrderItems() async {
    if (_existingOrderId == null) return;
    try {
      final orderData = await Api.get('orders/$_existingOrderId');
      final items = (orderData['items'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _order = items.map((i) {
            final m = i as Map<String, dynamic>;
            return OrderItem(
              foodId:   m['food_id'] as int,
              foodName: (m['food_name'] ?? '').toString(),
              price:    (m['selling_price'] ?? 0).toDouble(),
              quantity: (m['quantity'] as num).toInt(),
            );
          }).toList();
        });
      }
    } catch (_) {}
  }

  List<Food> get _filtered {
    var list = _foods;
    if (_selectedCat != null) {
      list = list.where((f) => f.categoryId == _selectedCat).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((f) => f.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int _qty(Food food) {
    return _order
        .where((i) => i.foodId == food.id)
        .firstOrNull
        ?.quantity ?? 0;
  }

  void _increment(Food food) {
    setState(() {
      final idx = _order.indexWhere((i) => i.foodId == food.id);
      if (idx >= 0) {
        _order[idx].quantity++;
      } else {
        _order.add(OrderItem(
          foodId:   food.id,
          foodName: food.name,
          price:    food.sellingPrice,
          quantity: 1,
        ));
      }
    });
  }

  void _decrement(Food food) {
    setState(() {
      final idx = _order.indexWhere((i) => i.foodId == food.id);
      if (idx >= 0) {
        if (_order[idx].quantity <= 1) {
          _order.removeAt(idx);
        } else {
          _order[idx].quantity--;
        }
      }
    });
  }

  double get _total  => _order.fold(0.0, (s, i) => s + i.subtotal);
  int    get _total2 => _order.fold(0, (s, i) => s + i.quantity);

  Future<void> _saveOrder() async {
    if (_order.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hech bir taom tanlanmagan')));
      return;
    }
    final ok = await _confirm();
    if (!ok) return;

    setState(() => _saving = true);
    try {
      final items = _order.map((i) => i.toJson()).toList();
      if (_existingOrderId != null) {
        await Api.put('orders/$_existingOrderId/items', {'items': items});
      } else {
        final res = await Api.post('orders', {
          'placeId': widget.place.id,
          'items':   items,
        });
        _existingOrderId = res['id'] as int?;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Buyurtma saqlandi!'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Buyurtmani saqlash',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stol: ${widget.place.name}',
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                ..._order.map((i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('${i.foodName} × ${i.quantity}',
                                  style: const TextStyle(fontSize: 13))),
                          Text(
                              '${i.subtotal.toStringAsFixed(0)} so\'m',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jami:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_total.toStringAsFixed(0)} so\'m',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Bekor',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0),
                child: const Text('Saqlash',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showReceipt() {
    if (_existingOrderId == null && _order.isEmpty) return;
    ReceiptDialog.show(
      context,
      placeName: widget.place.name,
      orderId:   _existingOrderId,
      items:     List.from(_order),
      total:     _total,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textDark),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.place.name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textDark)),
            if (widget.place.zone.isNotEmpty)
              Text(widget.place.zone,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          // Auto-refresh indikatori
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
              ),
            ),
          // Shot chiqarish
          if (_existingOrderId != null || _order.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.receipt_outlined,
                  color: AppColors.textDark, size: 22),
              tooltip: 'Shot ko\'rish',
              onPressed: _showReceipt,
            ),
          if (_existingOrderId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('#$_existingOrderId',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Taom qidirish...',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: AppColors.textMuted, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 1.5)),
                      ),
                    ),
                  ),
                  if (_categories.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        children: [
                          _catChip('Barchasi', null),
                          ..._categories
                              .map((c) => _catChip(c.name, c.id)),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('Taomlar topilmadi',
                                style: TextStyle(
                                    color: AppColors.textMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 100),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) => _FoodRow(
                              food:     _filtered[i],
                              qty:      _qty(_filtered[i]),
                              onAdd:    () => _increment(_filtered[i]),
                              onRemove: () => _decrement(_filtered[i]),
                            ),
                          ),
                  ),
                ]),
      bottomNavigationBar: _total2 == 0
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  // Shot tugmasi
                  Container(
                    height: 48,
                    margin: const EdgeInsets.only(right: 10),
                    child: OutlinedButton.icon(
                      onPressed: _showReceipt,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.receipt_outlined, size: 18),
                      label: const Text('Shot',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_total2 ta taom',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted)),
                        Text('${_total.toStringAsFixed(0)} so\'m',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark)),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 20),
                      label: Text(
                          _saving ? 'Saqlanmoqda...' : 'Saqlash',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _catChip(String label, int? id) {
    final sel = _selectedCat == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCat = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: sel ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  color: sel ? Colors.white : AppColors.textMuted)),
        ),
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
}

// ── Taom qatori ───────────────────────────────────────────────────────────────

class _FoodRow extends StatelessWidget {
  final Food food;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _FoodRow({
    required this.food,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inOrder = qty > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: inOrder ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: inOrder ? AppColors.primary : AppColors.border,
            width: inOrder ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: inOrder
                  ? AppColors.primary.withAlpha(20)
                  : AppColors.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                food.name.isNotEmpty ? food.name[0].toUpperCase() : '?',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: inOrder
                        ? AppColors.primary
                        : AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textDark),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${food.sellingPrice.toStringAsFixed(0)} so\'m',
                    style: TextStyle(
                        fontSize: 12,
                        color: inOrder
                            ? AppColors.primary
                            : AppColors.textMuted,
                        fontWeight: inOrder
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ],
            ),
          ),
          if (qty > 0) ...[
            _QtyBtn(icon: Icons.remove, onTap: onRemove, color: AppColors.danger),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('$qty',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textDark)),
            ),
          ],
          _QtyBtn(icon: Icons.add, onTap: onAdd, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );
}