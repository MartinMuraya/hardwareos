import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/providers/business_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final _promptController = TextEditingController();
  final List<Map<String, String>> _messages = [];
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
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _askGemini({String? predefinedPrompt, String? quickInsightType}) async {
    final biz = context.read<BusinessProvider>();
    if (biz.businessId == null) return;
    if (biz.plan != 'pro') {
      _showUpgradeDialog();
      return;
    }

    final prompt = predefinedPrompt ?? _promptController.text.trim();
    if (prompt.isEmpty && quickInsightType == null) return;

    setState(() {
      if (prompt.isNotEmpty) {
        _messages.add({'role': 'user', 'text': prompt});
      } else if (quickInsightType != null) {
        _messages.add({'role': 'user', 'text': 'Generate $quickInsightType insights'});
      }
      _loading = true;
    });
    
    _promptController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      final functions = FirebaseFunctions.instance;
      String responseText = "";

      if (quickInsightType != null) {
        final res = await functions.httpsCallable('getAIQuickInsights').call({
          'businessId': biz.businessId,
          'type': quickInsightType,
        });
        responseText = res.data['insights'] as String;
      } else {
        final res = await functions.httpsCallable('getAIInsights').call({
          'businessId': biz.businessId,
          'prompt': prompt,
        });
        responseText = res.data['insights'] as String;
      }

      setState(() {
        _messages.add({'role': 'ai', 'text': responseText});
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Error: ${e.message}'});
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'An unexpected error occurred.'});
        _loading = false;
      });
    }
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accent),
            SizedBox(width: 8),
            Text('Pro Feature'),
          ],
        ),
        content: const Text('AI Assistant is available exclusively on the Pro plan. Upgrade to unlock powerful business insights.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to billing (not implemented in this snippet)
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = Responsive.padding(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Business Advisor'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
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
                        child: const Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.accent),
                      ),
                      const SizedBox(height: 24),
                      Text('How can I help your business today?',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildQuickAction('Inventory Health', Icons.inventory_2, () => _askGemini(quickInsightType: 'inventory_optimization')),
                          _buildQuickAction('Sales Trends', Icons.trending_up, () => _askGemini(quickInsightType: 'sales_trends')),
                          _buildQuickAction('Profit Analysis', Icons.attach_money, () => _askGemini(quickInsightType: 'profit_analysis')),
                          _buildQuickAction('Reorder Suggestions', Icons.shopping_cart, () => _askGemini(quickInsightType: 'reorder_suggestions')),
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
                  final isUser = msg['role'] == 'user';
                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? 300 : 600),
                      decoration: BoxDecoration(
                        color: isUser ? AppColors.accent : theme.cardColor,
                        borderRadius: BorderRadius.circular(16).copyWith(
                          bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(16),
                          bottomLeft: !isUser ? const Radius.circular(0) : const Radius.circular(16),
                        ),
                      ),
                      child: isUser
                          ? Text(msg['text']!, style: const TextStyle(color: Colors.white))
                          : MarkdownBody(data: msg['text']!),
                    ),
                  );
                },
              ),
            ),
          
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),

          // Input area
          Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    decoration: InputDecoration(
                      hintText: 'Ask about your sales, inventory, or expenses...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onSubmitted: (_) => _askGemini(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _loading ? null : _askGemini,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.accent),
      label: Text(title),
      onPressed: onTap,
      backgroundColor: AppColors.accent.withValues(alpha: 0.1),
      side: BorderSide.none,
    );
  }
}
