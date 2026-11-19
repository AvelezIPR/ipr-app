/// Saneador de la descripción HTML de la ficha (RF-027, AC-027-1..4).
///
/// **No confía en el servidor**: el contrato dice que el HTML llega saneado,
/// pero el saneador de la web es por expresiones regulares y no está auditado
/// (SEC-04). Esta es la defensa propia de la app (AC-027-2).
///
/// Estrategia de **lista blanca y reconstrucción**: se recorre el texto con un
/// analizador léxico propio y se emite HTML nuevo solo con las etiquetas y los
/// atributos permitidos, con los valores siempre entrecomillados y escapados.
/// Lo que no se reconoce se descarta; nada del original se copia tal cual
/// salvo el texto entre etiquetas (que no puede contener `<`).
///
/// * Se descartan **con su contenido**: `script`, `style`, `iframe`, `object`,
///   `embed`, `form`, `svg`, `math`, `noscript`, `template`, `textarea`,
///   `select`, `button`, `audio`, `video`, `canvas`, `applet`, `frameset`...
/// * Etiquetas desconocidas: se quita la etiqueta y se conserva el texto.
/// * Atributos: solo `href`/`title` (a), `src`/`alt`/`title`/`width`/`height`
///   (img) y `colspan`/`rowspan` (celdas). Nunca `style`, `class`, `id` ni
///   `on*`.
/// * Enlaces: solo `https`, sin credenciales en la URL. Cualquier otro
///   esquema (`javascript:`, `data:`, `http:`, `intent:`, `file:`...) quita el
///   `href`, aunque venga disfrazado con entidades, espacios o mayúsculas.
/// * Imágenes: solo `https` y de hosts que acepte [isImageUrlAllowed]
///   (lista blanca `mediaHosts`, SC-043). Sin `srcset`.
///
/// Es Dart puro: vive en `domain/` y no depende de Flutter.
final class HtmlSanitizer {
  const new({
    required this.isImageUrlAllowed,
    this.maxLength = defaultMaxLength,
  });

  /// Decide si la URL de una imagen incrustada se puede pedir.
  final bool Function(String url) isImageUrlAllowed;

  /// Tope de entrada: lo que exceda se descarta (protege memoria y tiempo).
  final int maxLength;

  static const defaultMaxLength = 200000;

  static const _maxDepth = 64;

  /// Etiquetas con contenido que NO se debe conservar jamás.
  static const _dropWithContent = {
    'script',
    'style',
    'iframe',
    'frame',
    'frameset',
    'object',
    'embed',
    'applet',
    'form',
    'svg',
    'math',
    'noscript',
    'noembed',
    'noframes',
    'template',
    'textarea',
    'select',
    'option',
    'button',
    'audio',
    'video',
    'canvas',
    'title',
    'head',
    'xmp',
    'plaintext',
    'listing',
  };

  static const _voidTags = {'br', 'hr', 'img'};

  static const _allowedTags = {
    'p',
    'br',
    'hr',
    'div',
    'span',
    'strong',
    'b',
    'em',
    'i',
    'u',
    's',
    'small',
    'sub',
    'sup',
    'mark',
    'ul',
    'ol',
    'li',
    'dl',
    'dt',
    'dd',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'pre',
    'code',
    'table',
    'caption',
    'thead',
    'tbody',
    'tfoot',
    'tr',
    'th',
    'td',
    'a',
    'img',
  };

