import 'package:flutter_test/flutter_test.dart';
import 'package:negaautism_mobile/provider_service.dart';

ProviderDirectory directory({bool empty = false}) =>
    ProviderDirectory.fromJson({
      'categories': [
        {'id': 1, 'category_name': 'Therapy'},
        {'id': 2, 'category_name': 'Education'},
        {'id': 3, 'category_name': 'Unused category'},
      ],
      'counties': [
        {'id': 1, 'county_name': 'Alpha'},
        {'id': 2, 'county_name': 'Beta'},
        {'id': 3, 'county_name': 'Multiple'},
        {'id': 4, 'county_name': 'Unused county'},
      ],
      'providers': empty
          ? []
          : [
              {
                'id': 1,
                'name': 'Alpha provider',
                'category_id': 1,
                'category_name': 'Therapy',
                'county_id': 1,
                'county_name': 'Alpha',
              },
              {
                'id': 2,
                'name': 'Regional provider',
                'category_id': 2,
                'category_name': 'Education',
                'county_id': 3,
                'county_name': 'Multiple',
              },
            ],
    });

void main() {
  test(
    'browsing hides unused lookup choices without removing editor choices',
    () {
      final data = directory();
      expect(data.browsingCategories.map((c) => c.id), [1, 2]);
      expect(data.browsingCounties.map((c) => c.id), [1, 3]);
      expect(data.categories.length, 3);
      expect(data.counties.length, 4);
    },
  );

  test(
    'selecting filters preserves other populated choices and Multiple coverage',
    () {
      final data = directory();
      expect(data.matchingProviders(countyId: 1).map((p) => p.id), [1, 2]);
      expect(
        data.matchingProviders(countyId: 1, categoryId: 2).map((p) => p.id),
        [2],
      );
      expect(data.matchingProviders(search: 'ALPHA').map((p) => p.id), [1]);
      expect(data.browsingCategories.map((c) => c.id), [1, 2]);
      expect(data.browsingCounties.map((c) => c.id), [1, 3]);
    },
  );

  test('an empty directory has no county or category browsing choices', () {
    final data = directory(empty: true);
    expect(data.browsingCategories, isEmpty);
    expect(data.browsingCounties, isEmpty);
    expect(data.matchingProviders(), isEmpty);
  });
}
