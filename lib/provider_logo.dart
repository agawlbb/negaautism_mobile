import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'provider_contact_links.dart';

class ProviderLogoException implements Exception {
  final String message;
  const ProviderLogoException(this.message);
}

class ProviderLogo {
  final Uint8List bytes;
  final String filename;
  final String? sourceUrl;
  ProviderLogo._(this.bytes, this.filename, this.sourceUrl);

  factory ProviderLogo.fromBytes(Uint8List bytes, {String? sourceUrl}) {
    if (bytes.isEmpty || bytes.length > 500 * 1024) {
      throw const ProviderLogoException('Choose a logo no larger than 500 KB.');
    }
    final png =
        bytes.length >= 8 &&
        bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
    final jpeg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpeg) {
      throw const ProviderLogoException('Choose a JPG or PNG logo.');
    }
    return ProviderLogo._(bytes, png ? 'logo.png' : 'logo.jpg', sourceUrl);
  }

  factory ProviderLogo.fromJson(Map<String, dynamic> json) {
    final encoded = json['data_base64'];
    if (encoded is! String || encoded.length > 683000) {
      throw const ProviderLogoException('The suggested logo is too large.');
    }
    return ProviderLogo.fromBytes(
      base64Decode(encoded),
      sourceUrl: json['source_url'] as String?,
    );
  }
}

Future<ProviderLogo?> pickProviderLogo() async {
  const images = XTypeGroup(
    label: 'Logo (JPG or PNG)',
    extensions: ['jpg', 'jpeg', 'png'],
    mimeTypes: ['image/jpeg', 'image/png'],
  );
  final file = await openFile(acceptedTypeGroups: [images]);
  if (file == null) return null;
  if (await file.length() > 500 * 1024) {
    throw const ProviderLogoException('Choose a logo no larger than 500 KB.');
  }
  return ProviderLogo.fromBytes(await file.readAsBytes());
}

class ProviderLogoView extends StatelessWidget {
  final String? url;
  final ProviderLogo? logo;
  final double size;
  const ProviderLogoView({super.key, this.url, this.logo, this.size = 80});
  @override
  Widget build(BuildContext context) {
    Widget unavailable(BuildContext _, Object error, StackTrace? stack) =>
        const Icon(Icons.business_outlined);
    return SizedBox(
      width: size,
      height: size,
      child: Semantics(
        label: 'Provider logo',
        child: logo != null
            ? Image.memory(
                logo!.bytes,
                fit: BoxFit.contain,
                errorBuilder: unavailable,
              )
            : url != null
            ? Image.network(
                url!,
                fit: BoxFit.contain,
                cacheWidth: 256,
                errorBuilder: unavailable,
              )
            : const Icon(Icons.business_outlined),
      ),
    );
  }
}

class ProviderLogoInput extends StatefulWidget {
  final ProviderLogo? logo;
  final String? existingUrl;
  final bool enabled;
  final ValueChanged<ProviderLogo?> onChanged;
  final Future<ProviderLogo?> Function() pick;
  const ProviderLogoInput({
    super.key,
    required this.logo,
    required this.onChanged,
    this.existingUrl,
    this.enabled = true,
    this.pick = pickProviderLogo,
  });
  @override
  State<ProviderLogoInput> createState() => _ProviderLogoInputState();
}

class _ProviderLogoInputState extends State<ProviderLogoInput> {
  bool _picking = false;
  String? _error;
  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final logo = await widget.pick();
      if (mounted && widget.enabled && logo != null) widget.onChanged(logo);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ProviderLogoException
              ? e.message
              : 'Unable to select a logo. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logo (optional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (widget.logo != null || widget.existingUrl != null)
          ProviderLogoView(logo: widget.logo, url: widget.existingUrl),
        if (widget.logo?.sourceUrl != null)
          ProviderContactLinks(website: widget.logo!.sourceUrl!, phone: ''),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: !widget.enabled || _picking ? null : _pick,
              icon: const Icon(Icons.upload_outlined),
              label: Text(_picking ? 'Selecting…' : 'Upload logo'),
            ),
            if (widget.logo != null)
              TextButton(
                onPressed: !widget.enabled || _picking
                    ? null
                    : () => widget.onChanged(null),
                child: const Text('Discard selected logo'),
              ),
          ],
        ),
        const Text('JPG or PNG, up to 500 KB.'),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
