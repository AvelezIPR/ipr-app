import 'dart:convert';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/branches/data/datasources/branches_remote_datasource.dart';
import 'package:ipr_mobile/features/branches/data/mappers/branches_mappers.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/features/branches/domain/repositories/branches_repository.dart';

/// Repositorio de sedes con caché SWR (`CachePolicy.stores`: 24 h fresca, 30 d
/// obsoleta). Sin PII ni datos personales (RF-076, AC-076-2).
final class ApiBranchesRepository implements BranchesRepository {
  const new({required this._remote, required this._cache});

  static const cacheKey = 'branches.stores.v1';

  final BranchesRemoteDataSource _remote;
  final CacheStore _cache;

  @override
  Future<Result<BranchesSnapshot>> stores({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) async {
    final cached = await _readCache();
    final cachedBranches = cached == null ? null : _tryParse(cached.value);

    if (cached != null &&
        cachedBranches != null &&
        !forceRefresh &&
        !cached.isStale) {
      return Ok(BranchesSnapshot(branches: cachedBranches));
    }

    final response = await _remote.listStores(cancel: cancel);
    switch (response) {
      case Err<ApiResponse>(:final failure):
        if (cachedBranches != null && failure.retryable) {
          return Ok(BranchesSnapshot(branches: cachedBranches, stale: true));
        }
        return Err(failure);
      case Ok<ApiResponse>(:final value):
        if (value.notModified) {
          return cachedBranches != null
              ? Ok(BranchesSnapshot(branches: cachedBranches))
              : const Err(ContractFailure(detail: 'GET /stores 304 sin caché'));
        }
        final List<Branch> parsed;
        try {
          parsed = mapStores(value.data);
        } on Object {
          if (cachedBranches != null) {
            return Ok(BranchesSnapshot(branches: cachedBranches, stale: true));
          }
          return const Err(ContractFailure(detail: 'GET /stores'));
        }
        if (!value.isStale) {
          await _writeCache(jsonEncode(value.data));
        }
        return Ok(BranchesSnapshot(branches: parsed, stale: value.isStale));
    }
  }

  Future<CacheRead?> _readCache() async {
    try {
      return await _cache.read(cacheKey, CachePolicy.stores);
    } on Object {
      return null;
    }
  }

  Future<void> _writeCache(String value) async {
    try {
      await _cache.write(cacheKey, value);
    } on Object {
      // Caché dañada o llena: la pantalla sigue operando con la respuesta.
    }
  }

  List<Branch>? _tryParse(String raw) {
    try {
      return mapStores(jsonDecode(raw));
    } on Object {
      return null;
    }
  }
}
