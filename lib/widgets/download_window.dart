import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import '../models/download_info.dart';
import '../services/download_manager.dart';

class DownloadWindow extends StatefulWidget {
  final DownloadManager downloadManager;
  final VoidCallback? onClose;

  const DownloadWindow({
    Key? key,
    required this.downloadManager,
    this.onClose,
  }) : super(key: key);

  @override
  State<DownloadWindow> createState() => _DownloadWindowState();
}

class _DownloadWindowState extends State<DownloadWindow> {
  final TextEditingController _searchController = TextEditingController();
  List<DownloadInfo> _filteredDownloads = [];
  bool _showCompleted = true;
  bool _showFailed = true;

  @override
  void initState() {
    super.initState();
    debugPrint('DownloadWindow: Initializing with ${widget.downloadManager.allDownloads.length} downloads');

    _filteredDownloads = widget.downloadManager.allDownloads;
    _searchController.addListener(_filterDownloads);

    // Listen to download manager changes
    debugPrint('DownloadWindow: Setting up callbacks');
    widget.downloadManager.onDownloadListChanged = _refreshDownloads;
    widget.downloadManager.onDownloadProgressChanged = _refreshDownloads;

    debugPrint('DownloadWindow: Callbacks set up');

    // Force initial refresh after a short delay to catch any downloads that might be added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        debugPrint('DownloadWindow: Doing initial refresh');
        _refreshDownloads();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.downloadManager.onDownloadListChanged = null;
    widget.downloadManager.onDownloadProgressChanged = null;
    super.dispose();
  }

  void _refreshDownloads() {
    if (mounted) {
      final allDownloads = widget.downloadManager.allDownloads;
      final activeDownloads = widget.downloadManager.activeDownloads;
      final downloadQueue = widget.downloadManager.downloadQueue;

      debugPrint('DownloadWindow: Refresh triggered!');
      debugPrint('  Total downloads: ${allDownloads.length}');
      debugPrint('  Active downloads: ${activeDownloads.length}');
      debugPrint('  Queued downloads: ${downloadQueue.length}');

      for (final download in allDownloads) {
        debugPrint('  - ${download.filename}: ${download.status} (${download.downloadedBytes}/${download.totalBytes})');
      }

      setState(() {
        _filterDownloads();
      });

      debugPrint('DownloadWindow: UI updated');
    } else {
      debugPrint('DownloadWindow: Not mounted, skipping refresh');
    }
  }

