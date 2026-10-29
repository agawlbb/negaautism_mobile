import 'package:flutter/material.dart';

import 'provider_contact_links.dart';
import 'provider_extraction_service.dart';
import 'provider_service.dart';

/// Explicit field selection keeps existing administrator input intact by default.
class ProviderSuggestionsScreen extends StatefulWidget {
  final ProviderSuggestions suggestions;
  final ProviderDirectory directory;
  final Map<String, dynamic> current;
  const ProviderSuggestionsScreen({
    super.key,
    required this.suggestions,
    required this.directory,
    required this.current,
  });
  @override
  State<ProviderSuggestionsScreen> createState() =>
      _ProviderSuggestionsScreenState();
}

class _ProviderSuggestionsScreenState extends State<ProviderSuggestionsScreen> {
  final _selected = <String>{};
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Review website suggestions')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Choose which suggestions to apply. Existing fields are unchecked by default. You can edit everything in the provider form before saving.',
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
              onChanged: (checked) => setState(() {
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
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            for (final key in _selected) key: widget.suggestions.fields[key],
          }),
          child: const Text('Apply selected suggestions'),
        ),
      ],
    ),
  );
}
