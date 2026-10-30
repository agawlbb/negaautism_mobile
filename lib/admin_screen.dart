import 'admin_users_screen.dart';
import 'admin_pdf_screen.dart';
import 'admin_taxonomy_screen.dart';
import 'provider_edit_screen.dart';
import 'provider_service.dart';

import 'package:flutter/material.dart';

import 'manage_events_screen.dart';
import 'vps_api.dart';

class AdminScreen extends StatefulWidget {
  final VpsApi? api;
  const AdminScreen({super.key, this.api});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with WidgetsBindingObserver {
  late final VpsApi _api = widget.api ?? VpsApi();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
    });
    try {
      final data = await _api.request('GET', 'admin/dashboard');
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
    if (mounted) await _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _data?['permissions'] as Map<String, dynamic>? ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
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
                  if (permissions['manage_providers'] == true) ...[
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: const Text('Provider PDFs'),
                      onTap: () => _open(const AdminPdfScreen()),
                    ),
                    ListTile(
                      leading: const Icon(Icons.business),
                      title: const Text('Providers'),
                      subtitle: Text(
                        '${_data?['pending_providers'] ?? 0} awaiting approval',
                      ),
                      onTap: () =>
                          _open(const AdminQueueScreen(kind: 'providers')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.reviews_outlined),
                      title: const Text('Reviews'),
                      subtitle: Text(
                        '${_data?['pending_reviews'] ?? 0} awaiting approval',
                      ),
                      onTap: () =>
                          _open(const AdminQueueScreen(kind: 'reviews')),
                    ),
                  ],
                  if (permissions['manage_users'] == true)
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('Users'),
                      onTap: () => _open(const AdminUsersScreen()),
                    ),
                  if (permissions['manage_categories'] == true) ...[
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Categories'),
                      onTap: () =>
                          _open(const AdminTaxonomyScreen(kind: 'categories')),
                    ),
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('Counties'),
                      onTap: () =>
                          _open(const AdminTaxonomyScreen(kind: 'counties')),
                    ),
                  ],
                  if (permissions['moderator'] == true)
                    ListTile(
                      leading: const Icon(Icons.event),
                      title: const Text('Events'),
                      onTap: () => _open(const ManageEventsScreen()),
                    ),
                ],
              ),
            ),
    );
  }
}

