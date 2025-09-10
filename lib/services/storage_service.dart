import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_summary.dart';
import '../models/geofence.dart';

class StorageService {
  static const String dailySummaryKey = 'daily_summaries';
  static const String customGeofencesKey = 'custom_geofences';

  late SharedPreferencesAsync _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferencesAsync();
    ;
  }

  // ================= DAILY SUMMARIES =================

  Future<void> saveDailySummary(DailySummary summary) async {
    final _prefs = await SharedPreferencesAsync();

    final summariesJson = await _prefs.getString(dailySummaryKey);
    Map<String, dynamic> summaries = summariesJson != null
        ? jsonDecode(summariesJson)
        : {};

    final dateKey =
        '${summary.date.year}-${summary.date.month}-${summary.date.day}';
    summaries[dateKey] = summary.toMap();

    await _prefs.setString(dailySummaryKey, jsonEncode(summaries));
  }

  Future<DailySummary?> getDailySummary(DateTime date) async {
    final summariesJson = await _prefs.getString(dailySummaryKey);
    if (summariesJson == null) return null;

    final summaries = jsonDecode(summariesJson) as Map<String, dynamic>;
    final dateKey = '${date.year}-${date.month}-${date.day}';

    if (!summaries.containsKey(dateKey)) return null;
    return DailySummary.fromMap(Map<String, dynamic>.from(summaries[dateKey]));
  }

  Future<List<DailySummary>> getAllSummaries() async {
    final summariesJson = await _prefs.getString(dailySummaryKey);
    if (summariesJson == null) return [];

    final summaries = jsonDecode(summariesJson) as Map<String, dynamic>;
    return summaries.values
        .map((e) => DailySummary.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> deleteDailySummary(DateTime date) async {
    final summariesJson = await _prefs.getString(dailySummaryKey);
    if (summariesJson == null) return;

    final summaries = jsonDecode(summariesJson) as Map<String, dynamic>;
    final dateKey = '${date.year}-${date.month}-${date.day}';
    summaries.remove(dateKey);

    await _prefs.setString(dailySummaryKey, jsonEncode(summaries));
  }

  Future<void> clearAllSummaries() async {
    await _prefs.remove(dailySummaryKey);
  }

  // ================= GEOFENCES =================

  Future<void> saveGeofences(List<Geofence> geofences) async {
    final geofencesList = geofences.map((geofence) => geofence.toMap()).toList();
    await _prefs.setString(customGeofencesKey, jsonEncode(geofencesList));
  }

  Future<List<Geofence>> getGeofences() async {
    final geofencesJson = await _prefs.getString(customGeofencesKey);
    if (geofencesJson == null) return [];

    final decoded = jsonDecode(geofencesJson) as List<dynamic>;

    return decoded
        .map((g) => Geofence.fromMap(Map<String, dynamic>.from(g)))
        .toList();
  }

  Future<void> addGeofence(Geofence geofence) async {
    final geofences = await getGeofences();
    geofences.add(geofence);
    await saveGeofences(geofences);
  }

  Future<void> updateGeofence(Geofence updatedGeofence) async {
    final geofences = await getGeofences();
    final index = geofences.indexWhere((g) => g.id == updatedGeofence.id);
    if (index != -1) {
      geofences[index] = updatedGeofence;
      await saveGeofences(geofences);
    }
  }

  Future<void> deleteGeofence(String id) async {
    final geofences = await getGeofences();
    geofences.removeWhere((g) => g.id == id);
    await saveGeofences(geofences);
  }

  Future<void> clearAllGeofences() async {
    await _prefs.remove(customGeofencesKey);
  }
  
  Future<void> turnTrackingOn_Or_Off(bool isTracking) async {
    await _prefs.setBool('isTracking', isTracking);
  }
  
  Future<bool> isTrackingOn() async {
    return await _prefs.getBool('isTracking') ?? false;
  }
}
