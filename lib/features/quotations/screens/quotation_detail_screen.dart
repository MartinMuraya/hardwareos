import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/quotation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/quotation_pdf.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/quotation_status_badge.dart';

class QuotationDetailScreen extends StatefulWidget {
  final String quotationId;
  const QuotationDetailScreen({required this.quotationId, super.key});
  @override
  State<QuotationDetailScreen> createState() => _QuotationDetailScreenState();
}

class _QuotationDetailScreenState extends State<QuotationDetailScreen> {
  Quotation? _quotation;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  final _fmt = NumberFormat.currency(locale: 'en_KE', symbol: 'KES ');
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final data = await FunctionsService.call('getQuotation', {
        'businessId': bizId, 'quotationId': widget.quotationId,
      });
      final qt = Quotation.fromMap(Map<String, dynamic>.from(data['quotation'] as Map));
      if (mounted) setState(() { _quotation = qt; _loading = false; });
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      await FunctionsService.call('updateQuotationStatus', {
        'businessId': bizId, 'quotationId': widget.quotationId, 'status': status,
      });
      if (mounted) _load();
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _actionLoading = false; });
    }
  }

  Future<void> _sharePdf() async {
    if (_quotation == null) return;
    try {
      final pdf = await generateQuotationPdf(_quotation!);
      await Printing.sharePdf(
        bytes: pdf,
        filename: '${_quotation!.quotationNumber.replaceAll('/', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _convertToSale() async {
    final authProvider = context.read<AuthProvider>();
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: const Text('Convert to Sale'),
        content: const Text('Select payment method for this sale.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'cash'), child: const Text('Cash')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'mpesa'), child: const Text('M-Pesa')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'credit'), child: const Text('Credit')),
        ],
      ),
    );
    if (method == null) return;

    setState(() { _actionLoading = true; _error = null; });
    try {
      final bizId = authProvider.businessId!;
      await FunctionsService.call('convertQuotationToSale', {
        'businessId': bizId, 'quotationId': widget.quotationId, 'paymentMethod': method,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sale created ($method).')),
        );
        _load();
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _actionLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LoadingOverlay(
      isLoading: _loading || _actionLoading,
      message: _actionLoading ? 'Processing...' : 'Loading...',
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_quotation?.quotationNumber ?? 'Quotation'),
          actions: [
            if (_quotation != null)
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: 'Share PDF',
                onPressed: _sharePdf,
              ),
            if (_quotation != null && _quotation!.isEditable)
              PopupMenuButton<String>(
                onSelected: _updateStatus,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'sent', child: Text('Mark as Sent')),
                ],
              ),
            if (_quotation != null && _quotation!.status == 'sent')
              PopupMenuButton<String>(
                onSelected: _updateStatus,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'accepted', child: Text('Mark as Accepted')),
                  const PopupMenuItem(value: 'rejected', child: Text('Mark as Rejected')),
                ],
              ),
          ],
        ),
        body: _quotation == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(Responsive.padding(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                    ),

                  // Header card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_quotation!.quotationNumber,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(_quotation!.customerName,
                            style: theme.textTheme.bodyMedium),
                          if (_quotation!.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(_quotation!.customerPhone,
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        ])),
                        QuotationStatusBadge(status: _quotation!.status),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(children: [
                        _InfoChip(label: 'Date', value: _dateFmt.format(_quotation!.createdAt), theme: theme),
                        if (_quotation!.validUntil != null) ...[
                          Container(width: 1, height: 30, color: theme.dividerColor),
                          _InfoChip(label: 'Valid Until', value: _dateFmt.format(_quotation!.validUntil!), theme: theme),
                        ],
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Items table
                  Text('Items', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(children: [
                      ..._quotation!.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(item.name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
                          SizedBox(width: 60, child: Text('x${item.quantity}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                          SizedBox(width: 80, child: Text(_fmt.format(item.unitPrice),
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant))),
                          SizedBox(width: 80, child: Text(_fmt.format(item.total),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        ]),
                      )),
                      const Divider(),
                      _QtRow('Subtotal', _fmt.format(_quotation!.subtotal), theme: theme),
                      if (_quotation!.discountAmount > 0)
                        _QtRow('Discount', '-${_fmt.format(_quotation!.discountAmount)}',
                          color: AppColors.error, theme: theme),
                      const SizedBox(height: 4),
                      _QtRow('Total', _fmt.format(_quotation!.total),
                        color: AppColors.accent, bold: true, theme: theme),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  if (_quotation!.notes.isNotEmpty) ...[
                    Text('Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text(_quotation!.notes,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Convert to sale button
                  if (_quotation!.isConvertible)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _convertToSale,
                        icon: const Icon(Icons.sell_rounded, size: 18),
                        label: const Text('Convert to Sale'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ]),
              ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label, value;
  final ThemeData theme;
  const _InfoChip({required this.label, required this.value, required this.theme});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: theme.colorScheme.onSurface)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
  ]));
}

class _QtRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold;
  final ThemeData theme;
  const _QtRow(this.label, this.value, {this.color, this.bold = false, required this.theme});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
      Text(value, style: TextStyle(
        color: color ?? theme.colorScheme.onSurface,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        fontSize: 13,
      )),
    ]),
  );
}
