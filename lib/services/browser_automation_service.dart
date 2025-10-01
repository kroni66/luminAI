import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'browser_controller.dart';
import 'navigation_manager.dart';
import 'tab_manager.dart';

/// Browser automation tools for AI function calling
/// Based on X.AI function calling pattern for browser control
class BrowserAutomationService {
  final TabManager _tabManager;
  final NavigationManager _navigationManager;

  BrowserAutomationService(
    this._tabManager,
    this._navigationManager,
  );

  /// Get the current active browser controller
  BrowserController? get _currentController {
    return _tabManager.activeTab?.browserController;
  }

  /// Function definitions for AI function calling
  Map<String, dynamic> get functionDefinitions => {
    'navigate_to_url': {
      'name': 'navigate_to_url',
      'description': 'Navigate to a specific URL in the current browser tab',
      'parameters': {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'The URL to navigate to (must include http:// or https://)',
          },
        },
        'required': ['url'],
      },
    },
    'search_google': {
      'name': 'search_google',
      'description': 'Search for content on Google and navigate to results',
      'parameters': {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'The search query to perform on Google',
          },
        },
        'required': ['query'],
      },
    },
    'click_element': {
      'name': 'click_element',
      'description': 'Click on an element on the current webpage using CSS selector or XPath',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector or XPath to identify the element to click',
          },
          'selector_type': {
            'type': 'string',
            'enum': ['css', 'xpath'],
            'description': 'Type of selector to use',
            'default': 'css',
          },
        },
        'required': ['selector'],
      },
    },
    'extract_text': {
      'name': 'extract_text',
      'description': 'Extract text content from the current webpage',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector to extract text from (optional - extracts all text if not provided)',
          },
        },
        'required': [],
      },
    },
    'extract_links': {
      'name': 'extract_links',
      'description': 'Extract all links from the current webpage',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector to limit link extraction to specific elements (optional)',
          },
        },
        'required': [],
      },
    },
    'scroll_page': {
      'name': 'scroll_page',
      'description': 'Scroll the current webpage',
      'parameters': {
        'type': 'object',
        'properties': {
          'direction': {
            'type': 'string',
            'enum': ['up', 'down', 'top', 'bottom'],
            'description': 'Direction to scroll',
          },
          'amount': {
            'type': 'number',
            'description': 'Amount to scroll in pixels (for up/down directions)',
            'default': 500,
          },
        },
        'required': ['direction'],
      },
    },
    'wait_for_element': {
      'name': 'wait_for_element',
      'description': 'Wait for an element to appear on the page',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector to wait for',
          },
          'timeout': {
            'type': 'number',
            'description': 'Maximum time to wait in seconds',
            'default': 10,
          },
        },
        'required': ['selector'],
      },
    },
    'type_text': {
      'name': 'type_text',
      'description': 'Type text into an input field',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector for the input field',
          },
          'text': {
            'type': 'string',
            'description': 'Text to type into the field',
          },
        },
        'required': ['selector', 'text'],
      },
    },
    'take_screenshot': {
      'name': 'take_screenshot',
      'description': 'Take a screenshot of the current webpage',
      'parameters': {
        'type': 'object',
        'properties': {
          'full_page': {
            'type': 'boolean',
            'description': 'Whether to capture the full page or just the viewport',
            'default': false,
          },
        },
        'required': [],
      },
    },
    'get_page_title': {
      'name': 'get_page_title',
      'description': 'Get the title of the current webpage',
      'parameters': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
    'get_current_url': {
      'name': 'get_current_url',
      'description': 'Get the current URL of the active tab',
      'parameters': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
    'new_tab': {
      'name': 'new_tab',
      'description': 'Open a new browser tab',
      'parameters': {
        'type': 'object',
        'properties': {
          'url': {
            'type': 'string',
            'description': 'URL to open in the new tab (optional)',
          },
        },
        'required': [],
      },
    },
    'switch_tab': {
      'name': 'switch_tab',
      'description': 'Switch to a different tab by index',
      'parameters': {
        'type': 'object',
        'properties': {
          'tab_index': {
            'type': 'number',
            'description': 'Index of the tab to switch to (0-based)',
          },
        },
        'required': ['tab_index'],
      },
    },
    'close_tab': {
      'name': 'close_tab',
      'description': 'Close a browser tab',
      'parameters': {
        'type': 'object',
        'properties': {
          'tab_index': {
            'type': 'number',
            'description': 'Index of the tab to close (optional - closes current tab if not specified)',
          },
        },
        'required': [],
      },
    },
    'wait_for_page_load': {
      'name': 'wait_for_page_load',
      'description': 'Wait for the current page to fully load',
      'parameters': {
        'type': 'object',
        'properties': {
          'timeout_seconds': {
            'type': 'number',
            'description': 'Maximum time to wait in seconds',
            'default': 30,
          },
        },
        'required': [],
      },
    },
    'check_element_exists': {
      'name': 'check_element_exists',
      'description': 'Check if an element exists on the page',
      'parameters': {
        'type': 'object',
        'properties': {
          'selector': {
            'type': 'string',
            'description': 'CSS selector to check for',
          },
        },
        'required': ['selector'],
      },
    },
    'get_page_state': {
      'name': 'get_page_state',
      'description': 'Get current page state information (URL, title, loading status)',
      'parameters': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
    'refresh_page': {
      'name': 'refresh_page',
      'description': 'Refresh the current page',
      'parameters': {
        'type': 'object',
        'properties': {},
        'required': [],
      },
    },
  };

  /// Execute a browser automation function
  Future<Map<String, dynamic>> executeFunction(String functionName, Map<String, dynamic> parameters) async {
    try {
      switch (functionName) {
        case 'navigate_to_url':
          return await _navigateToUrl(parameters['url'] as String);

        case 'search_google':
          return await _searchGoogle(parameters['query'] as String);

        case 'click_element':
          return await _clickElement(
            parameters['selector'] as String,
            parameters['selector_type'] as String? ?? 'css',
          );

        case 'extract_text':
          return await _extractText(parameters['selector'] as String?);

        case 'extract_links':
          return await _extractLinks(parameters['selector'] as String?);

        case 'scroll_page':
          return await _scrollPage(
            parameters['direction'] as String,
            parameters['amount'] as int? ?? 500,
          );

        case 'wait_for_element':
          return await _waitForElement(
            parameters['selector'] as String,
            parameters['timeout'] as int? ?? 10,
          );

        case 'type_text':
          return await _typeText(
            parameters['selector'] as String,
            parameters['text'] as String,
          );

        case 'take_screenshot':
          return await _takeScreenshot(parameters['full_page'] as bool? ?? false);

        case 'get_page_title':
          return await _getPageTitle();

        case 'get_current_url':
          return await _getCurrentUrl();

        case 'new_tab':
          return await _newTab(parameters['url'] as String?);

        case 'switch_tab':
          return await _switchTab(parameters['tab_index'] as int);

        case 'close_tab':
          return await _closeTab(parameters['tab_index'] as int?);

        case 'wait_for_page_load':
          return await _waitForPageLoad(parameters['timeout_seconds'] as int? ?? 30);

        case 'check_element_exists':
          return await _checkElementExists(parameters['selector'] as String);

        case 'get_page_state':
          return await _getPageState();

        case 'refresh_page':
          return await _refreshPage();

        default:
          throw Exception('Unknown function: $functionName');
      }
    } catch (e) {
      debugPrint('Error executing browser function $functionName: $e');
      return {
        'success': false,
        'error': e.toString(),
        'function': functionName,
      };
    }
  }

  Future<Map<String, dynamic>> _navigateToUrl(String url) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    await _navigationManager.navigateToUrl(url);

    // Wait a bit for navigation to complete
    await Future.delayed(const Duration(seconds: 2));

    return {
      'success': true,
      'message': 'Navigated to $url',
      'url': url,
    };
  }

  Future<Map<String, dynamic>> _searchGoogle(String query) async {
    final searchUrl = 'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
    return await _navigateToUrl(searchUrl);
  }

  Future<Map<String, dynamic>> _clickElement(String selector, String selectorType) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = selectorType == 'xpath'
        ? '''
        var element = document.evaluate("$selector", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
        if (element) {
          element.click();
          "Element clicked successfully";
        } else {
          "Element not found";
        }
        '''
        : '''
        var element = document.querySelector("$selector");
        if (element) {
          element.click();
          "Element clicked successfully";
        } else {
          "Element not found";
        }
        ''';

    final result = await _currentController!.executeScript(script) ?? 'No result';

    return {
      'success': result.contains('successfully'),
      'message': result,
      'selector': selector,
    };
  }

  Future<Map<String, dynamic>> _extractText(String? selector) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = selector != null
        ? '''
        var element = document.querySelector("$selector");
        element ? element.textContent || element.innerText || "" : "";
        '''
        : '''
        document.body.textContent || document.body.innerText || "";
        ''';

    final result = await _currentController!.executeScript(script) ?? '';

    return {
      'success': true,
      'text': result.toString(),
      'selector': selector,
    };
  }

  Future<Map<String, dynamic>> _extractLinks(String? selector) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = selector != null
        ? '''
        var container = document.querySelector("$selector");
        if (!container) { "[]"; }
        var links = Array.from(container.querySelectorAll("a[href]"));
        JSON.stringify(links.map(function(a) {
          return {
            text: a.textContent.trim(),
            href: a.href,
            title: a.title || ""
          };
        }));
        '''
        : '''
        var links = Array.from(document.querySelectorAll("a[href]"));
        JSON.stringify(links.map(function(a) {
          return {
            text: a.textContent.trim(),
            href: a.href,
            title: a.title || ""
          };
        }));
        ''';

    final result = await _currentController!.executeScript(script) ?? '[]';
    final links = jsonDecode(result.toString());

    return {
      'success': true,
      'links': links,
      'count': links.length,
    };
  }

  Future<Map<String, dynamic>> _scrollPage(String direction, int amount) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    String script;
    switch (direction) {
      case 'up':
        script = 'window.scrollBy(0, -${amount}); "Scrolled up by ${amount}px";';
        break;
      case 'down':
        script = 'window.scrollBy(0, ${amount}); "Scrolled down by ${amount}px";';
        break;
      case 'top':
        script = 'window.scrollTo(0, 0); "Scrolled to top";';
        break;
      case 'bottom':
        script = 'window.scrollTo(0, document.body.scrollHeight); "Scrolled to bottom";';
        break;
      default:
        throw Exception('Invalid scroll direction: $direction');
    }

    final result = await _currentController!.executeScript(script) ?? 'Scroll completed';

    return {
      'success': true,
      'message': result.toString(),
      'direction': direction,
      'amount': direction == 'top' || direction == 'bottom' ? null : amount,
    };
  }

  Future<Map<String, dynamic>> _waitForElement(String selector, int timeoutSeconds) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final timeoutMs = timeoutSeconds * 1000;
    final script = '''
    function waitForElement(selector, timeout) {
      return new Promise((resolve) => {
        const element = document.querySelector(selector);
        if (element) {
          resolve("Element found immediately");
          return;
        }

        const observer = new MutationObserver(() => {
          const element = document.querySelector(selector);
          if (element) {
            observer.disconnect();
            resolve("Element found");
          }
        });

        observer.observe(document.body, {
          childList: true,
          subtree: true
        });

        setTimeout(() => {
          observer.disconnect();
          resolve("Element not found within timeout");
        }, timeout);
      });
    }
    waitForElement("$selector", $timeoutMs);
    ''';

    final result = await _currentController!.executeScript(script) ?? 'Timeout';

    return {
      'success': result.toString().contains('found'),
      'message': result.toString(),
      'selector': selector,
      'timeout_seconds': timeoutSeconds,
    };
  }

  Future<Map<String, dynamic>> _typeText(String selector, String text) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = '''
    var element = document.querySelector("$selector");
    if (element) {
      element.value = "${text.replaceAll('"', '\\"')}";
      element.dispatchEvent(new Event('input', { bubbles: true }));
      element.dispatchEvent(new Event('change', { bubbles: true }));
      "Text typed successfully";
    } else {
      "Element not found";
    }
    ''';

    final result = await _currentController!.executeScript(script) ?? 'No result';

    return {
      'success': result.contains('successfully'),
      'message': result,
      'selector': selector,
      'text_length': text.length,
    };
  }

  Future<Map<String, dynamic>> _takeScreenshot(bool fullPage) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    // Note: Taking actual screenshots would require additional implementation
    // For now, we'll return a placeholder response
    return {
      'success': true,
      'message': 'Screenshot functionality not implemented yet',
      'full_page': fullPage,
      'placeholder': true,
    };
  }

  Future<Map<String, dynamic>> _getPageTitle() async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = 'document.title;';
    final result = await _currentController!.executeScript(script) ?? 'Unknown Title';

    return {
      'success': true,
      'title': result.toString(),
    };
  }

  Future<Map<String, dynamic>> _getCurrentUrl() async {
    return {
      'success': true,
      'url': _navigationManager.currentUrl,
    };
  }

  Future<Map<String, dynamic>> _newTab(String? url) async {
    await _tabManager.addNewTab(url: url ?? 'about:blank');
    final tabIndex = _tabManager.activeTabIndex;

    return {
      'success': true,
      'message': 'New tab opened',
      'tab_index': tabIndex,
      'url': url ?? 'about:blank',
    };
  }

  Future<Map<String, dynamic>> _switchTab(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= _tabManager.tabs.length) {
      throw Exception('Invalid tab index: $tabIndex');
    }

    await _tabManager.switchToTab(tabIndex);

    return {
      'success': true,
      'message': 'Switched to tab $tabIndex',
      'tab_index': tabIndex,
      'url': _tabManager.tabs[tabIndex].url,
    };
  }

  Future<Map<String, dynamic>> _closeTab(int? tabIndex) async {
    final indexToClose = tabIndex ?? _tabManager.activeTabIndex;

    if (indexToClose < 0 || indexToClose >= _tabManager.tabs.length) {
      throw Exception('Invalid tab index: $indexToClose');
    }

    await _tabManager.closeTab(indexToClose);

    return {
      'success': true,
      'message': 'Tab $indexToClose closed',
      'closed_tab_index': indexToClose,
    };
  }

  Future<Map<String, dynamic>> _waitForPageLoad(int timeoutSeconds) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = '''
    (function() {
      return new Promise((resolve) => {
        if (document.readyState === 'complete') {
          resolve('Page already loaded');
          return;
        }

        const timeout = setTimeout(() => {
          resolve('Page load timeout after ${timeoutSeconds} seconds');
        }, ${timeoutSeconds * 1000});

        window.addEventListener('load', () => {
          clearTimeout(timeout);
          resolve('Page loaded successfully');
        });
      });
    })();
    ''';

    final result = await _currentController!.executeScript(script) ?? 'Script execution failed';

    return {
      'success': result.toString().contains('successfully') || result.toString().contains('already loaded'),
      'message': result.toString(),
      'timeout_seconds': timeoutSeconds,
    };
  }

  Future<Map<String, dynamic>> _checkElementExists(String selector) async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    final script = '''
    var element = document.querySelector("$selector");
    JSON.stringify({
      exists: element !== null,
      tagName: element ? element.tagName.toLowerCase() : null,
      text: element ? element.textContent.trim().substring(0, 100) : null
    });
    ''';

    final result = await _currentController!.executeScript(script) ?? '{"exists": false}';
    final parsed = jsonDecode(result.toString());

    return {
      'success': true,
      'selector': selector,
      'exists': parsed['exists'],
      'element_info': parsed,
    };
  }

  Future<Map<String, dynamic>> _getPageState() async {
    final url = _navigationManager.currentUrl;
    final title = await _getPageTitle();

    return {
      'success': true,
      'url': url,
      'title': title['title'],
      'tab_count': _tabManager.tabs.length,
      'active_tab_index': _tabManager.activeTabIndex,
      'can_go_back': await _navigationManager.canGoBack,
      'can_go_forward': await _navigationManager.canGoForward,
    };
  }

  Future<Map<String, dynamic>> _refreshPage() async {
    if (_currentController == null) {
      throw Exception('No active browser controller');
    }

    await _currentController!.reload();

    // Wait a bit for reload to start
    await Future.delayed(const Duration(seconds: 1));

    return {
      'success': true,
      'message': 'Page refresh initiated',
    };
  }
}
