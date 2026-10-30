import 'package:flutter/material.dart';

import 'vps_api.dart';

class AdminUserCleanupScreen extends StatefulWidget {
  final VpsApi? api;
  const AdminUserCleanupScreen({super.key, this.api});
  @override
  State<AdminUserCleanupScreen> createState() => _AdminUserCleanupScreenState();
}

class _AdminUserCleanupScreenState extends State<AdminUserCleanupScreen> {
  late final VpsApi _api = widget.api ?? VpsApi();
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selected = {};
  final Map<String, String> _failures = {};
  String? _after, _next, _error, _summary;
  bool _busy = true, _needsRefresh = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? after}) async {
    setState(() {
      _busy = true;
      _error = null;
      _summary = null;
      _selected.clear();
    });
    try {
      final data = await _api.request(
        'GET',
        'admin/user-cleanup',
        query: {if (after != null) 'after': after},
        timeout: const Duration(minutes: 2),
      );
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _after = after;
        _next = data['next_cursor'] as String?;
        _selected.addAll(_items.map((item) => item['uid'] as String));
        _failures.clear();
        _needsRefresh = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _needsRefresh = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy || _needsRefresh || _selected.isEmpty) return;
    final targets = _items
        .where((item) => _selected.contains(item['uid']))
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${targets.length} accounts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _summary = null;
    });
    try {
      final data = await _api.request(
        'POST',
        'admin/user-cleanup',
        body: {
          'users': [
            for (final item in targets)
              {'uid': item['uid'], 'full_name': item['full_name']},
          ],
        },
        timeout: const Duration(minutes: 3),
      );
      if (!mounted) return;
      final scheduled = Set<String>.from(data['scheduled'] as List);
      setState(() {
        _items.removeWhere((item) => scheduled.contains(item['uid']));
        _selected.clear();
        _failures.clear();
        for (final failure in data['failed'] as List) {
          _failures[failure['uid'] as String] = failure['message'] as String;
        }
        _summary =
            '${scheduled.length} deleted.${_failures.isEmpty ? '' : ' ${_failures.length} skipped.'}';
        _needsRefresh = _failures.isNotEmpty;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error Refresh before retrying.';
          _selected.clear();
          _needsRefresh = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Review suspicious signups')),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_summary != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_summary!)),
          Expanded(
            child: !_busy && _items.isEmpty && _error == null
                ? const Center(child: Text('No flagged accounts.'))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final uid = item['uid'] as String;
                      return CheckboxListTile(
                        value: _selected.contains(uid),
                        onChanged: _busy || _needsRefresh
                            ? null
                            : (selected) => setState(() {
                                if (selected == true) {
                                  _selected.add(uid);
                                } else {
                                  _selected.remove(uid);
                                }
                              }),
                        title: Text(item['full_name'] as String),
                        subtitle: Text(
                          '${item['username']}\n${item['email']}${_failures.containsKey(uid) ? '\n${_failures[uid]}' : ''}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _load(after: _after),
                    child: const Text('Refresh batch'),
                  ),
                  TextButton(
                    onPressed: _busy || _needsRefresh || _next == null
                        ? null
                        : () => _load(after: _next),
                    child: const Text('Next batch'),
                  ),
                  FilledButton(
                    onPressed: _busy || _needsRefresh || _selected.isEmpty
                        ? null
                        : _delete,
                    child: Text('Delete selected (${_selected.length})'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
