import 'package:flutter/material.dart';

import 'provider_contact_links.dart';
import 'provider_extraction_service.dart';
import 'provider_service.dart';

class ProviderReviewResult {
  final Map<String, dynamic> fields;
  final String? savedMessage;
  const ProviderReviewResult(this.fields, {this.savedMessage});
}

/// Explicit field selection keeps existing administrator input intact by default.
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
  bool _saving = false;
  String? _error;

  Map<String, dynamic> get _selectedFields => {
    for (final key in _selected) key: widget.suggestions.fields[key],
  };

  Future<void> _add() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.onAdd!(_selectedFields);
      if (!mounted) return;
      setState(() => _saving = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        Navigator.pop(
          context,
          ProviderReviewResult(_selectedFields, savedMessage: message),
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

  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      if (_hasValue(widget.suggestions.fields[key]) &&
          !_hasValue(widget.current[key])) {
        _selected.add(key);
      }
    }
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose which suggestions to apply. Existing fields are unchecked by default. Add the provider here, or apply the selections to edit them in the provider form.',
          ),
          for (final entry in labels.entries)
            if (_hasValue(widget.suggestions.fields[entry.key]))
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _display(entry.key, widget.suggestions.fields[entry.key]),
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
                    : (checked) => setState(() {
                        if (checked == true) {
                          _selected.add(entry.key);
                        } else {
                          _selected.remove(entry.key);
                        }
                      }),
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
          const SizedBox(height: 12),
          const Text('Sources', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final source in widget.suggestions.sources)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(source['field'] ?? ''),
                  SelectableText(source['excerpt'] ?? ''),
                  ProviderContactLinks(website: source['url'] ?? '', phone: ''),
                ],
              ),
            ),
        ],
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
                    : () => Navigator.pop(
                        context,
                        ProviderReviewResult(_selectedFields),
                      ),
                child: const Text('Apply selected suggestions'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
