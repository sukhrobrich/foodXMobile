import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../models/order_item.dart';

class ReceiptDialog extends StatelessWidget {
  final String placeName;
  final int?   orderId;
  final List<OrderItem> items;
  final double total;

  const ReceiptDialog({
    super.key,
    required this.placeName,
    required this.orderId,
    required this.items,
    required this.total,
  });

  static void show(
    BuildContext context, {
    required String placeName,
    int? orderId,
    required List<OrderItem> items,
    required double total,
  }) {
    showDialog(
      context: context,
      builder: (_) => ReceiptDialog(
        placeName: placeName,
        orderId:   orderId,
        items:     items,
        total:     total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.day.toString().padLeft(2,'0')}.${now.month.toString().padLeft(2,'0')}.${now.year}  '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                const SizedBox(height: 4),
                const Text('SHOT',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 2)),
                if (orderId != null)
                  Text('#$orderId',
                      style: TextStyle(
                          color: Colors.white.withAlpha(200), fontSize: 12)),
              ]),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(placeName.isNotEmpty ? placeName : 'Stol',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textDark)),
                      Text(timeStr,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                  ...items.map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(
                            child: Text(i.foodName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textDark)),
                          ),
                          Text('× ${i.quantity}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted)),
                          const SizedBox(width: 12),
                          Text(
                              '${i.subtotal.toStringAsFixed(0)} so\'m',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                        ]),
                      )),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('JAMI',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textDark)),
                      Text('${total.toStringAsFixed(0)} so\'m',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.textMuted),
                  child: const Text('Yopish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}