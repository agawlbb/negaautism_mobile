import 'package:flutter/services.dart';

class DocumentExport {
  static const _channel = MethodChannel('org.negaautism.mobileapp/documents');
  static Future<bool> savePdf(Uint8List bytes, String filename) async {
    if (bytes.length > 15 * 1024 * 1024 ||
        bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-' ||
        !RegExp(r'^[a-zA-Z0-9_-]+\.pdf$').hasMatch(filename)) {
      throw const FormatException('The PDF could not be exported.');
    }
    return await _channel.invokeMethod<bool>('savePdf', {
          'bytes': bytes,
          'filename': filename,
        }) ??
        false;
  }
}