class AdminQueueScreen extends StatefulWidget {
  final String kind;
  final VpsApi? api;
  const AdminQueueScreen({super.key, required this.kind, this.api});
  @override
  State<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends State<AdminQueueScreen> {
  late final VpsApi _api = widget.api ?? VpsApi();
  List<Map<String, dynamic>> _items = [];
  late bool _pending;
  bool _loading = true, _saving = false;
  String? _error;
  String _search = '';
  @override
  void initState() {
    super.initState();
    _pending = widget.kind != 'providers';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      final data = await _api.request(
        'GET',
        'admin/${widget.kind}',
        query: {'scope': _pending ? 'pending' : 'all'},
      );
      if (mounted) {
        setState(
          () => _items = (data['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProvider([Map<String, dynamic>? item]) async {
    if (_saving || _loading) return;
    setState(() => _saving = true);
    final service = ProviderService();
    try {
      final directory = await service.load();
      if (!mounted) return;
      final provider = item == null
          ? null
          : DirectoryProvider.fromJson({
              ...item,
              'category_id': item['category_id'] ?? 0,
              'county_id': item['county_id'] ?? 0,
              'category_name': item['category_name'] ?? '',
              'county_name': item['county_name'] ?? '',
            });
      await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderEditScreen(
            service: service,
            directory: directory,
            provider: provider,
          ),
        ),
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      service.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _approved(Map<String, dynamic> item) =>
      item['approved'] == true || '${item['approved']}' == '1';
  Future<void> _change(Map<String, dynamic> item, {bool delete = false}) async {
    if (_saving || _loading) return;
    final name = item['name'] ?? item['provider_name'] ?? 'this review';
    final action = delete
        ? 'Delete'
        : _approved(item)
        ? 'Unapprove'
        : 'Approve';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action $name?'),
        content: delete
            ? Text(
                widget.kind == 'reviews'
                    ? 'This review will be permanently deleted.'
                    : 'This provider will be permanently deleted. Providers with reviews cannot be deleted until those reviews are removed.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await _api.request(
        delete ? 'DELETE' : 'PATCH',
        'admin/${widget.kind}/${item['id']}${delete ? '' : '/approval'}',
        body: delete ? null : {'approved': !_approved(item)},
      );
      if (mounted) {
        if (result['message'] is String) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'] as String)));
        }
        await _load();
      }
    } catch (e) {
      // Keep the queue visible. A timed-out write may have succeeded; refresh before trying again.
      if (mounted) {
        setState(() => _error = '$e Refresh to check the current state.');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where(
          (item) =>
              '${item['name'] ?? item['provider_name']} ${item['text'] ?? ''} ${item['description'] ?? ''}'
                  .toLowerCase()
                  .contains(_search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      floatingActionButton:
          widget.kind == 'providers' && !_loading && !_saving && _error == null
          ? FloatingActionButton(
              onPressed: _editProvider,
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(
          widget.kind == 'providers' ? 'Manage providers' : 'Manage reviews',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search'),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Pending')),
              ButtonSegment(value: false, label: Text('All')),
            ],
            selected: {_pending},
            onSelectionChanged: _saving || _loading
                ? null
                : (v) {
                    _pending = v.first;
                    _load();
                  },
          ),
          if (_saving) const LinearProgressIndicator(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      if (!_saving) await _load();
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_error != null) ...[
                          Text(_error!),
                          TextButton(
                            onPressed: _saving ? null : _load,
                            child: const Text('Refresh'),
                          ),
                        ],
                        if (items.isEmpty && _error == null)
                          const Text('No matching records.'),
                        for (final item in items)
                          if (widget.kind == 'providers')
                            Card(
                              color: _approved(item)
                                  ? null
                                  : Colors.yellow.shade100,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item['name'] ?? 'Provider'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _approved(item)
                                            ? null
                                            : const TextStyle(
                                                color: Colors.black,
                                              ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: _saving || _error != null
                                          ? null
                                          : () => _editProvider(item),
                                    ),
                                    IconButton(
                                      tooltip: _approved(item)
                                          ? 'Unapprove'
                                          : 'Approve',
                                      icon: Icon(
                                        _approved(item)
                                            ? Icons.unpublished_outlined
                                            : Icons.check_circle_outline,
                                      ),
                                      onPressed: _saving || _error != null
                                          ? null
                                          : () => _change(item),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: _saving || _error != null
                                          ? null
                                          : () => _change(item, delete: true),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${item['name'] ?? item['provider_name'] ?? 'Review'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (widget.kind == 'reviews')
                                      Text('${item['stars']} / 5 stars'),
                                    Text(
                                      '${item['text'] ?? item['description'] ?? ''}',
                                    ),
                                    Text(
                                      _approved(item)
                                          ? 'Approved'
                                          : 'Awaiting approval',
                                    ),
                                    Wrap(
                                      spacing: 12,
                                      children: [
                                        if (widget.kind == 'providers')
                                          TextButton(
                                            onPressed: _saving || _error != null
                                                ? null
                                                : () => _editProvider(item),
                                            child: const Text('Edit'),
                                          ),
                                        TextButton(
                                          onPressed: _saving || _error != null
                                              ? null
                                              : () => _change(item),
                                          child: Text(
                                            _approved(item)
                                                ? 'Unapprove'
                                                : 'Approve',
                                          ),
                                        ),
                                        if (widget.kind == 'reviews' ||
                                            widget.kind == 'providers')
                                          TextButton(
                                            onPressed: _saving || _error != null
                                                ? null
                                                : () => _change(
                                                    item,
                                                    delete: true,
                                                  ),
                                            child: const Text('Delete'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
