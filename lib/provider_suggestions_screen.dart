import 'package:flutter/material.dart';

import 'provider_contact_links.dart';
import 'provider_extraction_service.dart';
import 'provider_service.dart';
import 'provider_logo.dart';

class ProviderReviewResult {
  final Map<String, dynamic> fields;
  final String? savedMessage;
  const ProviderReviewResult(this.fields, {this.savedMessage});
}

/// Review and complete every editable provider field before saving.
class ProviderSuggestionsScreen extends StatefulWidget {
  final ProviderSuggestions suggestions;
  final ProviderDirectory directory;
  final Map<String, dynamic> current;
  final Future<String> Function(Map<String, dynamic>)? onAdd;
  const ProviderSuggestionsScreen({
    super.key,
    required this.suggestions,
    required this.directory,
    required this.current,
    this.onAdd,
  });
  @override
  State<ProviderSuggestionsScreen> createState() =>
      _ProviderSuggestionsScreenState();
}

class _ProviderSuggestionsScreenState extends State<ProviderSuggestionsScreen> {
  final _selected = <String>{};
  final _form = GlobalKey<FormState>();
  final _text = <String, TextEditingController>{};
  final _choices = <String, int?>{};
  bool _saving = false;
  ProviderLogo? _logo;
  String? _error;

  Map<String, dynamic> get _fields => {
    for (final entry in _text.entries) entry.key: entry.value.text,
    ..._choices,
    'logo': _logo,
  };

