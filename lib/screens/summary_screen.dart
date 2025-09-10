import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/tracking_provider.dart';
import '../providers/geofence_provider.dart';
import '../models/geofence.dart';
import '../models/daily_summary.dart'; // For DailySummary type
import '../widgets/summary_card.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({Key? key}) : super(key: key);

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((callback){
      _loadSummaryForSelectedDate();
    });

  }

  Future<void> _loadSummaryForSelectedDate() async {
    await Provider.of<TrackingProvider>(
      context,
      listen: false,
    ).loadSummaryForDate(_selectedDate);
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadSummaryForSelectedDate();
  }

  void _goToNextDay() {
    // Prevent going to a future date beyond today
    final today = DateTime.now();
    if (_selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day) {
      return;
    }
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadSummaryForSelectedDate();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  Color _getColorForLocation(String locationName) {
    switch (locationName.toLowerCase()) {
      case 'home':
        return Colors.blue;
      case 'office':
        return Colors.green;
      case 'traveling':
        return Colors.orange;
      default:
        final hash = locationName.hashCode;
        return Color.fromARGB(
          255,
          (hash & 0xFF0000) >> 16,
          (hash & 0x00FF00) >> 8,
          hash & 0x0000FF,
        ).withOpacity(0.7);
    }
  }

  void _showChangeRadiusDialog(
    BuildContext context,
    Geofence geofence,
    GeofenceProvider geofenceProvider,
  ) {
    final TextEditingController radiusController = TextEditingController(
      text: geofence.radius.toString(),
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Change Radius for ${geofence.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: radiusController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'New Radius (meters)',
                hintText: 'e.g., 100.0',
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter a radius';
                final double? newRadius = double.tryParse(value);
                if (newRadius == null) return 'Invalid number';
                if (newRadius <= 0) return 'Radius must be positive';
                return null;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final double? newRadius = double.tryParse(
                    radiusController.text,
                  );
                  if (newRadius != null) {
                    geofenceProvider.updateGeofenceRadius(
                      geofence.id,
                      newRadius,
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Radius for ${geofence.name} updated to $newRadius m.',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invalid radius value entered.'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingProvider = Provider.of<TrackingProvider>(context);

    final geofenceProvider = Provider.of<GeofenceProvider>(
      context,
      listen: true,
    );
    final DailySummary? summary = trackingProvider.currentSummary;
    final bool isToday =
        _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat.yMMMMd().format(_selectedDate)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: _goToPreviousDay,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios),

            onPressed: isToday ? null : _goToNextDay,
          ),
        ],
      ),
      body:
          summary == null ||
              summary.date.year != _selectedDate.year ||
              summary.date.month != _selectedDate.month ||
              summary.date.day != _selectedDate.day
          ? Center(
              child:
                  summary == null &&
                      trackingProvider
                          .isLoadingSummary // Check if loading
                  ? const CircularProgressIndicator()
                  : Text(
                      'No summary available for ${DateFormat.yMMMMd().format(_selectedDate)}.',
                    ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        ...geofenceProvider.geofences.map((geofence) {
                          bool isEditableGeofence =
                              geofence.name.toLowerCase() != "home" &&
                              geofence.name.toLowerCase() != "office";
                          return ListTile(
                            key: ValueKey(geofence.id),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 2.0,
                              horizontal: 0.0,
                            ),
                            title: SummaryCard(
                              title: geofence.name,
                              duration: _formatDuration(
                                summary.getLocationDuration(geofence.id),
                              ),
                              color: _getColorForLocation(geofence.name),
                            ),
                            trailing: isEditableGeofence
                                ? PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (String value) {
                                      if (value == 'remove') {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext ctx) {
                                            return AlertDialog(
                                              title: const Text(
                                                'Confirm Deletion',
                                              ),
                                              content: Text(
                                                'Are you sure you want to remove "${geofence.name}"?',
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: const Text('Cancel'),
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(),
                                                ),
                                                TextButton(
                                                  child: const Text(
                                                    'Remove',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    geofenceProvider
                                                        .removeGeofence(
                                                          geofence.id,
                                                        );
                                                    Navigator.of(ctx).pop();
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Geofence "${geofence.name}" removed.',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      } else if (value == 'change_radius') {
                                        _showChangeRadiusDialog(
                                          context,
                                          geofence,
                                          geofenceProvider,
                                        );
                                      }
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        <PopupMenuEntry<String>>[
                                          const PopupMenuItem<String>(
                                            value: 'change_radius',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.settings_overscan,
                                              ),
                                              title: Text('Change Radius'),
                                            ),
                                          ),
                                          const PopupMenuItem<String>(
                                            value: 'remove',
                                            child: ListTile(
                                              leading: Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              title: Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                  )
                                : null, // No menu for non-editable geofences
                          );
                        }).toList(),
                        SummaryCard(
                          title: 'Traveling',
                          duration: _formatDuration(summary.travelingTime),
                          color: _getColorForLocation('traveling'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