  /// Devuelve HTML seguro derivado de [html].
  String sanitize(String html) {
    final src = html.length > maxLength ? html.substring(0, maxLength) : html;
    final out = StringBuffer();
    final open = <String>[];
    final n = src.length;
    var i = 0;

    while (i < n) {
      final lt = src.indexOf('<', i);
      if (lt < 0) {
        out.write(src.substring(i));
        break;
      }
      out.write(src.substring(i, lt));
      i = lt;

      // Comentarios: se descartan (también los condicionales de IE).
      if (src.startsWith('<!--', i)) {
        final end = src.indexOf('-->', i + 4);
        i = end < 0 ? n : end + 3;
        continue;
      }
      if (src.startsWith('<![CDATA[', i)) {
        final end = src.indexOf(']]>', i + 9);
        i = end < 0 ? n : end + 3;
        continue;
      }
      // `<!doctype>` y `<?xml ?>`: se descartan.
      if (i + 1 < n && (src[i + 1] == '!' || src[i + 1] == '?')) {
        final end = src.indexOf('>', i);
        i = end < 0 ? n : end + 1;
        continue;
      }
      // Etiqueta de cierre.
      if (i + 1 < n && src[i + 1] == '/') {
        final m = _closeTag.matchAsPrefix(src, i);
        if (m == null) {
          out.write('&lt;');
          i++;
          continue;
        }
        i = m.end;
        final name = m.group(1)!.toLowerCase();
        final at = open.lastIndexOf(name);
        if (at >= 0) {
          while (open.length > at) {
            out.write('</${open.removeLast()}>');
          }
        }
        continue;
      }
      // Etiqueta de apertura.
      final nameMatch = _openName.matchAsPrefix(src, i);
      if (nameMatch == null) {
        out.write('&lt;'); // `<` suelto: texto, nunca etiqueta.
        i++;
        continue;
      }
      final name = nameMatch.group(1)!.toLowerCase();
      final parsed = _parseAttributes(src, nameMatch.end);
      if (parsed == null) {
        // Etiqueta sin cerrar: se descarta todo lo que sigue.
        i = n;
        continue;
      }
      i = parsed.end;

      if (_dropWithContent.contains(name)) {
        i = _skipElement(src, name, i);
        continue;
      }
      if (!_allowedTags.contains(name)) {
        continue; // quita la etiqueta, deja texto
      }
      if (!_voidTags.contains(name) && open.length >= _maxDepth) continue;

      final attrs = _safeAttributes(name, parsed.attributes);
      if (name == 'img' && attrs == null) continue;
      out
        ..write('<')
        ..write(name)
        ..write(attrs ?? '')
        ..write('>');
      if (!_voidTags.contains(name)) open.add(name);
    }

    while (open.isNotEmpty) {
      out.write('</${open.removeLast()}>');
    }
    return out.toString();
  }

