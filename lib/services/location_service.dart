import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zitlac_location_app/services/storage_service.dart';
import '../models/daily_summary.dart';
import '../models/geofence.dart';
import 'geofence_service.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static bool _isTracking = false;

  static Future<bool> checkPermissions() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) print("Location services are disabled.");
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) print("Location permission denied. Requesting...");
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) print("Location permission was denied by user.");
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) print("Location permission denied forever.");
      return false;
    }
    if (kDebugMode) print("Location permissions are granted.");
    return true;
  }

  static Future<bool> isLocationServiceEnabled() async => await Geolocator.isLocationServiceEnabled();
  static Future<bool> requestLocationService() async => await Geolocator.openLocationSettings();
  static Future<LocationPermission> requestPermission() async => await Geolocator.requestPermission();

  static Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await checkPermissions(); 
      if (!hasPermission) {
        if (kDebugMode) print("Cannot get current position: Permissions not granted or service disabled.");
        return null; 
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      if (kDebugMode) print("Error getting current position: $e");
      return null;
    }
  }

  static Future<void> initializeNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      "location_tracking_channel", "Tracking location",
      description: "Tracking location...", importance: Importance.low,
      playSound: true, enableVibration: true, enableLights: false, showBadge: false,
    );
    final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  static Future<void> startLocationService(BuildContext context) async {
    if (_isTracking) return;
    final hasPermission = await checkPermissions();
    if (!hasPermission) throw Exception('Location permissions not granted. Cannot start service.');
    _isTracking = true;
    startPushingLocationUpdates();
  }

  static void stopLocationService() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    stopPushingLocationUpdates();
  }

  static bool get isTracking => _isTracking;

  static Future<bool> startPushingLocationUpdates() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        initialNotificationTitle: "Tracking location", initialNotificationContent: "Tracking in background",
        notificationChannelId: "location_tracking_channel", autoStart: false, autoStartOnBoot: false,
        foregroundServiceNotificationId: 888, foregroundServiceTypes: [AndroidForegroundType.location],
        onStart: onStartLocationUpdates, isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(),
    );
    return await service.startService();
  }

  static void stopPushingLocationUpdates() => FlutterBackgroundService().invoke("stopService");
}

@pragma('vm:entry-point')
void onStartLocationUpdates(ServiceInstance service) async {
  StreamSubscription<Position>? _positionUpdatesStream;
  DateTime _lastLocationUpdateTime = DateTime.now();
  DailySummary? _currentSummary;
  
  final StorageService storageService = StorageService();
  await storageService.init();
  List<Geofence> geofences = await storageService.getGeofences();
  final customGeofences = [
    Geofence(id: 'home', name: 'Home', latitude: 37.7743583, longitude: -122.4202183, radius: 50.0),
    Geofence(id: 'office', name: 'Office', latitude: 37.7858, longitude: -122.4364, radius: 50.0),
  ];
  geofences.addAll(customGeofences);

  LocationSettings activeSettings = const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 10);
  LocationSettings stationarySettings = const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 50,);
  LocationSettings currentStreamSettings = activeSettings;
  bool isUserStationary = false;
  Position? lastTrackedPositionForStationaryCheck;
  DateTime? lastSignificantMoveTimestamp = DateTime.now();
  const Duration stationaryDurationThreshold = Duration(minutes: 3);
  const double stationaryMovementThreshold = 15.0; // meters
  const double significantMovementThreshold = 20.0; // meters

  Future<void> initializeSummaryForCurrentDay() async {
    DateTime now = DateTime.now();
    _currentSummary = await storageService.getDailySummary(now);
    _currentSummary ??= DailySummary(date: DateTime(now.year, now.month, now.day), timeInLocations: {}, travelingTime: Duration.zero);
    _lastLocationUpdateTime = now; // Reset for delta calculation
  }

  Future<void> startOrRestartPositionStream(LocationSettings settings) async {
    await _positionUpdatesStream?.cancel();
    currentStreamSettings = settings;
    if (kDebugMode) print("Starting stream with: accuracy=${settings.accuracy}, filter=${settings.distanceFilter}, interval=60 seconds");
    
    await initializeSummaryForCurrentDay(); // Ensure summary and lastUpdateTime are fresh for the new stream

    _positionUpdatesStream = Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position? position) async {
        if (position == null) return;
        final DateTime now = DateTime.now();

        if (_currentSummary != null && (now.year != _currentSummary!.date.year || now.month != _currentSummary!.date.month || now.day != _currentSummary!.date.day)) {
          if (kDebugMode) print("Day changed. Old: ${_currentSummary!.date}, New: $now");
          await storageService.saveDailySummary(_currentSummary!); 
          await initializeSummaryForCurrentDay(); // Initializes for new day and resets _lastLocationUpdateTime
        }
        _currentSummary ??= DailySummary(date: DateTime(now.year, now.month, now.day), timeInLocations: {}, travelingTime: Duration.zero);

        double distanceMoved = 0;
        if (lastTrackedPositionForStationaryCheck != null) {
          distanceMoved = Geolocator.distanceBetween(
            lastTrackedPositionForStationaryCheck!.latitude, lastTrackedPositionForStationaryCheck!.longitude,
            position.latitude, position.longitude
          );
        }

        if (!isUserStationary) {
          if (distanceMoved < stationaryMovementThreshold) {
            if (now.difference(lastSignificantMoveTimestamp!) > stationaryDurationThreshold) {
              isUserStationary = true;
              if (kDebugMode) print("User stationary. Switching to low power mode.");
              if (_currentSummary != null) await storageService.saveDailySummary(_currentSummary!);
              startOrRestartPositionStream(stationarySettings); 
              return;
            }
          } else {
            lastSignificantMoveTimestamp = now;
          }
        } else {
          if (distanceMoved > significantMovementThreshold) {
            isUserStationary = false;
            lastSignificantMoveTimestamp = now;
            if (kDebugMode) print("User moving. Switching to active mode.");
            if (_currentSummary != null) await storageService.saveDailySummary(_currentSummary!);
            startOrRestartPositionStream(activeSettings);
            return;
          }
        }
        lastTrackedPositionForStationaryCheck = position;
        
        final timeDelta = now.difference(_lastLocationUpdateTime);
        if (timeDelta.isNegative) {
            if (kDebugMode) print("Corrected negative timeDelta. Resetting lastLocationUpdateTime.");
             _lastLocationUpdateTime = now; // Reset and skip this delta calculation
        } else {
            final insideGeofences = await GeofenceService.checkGeofences(position.latitude, position.longitude, geofences);
            if (insideGeofences.isNotEmpty) {
              for (Geofence geofenceEntry in insideGeofences) {
                _currentSummary = _currentSummary!.addTimeToLocation(geofenceEntry.id, timeDelta);
              }
            } else {
              _currentSummary = _currentSummary!.addTravelingTime(timeDelta);
            }
            _lastLocationUpdateTime = now;
            await storageService.saveDailySummary(_currentSummary!); 
        }
      },
      onError: (error) { if (kDebugMode) print("Position Stream Error: $error"); },
      onDone: () { if (kDebugMode) print("Position Stream Done"); },
    );
  }

  await initializeSummaryForCurrentDay(); // Initial summary load
  startOrRestartPositionStream(currentStreamSettings); // Start with initial settings

  service.on('stopService').listen((event) async {
    await _positionUpdatesStream?.cancel();
    if (_currentSummary != null) await storageService.saveDailySummary(_currentSummary!); 
    service.stopSelf();
    if (kDebugMode) print("Location service stopped, final summary saved.");
  });
}
