import 'package:flutter/material.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../services/ollama_service.dart';
import '../services/openrouter_service.dart';
import '../services/adblock_service.dart';
import '../services/settings_manager.dart';
import '../services/update_service.dart';
import 'package:dyn_mouse_scroll/dyn_mouse_scroll.dart';
import 'package:blurbox/blurbox.dart';

class SettingsWindow extends StatefulWidget {
  final double mouseSensitivity;
  final double trackpadSensitivity; // Keep for compatibility but unused
  final bool smoothScrolling;
  final double scrollFriction;
  final double scrollDeceleration;
  final double scrollMinVelocity;
  final double scrollMaxVelocity;
  final AppTheme appTheme;
  final AIProvider aiProvider;
  final String ollamaBaseUrl;
  final String ollamaModel;
  final String openRouterApiKey;
  final String openRouterModel;
  final OllamaService ollamaService;
  final OpenRouterService openRouterService;
  final bool adBlockingEnabled;
  final AdBlockService adBlockService;
  final bool autoCheckForUpdates;
  final Duration updateCheckInterval;
  final bool autoDownloadUpdates;
  final bool showUpdateNotifications;
  final DateTime? lastUpdateCheck;
  final UpdateService updateService;
  final bool updateDownloaded;
  final void Function(double scrollSpeed, bool smoothScrolling) onSettingsChanged;
  final void Function(double friction, double deceleration, double minVelocity, double maxVelocity) onScrollPhysicsChanged;
  final void Function(AppTheme theme) onThemeSettingsChanged;
  final void Function(String baseUrl, String model) onAISettingsChanged;
  final void Function(AIProvider provider, String apiKey, String model) onAIProviderSettingsChanged;
  final void Function(bool enabled) onAdBlockSettingsChanged;
  final void Function(bool autoCheck, Duration interval, bool autoDownload, bool showNotifications) onUpdateSettingsChanged;

  const SettingsWindow({
    super.key,
    required this.mouseSensitivity,
    required this.trackpadSensitivity,
    required this.smoothScrolling,
    required this.scrollFriction,
    required this.scrollDeceleration,
    required this.scrollMinVelocity,
    required this.scrollMaxVelocity,
    required this.appTheme,
    required this.aiProvider,
    required this.ollamaBaseUrl,
    required this.ollamaModel,
    required this.openRouterApiKey,
    required this.openRouterModel,
    required this.ollamaService,
    required this.openRouterService,
    required this.adBlockingEnabled,
    required this.adBlockService,
    required this.autoCheckForUpdates,
    required this.updateCheckInterval,
    required this.autoDownloadUpdates,
    required this.showUpdateNotifications,
    required this.lastUpdateCheck,
    required this.updateService,
    required this.updateDownloaded,
    required this.onSettingsChanged,
    required this.onScrollPhysicsChanged,
    required this.onThemeSettingsChanged,
    required this.onAISettingsChanged,
    required this.onAIProviderSettingsChanged,
    required this.onAdBlockSettingsChanged,
    required this.onUpdateSettingsChanged,
  });

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> with TickerProviderStateMixin {
  late double _mouseSensitivity;
  late double _trackpadSensitivity; // ignore: unused_field
  late bool _smoothScrolling;
  late double _scrollFriction;
  late double _scrollDeceleration;
  late double _scrollMinVelocity;
  late double _scrollMaxVelocity;
  late AppTheme _appTheme;
  late AIProvider _aiProvider;
  late String _ollamaBaseUrl;
  late String _ollamaModel;
  late String _openRouterApiKey;
  late String _openRouterModel;
  late bool _adBlockingEnabled;
  late bool _autoCheckForUpdates;
  late Duration _updateCheckInterval;
  late bool _autoDownloadUpdates;
  late bool _showUpdateNotifications;
  late DateTime? _lastUpdateCheck;

  late TabController _tabController;
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _openRouterApiKeyController = TextEditingController();
  final TextEditingController _openRouterModelController = TextEditingController();

  bool _isTestingConnection = false;
  bool _isConnected = false;
  String _connectionStatus = '';

  // Update state
  bool _isCheckingForUpdates = false;
  bool _isDownloadingUpdate = false;
  bool _updateAvailable = false;
  bool _updateDownloaded = false;
  ReleaseInfo? _latestRelease;
  String _updateStatus = '';
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _mouseSensitivity = widget.mouseSensitivity;
    _trackpadSensitivity = widget.trackpadSensitivity;
    _smoothScrolling = widget.smoothScrolling;
    _scrollFriction = widget.scrollFriction;
    _scrollDeceleration = widget.scrollDeceleration;
    _scrollMinVelocity = widget.scrollMinVelocity;
    _scrollMaxVelocity = widget.scrollMaxVelocity;
    _appTheme = widget.appTheme;
    _aiProvider = widget.aiProvider;
    _ollamaBaseUrl = widget.ollamaBaseUrl;
    _ollamaModel = widget.ollamaModel;
    _openRouterApiKey = widget.openRouterApiKey;
    _openRouterModel = widget.openRouterModel;
    _adBlockingEnabled = widget.adBlockingEnabled;
    _autoCheckForUpdates = widget.autoCheckForUpdates;
    _updateCheckInterval = widget.updateCheckInterval;
    _autoDownloadUpdates = widget.autoDownloadUpdates;
    _showUpdateNotifications = widget.showUpdateNotifications;
    _lastUpdateCheck = widget.lastUpdateCheck;
    _updateDownloaded = widget.updateDownloaded;

    _tabController = TabController(length: 5, vsync: this); // Changed from 4 to 5 tabs
    _baseUrlController.text = _ollamaBaseUrl;
    _modelController.text = _ollamaModel;
    _openRouterApiKeyController.text = _openRouterApiKey;
    _openRouterModelController.text = _openRouterModel;

    _isConnected = _getCurrentService().isConnected;
    _updateConnectionStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    _openRouterApiKeyController.dispose();
    _openRouterModelController.dispose();
    super.dispose();
  }

