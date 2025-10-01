import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Service for managing ad blocking functionality
class AdBlockService {
  static const String defaultEasyListUrl = 'https://easylist.to/easylist/easylist.txt';
  static const String defaultEasyListPrivacyUrl = 'https://easylist.to/easylist/easyprivacy.txt';

  // Built-in basic ad blocking rules (subset of EasyList)
  static const List<String> _builtInRules = [
    // Common ad selectors
    '###ad-banner',
    '###ad-container',
    '###advertisement',
    '###ads',
    '###ads-banner',
    '###ads-container',
    '###banner-ad',
    '###google-ad',
    '###sidebar-ad',
    '###top-ad',

    // Class-based rules
    '##.ad',
    '##.ad-banner',
    '##.ad-box',
    '##.ad-container',
    '##.ad-slot',
    '##.ad-unit',
    '##.ad-wrapper',
    '##.adblock',
    '##.ads',
    '##.ads-banner',
    '##.adsbygoogle',
    '##.advertisement',
    '##.banner-ad',
    '##.google-ad',
    '##.sidebar-ad',

    // ID-based rules
    '##[id*="ad"]',
    '##[id*="banner"]',
    '##[id*="google"]',
    '##[class*="ad"]',
    '##[class*="banner"]',
    '##[class*="google"]',

    // Domain blocking (basic)
    '||doubleclick.net^',
    '||googlesyndication.com^',
    '||googleadservices.com^',
    '||amazon-adsystem.com^',
    '||facebook.com/tr^',
    '||adsystem.amazon.com^',

    // YouTube ads
    '##.video-ads',
    '##.ytp-ad-module',
    '##.ytp-ad-overlay-container',
    '##.ytp-ad-player-overlay',
  ];

  bool _isEnabled = true;
  List<String> _rules = [];
  String _generatedCss = '';
  String _generatedJs = '';
  bool _isInitialized = false;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;
  String get cssRules => _generatedCss;
  String get jsRules => _generatedJs;

  /// Initialize the ad blocking service
  Future<void> initialize({bool enabled = true}) async {
    _isEnabled = enabled;

    if (!_isEnabled) {
      _isInitialized = true;
      return;
    }

    try {
      // Load built-in rules
      _rules = List.from(_builtInRules);

      // Try to load additional rules from assets (if available)
      await _loadAdditionalRules();

      // Generate CSS and JS rules
      await _generateRules();

      _isInitialized = true;
      debugPrint('AdBlock service initialized with ${_rules.length} rules');
    } catch (e) {
      debugPrint('Failed to initialize AdBlock service: $e');
      _isInitialized = true; // Still mark as initialized to avoid retry loops
    }
  }

