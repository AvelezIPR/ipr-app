import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/features/search/domain/repositories/search_repository.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Una llamada registrada a `search`.
final class SearchCall {
  new(this.query, this.page, this.cancellation, this.completer);

  final String query;
  final int page;
  final RequestCancellation? cancellation;
  final Completer<Result<SearchPage>> completer;

  void ok(SearchPage page) => completer.complete(Ok(page));
  void fail(AppFailure failure) => completer.complete(Err(failure));
}

/// Una llamada registrada a `suggestions`.
final class SuggestionsCall {
  new(this.query, this.cancellation, this.completer);

  final String query;
  final RequestCancellation? cancellation;
  final Completer<Result<SearchSuggestions>> completer;

  void ok(List<SearchSuggestion> items) => completer.complete(
    Ok(SearchSuggestions(items: items, total: items.length)),
  );
  void fail(AppFailure failure) => completer.complete(Err(failure));
}

/// Doble del repositorio: cada llamada queda pendiente hasta que la prueba la
/// resuelve, lo que permite simular respuestas fuera de orden.
final class FakeSearchRepository implements SearchRepository {
  final List<SearchCall> searchCalls = [];
  final List<SuggestionsCall> suggestionCalls = [];

  /// Si es verdadero, cada llamada se resuelve sola con [autoSearch] /
  /// [autoSuggestions] (pruebas de widgets sencillas).
  Result<SearchPage> Function(String query, int page)? autoSearch;
  Result<SearchSuggestions> Function(String query)? autoSuggestions;

  @override
  Future<Result<SearchPage>> search(
    String query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) {
    final call = SearchCall(query, page, cancellation, Completer());
    searchCalls.add(call);
    final auto = autoSearch;
    if (auto != null) call.completer.complete(auto(query, page));
    return call.completer.future;
  }

  @override
  Future<Result<SearchSuggestions>> suggestions(
    String query, {
    RequestCancellation? cancellation,
  }) {
    final call = SuggestionsCall(query, cancellation, Completer());
    suggestionCalls.add(call);
    final auto = autoSuggestions;
    if (auto != null) call.completer.complete(auto(query));
    return call.completer.future;
  }
}

ProductSummary product(
  int id, {
  String? name,
  PriceStatus price = const Priced(Money(185000)),
  StockStatus stock = StockStatus.inStock,
}) => ProductSummary(
  id: id,
  slug: 'producto-$id',
  name: name ?? 'Válvula solenoide $id',
  sku: 'QA-${id.toString().padLeft(4, '0')}',
  brandName: 'Elitech',
  price: price,
  availability: stock,
);

SearchPage pageOf(
  List<ProductSummary> items, {
  int page = 1,
  bool hasMore = false,
  int? total,
}) => SearchPage(
  items: items,
  page: page,
  hasMore: hasMore,
  total: total ?? items.length,
);

SearchSuggestion suggestion(int id) => SearchSuggestion(
  id: id,
  slug: 'producto-$id',
  name: 'Válvula solenoide $id',
  sku: 'QA-${id.toString().padLeft(4, '0')}',
  brandName: 'Elitech',
);

/// Lee un fixture de `test/fixtures/search/`.
Map<String, Object?> fixture(String file) =>
    jsonDecode(File('test/fixtures/search/$file').readAsStringSync())
        as Map<String, Object?>;

/// Sobre de `/search` armado con elementos de fixtures.
Map<String, Object?> searchEnvelope(
  List<Map<String, Object?>> items, {
  int page = 1,
  bool hasMore = false,
  int? total,
  String query = 'valvula',
}) => {
  'data': items,
  'meta': {
    'page': page,
    'perPage': 24,
    'total': total ?? items.length,
    'totalPages': hasMore ? page + 1 : page,
    'hasMore': hasMore,
    'query': query,
  },
};
