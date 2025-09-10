import 'package:flutter/foundation.dart';
import '../models/geofence.dart';
import '../services/storage_service.dart';

class GeofenceProvider with ChangeNotifier {
  List<Geofence> _geofences = [];

  List<Geofence> get geofences => _geofences;

  late StorageService storageService;



  GeofenceProvider() {
    _loadGeofences();
  }

  Future<void> _loadGeofences() async {
    storageService = StorageService();
    await storageService.init();
    // Load default geofences with 50m radius as specified
    _geofences = [
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

    // Load any custom geofences from storage
    final customGeofences = await storageService.getGeofences();
    _geofences.addAll(customGeofences);

    notifyListeners();
  }

  void addGeofence(Geofence geofence) {
    _geofences.add(geofence);
    storageService.saveGeofences(_geofences.where((geofence) => geofence.id != 'home' && geofence.id != 'office').toList());
    notifyListeners();
  }

  void removeGeofence(String id) {
    _geofences.removeWhere((geofence) => geofence.id == id);
    storageService.saveGeofences(_geofences.where((geofence) => geofence.id != 'home' && geofence.id != 'office').toList());
    notifyListeners();
  }

  void updateGeofenceRadius(String id, double newRadius) {
    final index = _geofences.indexWhere((geofence) => geofence.id == id);
    if (index != -1) {
      final updatedGeofence = Geofence(
        id: _geofences[index].id,
        name: _geofences[index].name,
        latitude: _geofences[index].latitude,
        longitude: _geofences[index].longitude,
        radius: newRadius,
      );
      _geofences[index] = updatedGeofence;
      storageService.saveGeofences(_geofences.where((geofence) => geofence.id != 'home' && geofence.id != 'office').toList());
      notifyListeners();
    }
  }


}