import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/tracking_provider.dart';

import '../services/location_service.dart';
import '../widgets/clock_buttons.dart';
import 'add_geofence_screeen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionsAndService();
    LocationService.initializeNotificationChannel();

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state); // It's good practice to call super
    final trackingProvider = Provider.of<TrackingProvider>(context, listen: false);

    if (state == AppLifecycleState.paused && trackingProvider.isTracking) {
      if (trackingProvider.currentSummary != null) {
        // Potentially save summary if needed, though background service should handle it
      }
    }
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsAndService();
      // Refresh current day's summary data from provider when app resumes
      trackingProvider.getCurrentDaySummary(); 
    }
  }

  Future<void> _checkPermissionsAndService() async {
    bool hasPermission = await LocationService.checkPermissions();
    bool serviceEnabled = await LocationService.isLocationServiceEnabled();

    if (!mounted) return;

    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are required.')),
      );
    }

    if (!serviceEnabled) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        actions: [
          IconButton(
            icon: _isFetchingLocation 
                ? SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(strokeWidth: 2.0, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))
                  )
                : const Icon(Icons.add_location),
            onPressed: _isFetchingLocation ? null : () async {
              setState(() {
                _isFetchingLocation = true;
              });

              try {
                bool hasPermission = await LocationService.checkPermissions();
                bool serviceEnabled = await LocationService.isLocationServiceEnabled();

                if (!mounted) return;

                if (!hasPermission) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location permissions are required. Please grant permission in settings.')),
                  );
                  await LocationService.requestPermission();
                  setState(() {
                    _isFetchingLocation = false;
                  });
                  return;
                }

                if (!serviceEnabled) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location services are disabled. Please enable them.')),
                  );
                  await LocationService.requestLocationService();
                  setState(() {
                    _isFetchingLocation = false;
                  });
                  return;
                }
                
                final Position? currentPosition =
                    await LocationService.getCurrentPosition(); 

                if (!mounted) return;

                if (currentPosition != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddGeofenceScreen(
                        initialPosition: currentPosition,
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not fetch current location. Please try again.')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error fetching location: ${e.toString()}')),
                );
              } finally {
                if (mounted) {
                  setState(() {
                    _isFetchingLocation = false;
                  });
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.summarize_rounded),
            onPressed: () {
              Navigator.pushNamed(context, '/summary');
            },
          ),
        ],
      ),
      body: const Center(
        child: ClockButtons(),
      ),
    );
  }
}
