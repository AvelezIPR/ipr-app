import 'dart:math' as math;

import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:meta/meta.dart';

/// Tipos de bloque de una landing de marca (`openapi.yaml` → `BrandBlock`).
enum BrandBlockType {
  hero,
  text,
  highlights,
  faq,
  cta;

  static BrandBlockType? tryParse(Object? raw) {
    for (final type in values) {
      if (type.name == raw) return type;
    }
    return null;
  }
}

/// Un elemento de un bloque de destacados o de preguntas frecuentes (en las
/// preguntas, [title] es la pregunta y [body] la respuesta).
@immutable
final class BrandBlockItem {
  const new({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is BrandBlockItem && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);
}

/// Bloque de contenido ya validado: solo texto plano y destinos que la app
/// sabe abrir (nunca HTML ni URLs arbitrarias).
@immutable
final class BrandBlock {
  const new({
    required this.type,
    this.title,
    this.subtitle,
    this.body,
    this.imageUrl,
    this.accentArgb,
    this.items = const [],
    this.ctaLabel,
    this.target,
  });

  final BrandBlockType type;
  final String? title;
  final String? subtitle;
  final String? body;
  final String? imageUrl;

  /// Color de la marca (`0xFFRRGGBB`) **solo si** el texto blanco se lee sobre
  /// él; si no, `null` y la app usa el azul de IPR.
  final int? accentArgb;
  final List<BrandBlockItem> items;
  final String? ctaLabel;
  final HomeTarget? target;

  /// ¿Tiene llamado a la acción completo (etiqueta y destino)?
  bool get hasCta => ctaLabel != null && target != null;

  @override
  bool operator ==(Object other) =>
      other is BrandBlock &&
      other.type == type &&
      other.title == title &&
      other.subtitle == subtitle &&
      other.body == body &&
      other.imageUrl == imageUrl &&
      other.accentArgb == accentArgb &&
      other.ctaLabel == ctaLabel &&
      other.target == target &&
      _same(other.items, items);

  @override
  int get hashCode => Object.hash(type, title, body, items.length);
}

/// Contenido editorial de la landing de una marca (W3-01).
@immutable
final class BrandLanding {
  const new({required this.slug, required this.blocks});

  final String slug;
  final List<BrandBlock> blocks;

  bool get isEmpty => blocks.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is BrandLanding &&
      other.slug == slug &&
      _same(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(slug, blocks.length);
}

/// Color de marca utilizable en el hero (W3-01): solo si el texto blanco
/// encima cumple el contraste mínimo de WCAG AA para texto normal (4,5:1).
abstract final class BrandAccent {
  static const minContrast = 4.5;
  static final _hex = RegExp(r'^#[0-9A-Fa-f]{6}$');

  /// `0xFFRRGGBB` si [hex] es `#RRGGBB` y es lo bastante oscuro; si no, `null`.
  static int? tryParse(String? hex) {
    if (hex == null || !_hex.hasMatch(hex)) return null;
    final rgb = int.parse(hex.substring(1), radix: 16);
    final argb = 0xFF000000 | rgb;
    return contrastWithWhite(argb) >= minContrast ? argb : null;
  }

  /// Razón de contraste del blanco sobre [argb] (1 a 21).
  static double contrastWithWhite(int argb) {
    final luminance = _luminance(argb);
    return 1.05 / (luminance + 0.05);
  }

  static double _luminance(int argb) {
    double channel(int value) {
      final c = value / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final r = channel((argb >> 16) & 0xFF);
    final g = channel((argb >> 8) & 0xFF);
    final b = channel(argb & 0xFF);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
