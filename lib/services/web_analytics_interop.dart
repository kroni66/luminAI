// Google Analytics 4 SDK - Dart JavaScript Interop Wrapper
// This shows how to wrap a browser-based TypeScript SDK

@JS()
library google_analytics;

import 'package:js/js.dart';
import 'dart:js' as js;

// JavaScript interop declarations for gtag
@JS('gtag')
external void _gtag(String command, String targetId, dynamic config);

// Google Analytics configuration
@JS()
@anonymous
class GAConfig {
  external String get measurementId;
  external factory GAConfig({String measurementId});
}

// Event parameters
@JS()
@anonymous
class GAEventParams {
  external String? get event_category;
  external String? get event_label;
  external num? get value;
  external factory GAEventParams({
    String? event_category,
    String? event_label,
    num? value,
  });
}

/// Dart wrapper for Google Analytics 4
class GoogleAnalytics {
  final String measurementId;

  GoogleAnalytics(this.measurementId) {
    _initialize();
  }

  void _initialize() {
    // Load Google Analytics script dynamically
    final script = js.context['document'].callMethod('createElement', ['script']);
    script['src'] = 'https://www.googletagmanager.com/gtag/js?id=$measurementId';
    script['async'] = true;

    js.context['document']['head'].callMethod('appendChild', [script]);

    // Initialize gtag
    js.context['dataLayer'] = js.JsArray();
    js.context['gtag'] = js.allowInterop((dynamic command, [dynamic targetId, dynamic config]) {
      js.context['dataLayer'].callMethod('push', [js.JsObject.jsify({'command': command, 'targetId': targetId, 'config': config})]);
    });

    // Configure GA
    _gtag('js', DateTime.now().toIso8601String(), GAConfig(measurementId: measurementId));
    _gtag('config', measurementId, js.JsObject.jsify({
      'page_title': js.context['document']['title'],
      'page_location': js.context['document']['location']['href'],
    }));
  }

  /// Track a custom event
  void trackEvent(String eventName, {
    String? category,
    String? label,
    num? value,
    Map<String, dynamic>? customParams,
  }) {
    final params = <String, dynamic>{
      'event_category': category,
      'event_label': label,
      'value': value,
    };

    if (customParams != null) {
      params.addAll(customParams);
    }

    _gtag('event', eventName, js.JsObject.jsify(params));
  }

  /// Track page view
  void trackPageView(String pagePath, {String? pageTitle}) {
    _gtag('config', measurementId, js.JsObject.jsify({
      'page_path': pagePath,
      'page_title': pageTitle ?? js.context['document']['title'],
    }));
  }

  /// Set user properties
  void setUserProperty(String name, dynamic value) {
    _gtag('config', measurementId, js.JsObject.jsify({
      'custom_map': {name: value}
    }));
  }

  /// Track timing
  void trackTiming(String name, int value, {
    String? category,
    String? label,
  }) {
    _gtag('event', 'timing_complete', js.JsObject.jsify({
      'name': name,
      'value': value,
      'event_category': category ?? 'timing',
      'event_label': label,
    }));
  }

  /// Track exception
  void trackException(String description, {bool fatal = false}) {
    _gtag('event', 'exception', js.JsObject.jsify({
      'description': description,
      'fatal': fatal,
    }));
  }
}

// Firebase SDK interop example
@JS('firebase')
external dynamic get firebase;

@JS('firebase.analytics')
external dynamic get analytics;

@JS()
@anonymous
class FirebaseConfig {
  external String get apiKey;
  external String get authDomain;
  external String get projectId;
  external String get storageBucket;
  external String get messagingSenderId;
  external String get appId;
  external factory FirebaseConfig({
    String apiKey,
    String authDomain,
    String projectId,
    String storageBucket,
    String messagingSenderId,
    String appId,
  });
}

/// Firebase Analytics wrapper
class FirebaseAnalytics {
  FirebaseAnalytics(FirebaseConfig config) {
    // Initialize Firebase
    firebase.callMethod('initializeApp', [config]);
  }

  void logEvent(String eventName, {Map<String, dynamic>? parameters}) {
    final params = parameters != null ? js.JsObject.jsify(parameters) : null;
    analytics.callMethod('logEvent', [eventName, params]);
  }

  void setUserId(String userId) {
    analytics.callMethod('setUserId', [userId]);
  }

  void setUserProperty(String name, dynamic value) {
    analytics.callMethod('setUserProperty', [name, value]);
  }
}

// Usage examples
void exampleUsage() {
  // Google Analytics
  final ga = GoogleAnalytics('G-XXXXXXXXXX');

  // Track events
  ga.trackEvent('button_click', category: 'engagement', label: 'hero_button');
  ga.trackEvent('purchase', value: 99.99, customParams: {'currency': 'USD'});

  // Track page views
  ga.trackPageView('/dashboard');

  // Firebase Analytics
  final firebaseConfig = FirebaseConfig(
    apiKey: "your-api-key",
    authDomain: "your-project.firebaseapp.com",
    projectId: "your-project",
    storageBucket: "your-project.appspot.com",
    messagingSenderId: "123456789",
    appId: "1:123456789:web:abcdef123456",
  );

  final fa = FirebaseAnalytics(firebaseConfig);
  fa.logEvent('screen_view', parameters: {'screen_name': 'home'});
  fa.setUserId('user123');
}

// For non-web platforms, provide mock implementations
class MockGoogleAnalytics implements GoogleAnalytics {
  @override
  final String measurementId;

  MockGoogleAnalytics(this.measurementId);

  @override
  void trackEvent(String eventName, {String? category, String? label, num? value, Map<String, dynamic>? customParams}) {
    print('Mock GA: Event $eventName tracked');
  }

  @override
  void trackPageView(String pagePath, {String? pageTitle}) {
    print('Mock GA: Page $pagePath viewed');
  }

  @override
  void setUserProperty(String name, dynamic value) {
    print('Mock GA: User property $name set to $value');
  }

  @override
  void trackTiming(String name, int value, {String? category, String? label}) {
    print('Mock GA: Timing $name: ${value}ms');
  }

  @override
  void trackException(String description, {bool fatal = false}) {
    print('Mock GA: Exception tracked: $description');
  }

  @override
  void _initialize() {
    // No-op for mock
  }
}