  /// Load additional rules from assets or remote sources
  Future<void> _loadAdditionalRules() async {
    try {
      // Try to load additional rules from assets
      final additionalRules = await rootBundle.loadString('assets/adblock_rules.txt').catchError((_) => '');
      if (additionalRules.isNotEmpty) {
        final lines = LineSplitter.split(additionalRules)
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty && !line.startsWith('!') && !line.startsWith('['))
            .toList();
        _rules.addAll(lines);
      }
    } catch (e) {
      // Ignore if additional rules file doesn't exist
      debugPrint('No additional adblock rules found: $e');
    }
  }

  /// Generate CSS and JavaScript rules from filter list
  Future<void> _generateRules() async {
    final cssRules = <String>[];
    final domainBlocks = <String>[];

    for (final rule in _rules) {
      if (rule.startsWith('##')) {
        // Element hiding rule
        final selector = rule.substring(2);
        if (selector.isNotEmpty) {
          cssRules.add('$selector { display: none !important; }');
        }
      } else if (rule.startsWith('||') && rule.endsWith('^')) {
        // Domain blocking rule
        final domain = rule.substring(2, rule.length - 1);
        if (domain.isNotEmpty) {
          domainBlocks.add(domain);
        }
      } else if (rule.startsWith('###')) {
        // ID-based rule
        final id = rule.substring(3);
        if (id.isNotEmpty) {
          cssRules.add('#$id { display: none !important; }');
        }
      }
    }

    // Generate CSS
    _generatedCss = cssRules.join('\n');

    // Generate JavaScript for dynamic ad blocking and domain blocking
    _generatedJs = '''
(function() {
  'use strict';

  // Domain blocking list
  const blockedDomains = ${jsonEncode(domainBlocks)};

  // Function to check if URL should be blocked
  function shouldBlockUrl(url) {
    try {
      const urlObj = new URL(url);
      const hostname = urlObj.hostname.toLowerCase();

      for (const domain of blockedDomains) {
        if (hostname === domain || hostname.endsWith('.' + domain)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Block network requests (if supported)
  if (typeof XMLHttpRequest !== 'undefined') {
    const originalOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function(method, url, ...args) {
      if (shouldBlockUrl(url)) {
        console.log('AdBlock: Blocked XMLHttpRequest to', url);
        return;
      }
      return originalOpen.call(this, method, url, ...args);
    };
  }

  // Block fetch requests
  if (typeof fetch !== 'undefined') {
    const originalFetch = window.fetch;
    window.fetch = function(url, options) {
      if (shouldBlockUrl(url)) {
        console.log('AdBlock: Blocked fetch to', url);
        return Promise.reject(new Error('AdBlock: Request blocked'));
      }
      return originalFetch.call(this, url, options);
    };
  }

  // Dynamic element hiding with MutationObserver
  function hideAds() {
    // Hide elements by common selectors
    const selectors = [
      '[id*="ad"]',
      '[class*="ad"]',
      '[id*="banner"]',
      '[class*="banner"]',
      '[id*="google"]',
      '[class*="google"]',
      '[id*="adsense"]',
      '[class*="adsense"]',
      '.ad',
      '.ads',
      '.advertisement',
      '.banner-ad',
      '.sidebar-ad',
      '.video-ads',
      '.ytp-ad-module',
      '.ytp-ad-overlay-container',
      '.ytp-ad-player-overlay',
      '#ad-banner',
      '#ad-container',
      '#advertisement',
      '#ads',
      '#ads-banner',
      '#ads-container',
      '#banner-ad',
      '#google-ad',
      '#sidebar-ad',
      '#top-ad'
    ];

    selectors.forEach(selector => {
      try {
        const elements = document.querySelectorAll(selector);
        elements.forEach(el => {
          if (el && el.style.display !== 'none') {
            el.style.display = 'none';
            console.log('AdBlock: Hidden element with selector:', selector);
          }
        });
      } catch (e) {
        // Ignore selector errors
      }
    });

    // Hide by content analysis (simple heuristic)
    const allElements = document.querySelectorAll('*');
    allElements.forEach(el => {
      if (el && el.textContent && el.children.length === 0) {
        const text = el.textContent.toLowerCase();
        if ((text.includes('advertisement') || text.includes('sponsored') || text.includes('ad by')) &&
            el.offsetHeight > 0 && el.offsetWidth > 0) {
          el.style.display = 'none';
          console.log('AdBlock: Hidden element by content analysis');
        }
      }
    });
  }

  // Run initial ad hiding
  hideAds();

  // Watch for dynamically added content
  const observer = new MutationObserver(function(mutations) {
    let shouldCheck = false;
    mutations.forEach(function(mutation) {
      if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
        shouldCheck = true;
      }
    });

    if (shouldCheck) {
      // Debounce the ad hiding to avoid excessive calls
      clearTimeout(window.adBlockTimer);
      window.adBlockTimer = setTimeout(hideAds, 100);
    }
  });

  // Start observing
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  console.log('AdBlock: Initialized with ${domainBlocks.length} domain blocks');
})();
''';

    debugPrint('Generated ${_generatedCss.split('\n').length} CSS rules and JavaScript ad blocker');
  }

  /// Enable or disable ad blocking
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (enabled && !_isInitialized) {
      await initialize(enabled: true);
    }
  }

  /// Add custom rule
  void addRule(String rule) {
    if (!rule.trim().isEmpty && !_rules.contains(rule.trim())) {
      _rules.add(rule.trim());
      _generateRules(); // Regenerate rules
    }
  }

  /// Remove custom rule
  void removeRule(String rule) {
    _rules.remove(rule);
    _generateRules(); // Regenerate rules
  }

  /// Get all rules
  List<String> getRules() {
    return List.unmodifiable(_rules);
  }

  /// Clear all rules and reload defaults
  Future<void> resetToDefaults() async {
    _rules = List.from(_builtInRules);
    await _loadAdditionalRules();
    await _generateRules();
  }

  /// Check if a URL should be blocked
  bool shouldBlockUrl(String url) {
    if (!_isEnabled || !_isInitialized) return false;

    try {
      final uri = Uri.parse(url);
      final hostname = uri.host.toLowerCase();

      for (final rule in _rules) {
        if (rule.startsWith('||') && rule.endsWith('^')) {
          final domain = rule.substring(2, rule.length - 1);
          if (hostname == domain || hostname.endsWith('.$domain')) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get JavaScript code to inject for ad blocking
  String getInjectionScript() {
    if (!_isEnabled || !_isInitialized) {
      return '';
    }

    return '''
// AdBlock CSS Injection
(function() {
  const adBlockStyle = document.createElement('style');
  adBlockStyle.id = 'adblock-styles';
  adBlockStyle.textContent = ${jsonEncode(_generatedCss)};
  document.head.appendChild(adBlockStyle);
})();

// AdBlock JavaScript
$_generatedJs
''';
  }

  /// Dispose resources
  void dispose() {
    _rules.clear();
    _generatedCss = '';
    _generatedJs = '';
    _isInitialized = false;
  }
}
