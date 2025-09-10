import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
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

  static const FOREGRROUND_NOTIFICATION_ID = "002";

  static Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        print("Location permission denied. Requesting...");
      }
      permission = await requestPermission(); // Uses the new explicit method
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print("Location permission was denied by user.");
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print("Location permission denied forever.");
      }
      return false;
    }

    if (kDebugMode) {
      print("Location permissions are granted.");
    }
    return true;
  }

  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<bool> requestLocationService() async {
    return await Geolocator.openLocationSettings();
  }

  static Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      // First, check if permissions are granted and service is enabled
      bool hasPermission = await checkPermissions();
      if (!hasPermission) {
        if (kDebugMode) {
          print(
            "Cannot get current position: Permissions not granted or service disabled.",
          );
        }
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error getting current position: $e");
      }
      return null;
    }
  }

  static Future<void> initializeNotificationChannel() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    const AndroidNotificationChannel driverOnlineChannel =
        AndroidNotificationChannel(
          FOREGRROUND_NOTIFICATION_ID,
          "Tracking location",
          description: "Tracking lccation...",
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          showBadge: false,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(driverOnlineChannel);
  }

  static Future<void> startLocationService(BuildContext context) async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      // Consider showing a message to the user via BuildContext if available and appropriate
      // For a service, throwing an exception might be more direct.
      throw Exception(
        'Location permissions not granted. Cannot start service.',
      );
    }

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
        initialNotificationTitle: "Tracking location",
        initialNotificationContent: "Tracking in background",
        notificationChannelId: FOREGRROUND_NOTIFICATION_ID,
        autoStart: false,
        autoStartOnBoot: false,
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
        onStart: onStartLocationUpdates,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(),
    );

    final result = await service.startService();
    return result;
  }

  static void stopPushingLocationUpdates() {
    FlutterBackgroundService().invoke("stopService");
  }
}

@pragma('vm:entry-point')
void onStartLocationUpdates(ServiceInstance service) async {
  StreamSubscription<Position>? _positionUpdatesStream;
  DateTime _lastLocationUpdateTime = DateTime.now().toUtc();

  final storageService = StorageService();
  await storageService.init();

  bool isTrackingOn = await storageService.isTrackingOn();

  // this is done because this isolate can be triggered by dart on startup
  if (!isTrackingOn) {
    if (kDebugMode) {
      print("Tracking is turned off. Exiting location service.");
    }
    service.stopSelf();
    return;
  }

  List<Geofence> geofences = await storageService.getGeofences();

  // These are hardcoded geofences.
  final customGeofences = [
    Geofence(
      id: 'home',
      name: 'Home',
      latitude: 37.7743583,
      longitude: -122.4202183,
      radius: 50.0,
    ),
    Geofence(
      id: 'office',
      name: 'Office',
      latitude: 37.7858,
      longitude: -122.4364,
      radius: 50.0,
    ),
  ];
  geofences.addAll(customGeofences);

  // Initialize summary for the day the service starts
  DateTime serviceStartDate = DateTime.now().toUtc();
  DailySummary? _currentSummary = await storageService.getDailySummary(
    serviceStartDate,
  );
  _currentSummary ??= DailySummary(
    date: DateTime(
      serviceStartDate.year,
      serviceStartDate.month,
      serviceStartDate.day,
    ).toUtc(),
    timeInLocations: {},
    travelingTime: Duration.zero,
  );

  if (kDebugMode) {
    print(
      "Location service started. Initial summary for date: ${_currentSummary.date}",
    );
  }

  _positionUpdatesStream =
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        (Position? position) async {
          if (position != null) {
            final now = DateTime.now()
                .toUtc(); // Current timestamp for this position update

            // Check for day change based on _currentSummary's date
            if (_currentSummary != null &&
                (now.year != _currentSummary!.date.year ||
                    now.month != _currentSummary!.date.month ||
                    now.day != _currentSummary!.date.day)) {
              if (kDebugMode) {
                print(
                  "Day changed detected. Old summary date: ${_currentSummary!.date}, New date: $now",
                );
              }
              // Save the completed summary for the previous day
              await storageService.saveDailySummary(_currentSummary!);
              if (kDebugMode) {
                print("Saved summary for ${_currentSummary!.date}.");
              }

              // Create a new summary for the new day
              _currentSummary = DailySummary(
                date: DateTime(now.year, now.month, now.day),
                timeInLocations: {}, // Reset times for the new day
                travelingTime:
                    Duration.zero, // Reset travel time for the new day
              );
              _lastLocationUpdateTime =
                  now; // Reset last update time to now for accurate delta on new day
              if (kDebugMode) {
                print(
                  "Created new summary for ${_currentSummary!.date}. Reset _lastLocationUpdateTime to $now.",
                );
              }
            }

            _currentSummary ??= DailySummary(
              date: DateTime(now.year, now.month, now.day).toUtc(),
              timeInLocations: {},
              travelingTime: Duration.zero,
            );

            final timeDelta = now.difference(_lastLocationUpdateTime);

            final insideGeofences = await GeofenceService.checkGeofences(
              position.latitude,
              position.longitude,
              geofences, // Using geofences loaded/combined at service start
            );

            if (insideGeofences.isNotEmpty) {
              for (Geofence geofenceEntry in insideGeofences) {
                _currentSummary = _currentSummary!.addTimeToLocation(
                  geofenceEntry.id,
                  timeDelta,
                );
              }
            } else {
              _currentSummary = _currentSummary!.addTravelingTime(timeDelta);
            }

            _lastLocationUpdateTime = now; // Update for the next position event
            await storageService.saveDailySummary(
              _currentSummary!,
            ); // Save the potentially updated/new summary

            // keep checking if tracking is still on
            isTrackingOn = await storageService.isTrackingOn();
          }
        },
        onError: (error, stackTrace) async {
          if (kDebugMode) {
            print("Error in position stream: $error, StackTrace: $stackTrace");
          }
        },
        onDone: () {
          if (kDebugMode) {
            print("Position stream done.");
          }
        },
      );

  service.on('stopService').listen((event) async {
    storageService.turnTrackingOn_Or_Off(false);
    if (kDebugMode) {
      print(
        "'stopService' event received. Cancelling position stream and saving final summary.",
      );
    }
    await _positionUpdatesStream?.cancel();
    _positionUpdatesStream = null;
    if (_currentSummary != null) {
      await storageService.saveDailySummary(
        _currentSummary!,
      ); // Save the very last summary
      if (kDebugMode) {
        print(
          "Final summary saved for ${_currentSummary!.date} on stopService event.",
        );
      }
    }

    service.stopSelf();
  });
}
