import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'provider_service.dart';

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
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
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
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: choices
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
          .toList(),
      onChanged: _saving ? null : change,
      validator: (v) => v == null ? 'Choose a ${label.toLowerCase()}' : null,
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.provider == null ? 'Add provider' : 'Edit provider'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.provider == null)
              const Text(
                'New providers await approval on the website before appearing in the directory.',
              ),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Provider name'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Enter a provider name'
                  : null,
            ),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              maxLength: 10000,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            TextFormField(
              controller: _website,
              enabled: !_saving,
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
            TextFormField(
              controller: _phone,
              enabled: !_saving,
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
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save provider'),
            ),
          ],
        ),
      ),
    ),
  );
}
