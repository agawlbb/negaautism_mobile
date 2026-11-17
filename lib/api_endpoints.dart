/// All mobile HTTP API routes use the canonical website origin.
class ApiEndpoints {
  static Uri uri(String path, {Map<String, String>? query}) =>
      Uri.https('negaautism.org', '/api/$path', query);
  static final providers = uri('providers');
  static final events = uri('events');
}
