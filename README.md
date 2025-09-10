# Zitlac Location App (Android)

Zitlac Location App is a Flutter-based Android application designed for advanced location tracking, geofence management, and daily activity summarization. It leverages background services to provide continuous tracking while optimizing for battery consumption.

## Core Features

### 1. Advanced Location Tracking
- **Background Service**: Continuously tracks user location even when the app is not in the foreground, utilizing `flutter_background_service`.
- **Stationary Detection**: Intelligently detects if the user is stationary to switch to lower-power location polling, conserving battery life.
- **Dynamic Accuracy**: Adjusts location accuracy settings (e.g., from `LocationAccuracy.best` to `LocationAccuracy.medium`) based on movement status to further optimize battery usage.
- **Permission Handling**: Robustly checks and requests necessary location permissions.

### 2. Geofencing
- **Add Geofences**: Users can define geofences by specifying a location (using current GPS or manual input - though manual input screen isn't explicitly detailed in recent context, it's a common feature) and a radius.
- **Time Tracking within Geofences**: The app automatically calculates and records the time spent within each defined geofence.
- **Manage Geofences**:
    - **Remove**: Users can remove existing geofences.
    - **Change Radius**: The radius of existing geofences can be modified through a dialog.
- **Geofence Storage**: Geofence definitions are persisted locally using `StorageService`.

### 3. Daily Activity Summaries
- **View Summaries**: Users can view a summary of their daily activity, including time spent within each geofence and total traveling time.
- **Date Navigation**: Summaries for previous days can be accessed using a date navigator (previous/next day buttons).
- **Data Persistence**: Daily summaries are saved locally, allowing users to review historical data.
- **Day Change Handling**: The background service correctly handles transitions between days, saving the completed day's summary and starting a new one.

### 4. Data Persistence
- **Local Storage**: Utilizes a `StorageService` (likely built on top of a database like Hive or SQLite, though the specific implementation isn't detailed in the service layer) to store:
    - Geofence definitions
    - Daily summaries
    - Tracking state (on/off)

## Key Technologies & Plugins Used

- **Flutter**: For cross-platform UI development.
- **Provider**: For state management.
- **Geolocator**: For accessing device location (current position, position stream, permissions, service status).
- **flutter_background_service**: For running the location tracking logic as a foreground service, ensuring continuity even when the app is in the background.
- **flutter_local_notifications**: For managing the foreground service notification.
- **intl**: For date formatting in summaries.
- *(Potentially others like a database plugin for StorageService, e.g., hive, sqflite)*

## How to Run the Android Application

### Prerequisites
1.  **Flutter SDK**: Ensure you have Flutter installed and configured correctly. See [Flutter installation guide](https://docs.flutter.dev/get-started/install).
2.  **Android Studio / VS Code**: An IDE with Flutter and Dart plugins.
3.  **Android Emulator or Physical Device**: Configured for development.
    - For physical devices, ensure USB debugging is enabled.
    - For emulators, ensure Google Play Services are available if your location services depend on them for higher accuracy modes.

### Setup
1.  **Clone the Repository** (if applicable, otherwise open the project directory).
2.  **Get Dependencies**:
    Open a terminal in the project's root directory and run:
    ```bash
    flutter pub get
    ```

### Android Specific Configuration

1.  **Location Permissions**: The app will request location permissions at runtime. Ensure you grant them. For background location access on Android 10 (API level 29) and higher, users need to grant "Allow all the time" permission. The app should guide the user if this specific permission is crucial for its background functionality.
    - Add necessary permissions to your `android/app/src/main/AndroidManifest.xml`:
      ```xml
      <uses-permission android:name="android.permission.INTERNET"/>
      <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
      <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
      <!-- Required for flutter_background_service -->
      <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
      <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" /> <!-- If targeting Android 12+ -->
      <uses-permission android:name="android.permission.WAKE_LOCK" />
      <!-- Required for flutter_local_notifications if targeting Android 13+ -->
      <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
      ```
    - If targeting Android 10 (API 29) or higher and requiring background location, you might also need `ACCESS_BACKGROUND_LOCATION`:
      ```xml
      <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
      ```
      However, `flutter_background_service` with `foregroundServiceTypes: [AndroidForegroundType.location]` often handles this by running as a foreground service, which is a common way to get background location updates without needing `ACCESS_BACKGROUND_LOCATION` explicitly in all scenarios (policy varies by Android version and Play Store requirements).

2.  **Notification Channel**: The `LocationService` initializes a notification channel for the foreground service. This is standard practice.

3.  **Google Play Services** (for `geolocator`): Ensure your test device/emulator has Google Play Services updated for optimal location accuracy.

### Running the App
1.  **Select Target Device**: In your IDE (Android Studio / VS Code), select your connected Android device or a running emulator.
2.  **Run the App**:
    - **From IDE**: Click the "Run" button.
    - **From Terminal**: Navigate to the project root and run:
      ```bash
      flutter run
      ```

## Project Structure (Simplified Overview)

- `lib/`
  - `main.dart`: App entry point.
  - `models/`: Contains data models like `DailySummary.dart`, `Geofence.dart`.
  - `providers/`: State management classes using Provider (`TrackingProvider.dart`, `GeofenceProvider.dart`).
  - `screens/`: UI screens (`MainScreen.dart`, `SummaryScreen.dart`, `AddGeofenceScreen.dart`).
  - `services/`: Business logic and service integrations (`LocationService.dart`, `GeofenceService.dart`, `StorageService.dart`).
  - `widgets/`: Reusable UI components (`ClockButtons.dart`, `SummaryCard.dart`).

This README provides a general guide. Specific plugin versions or Android SDK target versions might require minor adjustments to the setup or manifest files.
