import 'package:flutter/material.dart';
import '../models/tab_info.dart';

class TabSelectionDialog extends StatefulWidget {
  final List<TabInfo> tabs;
  final Function(List<TabInfo>) onTabsSelected;

  const TabSelectionDialog({
    Key? key,
    required this.tabs,
    required this.onTabsSelected,
  }) : super(key: key);

  @override
  State<TabSelectionDialog> createState() => _TabSelectionDialogState();
}

class _TabSelectionDialogState extends State<TabSelectionDialog> {
  final Set<String> _selectedTabIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Tabs to Add Context'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose one or more tabs to include their content in your chat with the AI assistant.'),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.tabs.length,
                itemBuilder: (context, index) {
                  final tab = widget.tabs[index];
                  final isSelected = _selectedTabIds.contains(tab.id);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTabIds.remove(tab.id);
                          } else {
                            _selectedTabIds.add(tab.id);
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected ? Theme.of(context).primaryColor : null,
                        foregroundColor: isSelected ? Colors.white : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check : Icons.check_box_outline_blank,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                tab.title.isNotEmpty ? tab.title : 'New Tab',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                tab.url.isNotEmpty ? tab.url : 'about:blank',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                ),
                              ),
                              Text(
                                'Will be: @${_createShortTabName(tab.title.isNotEmpty ? tab.title : 'New Tab')}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              ],
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedTabIds.isNotEmpty ? _confirmSelection : null,
          child: Text('Add ${_selectedTabIds.length} Tab${_selectedTabIds.length != 1 ? 's' : ''}'),
        ),
      ],
    );
  }

  String _createShortTabName(String fullName) {
    // Create a short name by taking first word or first 15 characters
    final words = fullName.split(' ');
    if (words.length > 1 && words[0].length <= 15) {
      return words[0];
    }
    return fullName.length > 15 ? fullName.substring(0, 15) : fullName;
  }

  void _confirmSelection() {
    final selectedTabs = widget.tabs.where((tab) => _selectedTabIds.contains(tab.id)).toList();
    widget.onTabsSelected(selectedTabs);
    Navigator.of(context).pop();
  }
}
