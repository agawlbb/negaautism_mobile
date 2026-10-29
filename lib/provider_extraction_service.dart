import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'provider_service.dart';
import 'provider_logo.dart';

class ProviderSuggestions {
  final Map<String, dynamic> fields;
  final List<String> notes;
  final List<Map<String, String>> sources;
  ProviderSuggestions.fromJson(Map<String, dynamic> json)
    : fields = {...json},
      notes = (json['review_notes'] as List).cast<String>().toList(),
      sources = (json['sources'] as List)
          .map((s) => Map<String, String>.from(s as Map))
          .toList() {
    if (json['logo_image'] is Map) {
      try {
        fields['logo'] = ProviderLogo.fromJson(
          Map<String, dynamic>.from(json['logo_image'] as Map),
        );
      } catch (_) {
        notes.add(
          'The suggested logo could not be read. Upload a JPG or PNG logo manually.',
        );
      }
    }
  }
}

class ProviderExtractionException implements Exception {
  final String message;
  const ProviderExtractionException(this.message);
}

class ProviderExtractionService {
  final Uri endpoint;
  WebSocket? _socket;
  bool _closed = false;
  ProviderExtractionService({Uri? endpoint})
    : endpoint = endpoint ?? Uri.parse('wss://vps.negaautism.org/ws');

  Future<ProviderSuggestions> extract({
    required String url,
    required ProviderDirectory directory,
    required Future<String> Function() token,
    required void Function(String) progress,
  }) async {
    final random = Random.secure();
    final requestId = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final payload = <String, dynamic>{
      'request_id': requestId,
      'url': url,
      'categories': directory.categories
          .map((c) => {'id': c.id, 'name': c.name})
          .toList(),
      'counties': directory.counties
          .map((c) => {'id': c.id, 'name': c.name})
          .toList(),
    };
    var submitted = false;
    final deadline = DateTime.now().add(const Duration(minutes: 11));
    for (var attempt = 0; attempt < 4 && !_closed; attempt++) {
      try {
        final idToken = await token();
        if (_closed) break;
        final connecting = WebSocket.connect(endpoint.toString());
        var timedOut = false;
        unawaited(
          connecting.then((socket) {
            if (timedOut || _closed) unawaited(socket.close());
          }, onError: (Object _) {}),
        );
        final socket = await connecting.timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            timedOut = true;
            throw TimeoutException('Connection timed out');
          },
        );
        _socket = socket;
        if (_closed) {
          await socket.close();
          break;
        }
        socket.pingInterval = const Duration(seconds: 25);
        socket.add(
          jsonEncode({
            ...payload,
            'idToken': idToken,
            'resume_only': submitted,
          }),
        );
        submitted = true;
        await for (final raw in socket.timeout(const Duration(seconds: 90))) {
          if (_closed) break;
          if (DateTime.now().isAfter(deadline)) {
            throw TimeoutException('Review timed out');
          }
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'progress') progress(data['message'] as String);
          if (data['type'] == 'error') {
            throw ProviderExtractionException(
              data['message'] as String? ?? 'Website review failed.',
            );
          }
          if (data['type'] == 'result') {
            // Recheck sign-in and permission before presenting a retained result.
            await token();
            return ProviderSuggestions.fromJson(
              data['result'] as Map<String, dynamic>,
            );
          }
        }
      } on ProviderExtractionException {
        rethrow;
      } on FormatException {
        throw const ProviderExtractionException(
          'The website service returned an unexpected result.',
        );
      } catch (_) {
        if (attempt == 3 || DateTime.now().isAfter(deadline)) break;
      } finally {
        await _socket?.close();
        _socket = null;
      }
      if (!_closed) {
        progress('Reconnecting to the website review…');
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    throw const ProviderExtractionException(
      'Unable to retrieve the website review. You can enter details manually or start a new review.',
    );
  }

  void close() {
    _closed = true;
    unawaited(_socket?.close());
  }
}
