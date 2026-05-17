import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/themes/nexus_shell_theme.dart';
import '../auth/providers/auth_provider.dart';
import 'e2ee_chat.dart';

class _ChatUser {
  final String id;
  final String nickname;
  final String fullName;
  _ChatUser({required this.id, required this.nickname, required this.fullName});
}

class _ChatMsg {
  final String id;
  final String senderId;
  final String body;
  final bool isEncrypted;
  final DateTime createdAt;
  _ChatMsg({
    required this.id,
    required this.senderId,
    required this.body,
    required this.isEncrypted,
    required this.createdAt,
  });
}

class _FoundUser {
  final String id;
  final String nickname;
  final String fullName;
  final String at;
  _FoundUser({
    required this.id,
    required this.nickname,
    required this.fullName,
    required this.at,
  });
}

class MessengerScreen extends StatefulWidget {
  final ValueChanged<bool>? onChatOpenChanged;

  const MessengerScreen({super.key, this.onChatOpenChanged});

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

class _MessengerScreenState extends State<MessengerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late final AnimationController _loaderController;
  late final E2eeChatService _e2ee;
  List<_ChatUser> _friends = [];
  List<_FoundUser> _searchResults = [];
  List<_FoundUser> _incoming = [];
  _ChatUser? _peer;
  List<_ChatMsg> _messages = [];
  final Map<String, String> _recentByPeer = {};
  final Set<String> _unreadPeerIds = {};
  final _text = TextEditingController();
  final _search = TextEditingController();
  bool _loadingFriends = true;
  bool _loadingMsg = false;
  bool _searching = false;
  String? _error;
  Timer? _pollTimer;
  final Set<String> _messageIds = {};
  final Map<String, String> _outgoingTextByPayloadKey = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _e2ee = E2eeChatService(context.read<AuthProvider>());
    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _e2ee.ensureReady();
      } catch (_) {}
      if (mounted) _loadFriends();
    });
  }

  @override
  void dispose() {
    _stopPoll();
    _tabs.dispose();
    _loaderController.dispose();
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  void _stopPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _startPoll() {
    _stopPoll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _pollNewMessages(),
    );
  }

  String _toHttpsBase(String baseUrl) {
    if (!baseUrl.startsWith('http://')) return baseUrl;
    final rest = baseUrl.substring('http://'.length);
    if (rest.startsWith('localhost') ||
        rest.startsWith('127.') ||
        rest.startsWith('0.0.0.0')) {
      return baseUrl;
    }
    return 'https://$rest';
  }

  Future<Response<dynamic>> _getWithHttpsFallback(
    AuthProvider auth,
    String pathAndQuery,
  ) async {
    final httpBase = auth.dioBaseUrl;
    final httpsBase = _toHttpsBase(httpBase);
    if (httpsBase == httpBase) {
      return auth.http.get<dynamic>(pathAndQuery);
    }
    try {
      return await auth.http.get<dynamic>('$httpsBase$pathAndQuery');
    } catch (_) {
      return auth.http.get<dynamic>(pathAndQuery);
    }
  }

  Future<Response<dynamic>> _postWithHttpsFallback(
    AuthProvider auth,
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final httpBase = auth.dioBaseUrl;
    final httpsBase = _toHttpsBase(httpBase);
    if (httpsBase == httpBase) {
      return auth.http.post<dynamic>(path, data: data);
    }
    try {
      return await auth.http.post<dynamic>('$httpsBase$path', data: data);
    } catch (_) {
      return auth.http.post<dynamic>(path, data: data);
    }
  }

  Widget _startupLoader() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 26,
      width: 56,
      child: AnimatedBuilder(
        animation: _loaderController,
        builder: (context, _) {
          final t = _loaderController.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = (t * 3 + i) % 1.0;
              final wave = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
              final scale = 0.7 + wave * 0.6;
              final opacity = 0.25 + wave * 0.75;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  DateTime? _latestMessageTime() {
    if (_messages.isEmpty) return null;
    DateTime m = _messages.first.createdAt;
    for (final x in _messages) {
      if (x.createdAt.isAfter(m)) m = x.createdAt;
    }
    return m;
  }

  Future<_ChatMsg> _decodeMessage(Map<String, dynamic> m) async {
    final senderId = m['sender_id'] as String? ?? '';
    final myId = context.read<AuthProvider>().user?.id;
    final plainBody = m['body'] as String?;
    final nonceB64 = m['e2ee_nonce']?.toString();
    final cipherB64 = m['e2ee_ciphertext']?.toString();
    final senderPubB64 = m['e2ee_sender_key']?.toString();
    final encrypted =
        nonceB64 != null && cipherB64 != null && senderPubB64 != null;

    String text;
    if (encrypted) {
      if (senderId == myId) {
        final payloadKey = '$nonceB64|$cipherB64';
        text =
            _outgoingTextByPayloadKey[payloadKey] ??
            (plainBody?.trim().isNotEmpty == true
                ? plainBody!.trim()
                : '[E2EE] Сообщение отправлено');
      } else {
        final clear = await _e2ee.decryptIncoming(
          senderId: senderId,
          nonceB64: nonceB64,
          ciphertextB64: cipherB64,
          senderPubB64: senderPubB64,
        );
        text = clear ?? '[E2EE] Не удалось расшифровать сообщение';
      }
    } else {
      text = (plainBody ?? '').trim();
    }

    return _ChatMsg(
      id: m['id']?.toString() ?? '',
      senderId: senderId,
      body: text,
      isEncrypted: encrypted,
      createdAt:
          DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> _pollNewMessages() async {
    final p = _peer;
    if (p == null || !mounted || _loadingMsg) return;
    final after = _latestMessageTime();
    if (after == null) return;
    try {
      final auth = context.read<AuthProvider>();
      final q = Uri.encodeComponent(after.toUtc().toIso8601String());
      final r = await _getWithHttpsFallback(
        auth,
        '/chat/messages/${p.id}?after=$q',
      );
      final maps = (r.data as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final raw = await Future.wait(maps.map(_decodeMessage));
      if (raw.isEmpty || !mounted) return;
      final incoming = raw
          .where((m) => m.id.isNotEmpty && !_messageIds.contains(m.id))
          .toList();
      if (incoming.isEmpty) return;
      setState(() {
        for (final m in incoming) {
          _messageIds.add(m.id);
          _messages.add(m);
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
    } catch (_) {}
  }

  Future<void> _loadFriends() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() {
        _loadingFriends = false;
        _error = 'Войдите в аккаунт';
      });
      return;
    }
    setState(() {
      _loadingFriends = true;
      _error = null;
    });
    try {
      final r = await _getWithHttpsFallback(auth, '/friends');
      final list = (r.data as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (m) => _ChatUser(
              id: m['id']?.toString() ?? '',
              nickname: m['nickname'] as String? ?? '',
              fullName: m['full_name'] as String? ?? '',
            ),
          )
          .where((u) => u.id.isNotEmpty)
          .toList();
      setState(() {
        _friends = list;
        _loadingFriends = false;
      });
      unawaited(_loadRecentPreview());
    } catch (e) {
      setState(() {
        _loadingFriends = false;
        _error = 'Не удалось загрузить друзей ($e)';
      });
    }
  }

  Future<void> _loadRecentPreview() async {
    try {
      final auth = context.read<AuthProvider>();
      final r = await _getWithHttpsFallback(auth, '/chat/recent');
      final raw = r.data as List<dynamic>? ?? const <dynamic>[];
      final map = <String, String>{};
      final unread = <String>{};
      for (final item in raw) {
        final m = item is Map<String, dynamic>
            ? item
            : (item is Map ? Map<String, dynamic>.from(item) : null);
        if (m == null) continue;
        final peerId = m['peer_id']?.toString() ?? '';
        if (peerId.isEmpty || map.containsKey(peerId)) continue;
        map[peerId] = m['subtitle']?.toString() ?? '';
        final outgoing = m['is_outgoing'] == true;
        if (!outgoing) unread.add(peerId);
      }
      if (!mounted) return;
      setState(() {
        _recentByPeer
          ..clear()
          ..addAll(map);
        _unreadPeerIds
          ..clear()
          ..addAll(unread);
      });
    } catch (_) {}
  }

  Future<void> _loadIncoming() async {
    try {
      final auth = context.read<AuthProvider>();
      final r = await _getWithHttpsFallback(auth, '/friends/requests');
      final list = (r.data as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (m) => _FoundUser(
              id: m['id'] as String,
              nickname: m['nickname'] as String? ?? '',
              fullName: m['full_name'] as String? ?? '',
              at: m['at'] as String? ?? '@${m['nickname']}',
            ),
          )
          .toList();
      setState(() => _incoming = list);
    } catch (_) {}
  }

  Future<void> _runSearch() async {
    final q = _search.text.trim();
    if (q.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Минимум 2 символа')));
      return;
    }
    setState(() => _searching = true);
    try {
      final auth = context.read<AuthProvider>();
      final qs = Uri(queryParameters: {'q': q}).query;
      final r = await _getWithHttpsFallback(auth, '/users/search?$qs');
      final list = (r.data as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .map(
            (m) => _FoundUser(
              id: m['id'] as String,
              nickname: m['nickname'] as String? ?? '',
              fullName: m['full_name'] as String? ?? '',
              at: m['at'] as String? ?? '@${m['nickname']}',
            ),
          )
          .toList();
      setState(() {
        _searchResults = list;
        _searching = false;
      });
    } catch (e) {
      setState(() => _searching = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Поиск: $e')));
      }
    }
  }

  Future<void> _requestFriend(String userId) async {
    try {
      final auth = context.read<AuthProvider>();
      await _postWithHttpsFallback(
        auth,
        '/friends/request',
        data: {'user_id': userId},
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Заявка отправлена')));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.response?.data['error']?.toString() ?? 'Ошибка'),
          ),
        );
      }
    }
  }

  Future<void> _accept(String userId) async {
    try {
      final auth = context.read<AuthProvider>();
      await _postWithHttpsFallback(
        auth,
        '/friends/accept',
        data: {'user_id': userId},
      );
      await _loadIncoming();
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Добавлен в друзья')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _reject(String userId) async {
    try {
      final auth = context.read<AuthProvider>();
      await _postWithHttpsFallback(
        auth,
        '/friends/reject',
        data: {'user_id': userId},
      );
      await _loadIncoming();
    } catch (_) {}
  }

  Future<void> _openPeer(_ChatUser u) async {
    _stopPoll();
    setState(() {
      _peer = u;
      _messages = [];
      _messageIds.clear();
      _loadingMsg = true;
      _unreadPeerIds.remove(u.id);
    });
    widget.onChatOpenChanged?.call(true);
    try {
      final auth = context.read<AuthProvider>();
      final r = await _getWithHttpsFallback(auth, '/chat/messages/${u.id}');
      final maps = (r.data as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      final list = await Future.wait(maps.map(_decodeMessage));
      setState(() {
        _messages = list;
        for (final m in list) {
          _messageIds.add(m.id);
        }
        _loadingMsg = false;
      });
      _startPoll();
    } catch (e) {
      setState(() => _loadingMsg = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка чата: $e')));
      }
    }
  }

  Future<void> _blockPeer() async {
    final p = _peer;
    if (p == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать?'),
        content: Text('Вы не сможете писать ${p.nickname}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      await _postWithHttpsFallback(
        auth,
        '/chat/block',
        data: {'user_id': p.id},
      );
      _stopPoll();
      setState(() {
        _peer = null;
        _messages = [];
        _messageIds.clear();
      });
      widget.onChatOpenChanged?.call(false);
      await _loadFriends();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Пользователь заблокирован')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _send() async {
    final p = _peer;
    final t = _text.text.trim();
    if (p == null || t.isEmpty) return;
    try {
      final auth = context.read<AuthProvider>();
      final encrypted = await _e2ee.encryptForPeer(peerId: p.id, plaintext: t);
      if (encrypted == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('У собеседника нет E2EE-ключа. Отправка отменена.'),
            ),
          );
        }
        return;
      }
      await _postWithHttpsFallback(
        auth,
        '/chat/send',
        data: {'to': p.id, 'e2ee': encrypted.toJson()},
      );
      _outgoingTextByPayloadKey['${encrypted.nonceB64}|${encrypted.ciphertextB64}'] =
          t;
      setState(() {
        _messages.add(
          _ChatMsg(
            id: 'local_${DateTime.now().microsecondsSinceEpoch}',
            senderId: auth.user?.id ?? '',
            body: t,
            isEncrypted: true,
            createdAt: DateTime.now(),
          ),
        );
      });
      _text.clear();
      unawaited(_openPeer(p));
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.response?.data['error']?.toString() ?? 'Не отправлено',
            ),
          ),
        );
      }
    }
  }

  Widget _leftTabsPanel(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            onTap: (i) {
              if (i == 2) _loadIncoming();
            },
            tabs: const [
              Tab(text: 'Друзья'),
              Tab(text: 'Поиск'),
              Tab(text: 'Заявки'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (ctx, i) {
                  final u = _friends[i];
                  return ListTile(
                    selected: _peer?.id == u.id,
                    title: Text(
                      u.fullName.trim().isEmpty ? u.nickname : u.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _recentByPeer[u.id] ?? '@${u.nickname}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _unreadPeerIds.contains(u.id)
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () => _openPeer(u),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: const InputDecoration(
                              labelText: '@nickname или часть ника',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _runSearch(),
                          ),
                        ),
                        IconButton(
                          onPressed: _searching ? null : _runSearch,
                          icon: _searching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, i) {
                          final u = _searchResults[i];
                          return ListTile(
                            title: Text(u.nickname),
                            subtitle: Text(u.at),
                            trailing: TextButton(
                              onPressed: () => _requestFriend(u.id),
                              child: const Text('В друзья'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ListView.builder(
                itemCount: _incoming.length,
                itemBuilder: (ctx, i) {
                  final u = _incoming[i];
                  return ListTile(
                    title: Text(u.nickname),
                    subtitle: Text(u.at),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.check_rounded, color: cs.tertiary),
                          onPressed: () => _accept(u.id),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: cs.error),
                          onPressed: () => _reject(u.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messagesList(
    BuildContext context,
    String? myId,
    NexusShellTheme shell,
  ) {
    final cs = Theme.of(context).colorScheme;
    if (_peer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Выберите друга или найдите по @nickname',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }
    if (_loadingMsg) {
      return Center(child: _startupLoader());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final m = _messages[i];
        final mine = m.senderId == myId;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: mine ? shell.messageBubbleMine : shell.messageBubbleOther,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(mine ? 14 : 4),
                bottomRight: Radius.circular(mine ? 4 : 14),
              ),
            ),
            child: Text(
              m.isEncrypted ? '🔒 ${m.body}' : m.body,
              style: TextStyle(
                color: mine ? Colors.white : cs.onSurface,
                height: 1.35,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                decoration: const InputDecoration(
                  hintText: 'Сообщение…',
                  isDense: true,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _send,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  void _closeMobileChat() {
    _stopPoll();
    setState(() {
      _peer = null;
      _messages = [];
      _messageIds.clear();
    });
    widget.onChatOpenChanged?.call(false);
  }

  void _showPeerProfile(_ChatUser peer) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.fullName.trim().isEmpty ? peer.nickname : peer.fullName,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${peer.nickname}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                const Text('Профиль собеседника'),
                const SizedBox(height: 6),
                const Text(
                  'Публичные/приватные проекты: будут показаны после добавления отдельного API.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final myId = auth.user?.id;
    final shell = context.nexusShell;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    if (_loadingFriends) {
      return Center(child: _startupLoader());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (!wide) {
      final peer = _peer;
      if (peer != null) {
        return Scaffold(
          backgroundColor: shell.contentChrome,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _closeMobileChat,
            ),
            title: Text(peer.nickname),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => _showPeerProfile(peer),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => _openPeer(peer),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'block') _blockPeer();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Заблокировать'),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(child: _messagesList(context, myId, shell)),
              _composer(context),
            ],
          ),
        );
      }
      return ColoredBox(
        color: shell.contentChrome,
        child: _leftTabsPanel(context),
      );
    }

    final desktopPeer = _peer;

    return ColoredBox(
      color: shell.contentChrome,
      child: Row(
        children: [
          SizedBox(
            width: 280,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: _leftTabsPanel(context),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: Theme.of(context).dividerTheme.color,
          ),
          Expanded(
            child: Column(
              children: [
                if (desktopPeer != null)
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Чат с ${desktopPeer.nickname}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.person_outline_rounded),
                            onPressed: () => _showPeerProfile(desktopPeer),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () => _openPeer(desktopPeer),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'block') _blockPeer();
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'block',
                                child: Text('Заблокировать'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: _messagesList(context, myId, shell)),
                if (_peer != null) _composer(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
