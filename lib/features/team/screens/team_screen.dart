import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/functions_service.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../widgets/invite_user_dialog.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  String? _error;
  List<User> _team = [];

  @override
  void initState() {
    super.initState();
    _loadTeam();
  }

  Future<void> _loadTeam() async {
    setState(() { _loading = true; _error = null; });
    try {
      final bizId = context.read<AuthProvider>().businessId!;
      final result = await FunctionsService.call('getUsers', {'businessId': bizId});
      final rawList = (result['users'] as List?) ?? [];
      
      final users = rawList
          .map((e) => User.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (mounted) {
        setState(() {
          _team = users;
          _loading = false;
        });
      }
    } on FunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _showInviteDialog() {
    showDialog(
      context: context,
      builder: (_) => InviteUserDialog(onUserInvited: _loadTeam),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canInvite = auth.userRole == 'owner' || auth.userRole == 'manager';

    return LoadingOverlay(
      isLoading: _loading,
      message: 'Loading team...',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Team Management', style: AppTheme.darkTheme.textTheme.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${_team.length} member(s)',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (canInvite)
                    FilledButton.icon(
                      onPressed: _showInviteDialog,
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Invite Staff'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),

              Expanded(
                child: _team.isEmpty && !_loading
                    ? EmptyState(
                        icon: Icons.people_outline_rounded,
                        title: 'No team members yet',
                        subtitle: 'Invite staff or managers to help run your business.',
                        actionLabel: canInvite ? 'Invite Staff' : null,
                        onAction: canInvite ? _showInviteDialog : null,
                      )
                    : RefreshIndicator(
                        onRefresh: _loadTeam,
                        color: AppColors.accent,
                        backgroundColor: AppColors.card,
                        child: ListView.separated(
                          itemCount: _team.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _TeamMemberCard(user: _team[i]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final User user;
  const _TeamMemberCard({required this.user});

  @override
  Widget build(BuildContext context) {
    Color roleColor;
    switch (user.role) {
      case 'owner':   roleColor = AppColors.chartBlue; break;
      case 'manager': roleColor = AppColors.chartPurple; break;
      default:        roleColor = AppColors.textHint;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : 'Unknown User',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                if (user.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user.role.toUpperCase(),
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
