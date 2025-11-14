import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skill_chip.dart';

/// Simple data model the real home page can map onto the existing UI widgets.
class RecommendedUser {
  const RecommendedUser({
    required this.userId,
    required this.displayName,
    required this.offerSkills,
    required this.needSkills,
  });

  final int userId;
  final String displayName;
  final List<String> offerSkills;
  final List<String> needSkills;

  RecommendedUser copyWithName(String name) {
    return RecommendedUser(
      userId: userId,
      displayName: name,
      offerSkills: offerSkills,
      needSkills: needSkills,
    );
  }

  String get primarySkill {
    if (offerSkills.isNotEmpty) {
      return offerSkills.first;
    }
    if (needSkills.isNotEmpty) {
      return needSkills.first;
    }
    return 'Skill swapper';
  }

  List<String> get secondaryTags {
    final List<String> tags = <String>[];
    if (offerSkills.length > 1) {
      tags.add('Offers ${offerSkills.length} skills');
    }
    if (needSkills.isNotEmpty) {
      tags.add('Needs ${needSkills.length}');
    }
    return tags;
  }
}

enum RecommendationSource { matches, browse }

/// Prototype home screen that pulls live data.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final List<RecommendedUser> _allUsers = <RecommendedUser>[];
  final List<RecommendedUser> _visibleUsers = <RecommendedUser>[];

  bool _isLoading = false;
  String? _errorMessage;
  RecommendationSource _source = RecommendationSource.matches;
  late Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = _loadRecommendations();
    _searchController.addListener(() => _applyFilter(_searchController.text));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final int currentUserId = await _readCurrentUserId();
      final List<dynamic> matchRaw = await ApiService.fetchMatchSkills();
      List<RecommendedUser> users = _mapMatchResults(matchRaw, currentUserId);
      RecommendationSource source = RecommendationSource.matches;

      if (users.isEmpty) {
        final List<dynamic> browseRaw = await ApiService.fetchBrowseSkills();
        users = _mapBrowseResults(browseRaw, currentUserId);
        source = RecommendationSource.browse;
      }

      if (users.isEmpty) {
        _allUsers
          ..clear()
          ..addAll(<RecommendedUser>[]);
        _visibleUsers
          ..clear()
          ..addAll(<RecommendedUser>[]);
        setState(() {
          _isLoading = false;
          _source = source;
        });
        return;
      }

      final List<dynamic> userRecords = await ApiService.fetchUsers();
      final Map<int, String> nameLookup = _buildNameMap(userRecords);
      final List<RecommendedUser> resolved = users
          .map(
            (RecommendedUser user) => user.copyWithName(
              nameLookup[user.userId] ?? 'User ${user.userId}',
            ),
          )
          .toList();

      _allUsers
        ..clear()
        ..addAll(resolved);
      _visibleUsers
        ..clear()
        ..addAll(resolved);

      setState(() {
        _isLoading = false;
        _source = source;
      });
      _applyFilter(_searchController.text);
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load recommendations: $error';
      });
    }
  }

  Future<int> _readCurrentUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('userId');
    if (stored == null) {
      return -1;
    }
    return int.tryParse(stored) ?? -1;
  }

  Map<int, String> _buildNameMap(List<dynamic> records) {
    final Map<int, String> result = <int, String>{};
    for (final dynamic raw in records) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final Object? idValue = raw['UserID'];
      final int? userId = idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '');
      if (userId == null) {
        continue;
      }
      final String first = raw['FirstName']?.toString() ?? '';
      final String last = raw['LastName']?.toString() ?? '';
      final String name = '$first $last'.trim();
      result[userId] = name.isEmpty ? 'User $userId' : name;
    }
    return result;
  }

  List<RecommendedUser> _mapMatchResults(
    List<dynamic> payload,
    int currentUser,
  ) {
    final List<RecommendedUser> users = <RecommendedUser>[];
    for (final dynamic raw in payload) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final Object? idValue = raw['_id'];
      final int? userId = idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '');
      if (userId == null || userId == currentUser) {
        continue;
      }

      final List<dynamic>? skillList = raw['skills'] as List<dynamic>?;
      final List<String> offerSkills = <String>[];
      final List<String> needSkills = <String>[];

      if (skillList != null) {
        for (final dynamic item in skillList) {
          String? name;
          String type = 'offer';

          if (item is Map<String, dynamic>) {
            name = item['SkillName']?.toString().trim();
            type = item['Type']?.toString().toLowerCase() ?? 'offer';
          } else {
            name = item?.toString().trim();
          }

          if (name == null || name.isEmpty) {
            continue;
          }

          final List<String> bucket = type == 'need' ? needSkills : offerSkills;
          if (!bucket.contains(name)) {
            bucket.add(name);
          }
        }
      }

      users.add(
        RecommendedUser(
          userId: userId,
          displayName: 'User $userId',
          offerSkills: offerSkills,
          needSkills: needSkills,
        ),
      );
    }
    return users;
  }

  List<RecommendedUser> _mapBrowseResults(
    List<dynamic> payload,
    int currentUser,
  ) {
    final Map<int, List<String>> offers = <int, List<String>>{};
    final Map<int, List<String>> needs = <int, List<String>>{};

    for (final dynamic raw in payload) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final Object? idValue = raw['UserId'] ?? raw['UserID'];
      final int? userId = idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '');
      if (userId == null || userId == currentUser) {
        continue;
      }

      final String skillName = raw['SkillName']?.toString() ?? '';
      if (skillName.isEmpty) {
        continue;
      }

      final String type = raw['Type']?.toString().toLowerCase() ?? 'offer';
      final Map<int, List<String>> bucket = type == 'need' ? needs : offers;
      bucket.putIfAbsent(userId, () => <String>[]);
      if (!bucket[userId]!.contains(skillName)) {
        bucket[userId]!.add(skillName);
      }
    }

    final Set<int> allUserIds = <int>{...offers.keys, ...needs.keys};
    final List<RecommendedUser> users = <RecommendedUser>[];
    for (final int userId in allUserIds) {
      users.add(
        RecommendedUser(
          userId: userId,
          displayName: 'User $userId',
          offerSkills: List<String>.from(offers[userId] ?? <String>[]),
          needSkills: List<String>.from(needs[userId] ?? <String>[]),
        ),
      );
    }
    return users;
  }

  void _applyFilter(String query) {
    final String trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      _visibleUsers
        ..clear()
        ..addAll(_allUsers);
      setState(() {});
      return;
    }

    final List<RecommendedUser> filtered = _allUsers.where((
      RecommendedUser user,
    ) {
      final bool matchesName = user.displayName.toLowerCase().contains(trimmed);
      final bool matchesOffer = user.offerSkills.any(
        (String skill) => skill.toLowerCase().contains(trimmed),
      );
      final bool matchesNeed = user.needSkills.any(
        (String skill) => skill.toLowerCase().contains(trimmed),
      );
      return matchesName || matchesOffer || matchesNeed;
    }).toList();

    _visibleUsers
      ..clear()
      ..addAll(filtered);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: <Widget>[
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.dashboard_customize_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SkillSwap',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Dashboard',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _isLoading ? null : () => _loadRecommendations(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initialLoad,
          builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
            if (_isLoading) {
              return const _DashboardLoading();
            }

            if (_errorMessage != null) {
              return _ErrorState(
                message: _errorMessage!,
                onRetry: _loadRecommendations,
              );
            }

            if (_visibleUsers.isEmpty) {
              final String headline = _source == RecommendationSource.matches
                  ? 'No matches yet'
                  : 'No skills to browse yet';
              return _EmptyState(
                headline: headline,
                onRefresh: _loadRecommendations,
              );
            }

            final List<Widget> sections = <Widget>[
              _DashboardIntro(source: _source),
              _SearchPanel(
                controller: _searchController,
                onClear: () {
                  _searchController.clear();
                  _applyFilter('');
                },
              ),
            ];

            if (_source == RecommendationSource.browse) {
              sections.add(const _BrowseBanner());
            }

            sections.addAll(
              _visibleUsers.map(
                (RecommendedUser user) => _RecommendationCard(user: user),
              ),
            );

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadRecommendations,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemBuilder: (BuildContext context, int index) =>
                    sections[index],
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 16),
                itemCount: sections.length,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.user});

  final RecommendedUser user;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> offerSkills = user.offerSkills.take(3).toList();
    final List<String> needSkills = user.needSkills.take(3).toList();
    final int totalDisplayed = offerSkills.length + needSkills.length;
    final int totalAvailable = user.offerSkills.length + user.needSkills.length;
    final int remaining = totalAvailable - totalDisplayed;

    final SkillChipType primaryType = user.offerSkills.isNotEmpty
        ? SkillChipType.offer
        : (user.needSkills.isNotEmpty
              ? SkillChipType.need
              : SkillChipType.neutral);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (user.secondaryTags.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: user.secondaryTags
                              .map(
                                (String tag) => SkillChip(
                                  label: tag,
                                  type: SkillChipType.neutral,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/messages');
                  },
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Message'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SkillChip(
              label: user.primarySkill,
              type: primaryType,
              icon: primaryType == SkillChipType.offer
                  ? Icons.local_fire_department_outlined
                  : primaryType == SkillChipType.need
                  ? Icons.lightbulb_outline
                  : Icons.star_border,
            ),
            const SizedBox(height: 16),
            if (offerSkills.isNotEmpty)
              _SkillSection(
                title: 'Offering',
                skills: offerSkills,
                type: SkillChipType.offer,
              ),
            if (needSkills.isNotEmpty) ...<Widget>[
              if (offerSkills.isNotEmpty) const SizedBox(height: 12),
              _SkillSection(
                title: 'Looking for',
                skills: needSkills,
                type: SkillChipType.need,
              ),
            ],
            if (remaining > 0) ...<Widget>[
              const SizedBox(height: 12),
              SkillChip(
                label: '+$remaining more',
                type: SkillChipType.neutral,
                icon: Icons.more_horiz,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkillSection extends StatelessWidget {
  const _SkillSection({
    required this.title,
    required this.skills,
    required this.type,
  });

  final String title;
  final List<String> skills;
  final SkillChipType type;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: skills
              .map((String skill) => SkillChip(label: skill, type: type))
              .toList(),
        ),
      ],
    );
  }
}

class _DashboardIntro extends StatelessWidget {
  const _DashboardIntro({required this.source});

  final RecommendationSource source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isMatches = source == RecommendationSource.matches;
    final String headline = isMatches
        ? 'Matches for you'
        : 'Browse the community';
    final String subtitle = isMatches
        ? 'Connect with people who complement your skills.'
        : 'Add more skills to unlock tailored matches.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          headline,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({required this.controller, required this.onClear});

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Search people or skills',
            hintText: 'Try “UX Research” or “React”',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(onPressed: onClear, icon: const Icon(Icons.close))
                : null,
          ),
        ),
      ),
    );
  }
}

class _BrowseBanner extends StatelessWidget {
  const _BrowseBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBlueLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9CEFB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, color: AppColors.accentBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Showing browse results',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add or update your skills to unlock personalised matches.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Getting your matches...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              size: 36,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'We ran into a problem',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.headline, required this.onRefresh});

  final String headline;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.people_outline,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a skill or search for people to start matching.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
