import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../models/smart_note.dart';

class SmartNotesWindow extends StatefulWidget {
  final List<SmartNote> notes;
  final Function(SmartNote) onDeleteNote;
  final Function(SmartNote) onEditNote;
  final VoidCallback onClose;

  const SmartNotesWindow({
    super.key,
    required this.notes,
    required this.onDeleteNote,
    required this.onEditNote,
    required this.onClose,
  });

  @override
  State<SmartNotesWindow> createState() => _SmartNotesWindowState();
}

class _SmartNotesWindowState extends State<SmartNotesWindow> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SmartNote? _editingNote;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(SmartNote note) {
    setState(() {
      _editingNote = note;
      _editController.text = note.content;
    });
  }

  void _saveEdit() {
    if (_editingNote != null && _editController.text.trim().isNotEmpty) {
      final updatedNote = _editingNote!.copyWith(
        content: _editController.text.trim(),
        updatedAt: DateTime.now(),
      );
      widget.onEditNote(updatedNote);
    }
    setState(() {
      _editingNote = null;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingNote = null;
    });
  }

  List<SmartNote> get _filteredNotes {
    if (_searchQuery.isEmpty) {
      return widget.notes;
    }
    return widget.notes.where((note) =>
      note.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      (note.sourceTitle?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
      (note.sourceUrl?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
    ).toList();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        height: 700,
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ShadTheme.of(context).colorScheme.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    HeroiconsOutline.documentText,
                    size: 20,
                    color: ShadTheme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Smart Notes',
                    style: ShadTheme.of(context).textTheme.h3.copyWith(
                      color: ShadTheme.of(context).colorScheme.foreground,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: Icon(
                      HeroiconsOutline.xMark,
                      size: 20,
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: Icon(
                    HeroiconsOutline.magnifyingGlass,
                    size: 16,
                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: ShadTheme.of(context).colorScheme.primary,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),

            // Notes list
            Expanded(
              child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          HeroiconsOutline.documentText,
                          size: 48,
                          color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                            ? 'No notes yet. Right-click on text to add notes!'
                            : 'No notes found matching "${_searchQuery}"',
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(context).colorScheme.mutedForeground,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      final isEditing = _editingNote?.id == note.id;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ShadTheme.of(context).colorScheme.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ShadTheme.of(context).colorScheme.border,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with source and date
                            Row(
                              children: [
                                if (note.sourceTitle != null) ...[
                                  Icon(
                                    HeroiconsOutline.globeAlt,
                                    size: 14,
                                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      note.sourceTitle!,
                                      style: ShadTheme.of(context).textTheme.small.copyWith(
                                        color: ShadTheme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ] else ...[
                                  Icon(
                                    HeroiconsOutline.documentText,
                                    size: 14,
                                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Manual Note',
                                    style: ShadTheme.of(context).textTheme.small.copyWith(
                                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Text(
                                  _formatDate(note.createdAt),
                                  style: ShadTheme.of(context).textTheme.small.copyWith(
                                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Content
                            if (isEditing) ...[
                              TextField(
                                controller: _editController,
                                maxLines: null,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  contentPadding: const EdgeInsets.all(8),
                                ),
                                style: ShadTheme.of(context).textTheme.small.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: _cancelEdit,
                                    child: Text(
                                      'Cancel',
                                      style: ShadTheme.of(context).textTheme.small.copyWith(
                                        color: ShadTheme.of(context).colorScheme.mutedForeground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _saveEdit,
                                    child: Text(
                                      'Save',
                                      style: ShadTheme.of(context).textTheme.small,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                note.content,
                                style: ShadTheme.of(context).textTheme.small.copyWith(
                                  color: ShadTheme.of(context).colorScheme.foreground,
                                  height: 1.4,
                                ),
                              ),

                              // Actions
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    onPressed: () => _startEditing(note),
                                    icon: Icon(
                                      HeroiconsOutline.pencil,
                                      size: 14,
                                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                                    ),
                                    tooltip: 'Edit note',
                                    constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                    padding: EdgeInsets.zero,
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    onPressed: () => widget.onDeleteNote(note),
                                    icon: Icon(
                                      HeroiconsOutline.trash,
                                      size: 14,
                                      color: ShadTheme.of(context).colorScheme.destructive,
                                    ),
                                    tooltip: 'Delete note',
                                    constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                                    padding: EdgeInsets.zero,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
