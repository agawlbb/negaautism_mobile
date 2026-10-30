import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'document_export.dart';
import 'provider_service.dart';
import 'vps_api.dart';

class AdminPdfScreen extends StatefulWidget {
  final VpsApi? api;
  final ProviderService? providers;
  final Future<bool> Function(Uint8List, String)? export;
  const AdminPdfScreen({super.key, this.api, this.providers, this.export});
  @override
  State<AdminPdfScreen> createState() => _AdminPdfScreenState();
}

class _AdminPdfScreenState extends State<AdminPdfScreen> {
  late final VpsApi _api = widget.api ?? VpsApi();
  late final ProviderService _providers = widget.providers ?? ProviderService();
  ProviderDirectory? _directory;
  List<Map<String, dynamic>> _items = [];
  bool _single = true, _loading = true, _busy = false;
  int? _provider, _county, _category, _count;
  int _limit = 50;
  final _providerSearch = TextEditingController();
  String _approved = '1';
  String? _error;
  Map<String, dynamic> get _filters => {
    if (_county != null) 'county_id': _county,
    if (_category != null) 'category_id': _category,
    'approved': _approved,
  };
  @override
  void initState() {
    super.initState();
    _providerSearch.addListener(() {
      if (_provider == null) return;
      final selected = _items.where((item) => '${item['id']}' == '$_provider');
      if (selected.isEmpty || _providerSearch.text != selected.first['name']) {
        setState(() => _provider = null);
      }
    });
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final directory = await _providers.load();
      final data = await _api.request(
        'GET',
        'admin/providers',
        query: {'scope': 'all'},
      );
      if (mounted) {
        setState(() {
          _directory = directory;
          _items = (data['items'] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate({bool preview = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _api.request(
        'POST',
        'admin/pdf',
        body: {
          'mode': preview
              ? 'preview'
              : _single
              ? 'single'
              : 'booklet',
          if (_single && !preview) 'id': _provider else ..._filters,
        },
        timeout: const Duration(seconds: 90),
      );
      if (!mounted) return;
      if (preview) {
        setState(() {
          _count = data['count'] as int;
          _limit = data['limit'] as int;
        });
      } else {
        final encoded = data['pdf_base64'];
        final filename = data['filename'];
        if (encoded is! String ||
            encoded.length > 21 * 1024 * 1024 ||
            filename is! String) {
          throw const FormatException('Invalid PDF response.');
        }
        final bytes = base64Decode(encoded);
        if (bytes.length > 15 * 1024 * 1024 ||
            bytes.length < 5 ||
            String.fromCharCodes(bytes.take(5)) != '%PDF-') {
          throw const FormatException('Invalid PDF response.');
        }
        final saved = await (widget.export ?? DocumentExport.savePdf)(
          bytes,
          filename,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(saved ? 'PDF saved.' : 'Export cancelled.')),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _providerSearch.dispose();
    if (widget.api == null) _api.close();
    if (widget.providers == null) _providers.close();
    super.dispose();
  }

  Widget _choice(
    String label,
    List<ProviderChoice> options,
    int? selected,
    void Function(int?) update,
  ) => DropdownButtonFormField<int>(
    initialValue: selected,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<int>(value: null, child: Text('All')),
      ...options.map((v) => DropdownMenuItem(value: v.id, child: Text(v.name))),
    ],
    onChanged: _busy
        ? null
        : (value) {
            setState(() {
              update(value);
              _count = null;
            });
          },
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Provider PDFs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_directory == null) ...[
                  Text(_error ?? 'Unable to load providers.'),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ] else ...[
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('One provider')),
                      ButtonSegment(value: false, label: Text('Booklet')),
                    ],
                    selected: {_single},
                    onSelectionChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _single = value.first;
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 16),
                  if (_single)
                    DropdownMenu<int>(
                      controller: _providerSearch,
                      expandedInsets: EdgeInsets.zero,
                      enableFilter: true,
                      enableSearch: true,
                      requestFocusOnTap: true,
                      label: const Text('Find a provider'),
                      enabled: !_busy,
                      dropdownMenuEntries: [
                        for (final item in _items)
                          DropdownMenuEntry(
                            value: int.parse('${item['id']}'),
                            label: '${item['name']}',
                          ),
                      ],
                      onSelected: (value) => setState(() => _provider = value),
                    )
                  else ...[
                    _choice(
                      'County',
                      _directory!.counties,
                      _county,
                      (v) => _county = v,
                    ),
                    const SizedBox(height: 12),
                    _choice(
                      'Category',
                      _directory!.categories,
                      _category,
                      (v) => _category = v,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _approved,
                      decoration: const InputDecoration(labelText: 'Approval'),
                      items: const [
                        DropdownMenuItem(value: '1', child: Text('Approved')),
                        DropdownMenuItem(value: '0', child: Text('Unapproved')),
                        DropdownMenuItem(value: 'all', child: Text('All')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _approved = value!;
                              _count = null;
                            }),
                    ),
                    TextButton(
                      onPressed: _busy ? null : () => _generate(preview: true),
                      child: const Text('Preview matching providers'),
                    ),
                    if (_count != null)
                      Text(
                        '$_count matching providers${_count! > _limit ? '. Narrow the filters to $_limit or fewer.' : '.'}',
                      ),
                  ],
                  if (_error != null) Text(_error!),
                  if (_busy) const LinearProgressIndicator(),
                  FilledButton(
                    onPressed:
                        _busy ||
                            (_single
                                ? _provider == null
                                : _count == null ||
                                      _count == 0 ||
                                      _count! > _limit)
                        ? null
                        : _generate,
                    child: Text(
                      _single ? 'Save provider PDF' : 'Save booklet PDF',
                    ),
                  ),
                ],
              ],
            ),
    ),
  );
}
