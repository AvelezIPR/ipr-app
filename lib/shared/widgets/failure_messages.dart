import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';

/// Texto es-CO de un fallo. El mapa código → mensaje vive en `core/errors`;
/// los textos, en `l10n/app_es.arb`.
String failureText(AppLocalizations l10n, AppFailure failure) =>
    switch (failure.message) {
      FailureMessage.noConnection => l10n.failureNoConnection,
      FailureMessage.timeout => l10n.failureTimeout,
      FailureMessage.notFound => l10n.failureNotFound,
      FailureMessage.serviceUnavailable => l10n.failureServiceUnavailable,
      FailureMessage.rateLimited => l10n.failureRateLimited,
      FailureMessage.unauthorized => l10n.failureUnauthorized,
      FailureMessage.forbidden => l10n.failureForbidden,
      FailureMessage.blockedByEdge => l10n.failureBlockedByEdge,
      FailureMessage.validation => l10n.failureValidation,
      FailureMessage.conflict => l10n.failureConflict,
      FailureMessage.upgradeRequired => l10n.failureUpgradeRequired,
      FailureMessage.server => l10n.failureServer,
      FailureMessage.contract => l10n.failureContract,
      FailureMessage.unknown => l10n.failureUnknown,
    };
