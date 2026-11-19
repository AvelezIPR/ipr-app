import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/app/router/deep_link_policy.dart';
import 'package:ipr_mobile/app/router/placeholder_screens.dart';
import 'package:ipr_mobile/app/router/routes.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/features/search/search.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';

/// Notifica al router cuando cambia la sesión o la exigencia de actualizar.
final class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Decide a dónde redirigir. Función pura para poder probarla sin widgets.
///
/// Orden: 1) enlaces profundos (SC-067) · 2) actualización obligatoria ·
/// 3) guarda de sesión (`/login?from=…`, lista cerrada de rutas internas).
String? computeRedirect({
  required Uri uri,
  required DeepLinkPolicy deepLinks,
  required bool updateRequired,
  required SessionState session,
}) {
  if (deepLinks.isDeepLink(uri)) {
    return switch (deepLinks.decide(uri)) {
      DeepLinkAccepted(:final location) => location,
      DeepLinkRejected() => Routes.home,
    };
  }

  final path = uri.path;
  if (updateRequired) {
    return path == Routes.updateRequired ? null : Routes.updateRequired;
  }
  if (path == Routes.updateRequired) return Routes.home;

  if (Routes.isProtected(path) && session is! SessionAuthenticated) {
    if (session is SessionUnknown) return null; // aún leyendo el almacén
    final from = uri.hasQuery ? '$path?${uri.query}' : path;
    return Uri(path: Routes.login, queryParameters: {'from': from}).toString();
  }

  if ((path == Routes.login || path == Routes.register) &&
      session is SessionAuthenticated) {
    return Routes.safeInternal(uri.queryParameters['from']) == Routes.home
        ? Routes.account
        : Routes.safeInternal(uri.queryParameters['from']);
  }
  return null;
}

/// Router de la app. Pila por pestaña con `StatefulShellRoute.indexedStack`
/// (Inicio `/`, Catálogo `/catalog`, Carrito `/cart`, Cuenta `/account`).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref
    ..listen(sessionControllerProvider, (_, _) => refresh.ping())
    ..listen(updateRequiredProvider, (_, _) => refresh.ping())
    ..onDispose(refresh.dispose);

  final deepLinks = DeepLinkPolicy(
    allowedHost: ref.read(appConfigProvider).deepLinkHost,
  );

  Widget screen(
    BuildContext context,
    String Function(AppLocalizations) title,
  ) => PlaceholderScreen(title: title(AppLocalizations.of(context)));

  GoRoute simple(String path, String Function(AppLocalizations) title) =>
      GoRoute(path: path, builder: (c, s) => screen(c, title));

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) => computeRedirect(
      uri: state.uri,
      deepLinks: deepLinks,
      updateRequired: ref.read(updateRequiredProvider),
      session: ref.read(sessionControllerProvider),
    ),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (c, s) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.catalog,
                builder: (c, s) => const CatalogScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cart,
                builder: (c, s) => PlaceholderScreen(
                  title: AppLocalizations.of(c).tabCart,
                  showAppBar: false,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (c, s) => PlaceholderScreen(
                  title: AppLocalizations.of(c).tabAccount,
                  showAppBar: false,
                ),
              ),
            ],
          ),
        ],
      ),
      simple(Routes.login, (l) => l.tabAccount),
      simple(Routes.register, (l) => l.tabAccount),
      simple(Routes.passwordRecovery, (l) => l.tabAccount),
      GoRoute(
        path: Routes.catalogList,
        builder: (c, s) =>
            ProductListScreen(categorySlug: s.uri.queryParameters['category']),
      ),
      GoRoute(path: Routes.brands, builder: (c, s) => const BrandsScreen()),
      GoRoute(
        path: '${Routes.brandPrefix}/:slug',
        builder: (c, s) => BrandLandingScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(path: Routes.sale, builder: (c, s) => const SaleScreen()),
      GoRoute(
        path: Routes.search,
        builder: (c, s) =>
            SearchScreen(initialQuery: s.uri.queryParameters['q']),
      ),
      GoRoute(
        path: '${Routes.productPrefix}/:slug',
        builder: (c, s) => ProductDetailScreen(slug: s.pathParameters['slug']!),
      ),
      simple(Routes.checkout, (l) => l.tabCart),
      simple(Routes.checkoutResult, (l) => l.tabCart),
      simple(Routes.orders, (l) => l.tabAccount),
      simple('${Routes.orders}/:number', (l) => l.tabAccount),
      simple(Routes.profile, (l) => l.tabAccount),
      simple(Routes.addresses, (l) => l.tabAccount),
      simple(Routes.deleteAccount, (l) => l.tabAccount),
      simple(Routes.branches, (l) => l.placeholderTitle),
      simple(Routes.btu, (l) => l.placeholderTitle),
      simple(Routes.support, (l) => l.placeholderTitle),
      simple(Routes.pqrs, (l) => l.placeholderTitle),
      simple(Routes.legal, (l) => l.placeholderTitle),
      simple(Routes.engineering, (l) => l.placeholderTitle),
      GoRoute(
        path: Routes.updateRequired,
        builder: (c, s) => const UpdateRequiredScreen(),
      ),
    ],
  );
});