  dynamic _getCurrentService() {
    return _aiProvider == AIProvider.ollama ? widget.ollamaService : widget.openRouterService;
  }

  void _updateConnectionStatus() {
    final providerName = _aiProvider == AIProvider.ollama ? 'Ollama' : 'OpenRouter';
    if (_isConnected) {
      _connectionStatus = 'Connected to $providerName';
    } else {
      _connectionStatus = 'Not connected to $providerName';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BlurBox(
        blur: 20.0,
        color: const Color(0xFF0F1113).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(HeroiconsOutline.cog6Tooth, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Browser Settings',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(HeroiconsOutline.xMark, color: Colors.white70, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tab Bar
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.blue,
              tabs: const [
                Tab(text: 'Scrolling'),
                Tab(text: 'Appearance'),
                Tab(text: 'AI'),
                Tab(text: 'Ad Blocking'),
                Tab(text: 'Updates'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScrollingTab(),
                  _buildAppearanceTab(),
                  _buildAITab(),
                  _buildAdBlockingTab(),
                  _buildUpdatesTab(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    widget.onSettingsChanged(_mouseSensitivity, _smoothScrolling);
                    widget.onScrollPhysicsChanged(_scrollFriction, _scrollDeceleration, _scrollMinVelocity, _scrollMaxVelocity);
                    widget.onAISettingsChanged(_ollamaBaseUrl, _ollamaModel);
                    widget.onAIProviderSettingsChanged(_aiProvider, _openRouterApiKey, _openRouterModel);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildScrollingTab() {
    return DynMouseScroll(
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSliderSetting(
              title: 'Mouse Wheel Sensitivity',
              subtitle: 'Adjust mouse wheel scrolling sensitivity (lower = smaller, smoother steps per wheel click)',
              value: _mouseSensitivity,
              min: 0.05,
              max: 2.0,
              divisions: 39,
              onChanged: (value) {
                setState(() => _mouseSensitivity = value);
              },
            ),
            const SizedBox(height: 16),
            _buildSwitchSetting(
              title: 'Smooth Webview Scrolling',
              subtitle: 'Enable smooth scrolling with momentum in web pages',
              value: _smoothScrolling,
              onChanged: (value) {
                setState(() => _smoothScrolling = value);
              },
            ),
            const SizedBox(height: 24),
            // Advanced Scroll Physics Settings
            Text(
              'Advanced Scroll Physics',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fine-tune the momentum and feel of smooth scrolling',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              title: 'Momentum Friction',
              subtitle: 'How quickly scrolling momentum slows down (lower = more momentum)',
              value: _scrollFriction,
              min: 0.7,
              max: 0.95,
              divisions: 25,
              onChanged: (value) {
                setState(() => _scrollFriction = value);
              },
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              title: 'Deceleration Rate',
              subtitle: 'How fast scrolling comes to a stop (lower = faster stop)',
              value: _scrollDeceleration,
              min: 0.8,
              max: 0.98,
              divisions: 18,
              onChanged: (value) {
                setState(() => _scrollDeceleration = value);
              },
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              title: 'Minimum Velocity',
              subtitle: 'Minimum speed before momentum scrolling stops',
              value: _scrollMinVelocity,
              min: 0.01,
              max: 1.0,
              divisions: 99,
              onChanged: (value) {
                setState(() => _scrollMinVelocity = value);
              },
            ),
            const SizedBox(height: 16),
            _buildSliderSetting(
              title: 'Maximum Velocity',
              subtitle: 'Maximum scrolling speed (higher = faster scrolling)',
              value: _scrollMaxVelocity,
              min: 15.0,
              max: 60.0,
              divisions: 45,
              onChanged: (value) {
                setState(() => _scrollMaxVelocity = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceTab() {
    return DynMouseScroll(
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Selection
            _buildThemeSelection(),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose how the browser interface appears',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Column(
            children: [
              RadioListTile<AppTheme>(
                title: const Text('Dark', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Always use dark theme', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: AppTheme.dark,
                groupValue: _appTheme,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _appTheme = value;
                    });
                    widget.onThemeSettingsChanged(value);
                  }
                },
                activeColor: Colors.blue,
                dense: true,
              ),
              const Divider(color: Colors.white24, height: 1),
              RadioListTile<AppTheme>(
                title: const Text('Light', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Always use light theme', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: AppTheme.light,
                groupValue: _appTheme,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _appTheme = value;
                    });
                    widget.onThemeSettingsChanged(value);
                  }
                },
                activeColor: Colors.blue,
                dense: true,
              ),
              const Divider(color: Colors.white24, height: 1),
              RadioListTile<AppTheme>(
                title: const Text('System', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Follow system theme preference', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: AppTheme.system,
                groupValue: _appTheme,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _appTheme = value;
                    });
                    widget.onThemeSettingsChanged(value);
                  }
                },
                activeColor: Colors.blue,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAITab() {
    return DynMouseScroll(
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Provider Selection
            _buildProviderSelection(),
            const SizedBox(height: 24),

            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.error,
                        color: _isConnected ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isConnected ? 'Connected' : 'Connection Failed',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _connectionStatus,
                    style: TextStyle(
                      color: _isConnected ? Colors.green.shade700 : Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Provider-specific settings
            if (_aiProvider == AIProvider.ollama) ...[
              // Ollama Base URL Setting
              _buildTextFieldSetting(
                title: 'Ollama Base URL',
                subtitle: 'The URL where your Ollama server is running',
                controller: _baseUrlController,
                onChanged: (value) {
                  _ollamaBaseUrl = value;
                },
              ),
              const SizedBox(height: 16),

              // Ollama Model Setting
              _buildTextFieldSetting(
                title: 'Model Name',
                subtitle: 'The Ollama model to use for AI chat (e.g., gpt-oss:20b)',
                controller: _modelController,
                onChanged: (value) {
                  _ollamaModel = value;
                },
              ),
            ] else ...[
              // OpenRouter API Key Setting
              _buildTextFieldSetting(
                title: 'OpenRouter API Key',
                subtitle: 'Your OpenRouter API key for accessing AI models',
                controller: _openRouterApiKeyController,
                obscureText: true,
                onChanged: (value) {
                  _openRouterApiKey = value;
                },
              ),
              const SizedBox(height: 16),

              // OpenRouter Model Setting
              _buildTextFieldSetting(
                title: 'Model Name',
                subtitle: 'The model to use (e.g., x-ai/grok-4-fast, openai/gpt-4)',
                controller: _openRouterModelController,
                onChanged: (value) {
                  _openRouterModel = value;
                },
              ),
            ],
            const SizedBox(height: 24),

            // Test Connection Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTestingConnection ? null : _testConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isTestingConnection
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Testing Connection...'),
                        ],
                      )
                    : const Text('Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Provider',
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose which AI service to use for chat and recommendations',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Column(
            children: [
              RadioListTile<AIProvider>(
                title: const Text('Ollama (Local)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Run AI models locally on your machine', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: AIProvider.ollama,
                groupValue: _aiProvider,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _aiProvider = value;
                      _isConnected = widget.ollamaService.isConnected;
                      _updateConnectionStatus();
                    });
                  }
                },
                activeColor: Colors.blue,
                dense: true,
              ),
              const Divider(color: Colors.white24, height: 1),
              RadioListTile<AIProvider>(
                title: const Text('OpenRouter (Cloud)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Access AI models through OpenRouter API', style: TextStyle(color: Colors.white60, fontSize: 12)),
                value: AIProvider.openrouter,
                groupValue: _aiProvider,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _aiProvider = value;
                      _isConnected = widget.openRouterService.isConnected;
                      _updateConnectionStatus();
                    });
                  }
                },
                activeColor: Colors.blue,
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isCheckingForUpdates = true;
      _updateStatus = 'Checking for updates...';
    });

    try {
      final result = await widget.updateService.checkForUpdates();

      setState(() {
        _isCheckingForUpdates = false;
        _updateAvailable = result.updateAvailable;
        _latestRelease = result.latestRelease;

        if (result.updateAvailable && result.latestRelease != null) {
          _updateStatus = 'Update available: v${result.latestRelease!.version}';
        } else if (result.error != null) {
          _updateStatus = 'Error: ${result.error}';
        } else {
          _updateStatus = 'No updates available';
        }
      });
    } catch (e) {
      setState(() {
        _isCheckingForUpdates = false;
        _updateStatus = 'Error checking for updates: $e';
      });
    }
  }

  Future<void> _downloadAndInstallUpdate() async {
    if (_latestRelease == null) return;

    setState(() {
      _isDownloadingUpdate = true;
      _downloadProgress = 0.0;
    });

    try {
      final downloadUrl = await widget.updateService.getDownloadUrlForCurrentPlatform();

      if (downloadUrl == null) {
        setState(() {
          _isDownloadingUpdate = false;
          _updateStatus = 'No download URL available for your platform';
        });
        return;
      }

      final filePath = await widget.updateService.downloadUpdate(
        downloadUrl,
        (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      if (filePath != null) {
        final success = await widget.updateService.installUpdate(filePath);

        setState(() {
          _isDownloadingUpdate = false;
          if (success) {
            _updateStatus = 'Update installed successfully. Please restart the application.';
            _updateAvailable = false;
          } else {
            _updateStatus = 'Failed to install update';
          }
        });
      } else {
        setState(() {
          _isDownloadingUpdate = false;
          _updateStatus = 'Failed to download update';
        });
      }
    } catch (e) {
      setState(() {
        _isDownloadingUpdate = false;
        _updateStatus = 'Error downloading update: $e';
      });
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    // Update service configuration based on provider
    if (_aiProvider == AIProvider.ollama) {
      widget.ollamaService.updateConfiguration(
        baseUrl: _baseUrlController.text.trim(),
        model: _modelController.text.trim(),
      );
    } else {
      widget.openRouterService.updateConfiguration(
        apiKey: _openRouterApiKeyController.text.trim(),
        model: _openRouterModelController.text.trim(),
      );
    }

    // Test connection and get detailed status
    final currentService = _getCurrentService();
    final connected = await currentService.testConnection();
    final detailedStatus = await currentService.getConnectionStatus();

    setState(() {
      _isConnected = connected;
      _isTestingConnection = false;
      _connectionStatus = detailedStatus;
    });
  }

  Widget _buildSliderSetting({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.blue,
                  overlayColor: Colors.blue.withOpacity(0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blue,
          activeTrackColor: Colors.blue.withOpacity(0.3),
          inactiveThumbColor: Colors.white60,
          inactiveTrackColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String subtitle,
    required int value,
    required List<Map<String, dynamic>> items,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: DropdownButton<int>(
            value: value,
            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            items: items.map<DropdownMenuItem<int>>((item) {
              return DropdownMenuItem<int>(
                value: item['value'] as int,
                child: Text(
                  item['label'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),
            dropdownColor: Colors.grey[800],
            underline: const SizedBox(),
            isExpanded: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextFieldSetting({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscureText,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.06),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildAdBlockingTab() {
    return DynMouseScroll(
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ad Blocking Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.block,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Enable Ad Blocking',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Automatically hide ads and block ad servers',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _adBlockingEnabled,
                        onChanged: (value) {
                          setState(() {
                            _adBlockingEnabled = value;
                          });
                          widget.onAdBlockSettingsChanged(value);
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status Information
            if (widget.adBlockService.isInitialized)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ad Blocking Active',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${widget.adBlockService.getRules().length} rules loaded',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ad Blocking Initializing',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Loading ad blocking rules...',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Features List
            const Text(
              'Features',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            _buildFeatureItem(
              'Element Hiding',
              'Hides ad elements using CSS selectors',
              Icons.visibility_off,
            ),
            const SizedBox(height: 12),

            _buildFeatureItem(
              'Domain Blocking',
              'Blocks requests to known ad servers',
              Icons.block,
            ),
            const SizedBox(height: 12),

            _buildFeatureItem(
              'Dynamic Detection',
              'Continuously monitors and hides new ads',
              Icons.search,
            ),
            const SizedBox(height: 12),

            _buildFeatureItem(
              'Content Analysis',
              'Detects ads by analyzing page content',
              Icons.analytics,
            ),

            const SizedBox(height: 24),

            // Note
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ad blocking may affect the functionality of some websites. You can disable it temporarily if needed.',
                      style: TextStyle(
                        color: Colors.blue.shade100,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return DynMouseScroll(
      builder: (context, controller, physics) => SingleChildScrollView(
        controller: controller,
        physics: physics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Update checking settings
            _buildSwitchSetting(
              title: 'Automatically check for updates',
              subtitle: 'Check for new versions periodically',
              value: _autoCheckForUpdates,
              onChanged: (value) {
                setState(() => _autoCheckForUpdates = value);
                widget.onUpdateSettingsChanged(
                  value,
                  _updateCheckInterval,
                  _autoDownloadUpdates,
                  _showUpdateNotifications,
                );
              },
            ),
            const SizedBox(height: 16),

            // Update check interval
            _buildDropdownSetting(
              title: 'Check interval',
              subtitle: 'How often to check for updates',
              value: _updateCheckInterval.inHours,
              items: const [
                {'label': 'Every 6 hours', 'value': 6},
                {'label': 'Every 12 hours', 'value': 12},
                {'label': 'Every day', 'value': 24},
                {'label': 'Every week', 'value': 168},
              ],
              onChanged: (value) {
                final interval = Duration(hours: value);
                setState(() => _updateCheckInterval = interval);
                widget.onUpdateSettingsChanged(
                  _autoCheckForUpdates,
                  interval,
                  _autoDownloadUpdates,
                  _showUpdateNotifications,
                );
              },
            ),
            const SizedBox(height: 16),

            // Auto download updates
            _buildSwitchSetting(
              title: 'Automatically download updates',
              subtitle: 'Download updates in the background when available',
              value: _autoDownloadUpdates,
              onChanged: (value) {
                setState(() => _autoDownloadUpdates = value);
                widget.onUpdateSettingsChanged(
                  _autoCheckForUpdates,
                  _updateCheckInterval,
                  value,
                  _showUpdateNotifications,
                );
              },
            ),
            const SizedBox(height: 16),

            // Show update notifications
            _buildSwitchSetting(
              title: 'Show update notifications',
              subtitle: 'Display notifications when updates are available',
              value: _showUpdateNotifications,
              onChanged: (value) {
                setState(() => _showUpdateNotifications = value);
                widget.onUpdateSettingsChanged(
                  _autoCheckForUpdates,
                  _updateCheckInterval,
                  _autoDownloadUpdates,
                  value,
                );
              },
            ),
            const SizedBox(height: 24),

            // Current version info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Current Version',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<String>(
                    future: widget.updateService.currentVersion,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          'Version ${snapshot.data}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        );
                      }
                      return const Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                  if (_lastUpdateCheck != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Last checked: ${_formatDateTime(_lastUpdateCheck!)}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Update status and actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _updateDownloaded
                    ? Colors.blue.withOpacity(0.1)
                    : _updateAvailable
                        ? Colors.green.withOpacity(0.1)
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _updateDownloaded
                      ? Colors.blue.withOpacity(0.3)
                      : _updateAvailable
                          ? Colors.green.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _updateDownloaded
                            ? Icons.download_done
                            : _updateAvailable
                                ? Icons.system_update
                                : Icons.check_circle,
                        color: _updateDownloaded
                            ? Colors.blue
                            : _updateAvailable
                                ? Colors.green
                                : Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _updateDownloaded
                              ? 'Update Downloaded'
                              : _updateAvailable
                                  ? 'Update Available'
                                  : 'Up to Date',
                          style: TextStyle(
                            color: _updateDownloaded
                                ? Colors.blue
                                : _updateAvailable
                                    ? Colors.green
                                    : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_updateDownloaded) ...[
                    const Text(
                      'Update downloaded successfully. Restart the application to apply.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ] else if (_latestRelease != null && _updateAvailable) ...[
                    Text(
                      'Version ${_latestRelease!.version} is available',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _latestRelease!.body.split('\n').first, // First line of release notes
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (_updateStatus.isNotEmpty) ...[
                    Text(
                      _updateStatus,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Action buttons
                  if (_updateDownloaded) ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Implement restart functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please restart the application manually to apply the update.'),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Restart Now'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isCheckingForUpdates ? null : _checkForUpdates,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: _isCheckingForUpdates
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text('Check for Updates'),
                          ),
                        ),
                        if (_updateAvailable) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isDownloadingUpdate ? null : _downloadAndInstallUpdate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: _isDownloadingUpdate
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Download & Install'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  if (_isDownloadingUpdate && _downloadProgress > 0) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _downloadProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_downloadProgress * 100).toStringAsFixed(1)}% downloaded',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}