  /// ¿Queda algo que mostrar? Falso si el HTML ya saneado no tiene texto ni
  /// imágenes (para omitir la sección sin dejar encabezados vacíos,
  /// AC-027-5).
  static bool hasVisibleContent(String sanitized) {
    if (sanitized.contains('<img')) return true;
    final text = sanitized
        .replaceAll(RegExp('<[^>]*>'), '')
        .replaceAll(RegExp('&nbsp;|&#160;|&#xa0;', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s ]+'), '');
    return text.isNotEmpty;
  }

  static final _closeTag = RegExp('</([a-zA-Z][a-zA-Z0-9]*)[^>]*>');
  static final _openName = RegExp('<([a-zA-Z][a-zA-Z0-9]*)');

  /// Salta hasta después de la etiqueta de cierre de [name]; si no existe,
  /// descarta el resto del documento.
  int _skipElement(String src, String name, int from) {
    final close = RegExp('</$name[\\s/>]', caseSensitive: false);
    final m = close.firstMatch(src.substring(from));
    if (m == null) return src.length;
    final closeStart = from + m.start;
    final end = src.indexOf('>', closeStart);
    return end < 0 ? src.length : end + 1;
  }

  /// Lee los atributos desde [from] hasta el `>` que cierra la etiqueta
  /// (respetando comillas). `null` si la etiqueta no termina.
  ({int end, Map<String, String> attributes})? _parseAttributes(
    String src,
    int from,
  ) {
    final attrs = <String, String>{};
    final n = src.length;
    var i = from;
    while (i < n) {
      final c = src[i];
      if (c == '>') return (end: i + 1, attributes: attrs);
      if (_isSpace(c) || c == '/') {
        i++;
        continue;
      }
      // Nombre del atributo.
      final nameStart = i;
      while (i < n &&
          !_isSpace(src[i]) &&
          src[i] != '=' &&
          src[i] != '>' &&
          src[i] != '/') {
        i++;
      }
      var name = src.substring(nameStart, i).toLowerCase();
      if (name.isEmpty) {
        i++;
        continue;
      }
      while (i < n && _isSpace(src[i])) {
        i++;
      }
      var value = '';
      if (i < n && src[i] == '=') {
        i++;
        while (i < n && _isSpace(src[i])) {
          i++;
        }
        if (i < n && (src[i] == '"' || src[i] == "'")) {
          final quote = src[i];
          final close = src.indexOf(quote, i + 1);
          if (close < 0) return null;
          value = src.substring(i + 1, close);
          i = close + 1;
        } else {
          final valueStart = i;
          while (i < n && !_isSpace(src[i]) && src[i] != '>') {
            i++;
          }
          value = src.substring(valueStart, i);
        }
      }
      // El primer valor de un atributo repetido gana (como los navegadores).
      name = name.trim();
      attrs.putIfAbsent(name, () => _decodeEntities(value));
    }
    return null;
  }

  static bool _isSpace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\f';

  /// Atributos permitidos de [tag] ya validados y escapados (con espacio
  /// inicial) o `null` si la etiqueta no es válida sin ellos (`img`).
  String? _safeAttributes(String tag, Map<String, String> attrs) {
    final buf = StringBuffer();
    void put(String key, String value) =>
        buf.write(' $key="${_escapeAttribute(value)}"');

    switch (tag) {
      case 'a':
        final href = _safeHttpsUrl(attrs['href']);
        if (href != null) put('href', href);
        final title = attrs['title'];
        if (title != null && title.isNotEmpty) put('title', title);
      case 'img':
        final src = _safeHttpsUrl(attrs['src']);
        if (src == null || !isImageUrlAllowed(src)) return null;
        put('src', src);
        final alt = attrs['alt'];
        if (alt != null) put('alt', alt);
        final title = attrs['title'];
        if (title != null && title.isNotEmpty) put('title', title);
        for (final dim in const ['width', 'height']) {
          final v = attrs[dim];
          if (v != null && RegExp(r'^[0-9]{1,4}$').hasMatch(v.trim())) {
            put(dim, v.trim());
          }
        }
      case 'td' || 'th':
        for (final span in const ['colspan', 'rowspan']) {
          final v = attrs[span];
          if (v != null && RegExp(r'^[0-9]{1,2}$').hasMatch(v.trim())) {
            put(span, v.trim());
          }
        }
    }
    return buf.toString();
  }

  /// URL `https` válida o `null`. Quita espacios y caracteres de control
  /// (que los navegadores ignoran dentro del esquema) antes de validar.
  static String? _safeHttpsUrl(String? raw) {
    if (raw == null) return null;
    final compact = raw.replaceAll(RegExp(r'[\u0000- \u007f-\u009f]'), '');
    if (compact.isEmpty || !compact.toLowerCase().startsWith('https://')) {
      return null;
    }
    final uri = Uri.tryParse(compact);
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != 'https') return null;
    if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
    return compact;
  }

  static String _escapeAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static const _named = {
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'colon': ':',
    'tab': '\t',
    'newline': '\n',
    'sol': '/',
    'lpar': '(',
    'rpar': ')',
  };

  /// Decodifica entidades en un valor de atributo para validarlo como lo haría
  /// un navegador (`jav&#x61;script:` → `javascript:`).
  static String _decodeEntities(String value) {
    if (!value.contains('&')) return value;
    return value.replaceAllMapped(
      RegExp(
        '&(?:#([0-9]{1,7})|#[xX]([0-9a-fA-F]{1,6})|([a-zA-Z][a-zA-Z0-9]{1,10}));?',
      ),
      (m) {
        final dec = m.group(1);
        final hex = m.group(2);
        final named = m.group(3);
        int? code;
        if (dec != null) code = int.tryParse(dec);
        if (hex != null) code = int.tryParse(hex, radix: 16);
        if (code != null) {
          if (code <= 0 || code > 0x10FFFF) return '';
          return String.fromCharCode(code);
        }
        return _named[named!.toLowerCase()] ?? m.group(0)!;
      },
    );
  }
}
