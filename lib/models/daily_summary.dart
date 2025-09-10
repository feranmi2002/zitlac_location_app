class DailySummary {
  final DateTime date;
  final Map<String, int> timeInLocations; // microseconds
  final int travelingTimeMicroseconds;

  DailySummary({
    required this.date,
    required Map<String, Duration> timeInLocations,
    required Duration travelingTime,
  })  : timeInLocations = timeInLocations.map((locationId, durationSpent) => MapEntry(locationId, durationSpent.inMicroseconds)),
        travelingTimeMicroseconds = travelingTime.inMicroseconds;

  Duration get travelingTime => Duration(microseconds: travelingTimeMicroseconds);

  Map<String, Duration> get timeInLocationsAsDuration =>
      timeInLocations.map((locationId, durationSpent) => MapEntry(locationId, Duration(microseconds: durationSpent)));

  DailySummary addTimeToLocation(String locationId, Duration duration) {
    final updatedTimes = Map<String, int>.from(timeInLocations);
    updatedTimes[locationId] = (updatedTimes[locationId] ?? 0) + duration.inMicroseconds;

    return DailySummary(
      date: date,
      timeInLocations: updatedTimes.map((k, v) => MapEntry(k, Duration(microseconds: v))),
      travelingTime: Duration(microseconds: travelingTimeMicroseconds),
    );
  }

  DailySummary addTravelingTime(Duration duration) {
    return DailySummary(
      date: date,
      timeInLocations: timeInLocations.map((k, v) => MapEntry(k, Duration(microseconds: v))),
      travelingTime: Duration(microseconds: travelingTimeMicroseconds + duration.inMicroseconds),
    );
  }

  Duration getLocationDuration(String locationId) {
    return Duration(microseconds: timeInLocations[locationId] ?? 0);
  }

  /// 🔹 Serialization
  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'timeInLocations': timeInLocations,
      'travelingTimeMicroseconds': travelingTimeMicroseconds,
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      date: DateTime.parse(map['date']),
      timeInLocations: (map['timeInLocations'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, Duration(microseconds: v as int))),
      travelingTime: Duration(microseconds: map['travelingTimeMicroseconds'] as int),
    );
  }
}