  Future<void> _add() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.onAdd!(_fields);
      if (!mounted) return;
      setState(() => _saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        Navigator.pop(
          context,
          ProviderReviewResult(_fields, savedMessage: message),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ProviderApiException ? e.message : 'Unable to confirm the add. Check the directory before trying again.';
        });
      }
    }
  }

  static const labels = {
    'name': 'Provider name',
    'description': 'Description',
    'website': 'Website',
    'phone': 'Phone',
    'category_id': 'Category',
    'county_id': 'County',
  };
  bool _hasValue(dynamic value) =>
      value != null && value.toString().trim().isNotEmpty;

  List<ProviderChoice> _options(String key) => key == 'category_id'
      ? widget.directory.categories
      : widget.directory.counties;

  int? _validChoice(String key, dynamic value) =>
      _options(key).any((choice) => choice.id == value) ? value as int : null;

  bool _normalizedWebsite() {
    final current = providerWebsiteUri(
      widget.current['website']?.toString() ?? '',
    );
    final suggested = providerWebsiteUri(
      widget.suggestions.fields['website']?.toString() ?? '',
    );
    if (current == null || suggested == null || suggested.scheme != 'https') {
      return false;
    }
    // Only select an equivalent URL (or its HTTPS upgrade), never another site,
    // path, query, fragment or explicitly different port.
    Uri canonical(Uri uri) =>
        uri.replace(scheme: 'https', path: uri.path.isEmpty ? '/' : uri.path);
    return canonical(current) == canonical(suggested);
  }

  @override
  void initState() {
    super.initState();
    _logo =
        widget.current['logo'] as ProviderLogo? ??
        widget.suggestions.fields['logo'] as ProviderLogo?;
    for (final key in labels.keys) {
      final suggestion = widget.suggestions.fields[key];
      final isChoice = key == 'category_id' || key == 'county_id';
      final available = isChoice
          ? _validChoice(key, suggestion) != null
          : _hasValue(suggestion);
      if (available &&
          (!_hasValue(widget.current[key]) ||
              (key == 'website' && _normalizedWebsite()))) {
        _selected.add(key);
      }
      final value = _selected.contains(key) ? suggestion : widget.current[key];
      if (isChoice) {
        _choices[key] = _validChoice(key, value);
      } else {
        _text[key] = TextEditingController(text: value?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _select(String key, bool checked) {
    setState(() {
      if (checked) {
        _selected.add(key);
      } else {
        _selected.remove(key);
      }
      final value = checked
          ? widget.suggestions.fields[key]
          : widget.current[key];
      if (_text.containsKey(key)) {
        _text[key]!.text = value?.toString() ?? '';
      } else {
        _choices[key] = _validChoice(key, value);
      }
    });
  }

  Widget _editor(String key, String label) {
    if (_text.containsKey(key)) {
      final limit = key == 'description'
          ? 10000
          : key == 'phone'
          ? 50
          : 255;
      return TextFormField(
        key: ValueKey('review-$key'),
        controller: _text[key],
        enabled: !_saving,
        decoration: InputDecoration(labelText: label),
        maxLength: limit,
        maxLines: key == 'description' ? 4 : 1,
        keyboardType: key == 'website'
            ? TextInputType.url
            : key == 'phone'
            ? TextInputType.phone
            : TextInputType.text,
        onChanged: (_) => setState(() => _selected.remove(key)),
        validator: (value) {
          final text = (value ?? '').trim();
          if (key == 'name' && text.isEmpty) return 'Enter a provider name';
          if ((value ?? '').length > limit) {
            return 'Use at most $limit characters';
          }
          if (key == 'website' &&
              text.isNotEmpty &&
              providerWebsiteUri(text) == null) {
            return 'Enter an HTTP or HTTPS website';
          }
          return null;
        },
      );
    }
    return DropdownButtonFormField<int>(
      key: ValueKey('review-$key:${_choices[key]}'),
      initialValue: _choices[key],
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: _options(key)
          .map(
            (choice) =>
                DropdownMenuItem(value: choice.id, child: Text(choice.name)),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (value) => setState(() {
              _choices[key] = value;
              _selected.remove(key);
            }),
      validator: (value) =>
          value == null ? 'Choose a ${label.toLowerCase()}' : null,
    );
  }

  String _display(String key, dynamic value) {
    if (key == 'category_id' || key == 'county_id') {
      final choices = key == 'category_id'
          ? widget.directory.categories
          : widget.directory.counties;
      return choices
              .where((c) => c.id == value)
              .map((c) => c.name)
              .firstOrNull ??
          'Unknown';
    }
    return value?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Review website suggestions')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in labels.entries) ...[
                if (_hasValue(widget.suggestions.fields[entry.key]) &&
                    (_text.containsKey(entry.key) ||
                        _validChoice(
                              entry.key,
                              widget.suggestions.fields[entry.key],
                            ) !=
                            null))
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _display(
                            entry.key,
                            widget.suggestions.fields[entry.key],
                          ),
                        ),
                        if (_hasValue(widget.current[entry.key]))
                          Text(
                            'Current: ${_display(entry.key, widget.current[entry.key])}',
                          ),
                      ],
                    ),
                    value: _selected.contains(entry.key),
                    onChanged: _saving
                        ? null
                        : (checked) => _select(entry.key, checked == true),
                  ),
                _editor(entry.key, entry.value),
                const SizedBox(height: 12),
              ],
              if (widget.suggestions.fields['logo'] is ProviderLogo &&
                  !identical(_logo, widget.suggestions.fields['logo']))
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(
                          () => _logo =
                              widget.suggestions.fields['logo'] as ProviderLogo,
                        ),
                  child: const Text('Use suggested website logo'),
                ),
              ProviderLogoInput(
                logo: _logo,
                enabled: !_saving,
                onChanged: (logo) => setState(() => _logo = logo),
              ),
              if (_logo == null &&
                  widget.suggestions.fields['logo_url'] is String)
                ProviderContactLinks(
                  website: widget.suggestions.fields['logo_url'] as String,
                  phone: '',
                ),
              const Divider(),
              const Text(
                'Administrator review notes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_hasValue(widget.suggestions.fields['supporting_address']))
                SelectableText(
                  'Supporting address: ${widget.suggestions.fields['supporting_address']}',
                ),
              for (final note in widget.suggestions.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SelectableText(note),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (widget.onAdd != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _add,
                    child: Text(_saving ? 'Adding…' : 'Add provider'),
                  ),
                ),
              TextButton(
                onPressed: _saving
                    ? null
                    : () =>
                          Navigator.pop(context, ProviderReviewResult(_fields)),
                child: const Text('Apply changes to provider form'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
