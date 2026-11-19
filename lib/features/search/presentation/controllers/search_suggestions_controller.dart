import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_query.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/features/search/search_providers.dart';
import 'package:meta/meta.dart';

/// Sugerencias bajo el campo (RF-021). Un fallo del servicio de sugerencias
/// **no** es un error visible: queda como lista vacía y la búsqueda por texto
/// sigue funcionando (AC-021-4).
@immutable
final class SuggestionsState {
  const new({this.query = '', this.items = const [], this.loading = false});

  /// Texto (normalizado) al que corresponden [items]. Solo en memoria.
  final String query;
  final List<SearchSuggestion> items;
  final bool loading;
}

final NotifierProvider<SearchSuggestionsController, SuggestionsState>
searchSuggestionsControllerProvider =
    NotifierProvider.autoDispose<SearchSuggestionsController, SuggestionsState>(
      SearchSuggestionsController.new,
    );

/// Controlador de sugerencias: *debounce* de 300 ms (FA §7.1), mínimo de 2
/// caracteres (contrato `minLength: 2`), cancelación de la petición anterior
/// y descarte de respuestas que llegan fuera de orden (AC-021-2).
class SearchSuggestionsController extends Notifier<SuggestionsState> {
  /// Retraso de envío de las sugerencias.
  static const debounce = Duration(milliseconds: 300);

  Timer? _timer;
  RequestCancellation? _inflight;
  int _generation = 0;

  @override
  SuggestionsState build() {
    ref.onDispose(_cancelAll);
    return const SuggestionsState();
  }

  /// Llamar en cada cambio del texto del campo.
  void onTextChanged(String raw) {
    final query = SearchQuery.normalize(raw);
    if (!SearchQuery.isSuggestible(query)) {
      clear(); // AC-021-5: campo vacío (o muy corto) → sin sugerencias.
      return;
    }
    // Mismo texto normalizado (p. ej. solo un espacio final): nada que hacer.
    if (query == state.query) return;

    _cancelAll();
    final generation = _generation;
    // Las de otro término se ocultan: solo las del último texto (AC-021-2).
    state = SuggestionsState(query: query, loading: true);
    _timer = Timer(debounce, () => unawaited(_fetch(query, generation)));
  }

  /// Oculta y cancela todo (campo vacío, búsqueda enviada, borrar texto).
  void clear() {
    _cancelAll();
    if (state.query.isNotEmpty || state.items.isNotEmpty || state.loading) {
      state = const SuggestionsState();
    }
  }

  Future<void> _fetch(String query, int generation) async {
    final cancellation = RequestCancellation();
    _inflight = cancellation;
    final result = await ref
        .read(searchRepositoryProvider)
        .suggestions(query, cancellation: cancellation);
    if (!ref.mounted || generation != _generation) return;
    state = SuggestionsState(
      query: query,
      items: switch (result) {
        Ok<SearchSuggestions>(:final value) => value.items,
        Err<SearchSuggestions>() => const [],
      },
    );
  }

  void _cancelAll() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _inflight?.cancel();
    _inflight = null;
  }
}
