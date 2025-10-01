import 'package:flutter/material.dart';
import '../widgets/tab_sidebar.dart';

class ContextTreeSelectionDialog extends StatefulWidget {
  final List<ContextNode> contextNodes;
  final Function(List<ContextNode>) onNodesSelected;

  const ContextTreeSelectionDialog({
    Key? key,
    required this.contextNodes,
    required this.onNodesSelected,
  }) : super(key: key);

  @override
  State<ContextTreeSelectionDialog> createState() => _ContextTreeSelectionDialogState();
}

class _ContextTreeSelectionDialogState extends State<ContextTreeSelectionDialog> {
  final Set<String> _selectedNodeUrls = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Context Tree Nodes'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose one or more nodes from the context tree to include their content in your chat with the AI assistant.'),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.contextNodes.length,
                itemBuilder: (context, index) {
                  final node = widget.contextNodes[index];
                  final isSelected = _selectedNodeUrls.contains(node.url);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          if (isSelected) {
                            _selectedNodeUrls.remove(node.url);
                          } else {
                            _selectedNodeUrls.add(node.url);
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
                                  node.title.isNotEmpty ? node.title : 'Unknown Title',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  node.url.isNotEmpty ? node.url : 'No URL',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                  ),
                                ),
                                Text(
                                  'Will be: @${_createShortNodeName(node.title.isNotEmpty ? node.title : 'Unknown Title')}',
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
          onPressed: _selectedNodeUrls.isNotEmpty ? _confirmSelection : null,
          child: Text('Add ${_selectedNodeUrls.length} Node${_selectedNodeUrls.length != 1 ? 's' : ''}'),
        ),
      ],
    );
  }

  String _createShortNodeName(String fullName) {
    // Create a short name by taking first word or first 15 characters
    final words = fullName.split(' ');
    if (words.length > 1 && words[0].length <= 15) {
      return words[0];
    }
    return fullName.length > 15 ? fullName.substring(0, 15) : fullName;
  }

  void _confirmSelection() {
    final selectedNodes = widget.contextNodes.where((node) => _selectedNodeUrls.contains(node.url)).toList();
    widget.onNodesSelected(selectedNodes);
    Navigator.of(context).pop();
  }
}
