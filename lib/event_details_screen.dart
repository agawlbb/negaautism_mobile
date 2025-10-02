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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _timeCtrl.dispose();
    _locCtrl.dispose();
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
      final idToken = await user.getIdToken(true); // fresh token

      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim(); // '' allowed, server can map to NULL if desired
      final eventDateStr = _yyyyMmDd(_eventDate);
      final eventTime = _timeCtrl.text.trim(); // '' allowed
      final location = _locCtrl.text.trim();

      if (name.isEmpty || location.isEmpty) {
        throw Exception('Name and Location are required.');
      }

      final uri = Uri.parse('https://negaautism.org/api/add_event.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_token': idToken,
          'name': name,
          'description': desc,
          'event_date': eventDateStr, // YYYY-MM-DD
          'event_time': eventTime,
          'location': location,
        },
        encoding: Encoding.getByName('utf-8'),
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception((data['message'] ?? 'Add failed').toString());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Event added.')),
      );
      Navigator.of(context).pop(true); // signal success to refresh list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitEdit() async {
    final init = widget.initial!;
    if (init.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing event id for edit.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated.');
      final idToken = await user.getIdToken(true); // fresh token

      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final eventDateStr = _yyyyMmDd(_eventDate);
      final eventTime = _timeCtrl.text.trim();
      final location = _locCtrl.text.trim();

      if (name.isEmpty || location.isEmpty) {
        throw Exception('Name and Location are required.');
      }

      final uri = Uri.parse('https://negaautism.org/api/edit_event.php');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'id_token': idToken,
          'id': init.id.toString(),
          'name': name,
          'description': desc,         // server will convert '' to NULL as needed
          'event_date': eventDateStr,  // YYYY-MM-DD
          'event_time': eventTime,     // '' allowed
          'location': location,
        },
        encoding: Encoding.getByName('utf-8'),
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
      }
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception((data['message'] ?? 'Edit failed').toString());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Event updated.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _noopDelete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete (no-op for now)')),
    );
    // TODO: wire to https://negaautism.org/api/delete_event.php
  }

  String _dateLabel(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
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
              onPressed: _submitting ? null : _noopDelete,
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
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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

                  // Date picker
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

                  TextFormField(
                    controller: _locCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                        onPressed: _submitting ? null : _noopDelete,
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

/// A lightweight data carrier for the details screen.
/// (Mirrors your API shape; convert from your list model where needed.)
class EditableEvent {
  final int? id; // null => new event
  final String name;
  final String description;
  final DateTime eventDate; // stored as DateTime; sent as 'YYYY-MM-DD'
  final String eventTime;
  final String location;

  EditableEvent({
    this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.eventTime,
    required this.location,
  });
}
