import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:trust_app_updated/Pages/home_screen/home_screen.dart';
import 'local_notification_service.dart';

String _notificationRoute(RemoteMessage message) {
  return message.data['route']?.toString() ??
      message.data['data']?.toString() ??
      'home';
}

@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Background isolate: do not navigate here.
  debugPrint('Background message received. route=${_notificationRoute(message)}');
}

NavigatorNotification(message) {
  if (message == "offer") {
    Get.to(
        HomeScreen(
          currentIndex: 2,
        ),
        preventDuplicates: false);
  } else if (message == "home") {
    Get.to(
        HomeScreen(
          currentIndex: 0,
        ),
        preventDuplicates: false);
  } else {
    Get.to(
        HomeScreen(
          currentIndex: 1,
        ),
        preventDuplicates: false);
  }
}

class FCM {
  final _firebaseMessaging = FirebaseMessaging.instance;

  final streamCtlr = StreamController<String>.broadcast();
  final titleCtlr = StreamController<String>.broadcast();
  final bodyCtlr = StreamController<String>.broadcast();

  setNotifications(context) {
    LocalNotificationService.initialize(context);
    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        NavigatorNotification(_notificationRoute(message));
      }
    });

    ///forground work
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        LocalNotificationService.display(message);
        NavigatorNotification(_notificationRoute(message));
      }
    });

    ///When the app is in background but opened and user taps
    ///on the notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      NavigatorNotification(_notificationRoute(message));
    });

    // Avoid APNS-token-not-set error on iOS simulator.
    if (!Platform.isIOS) {
      _firebaseMessaging
          .getToken()
          .then((value) => debugPrint('Token: $value'))
          .catchError((_) {});
    }
  }

  dispose() {
    streamCtlr.close();
    bodyCtlr.close();
    titleCtlr.close();
  }
}
