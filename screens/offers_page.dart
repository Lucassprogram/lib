import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skill_chip.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  final List<_UserSkill> _offerSkills = <_UserSkill>[];
  final List<_UserSkill> _needSkills = <_UserSkill>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> rawSkills = await ApiService.getSkills();
      final List<_UserSkill> offers = <_UserSkill>[];
      final List<_UserSkill> needs = <_UserSkill>[];

      for (final dynamic raw in rawSkills) {
        if (raw is! Map<String, dynamic>) {
          continue;
        }
        final String name = raw['SkillName']?.toString().trim() ?? '';
        if (name.isEmpty) {
          continue;
        }
        final String type = raw['Type']?.toString().toLowerCase() ?? 'offer';
        final DateTime? createdAt = DateTime.tryParse(
          raw['CreatedAt']?.toString() ?? '',
        );

        final _UserSkill skill = _UserSkill(
          name: name,
          type: type == 'need' ? SkillChipType.need : SkillChipType.offer,
          createdAt: createdAt,
        );

        (type == 'need' ? needs : offers).add(skill);
      }

      offers.sort((a, b) => a.name.compareTo(b.name));
      needs.sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _offerSkills
          ..clear()
          ..addAll(offers);
        _needSkills
          ..clear()
          ..addAll(needs);
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your skills: $error';
      });
    }
  }

  Future<void> _handleAddSkill() async {
    final bool? added = await Navigator.pushNamed<bool>(context, '/addskill');
    if (added == true && mounted) {
      _loadSkills();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage My Skills')),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadSkills,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: <Widget>[
                    _SkillSummaryCard(
                      offerCount: _offerSkills.length,
                      needCount: _needSkills.length,
                      onAddSkill: _handleAddSkill,
                    ),
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _InlineMessage(message: _errorMessage!),
                    ],
                    const SizedBox(height: 24),
                    _SkillsSection(
                      title: 'I can offer',
                      skills: _offerSkills,
                      emptyLabel:
                          'Add a few skills to start sharing your strengths.',
                    ),
                    const SizedBox(height: 24),
                    _SkillsSection(
                      title: 'I want to learn',
                      skills: _needSkills,
                      emptyLabel:
                          'Add skills you want to learn to improve your matches.',
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAddSkill,
        icon: const Icon(Icons.add),
        label: const Text('Add Skill'),
      ),
    );
  }
}

class _SkillSummaryCard extends StatelessWidget {
  const _SkillSummaryCard({
    required this.offerCount,
    required this.needCount,
    required this.onAddSkill,
  });

  final int offerCount;
  final int needCount;
  final VoidCallback onAddSkill;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Keep your skills up to date',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _StatBadge(label: 'Offering', value: offerCount),
              const SizedBox(width: 16),
              _StatBadge(label: 'Looking for', value: needCount),
              const Spacer(),
              TextButton.icon(
                onPressed: onAddSkill,
                icon: const Icon(Icons.add),
                label: const Text('Add skill'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.title,
    required this.skills,
    required this.emptyLabel,
  });

  final String title;
  final List<_UserSkill> skills;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: skills
                  .map(
                    (_UserSkill skill) => SkillChip(
                      label: skill.name,
                      type: skill.type,
                      icon: skill.type == SkillChipType.offer
                          ? Icons.volunteer_activism_outlined
                          : Icons.lightbulb_outline,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.primary.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value.toString(),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserSkill {
  const _UserSkill({required this.name, required this.type, this.createdAt});

  final String name;
  final SkillChipType type;
  final DateTime? createdAt;
}
