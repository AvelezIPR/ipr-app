import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Especificaciones técnicas como pares nombre-valor **en texto** (RF-028,
/// AC-028-1/-3): un valor con marcado HTML se ve literal, sin interpretarse.
/// Sin atributos, la sección no se muestra (AC-028-2).
class ProductAttributes extends StatelessWidget {
  const new({required this.attributes, super.key});

  final List<ProductAttribute> attributes;

  @override
  Widget build(BuildContext context) {
    if (attributes.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.productDetailAttributesTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: IprSpace.s2),
        for (final attribute in attributes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: IprSpace.s1),
            child: Semantics(
              container: true,
              label: l10n.productDetailAttributeSemantics(
                attribute.name,
                attribute.displayValue,
              ),
              excludeSemantics: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      attribute.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: IprSpace.s3),
                  Expanded(
                    child: Text(
                      attribute.displayValue,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
