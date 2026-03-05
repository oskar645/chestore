class HomeFiltersState {
  final String category;
  final String subcategory;
  final String location;
  final bool preferLocationFirst;
  final int? radiusKm;
  final String carConditionFilter;
  final String carBrandFilter;
  final String carModelFilter;
  final String carDriveFilter;
  final String carBodyFilter;

  const HomeFiltersState({
    required this.category,
    required this.subcategory,
    required this.location,
    required this.preferLocationFirst,
    required this.radiusKm,
    required this.carConditionFilter,
    required this.carBrandFilter,
    required this.carModelFilter,
    required this.carDriveFilter,
    required this.carBodyFilter,
  });
}

class HomeFiltersSession {
  HomeFiltersSession._();

  static final HomeFiltersSession instance = HomeFiltersSession._();

  final Map<String, HomeFiltersState> _byUser = <String, HomeFiltersState>{};

  HomeFiltersState? read(String uid) {
    final key = uid.trim();
    if (key.isEmpty) return null;
    return _byUser[key];
  }

  void write({
    required String uid,
    required String category,
    required String subcategory,
    required String location,
    required bool preferLocationFirst,
    required int? radiusKm,
    required String carConditionFilter,
    required String carBrandFilter,
    required String carModelFilter,
    required String carDriveFilter,
    required String carBodyFilter,
  }) {
    final key = uid.trim();
    if (key.isEmpty) return;
    _byUser[key] = HomeFiltersState(
      category: category,
      subcategory: subcategory,
      location: location,
      preferLocationFirst: preferLocationFirst,
      radiusKm: radiusKm,
      carConditionFilter: carConditionFilter,
      carBrandFilter: carBrandFilter,
      carModelFilter: carModelFilter,
      carDriveFilter: carDriveFilter,
      carBodyFilter: carBodyFilter,
    );
  }

  void clear(String uid) {
    final key = uid.trim();
    if (key.isEmpty) return;
    _byUser.remove(key);
  }
}

final homeFiltersSession = HomeFiltersSession.instance;
