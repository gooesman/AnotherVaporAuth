import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../core/models/steam_friend.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_draft.dart';
import '../../core/protocol/friends_client.dart';
import '../error_text.dart';
import '../pending/pending_screen.dart';
import '../pending/session_retry.dart';
import '../widgets/steam_image_provider.dart';
import 'trade_compose_screen.dart';

final friendsClientProvider = Provider<FriendsClient>(
  (ref) => FriendsClient(ref.read(apiClientProvider)),
);

class FriendsScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  const FriendsScreen({super.key, required this.account});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SessionRetryState {
  List<SteamFriend> _friends = const [];
  bool _loading = true;
  bool _needsLogin = false;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    try {
      final friends = await fetchWithAutoRefresh(
        widget.account,
        () => ref.read(friendsClientProvider).fetch(widget.account),
        retryOnAnyError: false,
      );
      if (mounted) setState(() => _friends = friends);
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context);
        setState(() {
          _needsLogin = isAuthError(e);
          _error = _needsLogin
              ? l.confNeedsLogin
              : e is FormatException
              ? l.tradeLoadFailed
              : describeError(l, e);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _compose(SteamFriend friend) async {
    final result = await Navigator.of(context).push<TradeSendResult>(
      MaterialPageRoute(
        builder: (_) =>
            TradeComposeScreen(account: widget.account, partner: friend),
      ),
    );
    if (!mounted || result == null) return;
    final l = AppLocalizations.of(context);
    final showPending = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          result.needsMobileConfirmation || result.needsEmailConfirmation
              ? l.friendsTrade
              : l.tradeSent,
        ),
        content: SelectableText(
          [
            if (result.needsMobileConfirmation) l.tradeNeedsMobile,
            if (result.needsEmailConfirmation) l.tradeNeedsEmail,
            if (!result.needsMobileConfirmation &&
                !result.needsEmailConfirmation)
              l.tradeSent,
            '#${result.offerId}',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.tradeOpenPending),
          ),
        ],
      ),
    );
    if (mounted && showPending == true) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PendingScreen(account: widget.account),
        ),
      );
    }
  }

  Future<void> _details(SteamFriend friend) async {
    final l = AppLocalizations.of(context);
    final profile = Uri.https(
      'steamcommunity.com',
      '/profiles/${friend.steamId}/',
    );
    final trade = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(friend.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText('SteamID: ${friend.steamId}'),
            const SizedBox(height: 12),
            SelectableText(profile.toString()),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: Text(l.friendsProfile),
              onPressed: () async {
                var ok = false;
                try {
                  ok = await launchUrl(
                    profile,
                    mode: LaunchMode.externalApplication,
                  );
                } catch (_) {
                  /* Missing browser/platform handler. */
                }
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.friendsProfileOpenFailed)),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonClose),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.friendsTrade),
          ),
        ],
      ),
    );
    if (mounted && trade == true) await _compose(friend);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final visible = _friends
        .where(
          (friend) => '${friend.name} ${friend.steamId}'.toLowerCase().contains(
            _search,
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.friendsTitle),
        actions: [
          IconButton(
            tooltip: l.tradeOpenPending,
            icon: const Icon(Icons.swap_horiz),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PendingScreen(account: widget.account),
              ),
            ),
          ),
          IconButton(
            tooltip: l.commonRefresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: context.rInsets(left: 16, top: 12, right: 16, bottom: 8),
            child: TextField(
              decoration: InputDecoration(
                labelText: l.friendsSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: context.rSafeInsets(
                        left: 16,
                        right: 16,
                        bottom: 24,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Text(_error!),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: _needsLogin
                                      ? () => signInThen(widget.account, _load)
                                      : _load,
                                  child: Text(
                                    _needsLogin ? l.loginButton : l.commonRetry,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_error == null && visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(l.friendsEmpty),
                          ),
                        if (_error == null)
                          for (final friend in visible)
                            Card(
                              child: ListTile(
                                leading: ClipOval(
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: friend.avatarUrl.isEmpty
                                        ? const Icon(Icons.person)
                                        : Image(
                                            image: SteamImageProvider(
                                              friend.avatarUrl,
                                            ),
                                            errorBuilder: (_, _, _) =>
                                                const Icon(Icons.person),
                                          ),
                                  ),
                                ),
                                title: Text(friend.name),
                                subtitle: Text(
                                  '${switch (friend.state) {
                                    SteamFriendState.offline => l.friendsOffline,
                                    SteamFriendState.online => l.friendsOnline,
                                    SteamFriendState.playing => friend.game.isNotEmpty ? friend.game : l.friendsPlaying,
                                  }}\n${friend.steamId}',
                                ),
                                isThreeLine: true,
                                onTap: () => _details(friend),
                                trailing: IconButton(
                                  tooltip: l.friendsTrade,
                                  icon: const Icon(Icons.swap_horiz),
                                  onPressed: () => _compose(friend),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
