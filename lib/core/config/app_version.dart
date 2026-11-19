/// Compara dos versiones `x.y.z` (sin sufijos). Devuelve negativo, cero o
/// positivo como [Comparable.compareTo]. Lanza [FormatException] si alguna no
/// tiene el formato `x.y.z`.
int compareVersions(String a, String b) {
  List<int> parse(String v) {
    final parts = v.trim().split('+').first.split('.');
    if (parts.length != 3) throw FormatException('Versión inválida: "$v"');
    return parts.map(int.parse).toList();
  }

  final pa = parse(a);
  final pb = parse(b);
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// `true` si [current] cumple la versión mínima [minimum]. Si alguna es
/// ilegible se considera soportada (el 426 del servidor es la autoridad).
bool isVersionSupported({required String current, required String minimum}) {
  try {
    return compareVersions(current, minimum) >= 0;
  } on FormatException {
    return true;
  }
}
