import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';

class AIIntelligenceScreen extends StatefulWidget {
  const AIIntelligenceScreen({super.key});

  @override
  State<AIIntelligenceScreen> createState() => _AIIntelligenceScreenState();
}

class _AIIntelligenceScreenState extends State<AIIntelligenceScreen> {
  bool _isLoading = false;
  String? _reportMarkdown;
  String? _error;

  Future<void> _runAIAnalysis() async {
    final businessId =
        context.read<AuthProvider>().userProfile?['businessId'] as String?;
    if (businessId == null) {
      setState(() => _error = "Business ID not found.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _reportMarkdown = null;
    });

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('analyzeInventoryHealth');
      final result = await callable.call({'businessId': businessId});

      setState(() {
        _reportMarkdown = result.data['report'] as String;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = "Server Error: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Inventory Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Run Analysis',
            onPressed: _isLoading ? null : _runAIAnalysis,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text(
                      'Gemini is analyzing your inventory ledger...',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: AppColors.error),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 16),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _runAIAnalysis,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _reportMarkdown != null
                    ? Container(
                        margin: Responsive.isDesktop(context)
                            ? const EdgeInsets.symmetric(
                                horizontal: 120, vertical: 24)
                            : const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Markdown(
                          data: _reportMarkdown!,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            h1: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accent),
                            h2: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                            p: const TextStyle(fontSize: 16, height: 1.5),
                            listBullet: const TextStyle(fontSize: 16),
                          ),
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 80,
                                color: AppColors.accent.withValues(alpha: 0.5)),
                            const SizedBox(height: 24),
                            Text(
                              'Ready for AI Analysis',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Generate a mathematically-backed report on your stock health.',
                              style: TextStyle(
                                  color: Colors.black54, fontSize: 16),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _runAIAnalysis,
                              icon: const Icon(Icons.analytics),
                              label: const Text('Analyze Now',
                                  style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }
}
