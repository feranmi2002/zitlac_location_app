import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zitlac_location_app/services/geofence_service.dart';
import 'models/daily_summary.dart';
import 'providers/tracking_provider.dart';
import 'providers/geofence_provider.dart';
import 'services/storage_service.dart';
import 'screens/main_screen.dart';
import 'screens/summary_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => GeofenceProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Location Tracker',
        theme: ThemeData(primarySwatch: Colors.blue),
        initialRoute: '/',
        routes: {
          '/': (context) => const MainScreen(),
          '/summary': (context) => const SummaryScreen(),
        },
      ),
    );
  }
}
