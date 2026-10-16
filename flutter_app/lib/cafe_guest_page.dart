import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeGuestPage extends StatefulWidget {
  const CafeGuestPage({
    required this.qrToken,
    this.supabaseConfigured = true,
    super.key,
  });

  final String qrToken;
  final bool supabaseConfigured;

  @override
  State<CafeGuestPage> createState() => _CafeGuestPageState();
}

class _CafeGuestPageState extends State<CafeGuestPage> {
  late Future<Map<String, dynamic>> _tableContext;

  @override
  void initState() {
    super.initState();
    _tableContext = _loadTableContext();
  }

  Future<Map<String, dynamic>> _loadTableContext() async {
    if (!widget.supabaseConfigured) {
      throw StateError(
        'Table QR verification is not configured for this site.',
      );
    }
    final result = await Supabase.instance.client.rpc(
      'get_cafe_guest_table_context',
      params: {'p_qr_token': widget.qrToken},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Gelye Sherane Café'),
        backgroundColor: const Color(0xFF09243A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _tableContext,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _GuestTableError(
              message:
                  'This table QR could not be verified. Ask a team member '
                  'for help. ${snapshot.error}',
              onRetry: () =>
                  setState(() => _tableContext = _loadTableContext()),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final response = snapshot.data!;
          final table = Map<String, dynamic>.from(response['table'] as Map);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant,
                          size: 44,
                          color: Color(0xFFD6AA57),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          response['restaurant_name'] as String,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '${table['name']} · ${table['area']}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Table ordering is under development. It will '
                          'connect to the existing Table Orders workflow '
                          'after that integration is approved. For now, '
                          'please ask a team member for the menu and service.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuestTableError extends StatelessWidget {
  const _GuestTableError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_2, size: 52),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
