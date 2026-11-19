import 'package:meta/meta.dart';

/// Referencia a una imagen de producto (`openapi.yaml` → `ImageRef`).
@immutable
final class ImageRef {
  const new({required this.url, required this.alt, this.width, this.height});

  /// Lectura tolerante del contrato: `null` si no es un objeto con `url`.
  static ImageRef? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    final alt = json['alt'];
    final width = json['width'];
    final height = json['height'];
    return ImageRef(
      url: url,
      alt: alt is String ? alt : '',
      width: width is int ? width : null,
      height: height is int ? height : null,
    );
  }

  final String url;

  /// Texto alternativo; si viene vacío se usa el nombre del producto.
  final String alt;
  final int? width;
  final int? height;

  @override
  bool operator ==(Object other) =>
      other is ImageRef && other.url == url && other.alt == alt;

  @override
  int get hashCode => Object.hash(url, alt);
}