  void _filterDownloads() {
    final query = _searchController.text.toLowerCase();
    final allDownloads = widget.downloadManager.allDownloads;

    setState(() {
      _filteredDownloads = allDownloads.where((download) {
        // Filter by search query
        final matchesSearch = query.isEmpty ||
            download.filename.toLowerCase().contains(query) ||
            download.url.toLowerCase().contains(query);

        // Filter by status
        final showBasedOnStatus = (download.status == DownloadStatus.completed && _showCompleted) ||
            (download.status == DownloadStatus.failed && _showFailed) ||
            (download.status != DownloadStatus.completed && download.status != DownloadStatus.failed);

        return matchesSearch && showBasedOnStatus;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('Downloads'),
      description: const Text('Manage your file downloads'),
      actions: [
        ShadButton.outline(
          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header with search and filters
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      controller: _searchController,
                      placeholder: const Text('Search downloads...'),
                      leading: const Icon(HeroiconsOutline.magnifyingGlass),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ShadCheckbox(
                    value: _showCompleted,
                    onChanged: (value) {
                      setState(() {
                        _showCompleted = value ?? true;
                        _filterDownloads();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Completed'),
                  const SizedBox(width: 16),
                  ShadCheckbox(
                    value: _showFailed,
                    onChanged: (value) {
                      setState(() {
                        _showFailed = value ?? true;
                        _filterDownloads();
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  const Text('Failed'),
                  const SizedBox(width: 16),
                  ShadButton.secondary(
                    onPressed: () => widget.downloadManager.clearCompletedDownloads(),
                    child: const Text('Clear Completed'),
                  ),
                ],
              ),
            ),

            // Downloads list
            Expanded(
              child: _filteredDownloads.isEmpty
                  ? const Center(
                      child: Text('No downloads found'),
                    )
                  : ListView.builder(
                      itemCount: _filteredDownloads.length,
                      itemBuilder: (context, index) {
                        final download = _filteredDownloads[index];
                        return DownloadListItem(
                          download: download,
                          downloadManager: widget.downloadManager,
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

class DownloadListItem extends StatelessWidget {
  final DownloadInfo download;
  final DownloadManager downloadManager;

  const DownloadListItem({
    Key? key,
    required this.download,
    required this.downloadManager,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filename and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    download.filename,
                    style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(download.status),
              ],
            ),

            const SizedBox(height: 4),

            // URL
            Text(
              download.url,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Progress bar for active downloads
            if (download.status == DownloadStatus.downloading ||
                download.status == DownloadStatus.paused)
              _buildProgressSection(context),

            // File info and controls
            Row(
              children: [
                Expanded(
                  child: Text(
                    _getFileInfoText(),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
                _buildActionButtons(context),
              ],
            ),

            // Error message
            if (download.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  download.errorMessage!,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.destructive,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    final (color, text) = switch (status) {
      DownloadStatus.queued => (Colors.blue, 'Queued'),
      DownloadStatus.downloading => (Colors.green, 'Downloading'),
      DownloadStatus.paused => (Colors.orange, 'Paused'),
      DownloadStatus.completed => (Colors.green.shade700, 'Completed'),
      DownloadStatus.failed => (Colors.red, 'Failed'),
      DownloadStatus.cancelled => (Colors.grey, 'Cancelled'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ShadProgress(
                value: download.progressPercentage / 100,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${download.progressPercentage.toStringAsFixed(1)}%',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${DownloadInfo.formatFileSize(download.downloadedBytes)} / ${DownloadInfo.formatFileSize(download.totalBytes)}',
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
            if (download.status == DownloadStatus.downloading) ...[
              const SizedBox(width: 12),
              Text(
                '${DownloadInfo.formatFileSize(download.downloadSpeed.toInt())}/s',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(download.estimatedTimeRemaining),
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (download.status == DownloadStatus.downloading)
          ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: () => downloadManager.pauseDownload(download.id),
            child: const Icon(HeroiconsOutline.pause, size: 16),
          )
        else if (download.status == DownloadStatus.paused)
          ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: () => downloadManager.resumeDownload(download.id),
            child: const Icon(HeroiconsOutline.play, size: 16),
          )
        else if (download.status == DownloadStatus.failed)
          ShadButton.secondary(
            size: ShadButtonSize.sm,
            onPressed: () => downloadManager.retryDownload(download.id),
            child: const Icon(HeroiconsOutline.arrowPath, size: 16),
          ),

        if (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.paused ||
            download.status == DownloadStatus.queued)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: () => downloadManager.cancelDownload(download.id),
              child: const Icon(HeroiconsOutline.xMark, size: 16),
            ),
          ),

        if (download.status == DownloadStatus.completed)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ShadButton.secondary(
              size: ShadButtonSize.sm,
              onPressed: () {
                // TODO: Open file location or show in folder
              },
              child: const Icon(HeroiconsOutline.folderOpen, size: 16),
            ),
          ),
      ],
    );
  }

  String _getFileInfoText() {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final startTime = dateFormat.format(download.startTime);

    if (download.status == DownloadStatus.completed && download.endTime != null) {
      final endTime = dateFormat.format(download.endTime!);
      return 'Started: $startTime • Completed: $endTime';
    } else if (download.status == DownloadStatus.failed || download.status == DownloadStatus.cancelled) {
      return 'Started: $startTime';
    } else {
      return 'Started: $startTime • ${DownloadInfo.formatFileSize(download.totalBytes)}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s remaining';
    }
  }
}
