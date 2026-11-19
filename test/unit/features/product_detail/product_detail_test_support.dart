import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/data/dtos/product_detail_dto.dart';
import 'package:ipr_mobile/features/product_detail/data/mappers/product_detail_mapper.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/domain/repositories/product_detail_repository.dart';

/// Respuesta completa (`{data: ...}`) de un fixture de `product_detail`.
Map<String, dynamic> fixtureBody(String file) =>
    jsonDecode(File('test/fixtures/product_detail/$file').readAsStringSync())
        as Map<String, dynamic>;

/// Entidad construida con el mismo DTO y mapeador de producción.
ProductDetail fixtureProduct(String file) =>
    ProductDetailDto.fromJson(fixtureBody(file)['data'] as Map<String, dynamic>)
        .toEntity();

/// Repositorio de prueba: cada llamada consume el siguiente resultado (el
/// último se repite).
final class FakeProductDetailRepository implements ProductDetailRepository {
  new(this.results);

  final List<Result<ProductDetailLoad>> results;
  final List<({String slug, bool forceRefresh})> calls = [];

  @override
  Future<Result<ProductDetailLoad>> load(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancellation,
  }) async {
    calls.add((slug: slug, forceRefresh: forceRefresh));
    final index = calls.length - 1;
    return results[index < results.length ? index : results.length - 1];
  }
}

/// Repositorio que registra la cancelación recibida y responde cuando se le
/// indica.
final class CancellableProductDetailRepository
    implements ProductDetailRepository {
  final List<RequestCancellation?> cancellations = [];
  final List<Completer<Result<ProductDetailLoad>>> pending = [];

  @override
  Future<Result<ProductDetailLoad>> load(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancellation,
  }) {
    cancellations.add(cancellation);
    final completer = Completer<Result<ProductDetailLoad>>();
    pending.add(completer);
    return completer.future;
  }
}
