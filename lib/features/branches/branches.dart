// API pública de la feature `branches` (M5: sedes).
export 'branches_providers.dart' show branchesRepositoryProvider;
export 'domain/entities/branch.dart'
    show
        Branch,
        BranchPhone,
        BranchPhoneType,
        CityBranchGroup,
        groupBranchesByCity;
export 'domain/repositories/branches_repository.dart'
    show BranchesRepository, BranchesSnapshot;
export 'domain/rules/branch_maps_uri.dart' show buildBranchMapsUri;
export 'presentation/screens/branch_detail_screen.dart' show BranchDetailScreen;
export 'presentation/screens/branches_screen.dart' show BranchesScreen;
