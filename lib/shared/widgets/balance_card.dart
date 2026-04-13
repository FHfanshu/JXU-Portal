import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'ship_card.dart';

/// Campus Card Balance display widget.
class BalanceCard extends StatefulWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.yesterdaySpent,
    this.onTap,
    this.onPaymentTap,
    this.onRechargeTap,
    this.onBillTap,
  });

  final double? balance;
  final double? yesterdaySpent;
  final VoidCallback? onTap;
  final VoidCallback? onPaymentTap;
  final VoidCallback? onRechargeTap;
  final VoidCallback? onBillTap;

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _obscured = false;

  String _formatBalance(double? value) {
    if (value == null) return '--';
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ShipCard(
      onTap: widget.onTap,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.credit_card, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '校园卡',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _obscured = !_obscured),
                child: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Balance
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥ ',
                style: TextStyle(
                  fontSize: 18,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _obscured ? '****' : _formatBalance(widget.balance),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),

          // Yesterday spent
          if (widget.yesterdaySpent != null) ...[
            const SizedBox(height: 4),
            Text(
              '昨日消费 ¥${widget.yesterdaySpent!.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              _ActionChip(
                icon: Icons.qr_code_2,
                label: '付款码',
                onTap: widget.onPaymentTap,
              ),
              const SizedBox(width: 12),
              _ActionChip(
                icon: Icons.add_circle_outline,
                label: '充值',
                onTap: widget.onRechargeTap,
              ),
              const SizedBox(width: 12),
              _ActionChip(
                icon: Icons.receipt_long_outlined,
                label: '账单',
                onTap: widget.onBillTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
