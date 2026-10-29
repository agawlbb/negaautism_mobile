import 'dart:convert';

import 'package:http/http.dart' as http;

class ProviderChoice {
  final int id;
  final String name;
  const ProviderChoice(this.id, this.name);
}

class DirectoryProvider {
  final int id;
  final String name, website, description, phone, category, county;
  final int categoryId, countyId;

  DirectoryProvider.fromJson(Map<String, dynamic> json)
    : id = int.parse('${json['id']}'),
      name = json['name'] as String,
      website = json['website'] as String? ?? '',
      description = json['description'] as String? ?? '',
      phone = json['phone_number'] as String? ?? '',
      category = json['category_name'] as String,
      county = json['county_name'] as String,
      categoryId = int.parse('${json['category_id']}'),
      countyId = int.parse('${json['county_id']}');
}

class ProviderDirectory {
  final List<DirectoryProvider> providers;
  final List<ProviderChoice> categories, counties;

  // Keep all lookup choices for editing, but hide unused ones when browsing.
  List<ProviderChoice> get browsingCategories {
    final used = providers.map((p) => p.categoryId).toSet();
    return categories.where((c) => used.contains(c.id)).toList();
  }

  List<ProviderChoice> get browsingCounties {
    final used = providers.map((p) => p.countyId).toSet();
    return counties.where((c) => used.contains(c.id)).toList();
  }

  List<DirectoryProvider> matchingProviders({
    int? countyId,
    int? categoryId,
    String search = '',
  }) {
    final query = search.toLowerCase();
    return providers
        .where(
          (p) =>
              (countyId == null ||
                  p.countyId == countyId ||
                  p.county == 'Multiple') &&
              (categoryId == null || p.categoryId == categoryId) &&
              '${p.name} ${p.description} ${p.category} ${p.county}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
  }

  ProviderDirectory.fromJson(Map<String, dynamic> json)
    : providers = (json['providers'] as List)
          .map((p) => DirectoryProvider.fromJson(p as Map<String, dynamic>))
          .toList(),
      categories = (json['categories'] as List)
          .map(
            (c) => ProviderChoice(
              int.parse('${c['id']}'),
              c['category_name'] as String,
            ),
          )
          .toList(),
      counties = (json['counties'] as List)
          .map(
            (c) => ProviderChoice(
              int.parse('${c['id']}'),
              c['county_name'] as String,
            ),
          )
          .toList();
}

class ProviderApiException implements Exception {
  final String message;
  const ProviderApiException(this.message);
  @override
  String toString() => message;
}

class ProviderService {
  final http.Client _client;
  ProviderService({http.Client? client}) : _client = client ?? http.Client();
  static final _base = Uri.parse('https://negaautism.org/api/');

  Map<String, dynamic> _response(http.Response response) {
    if (response.statusCode == 404) {
      throw const ProviderApiException(
        'Provider service or provider was not found. Please try again later.',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ProviderApiException(
        'Sign in with provider management permission to save changes.',
      );
    }
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw ProviderApiException(
          data['message'] as String? ?? 'The provider request failed.',
        );
      }
      return data;
    } on FormatException {
      throw const ProviderApiException(
        'The provider service is unavailable. Please try again later.',
      );
    } on TypeError {
      throw const ProviderApiException(
        'The provider service returned an unexpected response.',
      );
    }
  }

  Future<ProviderDirectory> load({int? countyId, int? categoryId}) async {
    final uri = _base
        .resolve('get_providers.php')
        .replace(
          queryParameters: {
            if (countyId != null) 'county_id': '$countyId',
            if (categoryId != null) 'category_id': '$categoryId',
          },
        );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    return ProviderDirectory.fromJson(_response(response));
  }

  Future<String> save({
    required String token,
    int? id,
    required String name,
    required String website,
    required String description,
    required String phone,
    required int categoryId,
    required int countyId,
  }) async {
    if (token.isEmpty) {
      throw const ProviderApiException('Sign in to manage providers.');
    }
    // Never retry a write automatically: a timeout may follow a successful save.
    final response = await _client
        .post(
          _base.resolve('save_provider.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': token,
            if (id != null) 'id': id,
            'name': name.trim(),
            'website': website.trim(),
            'description': description.trim(),
            'phone_number': phone.trim(),
            'category_id': categoryId,
            'county_id': countyId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    return _response(response)['message'] as String;
  }

  void close() => _client.close();
}
