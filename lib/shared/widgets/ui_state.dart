import 'package:ipr_mobile/core/errors/app_failure.dart';

/// Estado de UI cerrado de un controlador (`flutter_app_architecture.md`
/// §5.2). `Empty` solo cuando el servidor respondió 200 con una lista vacía;
/// un fallo de red es [UiFailure], nunca [UiEmpty].
sealed class UiState<T> {
  const new();
}

final class UiLoading<T> extends UiState<T> {
  const new();
}

/// Datos listos. [stale] indica que se muestran datos guardados que pueden
/// estar desactualizados (muestra `StaleBanner`).
final class UiData<T> extends UiState<T> {
  const new(this.value, {this.stale = false});
  final T value;
  final bool stale;
}

final class UiEmpty<T> extends UiState<T> {
  const new();
}

final class UiFailure<T> extends UiState<T> {
  const new(this.failure);
  final AppFailure failure;
}
