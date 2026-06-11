import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _bizNameCtrl   = TextEditingController();
  bool _obscure        = true;
  bool _isSubmitting   = false;
  bool _accountCreated = false; // step 1 done, now enter biz name

  @override
  void dispose() {
    _emailCtrl.dispose(); _passCtrl.dispose(); _bizNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();
    final ok = await auth.createAccount(_emailCtrl.text.trim(), _passCtrl.text);
    if (mounted) setState(() { _isSubmitting = false; if (ok) _accountCreated = true; });
  }

  Future<void> _createBusiness() async {
    if (_bizNameCtrl.text.trim().length < 2) return;
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.createBusiness(_bizNameCtrl.text.trim());
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.accent, borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.hardware_rounded, color: AppColors.background, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text('Get Started',
                      style: AppTheme.darkTheme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text('14-day free trial • No credit card required',
                      style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                const SizedBox(height: 36),

                // Progress indicator
                Row(children: [
                  _StepDot(active: true, done: _accountCreated, label: '1. Account'),
                  Expanded(child: Container(height: 2,
                    color: _accountCreated ? AppColors.accent : AppColors.border)),
                  _StepDot(active: _accountCreated, done: false, label: '2. Business'),
                ]),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: !_accountCreated
                      ? _AccountStep(
                          emailCtrl: _emailCtrl, passCtrl: _passCtrl,
                          obscure: _obscure, isSubmitting: _isSubmitting,
                          error: auth.errorMessage,
                          onToggleObscure: () => setState(() => _obscure = !_obscure),
                          onSubmit: _createAccount,
                          onLogin: () => context.go('/login'),
                        )
                      : _BusinessStep(
                          bizNameCtrl: _bizNameCtrl, isSubmitting: _isSubmitting,
                          error: auth.errorMessage, onSubmit: _createBusiness,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, isSubmitting;
  final String? error;
  final VoidCallback onToggleObscure, onSubmit, onLogin;

  const _AccountStep({
    required this.emailCtrl, required this.passCtrl, required this.obscure,
    required this.isSubmitting, required this.error,
    required this.onToggleObscure, required this.onSubmit, required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Create Account', style: AppTheme.darkTheme.textTheme.headlineMedium),
      const SizedBox(height: 20),
      if (error != null) _ErrorBanner(message: error!),
      TextFormField(
        controller: emailCtrl,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(labelText: 'Email Address',
          prefixIcon: Icon(Icons.email_outlined, size: 18)),
        validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: passCtrl,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          suffixIcon: IconButton(
            icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18),
            onPressed: onToggleObscure,
          )),
        validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
      ),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: isSubmitting ? null : onSubmit,
        child: isSubmitting
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.background)))
          : const Text('Create Account'),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Already have an account? ',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        TextButton(onPressed: onLogin, child: const Text('Sign In')),
      ]),
    ]);
  }
}

class _BusinessStep extends StatelessWidget {
  final TextEditingController bizNameCtrl;
  final bool isSubmitting;
  final String? error;
  final VoidCallback onSubmit;

  const _BusinessStep({
    required this.bizNameCtrl, required this.isSubmitting,
    required this.error, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.store_rounded, color: AppColors.accent, size: 24),
        const SizedBox(width: 10),
        Text('Your Business', style: AppTheme.darkTheme.textTheme.headlineMedium),
      ]),
      const SizedBox(height: 6),
      const Text('This is your store name — visible to your team.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 24),
      if (error != null) _ErrorBanner(message: error!),
      TextFormField(
        controller: bizNameCtrl,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          labelText: 'Hardware Store Name',
          prefixIcon: Icon(Icons.storefront_outlined, size: 18),
          hintText: 'e.g. Muraya Hardware Ltd',
        ),
        validator: (v) => v == null || v.trim().length < 2 ? 'Enter a business name' : null,
        onFieldSubmitted: (_) => onSubmit(),
      ),
      const SizedBox(height: 24),

      // Trial info
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text(
            '14-day Pro trial included. No payment needed.',
            style: TextStyle(color: AppColors.accent, fontSize: 13),
          )),
        ]),
      ),
      const SizedBox(height: 20),

      ElevatedButton(
        onPressed: isSubmitting ? null : onSubmit,
        child: isSubmitting
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(AppColors.background)))
          : const Text('Launch My Store 🚀'),
      ),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final bool active, done;
  final String label;
  const _StepDot({required this.active, required this.done, required this.label});
  @override
  Widget build(BuildContext context) {
    final color = done || active ? AppColors.accent : AppColors.textHint;
    return Column(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: done ? AppColors.accent : (active ? AppColors.accent.withValues(alpha: 0.15) : AppColors.surfaceLight),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: done
          ? const Icon(Icons.check, size: 14, color: AppColors.background)
          : null,
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
        style: const TextStyle(color: AppColors.error, fontSize: 13))),
    ]),
  );
}
