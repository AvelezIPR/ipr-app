// API pública de la feature `support` (M2 + M5).
export 'domain/entities/pqrs.dart' show PqrsReceipt, PqrsSubmission, PqrsType;
export 'domain/repositories/pqrs_repository.dart' show PqrsRepository;
export 'domain/rules/pqrs_validation.dart' show PqrsField, PqrsValidation;
export 'presentation/screens/engineering_screen.dart' show EngineeringScreen;
export 'presentation/screens/help_screen.dart' show HelpScreen;
export 'presentation/screens/legal_screen.dart' show LegalScreen;
export 'presentation/screens/pqrs_screen.dart' show PqrsScreen;
export 'support_providers.dart'
    show pqrsRepositoryProvider, supportUuidProvider;
