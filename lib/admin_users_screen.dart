import 'package:flutter/material.dart';

import 'vps_api.dart';

const _permissionLabels = {
  'manage_users': 'Manage users',
  'manage_providers': 'Manage providers and reviews',
  'manage_categories': 'Manage categories and counties',
  'moderator': 'Moderator',
};

class AdminUsersScreen extends StatefulWidget {
  final VpsApi? api;
  const AdminUsersScreen({super.key, this.api});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late final VpsApi _api = widget.api ?? VpsApi();
  List<Map<String, dynamic>> _items = [];
  String? _error, _actor;
  String _search = '';
  bool _loading = true;
  bool _includePending = false;
  @override
  void initState() {
    super.initState();
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
        'admin/users',
        query: {'include_pending': _includePending ? '1' : '0'},
      );
      if (mounted) {
        setState(() {
          _items = (data['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
          _actor = data['actor_uid'] as String;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _UserEditor(api: _api, user: item, actor: _actor!),
      ),
    );
    if (changed == true && mounted) await _load();
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
          (v) => '${v['username']} ${v['full_name']} ${v['email']}'
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Show pending deletions'),
            value: _includePending,
            onChanged: _loading
                ? null
                : (value) {
                    _includePending = value;
                    _load();
                  },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search users'),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: _loading
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
                          TextButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                        if (items.isEmpty && _error == null)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No matching users.'),
                          ),
                        for (final item in items)
                          ListTile(
                            title: Text(
                              '${item['username'] == '' ? item['email'] : item['username']}',
                            ),
                            subtitle: Text(
                              '${item['full_name']}\n${item['email']}${item['pending_delete'] == true ? '\nPending deletion: ${item['delete_time']} (UTC)' : ''}',
                            ),
                            isThreeLine: true,
                            onTap: () => _edit(item),
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

class _UserEditor extends StatefulWidget {
  final VpsApi api;
  final Map<String, dynamic> user;
  final String actor;
  const _UserEditor({
    required this.api,
    required this.user,
    required this.actor,
  });
  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _form = GlobalKey<FormState>();
  late final _fields = {
    for (final key in ['username', 'full_name', 'specialty', 'clinic'])
      key: TextEditingController(text: widget.user[key] as String? ?? ''),
  };
  late String _type = widget.user['user_type'] == 'provider'
      ? 'provider'
      : 'parent';
  late final Map<String, bool> _permissions = {
    for (final key in _permissionLabels.keys)
      key: (widget.user['permissions'] as Map)[key] == true,
  };
  bool _saving = false;
  String? _error;
  bool get _self => widget.actor == widget.user['uid'];
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save({bool delete = false}) async {
    if (_saving || (!delete && !_form.currentState!.validate())) return;
    final permissionsChanged = _permissions.entries.any(
      (entry) => entry.value != (widget.user['permissions'] as Map)[entry.key],
    );
    if (delete || permissionsChanged) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            delete ? 'Schedule user deletion?' : 'Change user permissions?',
          ),
          content: Text(
            delete
                ? 'The account will be marked for deletion in 30 days. Firebase and the website profile remain until the daily cleanup removes them. Management accounts and accounts with associated content are protected. An existing deadline will not be extended.'
                : 'These permissions control what this user can manage on the site.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(delete ? 'Schedule deletion' : 'Save'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.request(
        delete ? 'DELETE' : 'PUT',
        'admin/users',
        body: {
          'uid': widget.user['uid'],
          if (!delete) ...{
            for (final entry in _fields.entries)
              entry.key: entry.value.text.trim(),
            'user_type': _type,
            'permissions': _permissions,
          },
        },
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
    child: Scaffold(
      appBar: AppBar(title: const Text('Edit user')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${widget.user['email']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.user['pending_delete'] == true)
              Text(
                'Pending deletion: ${widget.user['delete_time']} (UTC). Editing this profile does not cancel deletion.',
              ),
            if (widget.user['has_profile'] != true)
              const Text('This account has no website profile to edit.'),
            for (final entry in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextFormField(
                  controller: entry.value,
                  enabled: !_saving && widget.user['has_profile'] == true,
                  maxLength: entry.key == 'username' ? 50 : 255,
                  decoration: InputDecoration(
                    labelText: {
                      'username': 'Username',
                      'full_name': 'Full name',
                      'specialty': 'Specialty',
                      'clinic': 'Clinic',
                    }[entry.key],
                  ),
                  validator: (value) =>
                      ['username', 'full_name'].contains(entry.key) &&
                          (value == null || value.trim().isEmpty)
                      ? 'Enter a value.'
                      : null,
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'User type'),
              items: const [
                DropdownMenuItem(value: 'parent', child: Text('Parent')),
                DropdownMenuItem(value: 'provider', child: Text('Provider')),
              ],
              onChanged: _saving || widget.user['has_profile'] != true
                  ? null
                  : (value) => setState(() => _type = value!),
            ),
            Text(
              widget.user['verified'] == true ||
                      '${widget.user['verified']}' == '1'
                  ? 'Verified provider'
                  : 'Provider not verified',
            ),
            for (final entry in _permissionLabels.entries)
              SwitchListTile(
                title: Text(entry.value),
                value: _permissions[entry.key]!,
                onChanged:
                    _saving ||
                        widget.user['has_profile'] != true ||
                        (_self && entry.key == 'manage_users')
                    ? null
                    : (value) =>
                          setState(() => _permissions[entry.key] = value),
              ),
            if (_error != null) Text(_error!),
            if (_saving) const LinearProgressIndicator(),
            FilledButton(
              onPressed: _saving || widget.user['has_profile'] != true
                  ? null
                  : _save,
              child: const Text('Save user'),
            ),
            if (!_self)
              TextButton(
                onPressed: _saving ? null : () => _save(delete: true),
                child: const Text('Schedule deletion'),
              ),
          ],
        ),
      ),
    ),
  );
}
