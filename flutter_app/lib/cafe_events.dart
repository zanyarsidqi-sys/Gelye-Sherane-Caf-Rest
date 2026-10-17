import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cafe_finance_surface.dart';
import 'cafe_language.dart';
import 'cafe_request_id.dart';

const eventStates = {
  'open': 'Planned',
  'in_progress': 'In progress',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
};

DateTime? eventBaghdadInput(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(value)) return null;
  final date = DateTime.tryParse('${value.replaceFirst(' ', 'T')}:00Z');
  if (date == null ||
      date.toIso8601String().substring(0, 16).replaceFirst('T', ' ') != value) {
    return null;
  }
  return date.subtract(const Duration(hours: 3));
}

Map<String, dynamic> eventValues({
  required String title,
  required String start,
  required String end,
  required String location,
  required String host,
  required String guests,
  required String notes,
}) {
  final from = eventBaghdadInput(start), to = eventBaghdadInput(end);
  final size = guests.trim().isEmpty ? null : int.tryParse(guests.trim());
  if (title.trim().isEmpty ||
      title.trim().runes.length > 160 ||
      from == null ||
      to == null ||
      !to.isAfter(from) ||
      to.difference(from) > const Duration(days: 7) ||
      location.trim().runes.length > 160 ||
      host.trim().runes.length > 120 ||
      notes.runes.length > 2000 ||
      (guests.trim().isNotEmpty &&
          (size == null || size < 1 || size > 10000))) {
    throw const FormatException(
      'Enter a title, valid Baghdad start/end times (up to 7 days), and an optional guest count from 1 to 10000.',
    );
  }
  return {
    'title': title.trim(),
    'details': notes.trim(),
    'metadata': {
      'event_schema': 1,
      'starts_at': from.toIso8601String(),
      'ends_at': to.toIso8601String(),
      'location': location.trim(),
      'host': host.trim(),
      'guests': size,
    },
  };
}

bool scheduledCafeEvent(Map<String, dynamic> row) {
  final m = row['metadata'];
  if (m is! Map ||
      m['event_schema'] != 1 ||
      !eventStates.containsKey(row['status'])) {
    return false;
  }
  final from = DateTime.tryParse('${m['starts_at']}'),
      to = DateTime.tryParse('${m['ends_at']}');
  return from != null && to != null && to.isAfter(from);
}

bool eventInPeriod(Map<String, dynamic> row, String period, DateTime now) {
  if (!scheduledCafeEvent(row)) return period == 'Unscheduled';
  if (period == 'All') return true;
  if (period == 'Unscheduled') return false;
  final m = row['metadata'] as Map;
  final from = DateTime.parse(m['starts_at'] as String),
      to = DateTime.parse(m['ends_at'] as String);
  if (period == 'Past') return !to.isAfter(now);
  if (period == 'Upcoming') return from.isAfter(now);
  final local = now.toUtc().add(const Duration(hours: 3));
  final day = DateTime.utc(
    local.year,
    local.month,
    local.day,
  ).subtract(const Duration(hours: 3));
  return from.isBefore(day.add(const Duration(days: 1))) && to.isAfter(day);
}

abstract class CafeEventStore {
  Future<List<Map<String, dynamic>>> load();
  Future<void> save(Map<String, dynamic> command);
}

class SupabaseCafeEventStore implements CafeEventStore {
  SupabaseCafeEventStore(this.client);
  final SupabaseClient client;
  @override
  bool operator ==(Object other) =>
      other is SupabaseCafeEventStore && identical(other.client, client);
  @override
  int get hashCode => identityHashCode(client);
  @override
  Future<List<Map<String, dynamic>>> load() async =>
      List<Map<String, dynamic>>.from(
        await client
            .from('cafe_workspace_records')
            .select('id,title,details,status,metadata,updated_at')
            .eq('section_key', 'dashboard')
            .eq('subcard_key', 'events')
            .order('updated_at', ascending: false)
            .order('id')
            .limit(501),
      );

  @override
  Future<void> save(Map<String, dynamic> command) async {
    final user = client.auth.currentUser?.id;
    if (user == null || user != command['actor']) {
      throw const AuthException('Sign in again.');
    }
    final id = command['id'] as String, token = command['token'] as String;
    final payload = Map<String, dynamic>.from(command['values'] as Map);
    final metadata = Map<String, dynamic>.from(payload['metadata'] as Map);
    metadata['event_command'] = token;
    payload['metadata'] = metadata;
    // Resolve an ambiguous previous response before issuing this exact command again.
    final existing = await client
        .from('cafe_workspace_records')
        .select('metadata,updated_at')
        .eq('section_key', 'dashboard')
        .eq('subcard_key', 'events')
        .eq('id', id)
        .maybeSingle();
    if (existing?['metadata'] is Map &&
        existing!['metadata']['event_command'] == token) {
      return;
    }
    if (command['expected'] == null) {
      if (existing != null) {
        throw StateError(
          'Event identifier conflict. Refresh before continuing.',
        );
      }
      await client.from('cafe_workspace_records').insert({
        ...payload,
        'id': id,
        'section_key': 'dashboard',
        'subcard_key': 'events',
        'created_by': user,
        'updated_by': user,
      });
    } else {
      final result = await client
          .from('cafe_workspace_records')
          .update({...payload, 'updated_by': user})
          .eq('id', id)
          .eq('section_key', 'dashboard')
          .eq('subcard_key', 'events')
          .eq('updated_at', command['expected'] as String)
          .select('id');
      if (result.isEmpty) {
        throw StateError('Event changed elsewhere. Refresh before continuing.');
      }
    }
  }
}

