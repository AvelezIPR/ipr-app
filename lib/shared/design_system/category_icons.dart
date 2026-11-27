import 'package:material_ui/material_ui.dart';

/// Ícono decorativo de una categoría, deducido de su nombre o slug (Inicio y
/// árbol del Catálogo). Solo es un adorno: el nombre sigue siendo lo que se
/// lee y lo que identifica la categoría, y las desconocidas usan un ícono
/// genérico.
IconData categoryIconForName(String slug, String name) {
  final key = '$slug $name'.toLowerCase();
  const rules = <(String, IconData)>[
    ('aire', Icons.air),
    ('refriger', Icons.ac_unit),
    ('ventil', Icons.wind_power),
    ('ctric', Icons.bolt),
    ('material', Icons.inventory_2_outlined),
    ('consum', Icons.inventory_2_outlined),
    ('herramient', Icons.build_outlined),
    ('tablero', Icons.developer_board_outlined),
    ('control', Icons.developer_board_outlined),
  ];
  for (final (fragment, icon) in rules) {
    if (key.contains(fragment)) return icon;
  }
  return Icons.category_outlined;
}
