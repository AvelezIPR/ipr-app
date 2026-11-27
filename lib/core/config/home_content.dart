import 'package:meta/meta.dart';

/// A qué lleva un banner o un bloque destacado de la portada (`openapi.yaml` →
/// `HomeTarget`).
enum HomeTargetKind {
  category,
  product,
  brand,
  sale,
  branches,
  engineering,
  support,
  calculator,
  web,
  whatsapp;

  static HomeTargetKind? tryParse(Object? raw) {
    for (final kind in values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }

  /// `ref` es un slug (categoría, producto, marca).
  bool get needsSlug => this == category || this == product || this == brand;
}

/// Destino ya validado: un `kind` desconocido o un `ref` inválido nunca llega
/// aquí (se descarta el banner entero), así la app jamás abre una URL o una
/// ruta que el servidor no pueda justificar.
@immutable
final class HomeTarget {
  const new(this.kind, [this.ref]);

  /// Lectura tolerante: devuelve `null` si el destino no se puede usar.
  static HomeTarget? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final kind = HomeTargetKind.tryParse(json['kind']);
    if (kind == null) return null;
    final ref = json['ref'] is String ? (json['ref']! as String).trim() : null;

    if (kind.needsSlug) {
      return ref != null && _slug.hasMatch(ref) ? HomeTarget(kind, ref) : null;
    }
    switch (kind) {
      case HomeTargetKind.web:
        // https, sin credenciales y con host; la lista de hosts permitidos la
        // aplica la política de enlaces externos al abrirlo (SC-036).
        final uri = ref == null ? null : Uri.tryParse(ref);
        if (uri == null ||
            uri.scheme.toLowerCase() != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            ref!.length > _maxUrl) {
          return null;
        }
        return HomeTarget(kind, ref);
      case HomeTargetKind.whatsapp:
        return ref == null || ref.isEmpty || ref.length > _maxMessage
            ? null
            : HomeTarget(kind, ref);
      case HomeTargetKind.sale ||
          HomeTargetKind.branches ||
          HomeTargetKind.engineering ||
          HomeTargetKind.support ||
          HomeTargetKind.calculator:
        return HomeTarget(kind);
      case HomeTargetKind.category ||
          HomeTargetKind.product ||
          HomeTargetKind.brand:
        return null; // ya resuelto arriba
    }
  }

  static final _slug = RegExp(r'^[a-z0-9][a-z0-9._-]{0,199}$');
  static const _maxUrl = 500;
  static const _maxMessage = 300;

  final HomeTargetKind kind;
  final String? ref;

  @override
  bool operator ==(Object other) =>
      other is HomeTarget && other.kind == kind && other.ref == ref;

  @override
  int get hashCode => Object.hash(kind, ref);
}

/// Campaña del carrusel de la portada.
@immutable
final class HomeBanner {
  const new({
    required this.id,
    required this.alt,
    required this.imageUrl,
    required this.target,
  });

  final String id;

  /// Texto alternativo: lo que lee el lector de pantalla.
  final String alt;
  final String imageUrl;
  final HomeTarget target;

  @override
  bool operator ==(Object other) =>
      other is HomeBanner &&
      other.id == id &&
      other.alt == alt &&
      other.imageUrl == imageUrl &&
      other.target == target;

  @override
  int get hashCode => Object.hash(id, alt, imageUrl, target);
}

/// Cifra institucional ya redactada por Marketing (D-07).
@immutable
final class HomeStat {
  const new({
    required this.id,
    required this.value,
    required this.label,
    this.unit,
  });

  final String id;

  /// Cifra o frase corta ("+30", "31", "Líder del sector HVAC-R*").
  final String value;
  final String? unit;
  final String label;

  /// Cifra y unidad juntas, como se leen ("+30 años").
  String get spoken => unit == null ? value : '$value $unit';

  @override
  bool operator ==(Object other) =>
      other is HomeStat &&
      other.id == id &&
      other.value == value &&
      other.unit == unit &&
      other.label == label;

  @override
  int get hashCode => Object.hash(id, value, unit, label);
}

