import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

enum EventsScope { upcoming, all }

class ManageEventsScreen extends StatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  State<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends State<ManageEventsScreen> {
  static const String _baseUrl = 'https://negaautism.org/api/get_events.php';

  EventsScope _scope = EventsScope.upcoming;
  bool _loading = false;
  String? _error;
  List<EventItem> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents(); // default to upcoming
  }

  Future<void> _fetchEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse('$_baseUrl?scope=${_scope == EventsScope.upcoming ? 'upcoming' : 'all'}');
      final resp = await http.get(uri);

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      final success = data['success'] == true;
      if (!success) {
        throw Exception(data['message'] ?? 'API returned success=false');
      }

      final List<dynamic> list = data['events'] ?? [];
      final parsed = list
          .map((e) => EventItem.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          // Fallback sort: event_date asc, name asc (API already sorts, this is just defensive)
          final d = a.eventDate.compareTo(b.eventDate);
          return d != 0 ? d : a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });

      setState(() {
        _events = parsed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _events = [];
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchEvents();
  }

  void _onScopeChanged(EventsScope scope) {
    if (_scope == scope) return;
    setState(() {
      _scope = scope;
    });
    _fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    final hasData = !_loading && _error == null && _events.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Events')),
      body: Column(
        children: [
          // Scope selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<EventsScope>(
                    segments: const [
                      ButtonSegment(
                        value: EventsScope.upcoming,
                        label: Text('Upcoming'),
                      ),
                      ButtonSegment(
                        value: EventsScope.all,
                        label: Text('All'),
                      ),
                    ],
                    selected: <EventsScope>{_scope},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        _onScopeChanged(selection.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Error loading events:\n$_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _fetchEvents,
                      child: const Text('Retry'),
                    ),
                  ),
                ],
              )
                  : hasData
                  ? ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final e = _events[i];
                  return _EventCard(item: e);
                },
              )
                  : ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: Text('No events found.')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.item});
  final EventItem item;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (item.eventTime.isNotEmpty) item.eventTime,
      if (item.location.isNotEmpty) item.location,
    ].join(' • ');

    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date line
            Text(
              _formatDate(item.eventDate),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            // Title
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle),
            ],
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    // simple yyyy-mm-dd -> Mon, Oct 6, 2025 (local)
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final wd = weekdays[d.weekday - 1];
    final m = months[d.month - 1];
    return '$wd, $m ${d.day}, ${d.year}';
  }
}

class EventItem {
  final int id;
  final String name;
  final String description;
  final DateTime eventDate;
  final String eventTime;
  final String location;

  EventItem({
    required this.id,
    required this.name,
    required this.description,
    required this.eventDate,
    required this.eventTime,
    required this.location,
  });

  factory EventItem.fromJson(Map<String, dynamic> j) {
    // API returns event_date as 'YYYY-MM-DD'
    final dateStr = (j['event_date'] ?? '').toString();
    final date = DateTime.tryParse(dateStr) ??
        // If parsing fails for any reason, keep a sane default
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();

    return EventItem(
      id: (j['id'] ?? 0) is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
      name: (j['name'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      eventDate: date,
      eventTime: (j['event_time'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
    );
  }
}
