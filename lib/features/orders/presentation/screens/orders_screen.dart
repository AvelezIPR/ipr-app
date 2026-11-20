import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/orders/presentation/controllers/orders_list_controller.dart';
import 'package:ipr_mobile/features/orders/presentation/widgets/order_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Historial de pedidos del cliente (`/orders`, RF-107).
///
/// Solo en memoria y protegido contra capturas (`SensitiveScreen`, RNF-035).
class OrdersScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final ScrollController _scroll = ScrollController();

  static const _loadMoreExtent = 400.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  OrdersListController get _controller => ref.read(ordersListProvider.notifier);

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _loadMoreExtent) {
      unawaited(_controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(ordersListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersListTitle)),
      body: SensitiveScreen(
        protection: ref.watch(screenProtectionProvider),
        child: SafeArea(
          top: false,
          child: AsyncView<OrdersListData>(
            state: state,
            onRetry: _controller.reload,
            empty: EmptyState(
              title: l10n.ordersEmptyTitle,
              body: l10n.ordersEmptyBody,
              action: FilledButton(
                onPressed: () => context.go(Routes.catalog),
                child: Text(l10n.ordersEmptyAction),
              ),
            ),
            builder: (context, data) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _maybeLoadMore();
              });
              return RefreshIndicator(
                onRefresh: _controller.refresh,
                child: ListView.separated(
                  controller: _scroll,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(IprSpace.s4),
                  itemCount: data.items.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: IprSpace.s3),
                  itemBuilder: (context, index) {
                    if (index < data.items.length) {
                      final order = data.items[index];
                      return OrderSummaryCard(
                        order: order,
                        onTap: () => unawaited(
                          context.push(Routes.orderDetail(order.id)),
                        ),
                      );
                    }
                    return _PaginationFooter(
                      data: data,
                      onRetry: () =>
                          unawaited(_controller.loadMore(retry: true)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const new({required this.data, required this.onRetry});

  final OrdersListData data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (data.loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: IprSpace.s4),
        child: Center(
          child: Semantics(
            liveRegion: true,
            label: l10n.ordersLoadingMore,
            child: MediaQuery.of(context).disableAnimations
                ? const Icon(Icons.hourglass_empty)
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }
    final failure = data.pageFailure;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: IprSpace.s3),
        child: Column(
          children: [
            Text(
              '${l10n.ordersLoadMoreError} ${failureText(l10n, failure)}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: IprSpace.s2),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
