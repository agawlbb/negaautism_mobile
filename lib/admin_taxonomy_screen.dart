import 'package:flutter/material.dart';

import 'vps_api.dart';

class AdminTaxonomyScreen extends StatefulWidget {
  final String kind;
  final VpsApi? api;
  const AdminTaxonomyScreen({super.key, required this.kind, this.api});
  @override
  State<AdminTaxonomyScreen> createState() => _AdminTaxonomyScreenState();
}

class _AdminTaxonomyScreenState extends State<AdminTaxonomyScreen> {
  late final VpsApi _api = widget.api ?? VpsApi();
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.request('GET', 'admin/taxonomy/${widget.kind}');
      if (mounted) {
        setState(
          () => _items = (data['items'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _items = [];
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChoiceDialog(api: _api, kind: widget.kind, item: item),
    );
    if (saved == true && mounted) await _load();
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.kind == 'categories' ? 'Categories' : 'Counties'),
    ),
    floatingActionButton: _loading || _error != null
        ? null
        : FloatingActionButton(onPressed: _edit, child: const Icon(Icons.add)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
                for (final item in _items)
                  ListTile(
                    title: Text('${item['name']}'),
                    subtitle:
                        widget.kind == 'counties' &&
                            '${item['name']}'.toLowerCase() == 'multiple'
                        ? const Text('Reserved choice')
                        : null,
                    onTap:
                        widget.kind == 'counties' &&
                            '${item['name']}'.toLowerCase() == 'multiple'
                        ? null
                        : () => _edit(item),
                  ),
              ],
            ),
          ),
  );
}

class _ChoiceDialog extends StatefulWidget {
  final VpsApi api;
  final String kind;
  final Map<String, dynamic>? item;
  const _ChoiceDialog({required this.api, required this.kind, this.item});
  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.item?['name'] as String?,
  );
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    if (_saving) return;
    if (!delete && _name.text.trim().isEmpty) {
      setState(() => _error = 'Enter a name.');
      return;
    }
    if (delete) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete ${widget.item?['name']}?'),
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
      if (yes != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.item?['id'];
      await widget.api.request(
        delete
            ? 'DELETE'
            : id == null
            ? 'POST'
            : 'PUT',
        'admin/taxonomy/${widget.kind}${id == null ? '' : '/$id'}',
        body: delete ? null : {'name': _name.text.trim()},
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.item == null ? 'Add choice' : 'Edit choice'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            enabled: !_saving,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          if (_error != null) Text(_error!),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        if (widget.item != null)
          TextButton(
            onPressed: _saving ? null : () => _save(delete: true),
            child: const Text('Delete'),
          ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
