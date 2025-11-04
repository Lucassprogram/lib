import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';

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
      final int? userId = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
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

  List<RecommendedUser> _mapMatchResults(List<dynamic> payload, int currentUser) {
    final List<RecommendedUser> users = <RecommendedUser>[];
    for (final dynamic raw in payload) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final Object? idValue = raw['_id'];
      final int? userId = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
      if (userId == null || userId == currentUser) {
        continue;
      }
      final List<dynamic>? skillList = raw['skills'] as List<dynamic>?;
      final List<String> skills = skillList == null
          ? <String>[]
          : skillList.map((dynamic item) => item.toString()).toSet().toList();
      users.add(
        RecommendedUser(
          userId: userId,
          displayName: 'User $userId',
          offerSkills: skills,
          needSkills: const <String>[],
        ),
      );
    }
    return users;
  }

  List<RecommendedUser> _mapBrowseResults(List<dynamic> payload, int currentUser) {
    final Map<int, List<String>> offers = <int, List<String>>{};
    final Map<int, List<String>> needs = <int, List<String>>{};

    for (final dynamic raw in payload) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final Object? idValue = raw['UserId'] ?? raw['UserID'];
      final int? userId = idValue is int ? idValue : int.tryParse(idValue?.toString() ?? '');
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

    final List<RecommendedUser> filtered = _allUsers.where((RecommendedUser user) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('SkillSwap'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _loadRecommendations(),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initialLoad,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_errorMessage != null) {
            return _ErrorState(message: _errorMessage!, onRetry: _loadRecommendations);
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

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search for people or skills',
                  ),
                ),
              ),
              if (_source == RecommendationSource.browse)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: Text('Showing browse results (no personal matches yet)'),
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadRecommendations,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _visibleUsers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final RecommendedUser user = _visibleUsers[index];
                      return _RecommendationCard(user: user);
                    },
                  ),
                ),
              ),
            ],
          );
        },
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 24,
                  child: Text(user.displayName.isNotEmpty ? user.displayName[0] : '?'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user.displayName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Message'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              user.primarySkill,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                ...user.offerSkills.skip(1).take(3).map(
                  (String skill) => Chip(label: Text('Offers $skill')),
                ),
                ...user.needSkills.take(3).map(
                  (String skill) => Chip(label: Text('Needs $skill')),
                ),
                if (user.offerSkills.length + user.needSkills.length > 4)
                  Chip(label: Text('+${user.offerSkills.length + user.needSkills.length - 4} more')),
              ],
            ),
          ],
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              headline,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text('Add a skill or search for people to start matching.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}
