import 'package:ipr_mobile/app/bootstrap.dart';
import 'package:ipr_mobile/app/flavor.dart';

/// Ejecutar con `--dart-define-from-file=config/dev.json`.
Future<void> main() => bootstrap(Flavor.dev);
