/// Constants and configuration for WebView functionality
class WebViewConstants {
  // Timing constants
  static const Duration actionDelay = Duration(milliseconds: 500);
  static const Duration scriptDelay = Duration(milliseconds: 500);
  static const Duration httpTimeout = Duration(seconds: 10);
  static const Duration alternativeRequestDelay = Duration(milliseconds: 800);
  static const Duration randomDelayMin = Duration(milliseconds: 500);
  static const Duration randomDelayMax = Duration(milliseconds: 1000);

  // UI constants
  static const double appBarHeight = 60.0;
  static const int maxLinkTextLength = 100;

  // HTTP headers and user agents
  static const List<String> userAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.76',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  ];

  static const List<String> fallbackUserAgents = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/121.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 OPR/105.0.0.0',
  ];

  // Downloadable file extensions
  static const List<String> downloadableExtensions = [
    '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
    '.txt', '.rtf', '.zip', '.rar', '.7z', '.tar', '.gz',
    '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm',
    '.mp3', '.mp4', '.avi', '.mkv', '.mov', '.wmv',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.svg',
    '.iso', '.torrent'
  ];

  // JavaScript snippets
  static const String linkDetectionScript = '''
    (function() {
      // Initialize global variable for right-clicked link
      window.rightClickedLinkUrl = null;

      // Add context menu listener to capture right-clicked link URL
      document.addEventListener('contextmenu', function(e) {
        // Find the closest link element
        var link = e.target;
        if (link && link.tagName !== 'A') {
          link = link.closest('a');
        }

        // Store the link URL if found
        if (link && link.href) {
          window.rightClickedLinkUrl = link.href;
        } else {
          window.rightClickedLinkUrl = null;
        }
      });
    })();
  ''';

  // Error messages
  static const String noPageLoaded = 'No page loaded for analysis';
  static const String noImageFound = 'No image found on this page';
  static const String errorProcessingImage = 'Error processing image action';
  static const String errorGettingText = 'Error getting page text. Please try again.';
  static const String errorAnalyzingPage = 'Error analyzing page. Please try again.';
  static const String noPreviewAvailable = 'No preview available: Could not extract link information';
  static const String websiteUnavailable = 'Unable to access the website';

  // Default preview positions
  static const double defaultPreviewX = 100.0;
  static const double defaultPreviewY = 100.0;
}
