import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';

/// Envuelve una pantalla sensible (login, registro, perfil, direcciones,
/// pedidos, checkout, resultado, eliminación de cuenta): activa la protección
/// de captura mientras está visible y la desactiva al salir (SC-035).
class SensitiveScreen extends StatefulWidget {
  const new({required this.protection, required this.child, super.key});

  final ScreenProtection protection;
  final Widget child;

  @override
  State<SensitiveScreen> createState() => _SensitiveScreenState();
}

class _SensitiveScreenState extends State<SensitiveScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.protection.enable());
  }

  @override
  void dispose() {
    unawaited(widget.protection.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
