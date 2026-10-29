/// VPS read endpoints. Hosted writes migrate in the next implementation slice.
class ApiEndpoints {
  static final providers = Uri.https('vps.negaautism.org', '/api/providers');
  static final events = Uri.https('vps.negaautism.org', '/api/events');
}
