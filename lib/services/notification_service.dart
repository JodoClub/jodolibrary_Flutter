import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';
import 'auth_storage.dart';

/// Top-level background message handler required by Firebase Messaging.
/// Must be outside any class and marked with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM-BG] Background notification received: ${message.messageId} - ${message.notification?.title}');
  } catch (e) {
    debugPrint('[FCM-BG] Error initializing in background: $e');
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'jodo_notifications';
  static const String channelName = 'Jodo Library Notifications';
  static const String channelDesc =
      'Alerts for check-ins, fee dues, announcements, and seat bookings.';

  bool _initialized = false;
  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initializes Firebase, requests notification permissions, sets up local
  /// notifications for foreground display, and listens for message clicks.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 1. Request Notification Permissions (Android 13+ / iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      // 2. Setup Android Notification Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        if (Platform.isAndroid) {
          await androidPlugin.requestNotificationsPermission();
        }
      }

      // 3. Initialize Local Notifications
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationClick(response.payload);
        },
      );

      // 4. Fetch & Save Device FCM Token
      await _fetchAndPersistToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        _fcmToken = newToken;
        AuthStorage.saveFcmToken(newToken);
        syncTokenWithBackend(newToken);
      });

      // 5. Foreground Notification Listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM-FG] Foreground message: ${message.notification?.title}');
        _showForegroundNotification(message);
      });

      // 6. Handle App Opened from Background notification tap
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM-TAP] App opened via notification: ${message.data}');
        _handleMessagePayload(message.data);
      });

      // 7. Check if app was opened from terminated state by a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM-TERMINATED] Opened from terminated state: ${initialMessage.data}');
        _handleMessagePayload(initialMessage.data);
      }

      _initialized = true;
      debugPrint('[FCM] NotificationService initialized successfully.');
    } catch (e, stack) {
      debugPrint('[FCM-ERROR] Failed to initialize NotificationService: $e\n$stack');
    }
  }

  /// Fetches FCM token from Google Play Services and saves to local storage.
  Future<String?> _fetchAndPersistToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null && _fcmToken!.isNotEmpty) {
        debugPrint('[FCM] Device Token: $_fcmToken');
        await AuthStorage.saveFcmToken(_fcmToken!);
      }
    } catch (e) {
      debugPrint('[FCM] Error fetching FCM token: $e');
    }
    return _fcmToken;
  }

  /// Sends the current FCM device token to the Spring Boot backend
  /// so push notifications can be delivered to this user.
  Future<void> syncTokenWithBackend([String? token]) async {
    final tokenToSync = token ?? _fcmToken ?? await AuthStorage.getFcmToken();
    if (tokenToSync == null || tokenToSync.isEmpty) return;

    final isLoggedIn = await AuthStorage.isLoggedIn();
    if (!isLoggedIn) {
      debugPrint('[FCM] User not logged in; skipping backend token sync for now.');
      return;
    }

    try {
      final success = await ApiService.instance.registerFcmToken(tokenToSync);
      if (success) {
        debugPrint('[FCM] Successfully synced device FCM token with backend.');
      } else {
        debugPrint('[FCM] Backend rejected device token registration.');
      }
    } catch (e) {
      debugPrint('[FCM] Error syncing device token with backend: $e');
    }
  }

  /// Displays a heads-up floating banner when a notification arrives while the app is OPEN.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Jodo Library',
      body: notification.body ?? '',
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  /// Subscribe to a library announcement topic (e.g., library_uuid_123).
  Future<void> subscribeToLibrary(String libraryId) async {
    if (libraryId.trim().isEmpty) return;
    final topic = 'library_${libraryId.replaceAll('-', '_')}';
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('[FCM] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Failed to subscribe to topic $topic: $e');
    }
  }

  /// Unsubscribe from a library announcement topic.
  Future<void> unsubscribeFromLibrary(String libraryId) async {
    if (libraryId.trim().isEmpty) return;
    final topic = 'library_${libraryId.replaceAll('-', '_')}';
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('[FCM] Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('[FCM] Failed to unsubscribe from topic $topic: $e');
    }
  }

  void _handleNotificationClick(String? payload) {
    debugPrint('[FCM] Local notification tapped with payload: $payload');
  }

  void _handleMessagePayload(Map<String, dynamic> data) {
    debugPrint('[FCM] RemoteMessage data clicked: $data');
    // Can route to specific tab/screen depending on data['type']
  }
}