class CafeEvents extends StatefulWidget {
  const CafeEvents({super.key, this.store, required this.actor});
  final CafeEventStore? store;
  final String? actor;
  @override
  State<CafeEvents> createState() => _CafeEventsState();
}

class _CafeEventsState extends State<CafeEvents> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _pending;
  String? _error, _commandError;
  String _query = '', _period = 'Today', _status = 'All';
  bool _loading = true, _busy = false, _limited = false;
  int _request = 0, _operation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CafeEvents oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actor != widget.actor || oldWidget.store != widget.store) {
      _operation++;
      _pending = null;
      _busy = false;
      _commandError = null;
      _load();
    }
  }

  @override
  void dispose() {
    _request++;
    _operation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _rows = [];
      _error = null;
    });
    try {
      if (widget.store == null) throw StateError('Unavailable');
      final rows = await widget.store!.load();
      for (final row in rows) {
        if (row['id'] is! String ||
            row['title'] is! String ||
            row['metadata'] is! Map ||
            DateTime.tryParse('${row['updated_at']}') == null) {
          throw const FormatException('Invalid event record');
        }
      }
      if (!mounted || request != _request) return;
      setState(() {
        _limited = rows.length > 500;
        _rows = rows.take(500).toList();
      });
    } catch (_) {
      if (mounted && request == _request) {
        setState(
          () => _error = 'Could not load events. Check access and refresh.',
        );
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_pending == null || _busy) return;
    final operation = ++_operation, pending = _pending!;
    final store = widget.store;
    setState(() {
      _busy = true;
      _commandError = null;
    });
    try {
      if (store == null) throw StateError('Unavailable');
      await store.save(pending);
      if (!mounted || operation != _operation) return;
      _pending = null;
      await _load();
    } catch (error) {
      if (!mounted || operation != _operation) return;
      final rejected =
          error is StateError ||
          error is AuthException ||
          (error is PostgrestException &&
              const {'42501', '23505', '23514', '22023'}.contains(error.code));
      setState(() {
        if (rejected) _pending = null;
        _commandError = rejected
            ? 'Change rejected or event changed elsewhere. Review refreshed events before trying again.'
            : 'Result not confirmed. Retry the same change before creating another event. Keep this screen open until resolved.';
      });
      if (rejected) await _load();
    } finally {
      if (mounted && operation == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? row]) async {
    final operation = _operation;
    final values = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EventEditor(row: row),
    );
    if (values == null || !mounted || operation != _operation) return;
    _queue(values, row);
  }

  void _queue(Map<String, dynamic> values, Map<String, dynamic>? row) {
    _pending = {
      'id': row?['id'] ?? newCafeRequestId(),
      'token': newCafeRequestId(),
      'actor': widget.actor,
      'expected': row?['updated_at'],
      'values': {
        ...values,
        'status': values['status'] ?? row?['status'] ?? 'open',
        'metadata': {
          ...?row?['metadata'] as Map?,
          ...values['metadata'] as Map,
        },
      },
    };
    _send();
  }

  Future<void> _statusChange(Map<String, dynamic> row, String status) async {
    final operation = _operation;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: CafeText('Mark event ${eventStates[status]}?'),
        content: Text('${row['title']}\nThe event will remain in history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const CafeText('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const CafeText('Confirm'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted || operation != _operation) return;
    _queue({
      'title': row['title'],
      'details': row['details'],
      'status': status,
      'metadata': row['metadata'],
    }, row);
  }

  @override
  Widget build(BuildContext context) => CafeFinanceSurface(
    builder: (context) {
      final now = DateTime.now().toUtc();
      final rows =
          _rows
              .where(
                (r) =>
                    eventInPeriod(r, _period, now) &&
                    (_status == 'All' || r['status'] == _status) &&
                    '${r['title']} ${r['details']} ${r['metadata']['location'] ?? ''} ${r['metadata']['host'] ?? ''}'
                        .toLowerCase()
                        .contains(_query.trim().toLowerCase()),
              )
              .toList()
            ..sort(
              (a, b) => '${a['metadata']['starts_at'] ?? ''}'.compareTo(
                '${b['metadata']['starts_at'] ?? ''}',
              ),
            );
      final disabled =
          _loading ||
          _busy ||
          _error != null ||
          _pending != null ||
          widget.actor == null;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CafeText(
              'Events',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const CafeText(
              'Internal event planner · Baghdad time. Saving an event does not reserve tables, collect deposits or send invitations.',
            ),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: disabled ? null : () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const CafeText('Plan event'),
                ),
                OutlinedButton(
                  onPressed: _loading || _busy ? null : _load,
                  child: const CafeText('Refresh'),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) CafeText(_error!),
            if (_commandError != null) CafeText(_commandError!),
            if (_pending != null)
              OutlinedButton(
                onPressed: _busy ? null : _send,
                child: const CafeText('Retry same change'),
              ),
            if (!_loading && _error == null) ...[
              if (_limited)
                const CafeText(
                  'Only the 500 most recently updated records are loaded. Date and search filters cover these records; older events may be missing.',
                ),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  label: CafeText('Search title, location, host or notes'),
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in [
                    'Today',
                    'Upcoming',
                    'Past',
                    'All',
                    'Unscheduled',
                  ])
                    ChoiceChip(
                      label: CafeText(p),
                      selected: _period == p,
                      onSelected: (_) => setState(() => _period = p),
                    ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in {
                    'All': 'All statuses',
                    ...eventStates,
                  }.entries)
                    ChoiceChip(
                      label: CafeText(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) => setState(() => _status = entry.key),
                    ),
                ],
              ),
              CafeText(
                '${rows.length} matching events · ${_rows.length} loaded records',
              ),
              if (_rows.any((r) => !scheduledCafeEvent(r)))
                const CafeText(
                  'Older or invalid records are preserved under Unscheduled; they are not automatically converted into scheduled events.',
                ),
              if (rows.isEmpty)
                const CafeText('No events match these filters.'),
              for (final row in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          row['title'] as String,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        CafeText(eventStates[row['status']] ?? 'Unknown'),
                        if (scheduledCafeEvent(row)) ...[
                          CafeText(
                            '${cafeFinanceTimestamp(row['metadata']['starts_at'])} — ${cafeFinanceTimestamp(row['metadata']['ends_at'])} · Baghdad',
                          ),
                          CafeText(
                            'Location: ${row['metadata']['location']} · Host: ${row['metadata']['host']}',
                          ),
                          CafeText(
                            'Expected guests: ${row['metadata']['guests'] ?? 'Not recorded'}',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (const {
                                'open',
                                'in_progress',
                              }.contains(row['status']))
                                TextButton(
                                  onPressed: disabled ? null : () => _edit(row),
                                  child: const CafeText('Edit event'),
                                ),
                              if (row['status'] == 'open')
                                TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _statusChange(row, 'in_progress'),
                                  child: const CafeText('Start event'),
                                ),
                              if (row['status'] == 'in_progress')
                                TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _statusChange(row, 'completed'),
                                  child: const CafeText('Complete event'),
                                ),
                              if (const {
                                'open',
                                'in_progress',
                              }.contains(row['status']))
                                TextButton(
                                  onPressed: disabled
                                      ? null
                                      : () => _statusChange(row, 'cancelled'),
                                  child: const CafeText('Cancel event'),
                                ),
                            ],
                          ),
                        ] else
                          const CafeText(
                            'Unscheduled record · Preserved without changes',
                          ),
                        Text('${row['details'] ?? ''}'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({this.row});
  final Map<String, dynamic>? row;
  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final Map<String, TextEditingController> _fields;
  String? _error;
  @override
  void initState() {
    super.initState();
    final row = widget.row, metadata = row?['metadata'] as Map?;
    String time(String key) => metadata?[key] == null
        ? ''
        : DateTime.parse(metadata![key] as String)
              .toUtc()
              .add(const Duration(hours: 3))
              .toIso8601String()
              .substring(0, 16)
              .replaceFirst('T', ' ');
    _fields = {
      for (final entry in <String, String>{
        'Title': row?['title'] as String? ?? '',
        'Start · Baghdad': time('starts_at'),
        'End · Baghdad': time('ends_at'),
        'Location': '${metadata?['location'] ?? ''}',
        'Host': '${metadata?['host'] ?? ''}',
        'Expected guests': '${metadata?['guests'] ?? ''}',
        'Notes': row?['details'] as String? ?? '',
      }.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: CafeText(widget.row == null ? 'Plan event' : 'Edit event'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CafeText(
              'Start and end format: YYYY-MM-DD HH:MM, using 24-hour Baghdad time. Optional guest count is an estimate.',
            ),
            for (final entry in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: entry.value,
                  maxLength: entry.key == 'Notes'
                      ? 2000
                      : entry.key == 'Host'
                      ? 120
                      : 160,
                  maxLines: entry.key == 'Notes' ? 3 : 1,
                  keyboardType: entry.key == 'Expected guests'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(label: CafeText(entry.key)),
                ),
              ),
            if (_error != null) CafeText(_error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const CafeText('Back'),
      ),
      FilledButton(
        onPressed: () {
          try {
            final values = eventValues(
              title: _fields['Title']!.text,
              start: _fields['Start · Baghdad']!.text,
              end: _fields['End · Baghdad']!.text,
              location: _fields['Location']!.text,
              host: _fields['Host']!.text,
              guests: _fields['Expected guests']!.text,
              notes: _fields['Notes']!.text,
            );
            Navigator.pop(context, values);
          } on FormatException catch (error) {
            setState(() => _error = error.message);
          }
        },
        child: const CafeText('Confirm and save'),
      ),
    ],
  );
}
