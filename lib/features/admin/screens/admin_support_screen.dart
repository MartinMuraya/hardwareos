import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';

class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _tickets = [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await FunctionsService.call(
          'adminGetSupportTickets', {'status': _filter});
      final list = (res['tickets'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _tickets =
              list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _respondToTicket(String ticketId, String currentSubject) async {
    final msgCtrl = TextEditingController();
    String newStatus = 'answered';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text('Respond: $currentSubject'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: msgCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Your Response', border: OutlineInputBorder()),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: newStatus,
                  decoration: const InputDecoration(labelText: 'Update Status'),
                  items: const [
                    DropdownMenuItem(
                        value: 'answered', child: Text('Answered')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                    DropdownMenuItem(value: 'open', child: Text('Keep Open')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => newStatus = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Send Response'),
              ),
            ],
          ),
        );
      },
    );

    if (result == true && msgCtrl.text.isNotEmpty) {
      setState(() => _loading = true);
      try {
        await FunctionsService.call('adminRespondToTicket', {
          'ticketId': ticketId,
          'message': msgCtrl.text,
          'newStatus': newStatus,
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Response sent')));
        }
        _loadTickets();
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded), onPressed: _loadTickets),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) {
                    setState(() => _filter = 'all');
                    _loadTickets();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Open'),
                  selected: _filter == 'open',
                  onSelected: (_) {
                    setState(() => _filter = 'open');
                    _loadTickets();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Answered'),
                  selected: _filter == 'answered',
                  onSelected: (_) {
                    setState(() => _filter = 'answered');
                    _loadTickets();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Closed'),
                  selected: _filter == 'closed',
                  onSelected: (_) {
                    setState(() => _filter = 'closed');
                    _loadTickets();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)))
                    : _tickets.isEmpty
                        ? const EmptyState(
                            icon: Icons.support_agent_rounded,
                            title: 'No Tickets',
                            subtitle: 'No support tickets found.')
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _tickets.length,
                            itemBuilder: (context, i) {
                              final ticket = _tickets[i];
                              final ts = ticket['createdAt'] != null
                                  ? DateTime.tryParse(ticket['createdAt'])
                                  : null;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(ticket['subject'] ?? 'No Subject',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 8),
                                      Text(
                                          'Business ID: ${ticket['businessId']}'),
                                      if (ts != null)
                                        Text(
                                            'Created: ${DateFormat('MMM dd, HH:mm').format(ts)}'),
                                    ],
                                  ),
                                  trailing: _StatusBadge(
                                      status: ticket['status'] ?? 'open'),
                                  onTap: () => _respondToTicket(
                                      ticket['id'], ticket['subject'] ?? ''),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'open':
        color = AppColors.warning;
        break;
      case 'answered':
        color = AppColors.success;
        break;
      case 'closed':
        color = Colors.grey;
        break;
      default:
        color = AppColors.accent;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
