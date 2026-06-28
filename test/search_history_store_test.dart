import 'package:flutter_test/flutter_test.dart';
import 'package:net_flow/browser/services/search_history_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('remembers unique recent searches with newest first', () async {
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    await store.remember('old search');
    await store.remember('new search');
    await store.remember('old search');

    expect(store.load(), ['old search', 'new search']);
  });

  test('limits saved search history length', () async {
    final store = SearchHistoryStore(await SharedPreferences.getInstance());

    for (var index = 0; index < SearchHistoryStore.maxItems + 2; index += 1) {
      await store.remember('search $index');
    }

    expect(store.load(), hasLength(SearchHistoryStore.maxItems));
    expect(store.load().first, 'search ${SearchHistoryStore.maxItems + 1}');
    expect(store.load().last, 'search 2');
  });
}
