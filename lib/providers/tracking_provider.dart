import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:zitlac_location_app/models/geofence.dart';
import '../models/daily_summary.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class TrackingProvider with ChangeNotifier {
  bool _isTracking = false;
  DailySummary? _currentSummary;
  bool _isLoadingSummary = false;

  bool get isTracking => _isTracking;
  DailySummary? get currentSummary => _currentSummary;
  bool get isLoadingSummary => _isLoadingSummary;

  late StorageService storageService;

  TrackingProvider() {

    storageService = StorageService();
    storageService.init().then((_) {

      getCurrentDaySummary(); 
    });
  }

  Future<void> getCurrentDaySummary() async {
    _isLoadingSummary = true;
    notifyListeners();



    _isTracking = await storageService.isTrackingOn();

    final today = DateTime.now();
    final todaySummary = await storageService.getDailySummary(today);

    if (todaySummary != null) {
      _currentSummary = todaySummary;
    } else {
      _currentSummary = DailySummary(
        date: DateTime(today.year, today.month, today.day),
        timeInLocations: {}, 
        travelingTime: Duration.zero,
      );

    }
    _isLoadingSummary = false;
    notifyListeners();
  }


  Future<void> loadSummaryForDate(DateTime selectedDate) async {
    _isLoadingSummary = true;
    notifyListeners();



    final summary = await storageService.getDailySummary(selectedDate);

    if (summary != null) {
      _currentSummary = summary;
    } else {

      _currentSummary = DailySummary(
        date: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        timeInLocations: {},
        travelingTime: Duration.zero,
      );
    }
    _isLoadingSummary = false;
    notifyListeners();
  }

  void startTracking(BuildContext context) async {
    _isTracking = true;
    storageService.turnTrackingOn_Or_Off(true);
    LocationService.startLocationService(context);
    notifyListeners();
  }

  void stopTracking() async {
    _isTracking = false;
    storageService.turnTrackingOn_Or_Off(false);
    LocationService.stopLocationService();
    notifyListeners();
  }

}
