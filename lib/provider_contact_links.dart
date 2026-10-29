import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Uri? providerWebsiteUri(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  final parsed = Uri.tryParse(text);
  final uri = parsed?.hasScheme == true
      ? parsed
      : Uri.tryParse('https://$text');
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

Uri? providerPhoneUri(String value) {
  final match = RegExp(
    r'^\s*(\+?[\d\s().-]+?)(?:\s*(?:ext\.?|x|#)\s*(\d+))?\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;
  final number = match.group(1)!.replaceAll(RegExp(r'[^+\d]'), '');
  if (!number.contains(RegExp(r'\d'))) return null;
  final extension = match.group(2);
  return Uri(
    scheme: 'tel',
    path: '$number${extension == null ? '' : ';ext=$extension'}',
  );
}

Future<bool> openProviderLink(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class ProviderContactLinks extends StatelessWidget {
  final String website, phone;
  final Future<bool> Function(Uri) launch;
  const ProviderContactLinks({
    super.key,
    required this.website,
    required this.phone,
    this.launch = openProviderLink,
  });

  Future<void> _open(BuildContext context, Uri uri) async {
    var opened = false;
    try {
      opened = await launch(uri);
    } catch (_) {
      // A device may have no browser or phone handler installed.
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uri.scheme == 'tel'
                ? 'Unable to open the phone app.'
                : 'Unable to open the browser.',
          ),
        ),
      );
    }
  }

  Widget _link(BuildContext context, String text, IconData icon, Uri? uri) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: uri == null
            ? SelectableText(text)
            : TextButton.icon(
                onPressed: () => _open(context, uri),
                icon: Icon(icon),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                label: Text(
                  text,
                  style: const TextStyle(decoration: TextDecoration.underline),
                ),
              ),
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (phone.trim().isNotEmpty)
        _link(context, phone, Icons.phone_outlined, providerPhoneUri(phone)),
      if (website.trim().isNotEmpty)
        _link(context, website, Icons.open_in_new, providerWebsiteUri(website)),
    ],
  );
}
