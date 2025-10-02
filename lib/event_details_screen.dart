import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    this.initial, // null => Add mode; non-null => Edit mode
  });

  final EditableEvent? initial;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late DateTime _eventDate;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _locCtrl;
  late final TextEditingController _addressCtrl; // NEW
  late final TextEditingController _websiteCtrl; // NEW

  final _auth = FirebaseAuth.instance;
  bool _submitting = false;

  bool get _isEditMode => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    _nameCtrl = TextEditingController(text: init?.name ?? '');
    _descCtrl = TextEditingController(text: init?.description ?? '');
    _eventDate = init?.eventDate ?? DateTime.now();
    _timeCtrl = TextEditingController(text: init?.eventTime ?? '');
    _locCtrl = TextEditingController(text: init?.location ?? '');
    _addressCtrl = TextEditingController(text: init?.address ?? ''); // NEW
    _websiteCtrl = TextEditingController(text: init?.website ?? ''); // NEW
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _locCtrl.dispose();
    _addressCtrl.dispose(); // NEW
    _websiteCtrl.dispose(); // NEW
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _eventDate,
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Normalizes a website string for submission.
  /// Examples:
  ///  - "" -> ""
  ///  - "example.org" -> "https://example.org"
  ///  - "http://example.org" -> "http://example.org"
  ///  - "https://example.org/page" -> unchanged
  String _normalizeWebsite(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    // Case-insensitive match for http/https at the start
    if (s.startsWith(RegExp(r'https?://', caseSensitive: false))) return s;
    if (s.contains('.') && !s.contains(' ')) return 'https://$s';
    return s;
  }

  /// Stronger validation: validate the normalized form as a real URI
  String? _validateWebsite(String? v) {
    final normalized = _normalizeWebsite(v ?? '');
    if (normalized.isEmpty) return null; // optional field

    final uri = Uri.tryParse(normalized);
    if (uri == null || !(uri.hasScheme && uri.host.isNotEmpty)) {
      return 'Enter a valid website or leave blank';
    }
    return null;
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditMode) {
      await _submitEdit();
    } else {
      await _submitAdd();
    }
  }

  Future<void> _submitAdd() async {
    setState(() => _submitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated.');
      final idToken = await user.getIdToken(true);

      final uri = Uri.parse('https://negaautism.org/api/add_event.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_token': idToken,
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'event_date': _yyyyMmDd(_eventDate),
          'event_time': _timeCtrl.text.trim(),
          'location': _locCtrl.text.trim(),
          'address': _addressCtrl.text.trim(), // NEW
          'website': _normalizeWebsite(_websiteCtrl.text), // normalized
        },
      );

      final data = json.decode(resp.body);
      if (data['success'] != true) throw Exception(data['message']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Event added.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEdit() async {
    final init = widget.initial!;
    if (init.id == null) return;

    setState(() => _submitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated.');
      final idToken = await user.getIdToken(true);

      final uri = Uri.parse('https://negaautism.org/api/edit_event.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_token': idToken,
          'id': init.id.toString(),
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'event_date': _yyyyMmDd(_eventDate),
          'event_time': _timeCtrl.text.trim(),
          'location': _locCtrl.text.trim(),
          'address': _addressCtrl.text.trim(), // NEW
          'website': _normalizeWebsite(_websiteCtrl.text), // normalized
        },
      );

      final data = json.decode(resp.body);
      if (data['success'] != true) throw Exception(data['message']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Event updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
            'Are you sure you want to delete this event? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitDelete();
    }
  }

  Future<void> _submitDelete() async {
    final init = widget.initial!;
    if (init.id == null) return;

    setState(() => _submitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated.');
      final idToken = await user.getIdToken(true);

      final uri = Uri.parse('https://negaautism.org/api/delete_event.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_token': idToken,
          'id': init.id.toString(),
        },
      );

      final data = json.decode(resp.body);
      if (data['success'] != true) throw Exception(data['message']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Event deleted.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Event' : 'Add Event'),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _submitting ? null : _confirmDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting,
          child: Opacity(
            opacity: _submitting ? 0.7 : 1.0,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Event Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Event Date',
                      border: OutlineInputBorder(),
                    ),
                    child: InkWell(
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_dateLabel(_eventDate)),
                            const Icon(Icons.calendar_today_outlined, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Event Time (free text)',
                      hintText: 'e.g. 6:00 PM',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Location is now OPTIONAL
                  TextFormField(
                    controller: _locCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Address (optional)
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      hintText: 'Street, city, state, ZIP',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Website (optional) — starts blank; validated & normalized
                  TextFormField(
                    controller: _websiteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Website (optional)',
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateWebsite,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _handleSave,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_isEditMode ? 'Save Changes' : 'Create'),
                    ),
                  ),
                  if (_isEditMode) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _confirmDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EditableEvent {
  final int? id;
  final String name;
  final String description;
  final DateTime eventDate;
  final String eventTime;
  final String location; // optional in UI; empty string is fine
  final String address;  // NEW
  final String website;  // NEW

  EditableEvent({
    this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.eventTime,
    required this.location,
    required this.address,   // NEW
    required this.website,   // NEW
  });
}
