import 'package:meta/meta.dart';

/// Contenido de una sección del inicio junto con su frescura.
///
/// [stale] es verdadero cuando se muestran datos guardados (la red falló o el
/// servidor avisó `X-IPR-Data-State: stale`): la interfaz añade el aviso.
@immutable
final class SectionData<T> {
  const new(this.value, {this.stale = false});

  final T value;
  final bool stale;
}
