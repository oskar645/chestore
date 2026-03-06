class HomeFiltersState {
  final String category;
  final String subcategory;
  final String location;
  final bool preferLocationFirst;
  final int? radiusKm;
  final String autoBrand;
  final String autoModel;
  final String autoCondition;
  final int? autoMileageTo;
  final bool onlyUncrashed;

  const HomeFiltersState({
    required this.category,
    required this.subcategory,
    required this.location,
    required this.preferLocationFirst,
    required this.radiusKm,
    required this.autoBrand,
    required this.autoModel,
    required this.autoCondition,
    required this.autoMileageTo,
    required this.onlyUncrashed,
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
    required String autoBrand,
    required String autoModel,
    required String autoCondition,
    required int? autoMileageTo,
    required bool onlyUncrashed,
  }) {
    final key = uid.trim();
    if (key.isEmpty) return;
    _byUser[key] = HomeFiltersState(
      category: category,
      subcategory: subcategory,
      location: location,
      preferLocationFirst: preferLocationFirst,
      radiusKm: radiusKm,
      autoBrand: autoBrand,
      autoModel: autoModel,
      autoCondition: autoCondition,
      autoMileageTo: autoMileageTo,
      onlyUncrashed: onlyUncrashed,
    );
  }

  void clear(String uid) {
    final key = uid.trim();
    if (key.isEmpty) return;
    _byUser.remove(key);
  }
}

final homeFiltersSession = HomeFiltersSession.instance;
