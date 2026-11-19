import 'package:ipr_mobile/core/errors/app_failure.dart';

/// Resultado de una operación: valor o [AppFailure]. Sustituye a las
/// excepciones de red en la frontera de los repositorios.
sealed class Result<T> {
  const new();

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// Valor o `null` si falló.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// Fallo o `null` si fue exitoso.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  R when<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) => switch (this) {
    Ok<T>(:final value) => ok(value),
    Err<T>(:final failure) => err(failure),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok(transform(value)),
    Err<T>(:final failure) => Err(failure),
  };
}

final class Ok<T> extends Result<T> {
  const new(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const new(this.failure);
  final AppFailure failure;
}
