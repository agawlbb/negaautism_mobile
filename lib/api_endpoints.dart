/// All mobile HTTP API routes use the same VPS origin.
class ApiEndpoints {
  static Uri uri(String path, {Map<String, String>? query}) =>
      Uri.https('vps.negaautism.org', '/api/$path', query);
  static final providers = uri('providers');
  static final events = uri('events');
}
