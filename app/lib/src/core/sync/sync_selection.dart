/// Independently selected content for an upload or a pull.
class SyncSelection {
  final bool accounts;
  final bool settings;
  final bool favorites;
  final bool acceleration;

  const SyncSelection({
    this.accounts = true,
    this.settings = true,
    this.favorites = true,
    this.acceleration = true,
  });

  bool get any => accounts || anySettings;
  bool get anySettings => settings || favorites || acceleration;

  static const settingKeys = {
    'skin',
    'brightness_mode',
    'hold_confirm',
    'delete_hold',
    'haptics',
    'block_screenshots',
    'auto_confirm_market',
  };

  Map<String, dynamic> selectSettings(Map<String, dynamic> document) => {
    for (final entry in document.entries)
      if ((settings && settingKeys.contains(entry.key)) ||
          (favorites && entry.key == 'market_favorites') ||
          (acceleration && entry.key == 'steam_acceleration'))
        entry.key: entry.value,
  };

  factory SyncSelection.fromJson(Object? value, {bool legacySettings = true}) {
    final json = value is Map ? value : const {};
    return SyncSelection(
      accounts: json['accounts'] is bool ? json['accounts'] as bool : true,
      settings: json['settings'] is bool
          ? json['settings'] as bool
          : legacySettings,
      favorites: json['favorites'] is bool
          ? json['favorites'] as bool
          : legacySettings,
      acceleration: json['acceleration'] is bool
          ? json['acceleration'] as bool
          : legacySettings,
    );
  }

  Map<String, dynamic> toJson() => {
    'accounts': accounts,
    'settings': settings,
    'favorites': favorites,
    'acceleration': acceleration,
  };

  SyncSelection copyWith({
    bool? accounts,
    bool? settings,
    bool? favorites,
    bool? acceleration,
  }) => SyncSelection(
    accounts: accounts ?? this.accounts,
    settings: settings ?? this.settings,
    favorites: favorites ?? this.favorites,
    acceleration: acceleration ?? this.acceleration,
  );
}
