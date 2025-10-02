import 'package:flutter/material.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({
    super.key,
    this.initial, // if null -> add mode; else edit mode
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

  void _noopSave() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditMode ? 'Save Changes (no-op)' : 'Create Event (no-op)'),
      ),
    );
    // TODO: wire to add_event.php or edit_event.php
  }

  void _noopDelete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete (no-op)')),
    );
    // TODO: wire to delete_event.php
  }

  String _dateLabel(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
    // Stored/submitted as YYYY-MM-DD when wired
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
              onPressed: _noopDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: SafeArea(
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
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _noopSave,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditMode ? 'Save Changes' : 'Create'),
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _noopDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ],
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
  final DateTime eventDate; // store as DateTime; convert to 'YYYY-MM-DD' when sending
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
