import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class AIMessage {
  final String role;
  final String text;
  final List<Map<String, dynamic>> draftActions;

  AIMessage({required this.role, required this.text, this.draftActions = const []});
}

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _promptController = TextEditingController();
  final List<AIMessage> _messages = [];
  bool _loading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _runAnalystQuery({required String queryType, String? userText}) async {
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId;

    final prompt = userText ?? _promptController.text.trim();
    if (prompt.isEmpty && queryType == 'custom') return;

    final displayLabel = _getAnalystLabel(queryType, prompt);

    setState(() {
      _messages.add(AIMessage(role: 'user', text: displayLabel));
      _loading = true;
    });

    _promptController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final functions = FirebaseFunctions.instance;
      final res = await functions.httpsCallable('runAIBusinessAnalyst').call({
        'businessId': bizId,
        'queryType': queryType,
        'customPrompt': prompt,
      });

      final analysisText = res.data['analysisText'] as String? ?? 'Analysis complete.';
      final rawActions = (res.data['draftActions'] as List?) ?? [];
      final draftActions = rawActions.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          _messages.add(AIMessage(role: 'ai', text: analysisText, draftActions: draftActions));
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AIMessage(role: 'ai', text: 'Error: ${e.message}'));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(AIMessage(role: 'ai', text: 'Failed to complete analysis: $e'));
          _loading = false;
        });
      }
    }
  }

  String _getAnalystLabel(String queryType, String prompt) {
    switch (queryType) {
      case 'runout_forecast': return 'Which products will run out next week?';
      case 'profit_variance': return 'Why did profit decrease this month?';
      case 'supplier_reorder': return 'Which supplier should I reorder from?';
      case 'anomaly_detection': return 'Detect suspicious inventory adjustments';
      case 'revenue_forecast': return 'Forecast next month\'s revenue';
      case 'optimal_reorder': return 'Recommend optimal reorder quantities';
      default: return prompt;
    }
  }

  Future<void> _approveAction(Map<String, dynamic> action) async {
    final auth = context.read<AuthProvider>();
    final bizId = auth.businessId!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final res = await FirebaseFunctions.instance.httpsCallable('approveAIDraftedAction').call({
        'businessId': bizId,
        'actionType': action['actionType'],
        'payload': action['payload'],
      });

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(res.data['message'] ?? 'Action approved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Approval failed: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Business Analyst', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('Autonomous Operations & Risk Intelligence', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded),
            tooltip: 'Clear Chat',
            onPressed: () => setState(() => _messages.clear()),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.analytics_rounded, size: 64, color: AppColors.accent),
                      ),
                      const SizedBox(height: 24),
                      Text('Senior Retail Business Analyst', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Select an executive analytical query or ask custom operational questions below.',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildAnalystQueryChip('Which products run out next week?', Icons.speed_rounded, 'runout_forecast'),
                          _buildAnalystQueryChip('Why did profit change this month?', Icons.trending_down_rounded, 'profit_variance'),
                          _buildAnalystQueryChip('Which supplier to reorder from?', Icons.local_shipping_rounded, 'supplier_reorder'),
                          _buildAnalystQueryChip('Detect suspicious inventory losses', Icons.security_rounded, 'anomaly_detection'),
                          _buildAnalystQueryChip('Forecast next month\'s revenue', Icons.insights_rounded, 'revenue_forecast'),
                          _buildAnalystQueryChip('Recommend optimal reorder quantities', Icons.auto_awesome_rounded, 'optimal_reorder'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(pad),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg.role == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? 320 : 650),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.accent : theme.cardColor,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                          bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                        ),
                        border: isUser ? null : Border.all(color: theme.dividerColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isUser)
                            Text(msg.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                          else
                            MarkdownBody(data: msg.text),
                          if (!isUser && msg.draftActions.isNotEmpty) ...[
                            const Divider(height: 24),
                            Text('🤖 Proposed Autonomous Actions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                            const SizedBox(height: 8),
                            ...msg.draftActions.map((action) => _buildActionProposalCard(action, theme)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_loading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Text('Analyst evaluating sales velocity, inventory, and profit drivers...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: 'Ask the analyst (e.g. "Forecast profit for next quarter")...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onSubmitted: (_) => _runAnalystQuery(queryType: 'custom'),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _loading ? null : () => _runAnalystQuery(queryType: 'custom'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalystQueryChip(String title, IconData icon, String queryType) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onPressed: () => _runAnalystQuery(queryType: queryType),
      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }

  Widget _buildActionProposalCard(Map<String, dynamic> action, ThemeData theme) {
    final payload = Map<String, dynamic>.from(action['payload'] as Map? ?? {});
    final items = (payload['items'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action['title'] ?? 'Proposed Action',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(action['description'] ?? '', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Items in Draft:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            ...items.map((it) {
              final map = Map<String, dynamic>.from(it as Map);
              return Text('• ${map['productName'] ?? 'Item'}: Qty ${map['quantity']}', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant));
            }),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => _approveAction(action),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Approve & Draft Purchase Order'),
            ),
          ),
        ],
      ),
    );
  }
}
