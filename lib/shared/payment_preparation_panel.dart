import 'package:flutter/material.dart';
import 'cash_collection_panel.dart';

/// Cash collection and review. Cash is recorded only after staff confirmation.
/// A future payment flow must use an authorized backend transaction with
/// idempotency, receipt generation, and settlement reconciliation.
class PaymentPreparationPanel extends StatelessWidget {
  const PaymentPreparationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Card(
          margin: EdgeInsets.all(12),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.point_of_sale_outlined),
                  SizedBox(width: 8),
                  Expanded(child: Text('Checkout preparation',
                      style: TextStyle(fontWeight: FontWeight.bold))),
                ]),
                SizedBox(height: 8),
                Text('Record cash physically received. Card and credit are not enabled.'),
                SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Chip(label: Text('Cash — staff recorded')),
                  Chip(label: Text('Card — not connected')),
                  Chip(label: Text('Credit — not connected')),
                ]),
              ],
            ),
          ),
        ),
        const Expanded(child: CashCollectionPanel()),
      ],
    );
  }
}
