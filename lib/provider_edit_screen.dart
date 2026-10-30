import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'provider_service.dart';
import 'provider_logo.dart';
import 'provider_contact_links.dart';
import 'provider_extraction_service.dart';
import 'provider_suggestions_screen.dart';
import 'website_theme.dart';

class ProviderEditScreen extends StatefulWidget {
  final ProviderService service;
  final ProviderDirectory directory;
  final DirectoryProvider? provider;
  final FirebaseAuth? auth;
  final ProviderExtractionService? extractionService;
  const ProviderEditScreen({
    super.key,
    required this.service,
    required this.directory,
    this.provider,
    this.auth,
    this.extractionService,
  });
  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _form = GlobalKey<FormState>();
  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  late final TextEditingController _name, _website, _description, _phone;
  late final String? _uid;
  int? _category, _county;
  ProviderLogo? _logo;
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
    _uid = _auth.currentUser?.uid;
    _name = TextEditingController(text: p?.name);
    _website = TextEditingController(text: p?.website);
    _description = TextEditingController(text: p?.description);
    _phone = TextEditingController(text: p?.phone);
    _category = widget.directory.categories.any((c) => c.id == p?.categoryId)
        ? p?.categoryId
        : null;
    _county = widget.directory.counties.any((c) => c.id == p?.countyId)
        ? p?.countyId
        : null;
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
    final user = _auth.currentUser;
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
        _auth.currentUser?.uid != _uid) {
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
    'logo': _logo,
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
    final review = await Navigator.push<ProviderReviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderSuggestionsScreen(
          suggestions: _suggestions!,
          directory: widget.directory,
          current: _current,
          onAdd: widget.provider == null ? _addFromReview : null,
        ),
      ),
    );
    if (!mounted || review == null) return;
    if (review.savedMessage != null) {
      await _closeAfterSave(review.savedMessage!);
      return;
    }
    final selected = review.fields;
    try {
      await _freshToken();
      if (!mounted) return;
      setState(() {
        if (selected.containsKey('logo')) {
          _logo = selected['logo'] as ProviderLogo?;
        }
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
    final service = _extraction =
        widget.extractionService ?? ProviderExtractionService();
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

  Future<void> _closeAfterSave(String message) async {
    setState(() => _saving = false);
    // Allow PopScope to rebuild before closing the form.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, message);
  }

  String _saveError(Object error) => error is ProviderApiException
      ? error.message
      : error is ProviderExtractionException
      ? error.message
      : error is TimeoutException
      ? 'The save timed out. Check the directory before submitting again.'
      : 'Unable to confirm the save. Check your connection and the directory before trying again.';

  Future<String> _submit(Map<String, dynamic> fields) async {
    final name = (fields['name'] as String? ?? '').trim();
    final website = (fields['website'] as String? ?? '').trim();
    final description = fields['description'] as String? ?? '';
    final phone = fields['phone'] as String? ?? '';
    final category = fields['category_id'];
    final county = fields['county_id'];
    if (name.isEmpty || name.length > 255) {
      throw const ProviderApiException(
        'Enter a provider name in the provider form before adding.',
      );
    }
    if (!widget.directory.categories.any((c) => c.id == category) ||
        !widget.directory.counties.any((c) => c.id == county)) {
      throw const ProviderApiException(
        'Select a category and county in the provider form before adding.',
      );
    }
    if (description.length > 10000 ||
        phone.length > 50 ||
        website.length > 255 ||
        (website.isNotEmpty && providerWebsiteUri(website) == null)) {
      throw const ProviderApiException(
        'Correct the contact details or description in the provider form before adding.',
      );
    }
    final token = await _freshToken();
    return widget.service.save(
      token: token,
      id: widget.provider?.id,
      name: name,
      website: website,
      description: description,
      phone: phone,
      categoryId: category as int,
      countyId: county as int,
      logo: fields['logo'] as ProviderLogo?,
    );
  }

  Future<String> _addFromReview(Map<String, dynamic> selected) async {
    if (_saving) {
      throw const ProviderApiException('An add is already in progress.');
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      return await _submit({..._current, ...selected});
    } catch (e) {
      throw ProviderApiException(_saveError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _extracting || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await _submit(_current);
      if (mounted) await _closeAfterSave(message);
    } catch (e) {
      if (mounted) setState(() => _error = _saveError(e));
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
        centerTitle: false,
        title: WebsiteHeaderTitle(
          widget.provider == null ? 'Add provider' : 'Edit provider',
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  child: const Text('Review suggestions'),
                ),
            ],
            ProviderLogoInput(
              logo: _logo,
              existingUrl: providerLogoUrl(widget.provider?.logo ?? ''),
              enabled: !_saving && !_extracting,
              onChanged: (logo) => setState(() => _logo = logo),
            ),
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
              child: Text(
                _saving
                    ? 'Saving…'
                    : widget.provider == null
                    ? 'Add provider'
                    : 'Save provider',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
