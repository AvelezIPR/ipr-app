import 'dart:convert';
import 'dart:io';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';

/// Carga un fixture de `test/fixtures/home/` (un elemento del contrato).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/home/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Respuesta `{data: [...]}` de `/categories` y `/brands`.
Map<String, dynamic> listBody(List<Map<String, dynamic>> items) => {
  'data': items,
};

/// Respuesta de `/products` con `meta` válido.
Map<String, dynamic> productPage(List<Map<String, dynamic>> items) => {
  'data': items,
  'meta': fixture('PageMeta.valid.json'),
};

/// Repositorio doble: cada método devuelve el siguiente resultado guionado
/// (el último se repite) y registra las llamadas (`forceRefresh`).
class FakeHomeRepository implements HomeRepository {
  new({
    List<Result<SectionData<List<HomeCategory>>>>? categoryResults,
    List<Result<SectionData<List<HomeBrand>>>>? brandResults,
    List<Result<SectionData<List<ProductSummary>>>>? featuredResults,
  }) : categoryResults = [...?categoryResults],
       brandResults = [...?brandResults],
       featuredResults = [...?featuredResults];

  final List<Result<SectionData<List<HomeCategory>>>> categoryResults;
  final List<Result<SectionData<List<HomeBrand>>>> brandResults;
  final List<Result<SectionData<List<ProductSummary>>>> featuredResults;

  final List<bool> categoryCalls = [];
  final List<bool> brandCalls = [];
  final List<bool> featuredCalls = [];

  T _next<T>(List<T> queue, T fallback) {
    if (queue.isEmpty) return fallback;
    return queue.length > 1 ? queue.removeAt(0) : queue.first;
  }

  @override
  Future<Result<SectionData<List<HomeCategory>>>> categories({
    bool forceRefresh = false,
  }) {
    categoryCalls.add(forceRefresh);
    return Future.value(_next(categoryResults, const Err(UnknownFailure())));
  }

  @override
  Future<Result<SectionData<List<HomeBrand>>>> brands({
    bool forceRefresh = false,
  }) {
    brandCalls.add(forceRefresh);
    return Future.value(_next(brandResults, const Err(UnknownFailure())));
  }

  @override
  Future<Result<SectionData<List<ProductSummary>>>> featuredProducts({
    bool forceRefresh = false,
  }) {
    featuredCalls.add(forceRefresh);
    return Future.value(_next(featuredResults, const Err(UnknownFailure())));
  }
}
