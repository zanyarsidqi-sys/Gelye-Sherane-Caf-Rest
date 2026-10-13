import 'package:flutter/material.dart';

import '../services/web_app_update.dart';

class AppUpdateButton extends StatefulWidget {
  const AppUpdateButton({super.key, this.onUpdate});

  final Future<void> Function()? onUpdate;

  @override
  State<AppUpdateButton> createState() => _AppUpdateButtonState();
}

class _AppUpdateButtonState extends State<AppUpdateButton> {
  bool _busy = false;
  String? _error;

  Future<void> _confirmAndUpdate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update the app?'),
        content: const Text(
          'Updating reloads the app and may discard anything not saved. '
          'Save your work before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await (widget.onUpdate ?? applyWebAppUpdate)();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not start the update. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _confirmAndUpdate,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_alt),
            label: Text(_busy ? 'Refreshing…' : 'Update now'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                textAlign: TextAlign.end,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
}
