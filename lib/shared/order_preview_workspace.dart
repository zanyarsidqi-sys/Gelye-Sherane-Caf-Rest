import 'package:flutter/material.dart';
import '../services/local_order_preview.dart';
import '../services/local_menu_preview.dart';
import 'live_records_panel.dart';
import 'live_kitchen_panel.dart';
import 'live_order_create_panel.dart';

/// Interactive prototype only: all changes disappear when the app restarts.
class OrderPreviewWorkspace extends StatefulWidget {
  const OrderPreviewWorkspace({super.key, required this.kind});
  final String kind; // table, motel, kitchen
  @override
  State<OrderPreviewWorkspace> createState() => _OrderPreviewWorkspaceState();
}

class _OrderPreviewWorkspaceState extends State<OrderPreviewWorkspace> {
  final _destination = TextEditingController();
  final _barcode = TextEditingController();
  final _menu = LocalMenuPreview.instance;
  final _quantity = TextEditingController(text: '1');
  bool _tourism = false;
  bool _showLive = true;
  bool _createLive = false;
  String _statusFilter = "all";
  String _orderSearch = "";
  final _store = LocalOrderPreview.instance;
  @override
  void initState() {
    super.initState();
    _store.addListener(_refresh);
    _menu.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_refresh);
    _menu.removeListener(_refresh);
    _destination.dispose();
    _barcode.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _create() {
    final motel = widget.kind == 'motel';
    final qty = int.tryParse(_quantity.text.trim());
    final destination = _destination.text.trim();
    final product = _menu.findByBarcode(_barcode.text.trim());
    if (destination.isEmpty ||
        product == null ||
        qty == null ||
        qty <= 0 ||
        qty > 999) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Enter a destination, an existing menu barcode and a valid quantity.')));
      return;
    }
    final tourismMode = motel || _tourism;
    if (!mounted) return;
    _store.add(
        destination: destination,
        isMotel: motel,
        tourism: tourismMode,
        item: product.name,
        quantity: qty,
        unitPrice: product.priceFor(tourism: tourismMode));
    _destination.clear();
    _barcode.clear();
    _quantity.text = '1';
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Preview order created locally (not submitted).')));
  }

  @override
  Widget build(BuildContext context) {
    final kitchen = widget.kind == 'kitchen';
    final motel = widget.kind == 'motel';
    final orders =
        _store.orders.where((o) => kitchen || o.isMotel == motel).toList();
    final visibleOrders = orders.where((o) {
      final matchesStatus = _statusFilter == "all" || o.status.name == _statusFilter;
      final query = _orderSearch.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          o.destination.toLowerCase().contains(query) ||
          o.item.toLowerCase().contains(query) ||
          o.id.toString().contains(query);
      return matchesStatus && matchesSearch;
    }).toList();
    final active = orders
        .where((o) =>
            o.status != PreviewOrderStatus.cancelled &&
            o.status != PreviewOrderStatus.served)
        .length;
    if (_createLive && !kitchen) {
      return Column(children: [
        SwitchListTile(
            title: const Text('Create an authorized Supabase order'),
            subtitle: const Text('Switch off only for local demonstration; live data requires Supabase permissions'),
            value: _createLive,
            onChanged: (value) => setState(() => _createLive = value)),
        Expanded(child: LiveOrderCreatePanel(isMotel: motel)),
      ]);
    }
    if (_showLive) {
      return Column(children: [
        SwitchListTile(
            title: Text(kitchen
                ? 'LIVE kitchen queue (authorized status updates)'
                : 'Read-only Supabase records'),
            subtitle: const Text('Switch off only for local demonstration; live data requires Supabase permissions'),
            value: _showLive,
            onChanged: (value) => setState(() => _showLive = value)),
        Expanded(
            child: kitchen
                ? const LiveKitchenPanel()
                : LiveRecordsPanel(kind: widget.kind)),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (!kitchen)
        SwitchListTile(
            title: const Text('Create an authorized Supabase order'),
            subtitle: const Text(
                'Requires optional reviewed gs_ migration and backend create permission'),
            value: _createLive,
            onChanged: (value) => setState(() {
                  _showLive = false;
                  _createLive = value;
                })),
      SwitchListTile(
          title: Text(kitchen
              ? 'LIVE kitchen queue (authorized status updates)'
              : 'Read-only Supabase records'),
          subtitle: Text(kitchen
              ? 'Requires optional SQL migrations 001 and 002; kitchen edit permission enforced by server'
              : 'Optional gs_ database tables; does not create or edit live orders'),
          value: _showLive,
          onChanged: (value) => setState(() => _showLive = value)),
      const Card(
          child: ListTile(
              leading: Icon(Icons.science_outlined),
              title: Text('LOCAL DEMONSTRATION — NOT LIVE ORDERS'),
              subtitle: Text(
                  'Select products by barcode from the local Menu preview. Prices are derived from the selected product and mode, but are NOT server-enforced. No real orders or payments are created.'))),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        Chip(label: Text('Preview orders: ${orders.length}')),
        Chip(label: Text('Active: $active')),
        if (kitchen)
          Chip(
              label: Text(
                  'Ready: ${orders.where((o) => o.status == PreviewOrderStatus.ready).length}')),
      ]),
      if (!kitchen) ...[
        const SizedBox(height: 16),
        Text(
            motel
                ? 'Create motel delivery preview'
                : 'Create table order preview',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(
              width: 210,
              child: TextField(
                  controller: _destination,
                  decoration: InputDecoration(
                      labelText: motel ? 'Motel room / villa' : 'Table number',
                      border: const OutlineInputBorder()))),
          SizedBox(
              width: 260,
              child: TextField(
                  controller: _barcode,
                  decoration: const InputDecoration(
                      labelText: 'Existing menu barcode',
                      helperText: 'Create products in Menu first',
                      border: OutlineInputBorder()))),
          SizedBox(
              width: 120,
              child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantity', border: OutlineInputBorder()))),
        ]),
        const SizedBox(height: 8),
        if (_menu.items.isEmpty)
          const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                  'Add a product in Menu before creating a preview order')),
        if (motel)
          const ListTile(
              leading: Icon(Icons.hotel),
              title: Text('Tourism Mode enforced for motel previews'))
        else
          SwitchListTile(
              title: const Text('Tourism Mode'),
              subtitle: const Text('Off by default; select only when needed'),
              value: _tourism,
              onChanged: (v) => setState(() => _tourism = v)),
        Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Create local preview order'))),
      ],
      const SizedBox(height: 20),
      Text(kitchen ? 'Kitchen preview queue' : 'Preview order history',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search order ID, table / room or product',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => _orderSearch = value),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          ChoiceChip(label: const Text('All'), selected: _statusFilter == 'all',
            onSelected: (_) => setState(() => _statusFilter = 'all')),
          const SizedBox(width: 6),
          for (final status in PreviewOrderStatus.values) ...[
            ChoiceChip(label: Text(status.name),
              selected: _statusFilter == status.name,
              onSelected: (_) => setState(() => _statusFilter = status.name)),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: 8),
      if (visibleOrders.isEmpty)
        const Card(child: ListTile(title: Text('No matching preview orders'))),
      for (final order in visibleOrders)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  ListTile(
                    leading: Icon(order.isMotel
                        ? Icons.hotel_outlined
                        : Icons.table_restaurant),
                    title: Text(
                        '#${order.id} • ${order.destination} • ${order.item} × ${order.quantity}'),
                    subtitle: Text(
                        '${order.tourism ? "Tourism" : "Normal"} • ${order.total} IQD • ${order.status.name}'),
                  ),
                  Wrap(spacing: 8, children: [
                    for (final status in PreviewOrderStatus.values)
                      OutlinedButton(
                          onPressed: order.status == status
                              ? null
                              : () => _store.changeStatus(order, status),
                          child: Text(status.name)),
                  ]),
                ]))),
      const SizedBox(height: 12),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: orders.isEmpty ? null : () => _store.clear(),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear ALL local preview orders'))),
    ]);
  }
}
