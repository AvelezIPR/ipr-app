import 'package:ipr_mobile/app/bootstrap.dart';
import 'package:ipr_mobile/app/flavor.dart';

/// Ejecutar con `--dart-define-from-file=config/staging.json`.
Future<void> main() => bootstrap(Flavor.staging);
