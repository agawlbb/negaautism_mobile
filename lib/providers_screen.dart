import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'provider_edit_screen.dart';
import 'provider_service.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});
  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final _service = ProviderService();
  StreamSubscription<User?>? _auth;
  ProviderDirectory? _directory;
  bool _loading = true, _canManage = false;
  String? _error;
  String _search = '';
  int? _county, _category;
  int _request = 0, _permissionRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _auth = FirebaseAuth.instance.idTokenChanges().listen(
      (user) => _permissions(user),
    );
  }

  Future<void> _permissions(User? user) async {
    final request = ++_permissionRequest;
    if (mounted) setState(() => _canManage = false);
    try {
      final result = await user?.getIdTokenResult();
      if (mounted &&
          request == _permissionRequest &&
          FirebaseAuth.instance.currentUser?.uid == user?.uid) {
        setState(
          () => _canManage =
              user != null && result?.claims?['manage_providers'] == true,
        );
      }
    } catch (_) {
      // Browsing remains available when permission verification fails.
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final directory = await _service.load(
        countyId: _county,
        categoryId: _category,
      );
      if (mounted && request == _request) {
        setState(() => _directory = directory);
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e is ProviderApiException ? e.message : 'Unable to load providers. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _edit([DirectoryProvider? provider]) async {
    if (!_canManage || _directory == null) return;
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderEditScreen(
          service: _service,
          directory: _directory!,
          provider: provider,
        ),
      ),
    );
    if (!mounted) return;
    await _permissions(FirebaseAuth.instance.currentUser);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      await _load();
    }
  }

  @override
  void dispose() {
    _auth?.cancel();
    _service.close();
    super.dispose();
  }

  Widget _filter(
    String label,
    List<ProviderChoice> choices,
    int? value,
    ValueChanged<int?> change,
  ) => DropdownButton<int>(
    value: value,
    isExpanded: true,
    hint: Text('All ${label.toLowerCase()}'),
    items: [
      DropdownMenuItem<int>(
        value: null,
        child: Text('All ${label.toLowerCase()}'),
      ),
      ...choices.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
    ],
    onChanged: _loading ? null : change,
  );

  @override
  Widget build(BuildContext context) {
    final providers = (_directory?.providers ?? <DirectoryProvider>[])
        .where(
          (p) => '${p.name} ${p.description} ${p.category} ${p.county}'
              .toLowerCase()
              .contains(_search.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Providers'),
        actions: [
          IconButton(
            tooltip: 'Refresh providers',
            onPressed: _loading
                ? null
                : () {
                    _permissions(FirebaseAuth.instance.currentUser);
                    _load();
                  },
            icon: const Icon(Icons.refresh),
          ),
          if (_canManage && _directory != null)
            IconButton(
              tooltip: 'Add provider',
              onPressed: _loading ? null : () => _edit(),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search providers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                if (_directory != null) ...[
                  _filter('Counties', _directory!.counties, _county, (v) {
                    setState(() => _county = v);
                    _load();
                  }),
                  _filter('Categories', _directory!.categories, _category, (v) {
                    setState(() => _category = v);
                    _load();
                  }),
                ],
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            ),
          if (!_loading && _error == null && providers.isEmpty)
            const Expanded(
              child: Center(
                child: Text('No providers match your search or filters.'),
              ),
            ),
          if (_error == null && providers.isNotEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: providers.length,
                  itemBuilder: (context, index) {
                    final p = providers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ExpansionTile(
                        title: Text(p.name),
                        subtitle: Text('${p.category} · ${p.county}'),
                        childrenPadding: const EdgeInsets.all(16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.description.isNotEmpty)
                            SelectableText(p.description),
                          if (p.phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SelectableText('Phone: ${p.phone}'),
                            ),
                          if (p.website.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SelectableText('Website: ${p.website}'),
                            ),
                          if (_canManage)
                            TextButton.icon(
                              onPressed: () => _edit(p),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit provider'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
