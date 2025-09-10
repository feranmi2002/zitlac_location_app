class Geofence{
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius ; // in meters

  Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radius = 50.0, // default radius in meters
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }

  factory Geofence.fromMap(Map<String, dynamic> map) {
    return Geofence(
      id: map['id'],
      name: map['name'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      radius: map['radius'],
    );
  }
}