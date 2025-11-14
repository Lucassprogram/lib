import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'widgets/user_search_dialog.dart';
import '../theme/app_theme.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  static const double _compactWidthBreakpoint = 840;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _messageScroll = ScrollController();
  bool _showListOnCompact = true;

  List<Map<String, dynamic>> _conversations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _allMessages = <Map<String, dynamic>>[];
  bool _loadingConversations = true;
  bool _loadingMessages = false;
  int? _selectedPartnerId;
  String _selectedPartnerName = '';
  int _selfId = -1;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _selfId = int.tryParse(prefs.getString('userId') ?? '') ?? -1;
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loadingConversations = true);
    final List<Map<String, dynamic>> msgs = await ApiService.fetchAllMessages();
    // Build conversations by partner
    final Map<int, Map<String, dynamic>> conv = <int, Map<String, dynamic>>{};
    for (final Map<String, dynamic> m in msgs) {
      final int? from = _toInt(m['from'] ?? m['From']);
      final int? to = _toInt(m['to'] ?? m['To']);
      if (from == null || to == null) continue;
      final int partner = from == _selfId ? to : (to == _selfId ? from : to);
      final String body = m['body']?.toString() ?? m['text']?.toString() ?? '';
      final String created =
          m['createdAt']?.toString() ?? m['created']?.toString() ?? '';
      final String name = from == partner
          ? (m['fromName']?.toString() ?? '')
          : (m['toName']?.toString() ?? '');
      final Map<String, dynamic> prev =
          conv[partner] ??
          <String, dynamic>{
            'partnerId': partner,
            'partnerName': name,
            'lastMessage': body,
            'lastAt': created,
          };
      // Update if newer
      if (((prev['lastAt']?.toString() ?? '')).compareTo(created) <= 0) {
        prev['partnerName'] =
            (prev['partnerName']?.toString().isNotEmpty ?? false)
            ? prev['partnerName']
            : name;
        prev['lastMessage'] = body;
        prev['lastAt'] = created;
      }
      conv[partner] = prev;
    }
    final List<Map<String, dynamic>> rows = conv.values.toList()
      ..sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            (b['lastAt']?.toString() ?? '').compareTo(
              a['lastAt']?.toString() ?? '',
            ),
      );

    setState(() {
      _allMessages = msgs;
      _conversations = rows;
      _loadingConversations = false;
    });
  }

  Future<void> _openConversation(int partnerId, String fallbackName) async {
    final bool isCompact =
        MediaQuery.of(context).size.width < _compactWidthBreakpoint;
    setState(() {
      _selectedPartnerId = partnerId;
      _selectedPartnerName = fallbackName;
      _messages.clear();
      _loadingMessages = true;
      if (isCompact) {
        _showListOnCompact = false;
      }
    });
    final List<Map<String, dynamic>> rows =
        _allMessages.where((Map<String, dynamic> m) {
          final int? from = _toInt(m['from'] ?? m['From']);
          final int? to = _toInt(m['to'] ?? m['To']);
          return from == partnerId || to == partnerId;
        }).toList()..sort(
          (Map<String, dynamic> a, Map<String, dynamic> b) =>
              (a['createdAt']?.toString() ?? '').compareTo(
                b['createdAt']?.toString() ?? '',
              ),
        );
    setState(() {
      _messages = rows;
      _loadingMessages = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (_messageScroll.hasClients) {
      _messageScroll.jumpTo(_messageScroll.position.maxScrollExtent);
    }
  }

  Future<void> _send() async {
    final String text = _composer.text.trim();
    final int? partnerId = _selectedPartnerId;
    if (text.isEmpty || partnerId == null) return;
    _composer.clear();
    final Map<String, dynamic> res = await ApiService.sendMessage(
      to: partnerId,
      body: text,
    );
    if (res['error'] != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: ${res['error']}')));
      return;
    }
    // Optimistic update: append the message locally so it appears immediately.
    final String nowIso = DateTime.now().toIso8601String();
    final Map<String, dynamic> newMsg = <String, dynamic>{
      'from': _selfId,
      'to': partnerId,
      'body': text,
      'createdAt': nowIso,
    };
    setState(() {
      _messages.add(newMsg);
      _allMessages.add(newMsg);

      // Update conversations preview and order
      final int idx = _conversations.indexWhere(
        (Map<String, dynamic> row) => _idForConversation(row) == partnerId,
      );
      if (idx >= 0) {
        final Map<String, dynamic> row = Map<String, dynamic>.from(
          _conversations[idx],
        );
        row['lastMessage'] = text;
        row['lastAt'] = nowIso;
        if ((row['partnerName']?.toString().isEmpty ?? true) &&
            _selectedPartnerName.isNotEmpty) {
          row['partnerName'] = _selectedPartnerName;
        }
        _conversations[idx] = row;
      } else {
        _conversations.insert(0, <String, dynamic>{
          'partnerId': partnerId,
          'partnerName': _selectedPartnerName,
          'lastMessage': text,
          'lastAt': nowIso,
        });
      }
      _conversations.sort(
        (Map<String, dynamic> a, Map<String, dynamic> b) =>
            (b['lastAt']?.toString() ?? '').compareTo(
              a['lastAt']?.toString() ?? '',
            ),
      );
    });

    // Scroll to bottom so the new message is visible.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    if (_messageScroll.hasClients) {
      _messageScroll.jumpTo(_messageScroll.position.maxScrollExtent);
    }
  }

  int? _toInt(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  List<Map<String, dynamic>> get _filteredConversations {
    final String q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _conversations;
    return _conversations.where((Map<String, dynamic> row) {
      final String name = _nameForConversation(row).toLowerCase();
      final String preview =
          (row['lastMessage']?.toString() ?? row['preview']?.toString() ?? '')
              .toLowerCase();
      return name.contains(q) || preview.contains(q);
    }).toList();
  }

  String _nameForConversation(Map<String, dynamic> row) {
    // Flexible: try common field names
    final String viaName =
        row['partnerName']?.toString() ??
        row['name']?.toString() ??
        row['displayName']?.toString() ??
        '';
    if (viaName.isNotEmpty) return viaName;
    final Object? pid = row['partnerId'] ?? row['userId'] ?? row['UserId'];
    final int? id = pid is int ? pid : int.tryParse(pid?.toString() ?? '');
    return id == null ? 'Conversation' : 'User $id';
  }

  int? _idForConversation(Map<String, dynamic> row) {
    final Object? pid = row['partnerId'] ?? row['userId'] ?? row['UserId'];
    return pid is int ? pid : int.tryParse(pid?.toString() ?? '');
  }

  @override
  void dispose() {
    _search.dispose();
    _composer.dispose();
    _messageScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double width = MediaQuery.of(context).size.width;
    final bool isCompact = width < _compactWidthBreakpoint;

    if (!isCompact && !_showListOnCompact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_showListOnCompact) {
          setState(() {
            _showListOnCompact = true;
          });
        }
      });
    }

    final bool showListPane =
        !isCompact || _showListOnCompact || _selectedPartnerId == null;
    final String appBarTitle =
        !isCompact || showListPane || _selectedPartnerId == null
        ? 'Messages'
        : (_selectedPartnerName.isEmpty
              ? 'User ${_selectedPartnerId ?? ''}'
              : _selectedPartnerName);

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        leading: isCompact && !showListPane && _selectedPartnerId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showListOnCompact = true;
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: isCompact
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: showListPane
                    ? KeyedSubtree(
                        key: ValueKey('list'),
                        child: _buildConversationList(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('pane'),
                        child: _buildConversationPane(theme: theme),
                      ),
              )
            : Row(
                children: <Widget>[
                  SizedBox(width: 320, child: _buildConversationList()),
                  const VerticalDivider(width: 1),
                  Expanded(child: _buildConversationPane(theme: theme)),
                ],
              ),
      ),
    );
  }

  Widget _buildConversationList() {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openUserPicker(context),
                  icon: const Icon(Icons.person_search),
                  label: const Text('New message'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _loadingConversations
              ? const Center(child: CircularProgressIndicator())
              : _filteredConversations.isEmpty
              ? const _EmptyList()
              : ListView.builder(
                  itemCount: _filteredConversations.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> row =
                        _filteredConversations[index];
                    final String name = _nameForConversation(row);
                    final int? partnerId = _idForConversation(row);
                    final String preview =
                        row['lastMessage']?.toString() ??
                        row['preview']?.toString() ??
                        '';
                    final bool selected =
                        partnerId != null && partnerId == _selectedPartnerId;
                    return ListTile(
                      selected: selected,
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: preview.isEmpty
                          ? null
                          : Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: partnerId == null
                          ? null
                          : () => _openConversation(partnerId, name),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildConversationPane({required ThemeData theme}) {
    if (_selectedPartnerId == null) {
      return const _EmptyChat();
    }
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedPartnerName.isEmpty
                      ? 'User ${_selectedPartnerId ?? ''}'
                      : _selectedPartnerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _messageScroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> m = _messages[index];
                    final Object? fromVal =
                        m['from'] ?? m['senderId'] ?? m['From'];
                    final int? from = fromVal is int
                        ? fromVal
                        : int.tryParse(fromVal?.toString() ?? '');
                    final bool mine = from == _selfId;
                    final String text =
                        m['text']?.toString() ??
                        m['message']?.toString() ??
                        m['body']?.toString() ??
                        '';
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(maxWidth: 520),
                        decoration: BoxDecoration(
                          color: mine
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(text),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  color: AppColors.primary,
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openUserPicker(BuildContext context) async {
    final Map<String, dynamic>? picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) => const UserSearchDialog(),
    );
    if (picked == null) {
      return;
    }
    final int? id = _toInt(
      picked['UserID'] ?? picked['userId'] ?? picked['id'],
    );
    final String name =
        '${picked['FirstName'] ?? ''} ${picked['LastName'] ?? ''}'.trim();
    if (id != null) {
      await _openConversation(id, name);
    }
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        'No conversations yet',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        'Select a conversation to start chatting',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
