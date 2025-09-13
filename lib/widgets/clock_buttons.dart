import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:zitlac_location_app/providers/geofence_provider.dart';
import '../providers/tracking_provider.dart';
import '../services/location_service.dart';

class ClockButtons extends StatelessWidget {
  const ClockButtons({super.key});



  @override
  Widget build(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context);
    final geoFenceProvider = Provider.of<GeofenceProvider>(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: trackingProvider.isTracking
              ? null
              : () async {
            bool hasPermission = await LocationService.checkPermissions();
            if (!hasPermission) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location permissions required')),
              );
              await LocationService.requestPermission();
              return;
            }

            bool serviceEnabled = await LocationService.isLocationServiceEnabled();
            if (!serviceEnabled) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location services are disabled.')),
              );

              await LocationService.requestLocationService();
              return;
            }

            final Position? currentPosition =
            await LocationService.getCurrentPosition();

            if (currentPosition == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not fetch current location.')),
              );
              return;
            }

            trackingProvider.startTracking(context);

          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          ),
          child: const Text('Clock In', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: trackingProvider.isTracking
              ? () {
            trackingProvider.stopTracking();
          }
              : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          ),
          child: const Text('Clock Out', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(height: 30),
        Text(
          trackingProvider.isTracking ? 'Tracking Active' : 'Not Tracking',
          style: TextStyle(
            fontSize: 18,
            color: trackingProvider.isTracking ? Colors.green : Colors.grey,
          ),
        ),
      ],
    );
  }
}