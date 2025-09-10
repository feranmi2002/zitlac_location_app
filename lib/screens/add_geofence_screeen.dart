import 'package:flutter/material.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:provider/provider.dart';
import '../providers/geofence_provider.dart';
import '../models/geofence.dart';

class AddGeofenceScreen extends StatefulWidget {
  final Position initialPosition;

  const AddGeofenceScreen({
    Key? key,
      required this.initialPosition,
  }) : super(key: key);

  @override
  _AddGeofenceScreenState createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController(text: '50.0');
  double _latitude = 0.0;
  double _longitude = 0.0;

  @override
  void initState() {
    super.initState();
    
      _latitude = widget.initialPosition.latitude!;
      _longitude = widget.initialPosition.longitude;
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Custom Geofence'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Location Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a radius';
                  }
                  final radius = double.tryParse(value);
                  if (radius == null || radius <= 0) {
                    return 'Please enter a valid radius';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Latitude: ${_latitude.toStringAsFixed(6)}'),
              Text('Longitude: ${_longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
                    final newGeofence = Geofence(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text,
                      latitude: _latitude,
                      longitude: _longitude,
                      radius: double.parse(_radiusController.text),
                    );

                    geofenceProvider.addGeofence(newGeofence);
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save Geofence'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}