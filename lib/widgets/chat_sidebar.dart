import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../services/settings_manager.dart';
import 'package:blurbox/blurbox.dart';
import '../widgets/tab_sidebar.dart';
import 'context_tree_selection_dialog.dart';

class ChatSidebar extends StatefulWidget {
  final bool isChatOpen;
  final double chatWidth;
  final List<Map<String, dynamic>> chatMessages;
  final TextEditingController chatController;
  final ScrollController chatScrollController;
  final VoidCallback onToggleChat;
  final VoidCallback onSendMessage;
  final Function(String) onQuickAction;
  final VoidCallback onClearChat;
  final VoidCallback onAddTabContext;
  final SettingsManager settingsManager;
  final Function(String) getLocalizedString;
  final bool isContextModeEnabled;
  final List<ContextNode> contextNodes;
  final Function(List<ContextNode>)? onAddContextNodes;
  final bool isStreaming;
  final VoidCallback? onStopStreaming;
  final bool toolModeEnabled;
  final Function(bool) onToggleToolMode;

  const ChatSidebar({
    Key? key,
    required this.isChatOpen,
    required this.chatWidth,
    required this.chatMessages,
    required this.chatController,
    required this.chatScrollController,
    required this.onToggleChat,
    required this.onSendMessage,
    required this.onQuickAction,
    required this.onClearChat,
    required this.onAddTabContext,
    required this.settingsManager,
    required this.getLocalizedString,
    required this.isContextModeEnabled,
    required this.contextNodes,
    this.onAddContextNodes,
    required this.isStreaming,
    this.onStopStreaming,
    required this.toolModeEnabled,
    required this.onToggleToolMode,
  }) : super(key: key);

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start from right (outside screen)
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    if (widget.isChatOpen) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(ChatSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChatOpen != oldWidget.isChatOpen) {
      if (widget.isChatOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  Widget _buildFlagIcon(AssistantLanguage language) {
    String flagText;
    switch (language) {
      case AssistantLanguage.english:
        flagText = '🇺🇸'; // US flag for English
        break;
      case AssistantLanguage.czech:
        flagText = '🇨🇿'; // Czech flag
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        flagText,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ShadTheme.of(context).colorScheme.primary,
            ShadTheme.of(context).colorScheme.primary.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        HeroiconsOutline.sparkles,
        size: 14,
        color: ShadTheme.of(context).colorScheme.primaryForeground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        if (_slideAnimation.value.dx == 1.0 && !widget.isChatOpen) {
          return const SizedBox();
        }

        return Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: BlurBox(
              blur: 8.0,
              color: ShadTheme.of(context).colorScheme.card.withOpacity(0.9),
              child: Container(
                width: widget.chatWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
              child: Column(
                children: [
                  // Chat header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ShadTheme.of(context).colorScheme.primary,
                      border: Border(
                        bottom: BorderSide(
                          color: ShadTheme.of(context).colorScheme.border,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildAvatar(),
                        const SizedBox(width: 8),
                        Text(
                          widget.getLocalizedString('assistant_title'),
                          style: ShadTheme.of(context).textTheme.h4.copyWith(
                            color: ShadTheme.of(context).colorScheme.primaryForeground,
                          ),
                        ),
                        const Spacer(),
                        // Language switcher
                        ShadButton(
                          onPressed: () async {
                            final newLanguage = widget.settingsManager.assistantLanguage == AssistantLanguage.english
                                ? AssistantLanguage.czech
                                : AssistantLanguage.english;
                            await widget.settingsManager.updateAssistantLanguage(newLanguage);
                          },
                          size: ShadButtonSize.sm,
                          child: _buildFlagIcon(widget.settingsManager.assistantLanguage),
                        ),
                        const SizedBox(width: 8),
                        if (widget.chatMessages.isNotEmpty)
                          ShadButton(
                            onPressed: () {
                              // Show confirmation dialog before clearing
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return ShadDialog(
                                    title: Text(widget.getLocalizedString('clear_chat_title')),
                                    description: Text(widget.getLocalizedString('clear_chat_description')),
                                    actions: [
                                      ShadButton.outline(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text(widget.getLocalizedString('cancel')),
                                      ),
                                      ShadButton.destructive(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          widget.onClearChat();
                                        },
                                        child: Text(widget.getLocalizedString('clear')),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            size: ShadButtonSize.sm,
                            child: Icon(HeroiconsOutline.trash, size: 14, color: ShadTheme.of(context).colorScheme.primaryForeground),
                          ),
                        if (widget.chatMessages.isNotEmpty)
                          const SizedBox(width: 8),
                        ShadButton(
                          onPressed: widget.onToggleChat,
                          size: ShadButtonSize.sm,
                          child: Icon(HeroiconsOutline.xMark, size: 14, color: const Color(0xFF000000)),
                        ),
                      ],
                    ),
                  ),

                  // Messages area
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: widget.chatMessages.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                        Text(
                          widget.getLocalizedString('welcome_message'),
                          textAlign: TextAlign.center,
                          style: ShadTheme.of(context).textTheme.lead.copyWith(
                            color: ShadTheme.of(context).colorScheme.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.getLocalizedString('quick_actions'),
                          style: ShadTheme.of(context).textTheme.h4.copyWith(
                            color: ShadTheme.of(context).colorScheme.foreground,
                          ),
                        ),
                                const SizedBox(height: 12),
                                _buildQuickActions(),
                              ],
                            )
                          : Column(
                              children: [
                                // Quick actions bar when there are messages
                                Container(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildCompactQuickAction('Summarize', HeroiconsOutline.documentText, 'Summarize Website'),
                                        _buildCompactQuickAction('Key Points', HeroiconsOutline.listBullet, 'Top 10 Key Points'),
                                        _buildCompactQuickAction('Topics', HeroiconsOutline.tag, 'Main Topics'),
                                        _buildCompactQuickAction('Takeaways', HeroiconsOutline.lightBulb, 'Key Takeaways'),
                                        _buildCompactQuickAction('Explain', HeroiconsOutline.academicCap, 'Explain Simply'),
                                      ],
                                    ),
                                  ),
                                ),
                                // Messages list
                                Expanded(
                                  child: ListView.builder(
                                    controller: widget.chatScrollController,
                                    itemCount: widget.chatMessages.length,
                                    itemBuilder: (context, index) {
                                final message = widget.chatMessages[index];
                                final isUser = message['sender'] == 'user';
                                final isStreaming = message['streaming'] == true;
                                final messageText = message['message'] ?? '';
                                final imageData = message['imageData'] as String?;

                                return Align(
                                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                                    ),
                                    child: Stack(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isUser
                                              ? ShadTheme.of(context).colorScheme.primary
                                              : ShadTheme.of(context).colorScheme.muted,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Display image if present
                                              if (imageData != null && imageData.isNotEmpty)
                                                Container(
                                                  margin: const EdgeInsets.only(bottom: 8),
                                                  constraints: const BoxConstraints(
                                                    maxWidth: 200,
                                                    maxHeight: 150,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isUser
                                                        ? ShadTheme.of(context).colorScheme.primaryForeground.withOpacity(0.3)
                                                        : ShadTheme.of(context).colorScheme.border,
                                                    ),
                                                  ),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Image.memory(
                                                      _base64ToImage(imageData),
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context, error, stackTrace) {
                                                        return Container(
                                                          padding: const EdgeInsets.all(8),
                                                          child: Text(
                                                            'Failed to load image',
                                                            style: TextStyle(
                                                              color: isUser
                                                                ? ShadTheme.of(context).colorScheme.primaryForeground
                                                                : ShadTheme.of(context).colorScheme.foreground,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              if (messageText.isNotEmpty)
                                                Text(
                                                  messageText,
                                                  style: ShadTheme.of(context).textTheme.p.copyWith(
                                                    color: isUser
                                                      ? ShadTheme.of(context).colorScheme.primaryForeground
                                                      : ShadTheme.of(context).colorScheme.foreground,
                                                  ),
                                                ),
                                              if (isStreaming)
                                                Padding(
                                                  padding: EdgeInsets.only(top: messageText.isNotEmpty ? 8 : 0),
                                                  child: _buildTypingIndicator(),
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Copy button
                                        if (messageText.isNotEmpty && !isStreaming)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: _CopyButton(
                                              messageText: messageText,
                                              isUser: isUser,
                                              onCopy: _copyMessageToClipboard,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                                    },
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Input area
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: ShadTheme.of(context).colorScheme.border),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Main input row
                        Row(
                          children: [
                            ShadButton.outline(
                              onPressed: _handleAddContext,
                              size: ShadButtonSize.sm,
                              child: Icon(HeroiconsOutline.plus, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ShadInput(
                                controller: widget.chatController,
                                placeholder: Text(widget.getLocalizedString('ask_me_anything')),
                                onSubmitted: (_) => widget.onSendMessage(),
                                enabled: !widget.isStreaming,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ShadButton(
                              onPressed: widget.isStreaming && widget.onStopStreaming != null
                                  ? widget.onStopStreaming
                                  : widget.onSendMessage,
                              size: ShadButtonSize.sm,
                              child: Icon(
                                widget.isStreaming && widget.onStopStreaming != null
                                    ? HeroiconsOutline.stop
                                    : HeroiconsOutline.paperAirplane,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Tool mode toggle
                        Row(
                          children: [
                            Icon(
                              widget.toolModeEnabled ? HeroiconsOutline.wrenchScrewdriver : HeroiconsOutline.chatBubbleLeft,
                              size: 16,
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.toolModeEnabled ? 'Tool Mode: ON' : 'Tool Mode: OFF',
                              style: ShadTheme.of(context).textTheme.p.copyWith(
                                color: ShadTheme.of(context).colorScheme.mutedForeground,
                              ),
                            ),
                            const Spacer(),
                            ShadSwitch(
                              value: widget.toolModeEnabled,
                              onChanged: widget.onToggleToolMode,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
  }
  
  Widget _buildQuickActions() {
    final quickActions = [
      {'title': widget.getLocalizedString('summarize_website'), 'icon': HeroiconsOutline.documentText, 'action': 'Summarize Website'},
      {'title': widget.getLocalizedString('top_10_key_points'), 'icon': HeroiconsOutline.listBullet, 'action': 'Top 10 Key Points'},
      {'title': widget.getLocalizedString('main_topics'), 'icon': HeroiconsOutline.tag, 'action': 'Main Topics'},
      {'title': widget.getLocalizedString('key_takeaways'), 'icon': HeroiconsOutline.lightBulb, 'action': 'Key Takeaways'},
      {'title': widget.getLocalizedString('explain_simply'), 'icon': HeroiconsOutline.academicCap, 'action': 'Explain Simply'},
    ];

    return Column(
      children: quickActions.map((action) => 
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          child: ShadButton.outline(
            onPressed: () => widget.onQuickAction(action['action'] as String),
            size: ShadButtonSize.sm,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action['icon'] as IconData, size: 16),
                const SizedBox(width: 8),
                Text(action['title'] as String),
              ],
            ),
          ),
        ),
      ).toList(),
    );
  }
  
  Widget _buildCompactQuickAction(String title, IconData icon, String action) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ShadButton.outline(
        onPressed: () => widget.onQuickAction(action),
        size: ShadButtonSize.sm,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        const SizedBox(width: 4),
        _buildDot(1),
        const SizedBox(width: 4),
        _buildDot(2),
      ],
    );
  }
  
  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimationController,
      builder: (context, child) {
        // Create a staggered animation for each dot
        final animationValue = (_typingAnimationController.value + (index * 0.2)) % 1.0;
        final opacity = (0.4 + (0.6 * (1 - (animationValue - 0.5).abs() * 2))).clamp(0.0, 1.0);

        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  void _copyMessageToClipboard(String messageText) async {
    try {
      await Clipboard.setData(ClipboardData(text: messageText));
      // Show a brief snackbar feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Message copied to clipboard'),
            duration: const Duration(seconds: 2),
            backgroundColor: ShadTheme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to copy message'),
            duration: const Duration(seconds: 2),
            backgroundColor: ShadTheme.of(context).colorScheme.destructive,
          ),
        );
      }
    }
  }

  void _handleAddContext() {
    if (widget.isContextModeEnabled && widget.onAddContextNodes != null) {
      // Show context tree selection dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return ContextTreeSelectionDialog(
            contextNodes: widget.contextNodes,
            onNodesSelected: widget.onAddContextNodes!,
          );
        },
      );
    } else {
      // Show regular tab selection dialog
      widget.onAddTabContext();
    }
  }

  Uint8List _base64ToImage(String base64String) {
    // Handle data URL format: "data:image/png;base64,..."
    if (base64String.startsWith('data:image/')) {
      final commaIndex = base64String.indexOf(',');
      if (commaIndex != -1) {
        base64String = base64String.substring(commaIndex + 1);
      }
    }
    return base64Decode(base64String);
  }
}

class _CopyButton extends StatefulWidget {
  final String messageText;
  final bool isUser;
  final Function(String) onCopy;

  const _CopyButton({
    required this.messageText,
    required this.isUser,
    required this.onCopy,
  });

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isPressed = true;
    });

    // Start the animation
    _animationController.forward().then((_) {
      // Copy the message
      widget.onCopy(widget.messageText);

      // Reverse the animation
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _isPressed = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _isPressed
                  ? (widget.isUser
                      ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.9)
                      : ShadTheme.of(context).colorScheme.muted.withOpacity(0.9))
                  : (widget.isUser
                      ? ShadTheme.of(context).colorScheme.primaryForeground
                      : ShadTheme.of(context).colorScheme.background).withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
              ),
              child: Icon(
                _isPressed ? HeroiconsSolid.documentDuplicate : HeroiconsOutline.documentDuplicate,
                size: 12,
                color: _isPressed
                  ? (widget.isUser
                      ? ShadTheme.of(context).colorScheme.primaryForeground.withOpacity(0.8)
                      : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8))
                  : (widget.isUser
                      ? ShadTheme.of(context).colorScheme.primary
                      : ShadTheme.of(context).colorScheme.foreground),
              ),
            ),
          );
        },
      ),
    );
  }
}
