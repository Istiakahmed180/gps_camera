enum UnitSystem {
  metric('Metres', 'm'),
  imperial('Feet', 'ft');

  const UnitSystem(this.label, this.symbol);

  final String label;
  final String symbol;
}

/// How times and distances are shown: watermark, camera, details and
/// reports. Stored values are always metres and UTC; only display changes.
class DisplayFormat {
  const DisplayFormat({this.use24Hour = false, this.units = UnitSystem.metric});

  factory DisplayFormat.fromJson(Map<String, dynamic> json) => DisplayFormat(
    use24Hour: json['use24Hour'] == true,
    units: UnitSystem.values.firstWhere(
      (u) => u.name == json['units'],
      orElse: () => UnitSystem.metric,
    ),
  );

  /// The app-wide choice. Set at startup and by Settings; a report isolate
  /// receives it through its job.
  static DisplayFormat current = const DisplayFormat();

  static const double feetPerMetre = 3.280839895;

  final bool use24Hour;
  final UnitSystem units;

  /// [meters] in the chosen unit, unrounded.
  double convert(double meters) =>
      units == UnitSystem.imperial ? meters * feetPerMetre : meters;

  DisplayFormat copyWith({bool? use24Hour, UnitSystem? units}) => DisplayFormat(
    use24Hour: use24Hour ?? this.use24Hour,
    units: units ?? this.units,
  );

  Map<String, dynamic> toJson() => {
    'use24Hour': use24Hour,
    'units': units.name,
  };

  @override
  bool operator ==(Object other) =>
      other is DisplayFormat &&
      other.use24Hour == use24Hour &&
      other.units == units;

  @override
  int get hashCode => Object.hash(use24Hour, units);
}
