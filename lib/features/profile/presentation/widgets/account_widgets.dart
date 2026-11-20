import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Encabezado de la pestaña: ícono decorativo, título (encabezado semántico)
/// y texto de apoyo. Sin datos personales.
class AccountHeader extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 40, color: theme.colorScheme.primary),
        ),
        const SizedBox(height: IprSpace.s3),
        Semantics(
          header: true,
          container: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: IprSpace.s2),
        Text(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// Título de una sección de la lista.
class AccountSectionTitle extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: IprSpace.s5, bottom: IprSpace.s1),
    child: Semantics(
      header: true,
      container: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// Fila de acceso: ícono + texto + flecha, con objetivo táctil ≥ 48 dp.
class AccountTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minTileHeight: IprSpace.minTapTarget,
    leading: ExcludeSemantics(child: Icon(icon)),
    title: Text(label),
    trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
    onTap: onTap,
  );
}
