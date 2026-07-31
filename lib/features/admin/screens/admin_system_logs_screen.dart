import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';

class AdminSystemLogsScreen extends StatefulWidget {
  const AdminSystemLogsScreen({super.key});

  @override
  State<AdminSystemLogsScreen> createState() => _AdminSystemLogsScreenState();
}

class _AdminSystemLogsScreenState extends State<AdminSystemLogsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await FunctionsService.call('adminGetSystemLogs', {'limit': 100});
      final raw = (res['logs'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _logs = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('System Audit Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _loading,
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!,
                        style: const TextStyle(color: AppColors.error)),
                  ],
                ),
              )
            : _logs.isEmpty
                ? const EmptyState(
                    icon: Icons.history_edu,
                    title: 'No Logs Found',
                    subtitle: 'No system audit logs found for the platform.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final action = log['action'] ?? 'Unknown Action';
                      final targetId = log['targetId'] ?? '';
                      final targetType = log['targetType'] ?? '';
                      final performedBy = log['performedBy'] ?? 'system';
                      final timestamp = log['timestamp'] != null
                          ? DateTime.tryParse(log['timestamp'])
                          : null;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.list_alt_rounded, size: 20),
                        ),
                        title: Text(action.toString().toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Target: $targetType ($targetId)'),
                            Text('Performed by: $performedBy'),
                          ],
                        ),
                        trailing: timestamp != null
                            ? Text(
                                DateFormat('MMM dd, HH:mm').format(timestamp),
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12))
                            : const SizedBox(),
                        isThreeLine: true,
                      );
                    },
                  ),
      ),
    );
  }
}