/// Bloque destacado de la portada (ingeniería, formación…).
@immutable
final class HomeHighlight {
  const new({
    required this.id,
    required this.title,
    required this.body,
    required this.cta,
    required this.target,
    this.eyebrow,
    this.imageUrl,
  });

  final String id;
  final String? eyebrow;
  final String title;
  final String body;
  final String cta;
  final String? imageUrl;
  final HomeTarget target;

  @override
  bool operator ==(Object other) =>
      other is HomeHighlight &&
      other.id == id &&
      other.eyebrow == eyebrow &&
      other.title == title &&
      other.body == body &&
      other.cta == cta &&
      other.imageUrl == imageUrl &&
      other.target == target;

  @override
  int get hashCode =>
      Object.hash(id, eyebrow, title, body, cta, imageUrl, target);
}

/// Contenido de la portada que entrega `/config` → `home` (W2). Todo es
/// opcional: sin él la portada muestra solo lo que la app calcula.
@immutable
final class HomeContent {
  const new({
    this.banners = const [],
    this.stats = const [],
    this.highlights = const [],
  });

  /// Lectura **tolerante**: lo ilegible se descarta uno a uno y nunca lanza.
  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    return HomeContent(
      banners: _items(json['banners'], _maxBanners, _banner),
      stats: _items(json['stats'], _maxStats, _stat),
      highlights: _items(json['highlights'], _maxHighlights, _highlight),
    );
  }

  static const empty = HomeContent();

  static const _maxBanners = 10;
  static const _maxStats = 6;
  static const _maxHighlights = 6;
  static const _maxText = 400;

  final List<HomeBanner> banners;
  final List<HomeStat> stats;
  final List<HomeHighlight> highlights;

  bool get isEmpty => banners.isEmpty && stats.isEmpty && highlights.isEmpty;

  static List<T> _items<T>(
    Object? raw,
    int max,
    T? Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List<Object?>) return const [];
    final out = <T>[];
    for (final item in raw) {
      if (out.length >= max) break;
      if (item is! Map<String, dynamic>) continue;
      final parsed = parse(item);
      if (parsed != null) out.add(parsed);
    }
    return List.unmodifiable(out);
  }

  static String? _text(Object? raw, {int max = _maxText}) {
    if (raw is! String) return null;
    final text = raw.trim();
    return text.isEmpty || text.length > max ? null : text;
  }

  /// URL de imagen: https con host; el servidor no puede pedir otra cosa. La
  /// lista de hosts de medios la aplica el widget de imagen (SC-043).
  static String? _imageUrl(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final url = raw['url'];
    if (url is! String) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return url;
  }

  static HomeBanner? _banner(Map<String, dynamic> json) {
    final id = _text(json['id'], max: 80);
    final alt = _text(json['alt']);
    final image = _imageUrl(json['image']);
    final target = HomeTarget.tryFromJson(json['target']);
    if (id == null || alt == null || image == null || target == null) {
      return null;
    }
    return HomeBanner(id: id, alt: alt, imageUrl: image, target: target);
  }

  static HomeStat? _stat(Map<String, dynamic> json) {
    final id = _text(json['id'], max: 80);
    final value = _text(json['value'], max: 80);
    final label = _text(json['label']);
    if (id == null || value == null || label == null) return null;
    return HomeStat(
      id: id,
      value: value,
      unit: _text(json['unit'], max: 40),
      label: label,
    );
  }

  static HomeHighlight? _highlight(Map<String, dynamic> json) {
    final id = _text(json['id'], max: 80);
    final title = _text(json['title']);
    final body = _text(json['body']);
    final cta = _text(json['cta'], max: 80);
    final target = HomeTarget.tryFromJson(json['target']);
    if (id == null ||
        title == null ||
        body == null ||
        cta == null ||
        target == null) {
      return null;
    }
    return HomeHighlight(
      id: id,
      eyebrow: _text(json['eyebrow'], max: 80),
      title: title,
      body: body,
      cta: cta,
      imageUrl: _imageUrl(json['image']),
      target: target,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeContent &&
      _same(other.banners, banners) &&
      _same(other.stats, stats) &&
      _same(other.highlights, highlights);

  @override
  int get hashCode =>
      Object.hash(banners.length, stats.length, highlights.length);
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
