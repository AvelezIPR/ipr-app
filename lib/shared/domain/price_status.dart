import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:meta/meta.dart';

/// Estado del precio de un producto.
///
/// [OnRequest] (sin precio en WooCommerce) muestra "Más información" →
/// WhatsApp y **nunca** "$0" (RF-012, ADR-002).
sealed class PriceStatus {
  const new();

  /// Interpreta `price.status` / `price.amount` del contrato. Defensa en
  /// profundidad: un precio 0, negativo, ausente o ilegible se trata como
  /// [OnRequest], aunque el servidor diga `priced`.
  factory fromContract({required String? status, Object? amount}) {
    if (status == 'priced') {
      final money = Money.tryFromJson(amount);
      if (money != null && !money.isZero) return Priced(money);
    }
    return const OnRequest();
  }

  bool get hasPrice => this is Priced;
}

@immutable
final class Priced extends PriceStatus {
  const new(this.amount);
  final Money amount;

  @override
  bool operator ==(Object other) => other is Priced && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;
}

@immutable
final class OnRequest extends PriceStatus {
  const new();

  @override
  bool operator ==(Object other) => other is OnRequest;

  @override
  int get hashCode => 0;
}
