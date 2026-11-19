import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_query.dart';
import 'package:ipr_mobile/features/search/presentation/controllers/search_results_controller.dart';
import 'package:ipr_mobile/features/search/presentation/controllers/search_suggestions_controller.dart';
import 'package:ipr_mobile/features/search/presentation/widgets/search_empty_view.dart';
import 'package:ipr_mobile/features/search/presentation/widgets/search_results_view.dart';
import 'package:ipr_mobile/features/search/presentation/widgets/search_suggestions_panel.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Pantalla de búsqueda `/search?q=` (PT-06/PT-07; RF-020 a RF-023).
///
/// * Campo enfocado al abrir (AC-001-2); sin consulta inicial muestra una
///   ayuda. Con [initialQuery] (enlace `/search?q=`) busca de inmediato.
/// * Sugerencias en vivo con *debounce* de 300 ms; resultados paginados.
/// * Un campo vacío o de solo espacios no emite petición y conserva el foco
///   (AC-020-3).
/// * "Sin resultados" solo tras un 200 vacío; un error de red muestra el error
///   con "Reintentar" (AC-023-5).
/// * El texto buscado es un dato del usuario: no se escribe en logs, analítica
///   ni disco.
class SearchScreen extends ConsumerStatefulWidget {
  const new({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text;
  final _focus = FocusNode();

  /// Hay texto escrito sin enviar: se muestran las sugerencias.
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final initial = SearchQuery.normalize(widget.initialQuery ?? '');
    _text = TextEditingController(text: initial);
    if (initial.isNotEmpty) {
      // Fuera de la fase de construcción: modifica el estado de un provider.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(searchResultsControllerProvider.notifier).submit(initial);
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _editing = true);
    ref.read(searchSuggestionsControllerProvider.notifier).onTextChanged(value);
  }

  void _submit([String? raw]) {
    final query = SearchQuery.normalize(raw ?? _text.text);
    if (query.isEmpty) {
      // AC-020-3: sin petición y el foco se mantiene en el campo.
      _focus.requestFocus();
      return;
    }
    ref.read(searchSuggestionsControllerProvider.notifier).clear();
    ref.read(searchResultsControllerProvider.notifier).submit(query);
    if (_text.text != query) _text.text = query;
    _focus.unfocus();
    setState(() => _editing = false);
  }

  void _clear() {
    _text.clear();
    ref.read(searchSuggestionsControllerProvider.notifier).clear();
    ref.read(searchResultsControllerProvider.notifier).clear();
    setState(() => _editing = false);
    _focus.requestFocus();
  }

  void _openProduct(String slug) => context.push(Routes.product(slug));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final suggestions = ref.watch(searchSuggestionsControllerProvider);
    // Se observa aquí (y no solo en la región de resultados) para que el
    // controlador autoDispose viva mientras la pantalla esté abierta, aunque
    // se estén mostrando las sugerencias.
    final results = ref.watch(searchResultsControllerProvider);
    final typed = SearchQuery.normalize(_text.text);
    final showSuggestions = _editing && SearchQuery.isSuggestible(typed);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IprSpace.s4,
                IprSpace.s2,
                IprSpace.s4,
                IprSpace.s2,
              ),
              child: ListenableBuilder(
                listenable: _text,
                builder: (context, _) => TextField(
                  controller: _text,
                  focusNode: _focus,
                  autofocus: (widget.initialQuery ?? '').trim().isEmpty,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(SearchQuery.maxLength),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.searchFieldLabel,
                    hintText: l10n.searchFieldHint,
                    prefixIcon: const ExcludeSemantics(
                      child: Icon(Icons.search),
                    ),
                    suffixIcon: _text.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.searchClearTooltip,
                            icon: const Icon(Icons.close),
                            constraints: const BoxConstraints(
                              minWidth: IprSpace.minTapTarget,
                              minHeight: IprSpace.minTapTarget,
                            ),
                            onPressed: _clear,
                          ),
                  ),
                  onChanged: _onChanged,
                  // Evita el desenfoque por defecto: lo gestiona [_submit].
                  onEditingComplete: () {},
                  onSubmitted: _submit,
                ),
              ),
            ),
            if (showSuggestions && suggestions.loading)
              LinearProgressIndicator(
                semanticsLabel: l10n.searchSuggestionsLoading,
              ),
            Expanded(
              child: showSuggestions
                  ? SearchSuggestionsPanel(
                      query: typed,
                      items: suggestions.query == typed
                          ? suggestions.items
                          : const [],
                      onOpen: (s) => _openProduct(s.slug),
                      onSeeAll: _submit,
                    )
                  : _ResultsRegion(
                      state: results,
                      onProductTap: (p) => _openProduct(p.slug),
                      onRetry: () => ref
                          .read(searchResultsControllerProvider.notifier)
                          .retry(),
                      onLoadMore: () => ref
                          .read(searchResultsControllerProvider.notifier)
                          .loadMore(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsRegion extends StatelessWidget {
  const new({
    required this.state,
    required this.onProductTap,
    required this.onRetry,
    required this.onLoadMore,
  });

  final SearchResultsState state;
  final ValueChanged<ProductSummary> onProductTap;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (state.isIdle) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(IprSpace.s5),
          child: Text(
            l10n.searchIdleBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return switch (state.ui) {
      UiLoading<SearchListing>() => const LoadingState(),
      UiFailure<SearchListing>(:final failure) => ErrorState(
        failure: failure,
        onRetry: onRetry,
      ),
      UiEmpty<SearchListing>() => SearchEmptyView(
        query: state.query,
        onRetry: onRetry,
      ),
      UiData<SearchListing>(:final value) => SearchResultsView(
        listing: value,
        onProductTap: onProductTap,
        onLoadMore: onLoadMore,
      ),
    };
  }
}
