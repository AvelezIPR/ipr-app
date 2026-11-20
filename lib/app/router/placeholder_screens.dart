import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Pantalla provisional de una ruta cuya feature se construye en una
/// rebanada posterior (M1..M5). No contiene lógica de negocio.
class PlaceholderScreen extends StatelessWidget {
  const new({required this.title, super.key, this.showAppBar = true});

  final String title;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineMedium),
            const SizedBox(height: IprSpace.s2),
            Text(
              l10n.placeholderBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
    if (!showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// Estructura de pestañas: barra inferior de 4 destinos (Inicio, Catálogo,
/// Carrito, Cuenta) con pila independiente por pestaña (ADR-005).
class ShellScaffold extends ConsumerWidget {
  const new({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cartUnits = ref.watch(cartUnitCountProvider);
    Widget cartIcon(IconData icon) => cartUnits == 0
        ? Icon(icon)
        : Badge(
            label: Text(cartUnits > 99 ? '99+' : '$cartUnits'),
            child: Icon(icon),
          );
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.tabHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            selectedIcon: const Icon(Icons.category),
            label: l10n.tabCatalog,
          ),
          NavigationDestination(
            icon: cartIcon(Icons.shopping_cart_outlined),
            selectedIcon: cartIcon(Icons.shopping_cart),
            label: l10n.tabCart,
            tooltip: cartUnits == 0 ? null : l10n.tabCartWithCount(cartUnits),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabAccount,
          ),
        ],
      ),
    );
  }
}

/// `/update-required`: versión por debajo del mínimo o 426 del servidor.
class UpdateRequiredScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.updateRequiredTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: IprSpace.s3),
                Text(
                  l10n.updateRequiredBody,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
