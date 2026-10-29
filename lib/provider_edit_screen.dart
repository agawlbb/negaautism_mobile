import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'provider_service.dart';
import 'provider_contact_links.dart';
import 'provider_extraction_service.dart';
import 'provider_suggestions_screen.dart';
import 'website_theme.dart';

class ProviderEditScreen extends StatefulWidget {
  final ProviderService service;
  final ProviderDirectory directory;
  final DirectoryProvider? provider;
  const ProviderEditScreen({
    super.key,
    required this.service,
    required this.directory,
    this.provider,
  });
  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _website, _description, _phone;
  late final String? _uid;
  int? _category, _county;
  bool _saving = false;
  bool _extracting = false;
  String _progress = '';
  ProviderExtractionService? _extraction;
  ProviderSuggestions? _suggestions;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _name = TextEditingController(text: p?.name);
    _website = TextEditingController(text: p?.website);
    _description = TextEditingController(text: p?.description);
    _phone = TextEditingController(text: p?.phone);
    _category = p?.categoryId;
    _county = p?.countyId;
  }

  @override
  void dispose() {
    for (final controller in [_name, _website, _description, _phone]) {
      controller.dispose();
    }
    _extraction?.close();
    super.dispose();
  }

  Future<String> _freshToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != _uid) {
      throw const ProviderExtractionException(
        'Your sign-in changed. Close this form and sign in again.',
      );
    }
    IdTokenResult result;
    try {
      result = await user.getIdTokenResult(true);
    } catch (_) {
      throw const ProviderExtractionException(
        'Unable to verify your sign-in. Please try again.',
      );
    }
    if (result.claims?['manage_providers'] != true ||
        result.token == null ||
        FirebaseAuth.instance.currentUser?.uid != _uid) {
      throw const ProviderExtractionException(
        'Provider management permission is required.',
      );
    }
    return result.token!;
  }

  Map<String, dynamic> get _current => {
    'name': _name.text,
    'description': _description.text,
    'website': _website.text,
    'phone': _phone.text,
    'category_id': _category,
    'county_id': _county,
  };

  Future<void> _reviewSuggestions() async {
    if (_suggestions == null) return;
    try {
      await _freshToken();
    } on ProviderExtractionException catch (e) {
      if (mounted) setState(() => _error = e.message);
      return;
    }
    if (!mounted) return;
    final selected = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderSuggestionsScreen(
          suggestions: _suggestions!,
          directory: widget.directory,
          current: _current,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    try {
      await _freshToken();
      if (!mounted) return;
      setState(() {
        for (final entry in {
          'name': _name,
          'description': _description,
          'website': _website,
          'phone': _phone,
        }.entries) {
          if (selected[entry.key] is String) {
            entry.value.text = selected[entry.key] as String;
          }
        }
        if (selected['category_id'] is int &&
            widget.directory.categories.any(
              (c) => c.id == selected['category_id'],
            )) {
          _category = selected['category_id'] as int;
        }
        if (selected['county_id'] is int &&
            widget.directory.counties.any(
              (c) => c.id == selected['county_id'],
            )) {
          _county = selected['county_id'] as int;
        }
      });
    } on ProviderExtractionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _fillFromWebsite() async {
    final url = providerWebsiteUri(_website.text);
    if (url == null) {
      setState(() => _error = 'Enter the provider website first.');
      return;
    }
    _extraction?.close();
    final service = _extraction = ProviderExtractionService();
    setState(() {
      _extracting = true;
      _error = null;
      _progress = 'Connecting…';
    });
    try {
      final suggestions = await service.extract(
        url: url.toString(),
        directory: widget.directory,
        token: _freshToken,
        progress: (message) {
          if (mounted) setState(() => _progress = message);
        },
      );
      if (!mounted) return;
      setState(() => _suggestions = suggestions);
      await _reviewSuggestions();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ProviderExtractionException ? e.message : 'Website assistance is unavailable. You can still enter details manually.',
        );
      }
    } finally {
      service.close();
      if (mounted) setState(() => _extracting = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _extracting || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != _uid) {
        throw const ProviderApiException(
          'Your sign-in changed. Close this form and sign in again.',
        );
      }
      final result = await user.getIdTokenResult(true);
      if (result.claims?['manage_providers'] != true ||
          result.token == null ||
          FirebaseAuth.instance.currentUser?.uid != _uid) {
        throw const ProviderApiException(
          'Provider management permission is required.',
        );
      }
      final message = await widget.service.save(
        token: result.token!,
        id: widget.provider?.id,
        name: _name.text,
        website: _website.text,
        description: _description.text,
        phone: _phone.text,
        categoryId: _category!,
        countyId: _county!,
      );
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ProviderApiException
              ? e.message
              : e is TimeoutException
              ? 'The save timed out. Check the directory before submitting again.'
              : 'Unable to confirm the save. Check your connection and the directory before trying again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _choice(
    String label,
    List<ProviderChoice> choices,
    int? value,
    ValueChanged<int?> change,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<int>(
        key: ValueKey('$label:$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: choices
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
            .toList(),
        onChanged: _saving || _extracting ? null : change,
        validator: (v) => v == null ? 'Choose a ${label.toLowerCase()}' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: websiteBrandGradient),
        ),
        title: Text(widget.provider == null ? 'Add provider' : 'Edit provider'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.provider == null)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'New providers await approval on the website before appearing in the directory.',
                ),
              ),
            if (widget.provider == null) ...[
              const Text(
                'Enter a website below, then choose Fill from website, or enter details manually.',
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _name,
              enabled: !_saving && !_extracting,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Provider name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a provider name'
                  : null,
            ),
            TextFormField(
              controller: _description,
              enabled: !_saving && !_extracting,
              maxLength: 10000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _website,
              enabled: !_saving && !_extracting,
              maxLength: 255,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Website (optional)',
              ),
              validator: (v) {
                var text = (v ?? '').trim();
                if (text.isEmpty) return null;
                if (!text.contains(':')) text = 'https://$text';
                final uri = Uri.tryParse(text);
                return uri != null &&
                        ['http', 'https'].contains(uri.scheme) &&
                        uri.host.isNotEmpty
                    ? null
                    : 'Enter an HTTP or HTTPS website';
              },
            ),
            if (widget.provider == null) ...[
              OutlinedButton.icon(
                onPressed: _saving || _extracting ? null : _fillFromWebsite,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _extracting ? 'Reading website…' : 'Fill from website',
                ),
              ),
              if (_extracting) ...[
                const LinearProgressIndicator(),
                Text(_progress),
              ],
              if (_suggestions != null)
                TextButton(
                  onPressed: _extracting ? null : _reviewSuggestions,
                  child: const Text('Review suggestions and sources'),
                ),
            ],
            TextFormField(
              controller: _phone,
              enabled: !_saving && !_extracting,
              maxLength: 50,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            _choice(
              'Category',
              widget.directory.categories,
              _category,
              (v) => setState(() => _category = v),
            ),
            _choice(
              'County',
              widget.directory.counties,
              _county,
              (v) => setState(() => _county = v),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ElevatedButton(
              onPressed: _saving || _extracting ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save provider'),
            ),
          ],
        ),
      ),
    ),
  );
}
