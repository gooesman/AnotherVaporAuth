import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../app/providers.dart';
import '../../app/responsive.dart';
import '../../core/models/steam_friend.dart';
import '../../core/models/steam_guard_account.dart';
import '../../core/models/trade_draft.dart';
import '../../services/steam_api_client.dart';
import '../error_text.dart';
import '../pending/session_retry.dart';
import '../pending/pending_screen.dart';
import 'trade_inventory_picker.dart';

class TradeComposeScreen extends ConsumerStatefulWidget {
  final SteamGuardAccount account;
  final SteamFriend partner;
  const TradeComposeScreen({
    super.key,
    required this.account,
    required this.partner,
  });

  @override
  ConsumerState<TradeComposeScreen> createState() => _TradeComposeScreenState();
}

class _TradeComposeScreenState extends ConsumerState<TradeComposeScreen>
    with SessionRetryState {
  final _message = TextEditingController();
  late final String _fromSteamId;
  late final String _fromName;
  List<TradeSelection> _give = [];
  List<TradeSelection> _receive = [];
  bool _busy = false;
  bool _sending = false;
  bool _needsLogin = false;
  bool _unknown = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fromSteamId = '${widget.account.steamId}';
    _fromName =
        widget.account.personaName ??
        widget.account.accountName ??
        _fromSteamId;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pick(bool mine) async {
    final selected = await Navigator.of(context).push<List<TradeSelection>>(
      MaterialPageRoute(
        builder: (_) => TradeInventoryPicker(
          account: widget.account,
          ownerSteamId: mine ? _fromSteamId : widget.partner.steamId,
          mine: mine,
          selected: mine ? _give : _receive,
        ),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (mine) {
        _give = selected;
      } else {
        _receive = selected;
      }
    });
  }

  Future<void> _review() async {
    if (_busy || (_give.isEmpty && _receive.isEmpty) || _unknown) return;
    // Lock before opening the dialog; same-frame double taps cannot create
    // two confirmation dialogs or race two send requests.
    setState(() {
      _busy = true;
      _error = null;
      _needsLogin = false;
    });
    final draft = TradeDraft(
      fromSteamId: _fromSteamId,
      partnerSteamId: widget.partner.steamId,
      give: _give,
      receive: _receive,
      message: _message.text,
    );
    final l = AppLocalizations.of(context);
    try {
      draft.validate('${widget.account.steamId}');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.tradeReview),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              padding: context.rSafeInsets(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.tradeFromAccount,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(_fromName),
                  SelectableText('SteamID: ${draft.fromSteamId}'),
                  const SizedBox(height: 16),
                  Text(
                    l.tradeToAccount,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    widget.partner.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText('SteamID: ${draft.partnerSteamId}'),
                  const SizedBox(height: 16),
                  Text(l.tradeReviewBody),
                  if (draft.receive.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        l.tradeGiftWarning,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _summary(l.tradeYourItems, draft.give),
                  const SizedBox(height: 12),
                  _summary(l.tradeTheirItems, draft.receive),
                  if (draft.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(draft.message),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              key: const ValueKey('trade-confirm-send'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l.tradeSend),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      // Re-check after the dialog as well as inside the HTTP client; even a
      // receive-only offer must stay bound to the account the user reviewed.
      draft.validate('${widget.account.steamId}');
      setState(() => _sending = true);
      // Never wrap sends in fetchWithAutoRefresh: a timeout could arrive after
      // Steam created the offer, and automatic retry would duplicate it.
      final result = await ref
          .read(tradeOffersClientProvider)
          .send(widget.account, draft);
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      final auth = isAuthError(e);
      // A server diagnostic/auth failure is definite. Network errors or a
      // malformed success reply are ambiguous and require checking offers.
      final unknown = !auth && e is! SteamApiException && e is! ArgumentError;
      setState(() {
        _needsLogin = auth;
        _unknown = unknown;
        _error = auth
            ? l.confNeedsLogin
            : e is TradeAccountMismatch
            ? l.loginAccountMismatch
            : unknown
            ? l.tradeUnknownResult
            : e is ArgumentError
            ? l.tradeValidationFailed
            : describeError(l, e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sending = false;
        });
      }
    }
  }

  Widget _summary(String title, List<TradeSelection> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$title (${items.fold<int>(0, (n, s) => n + s.amount)})',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      for (final selection in items)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${selection.item.name} × ${selection.amount}\n'
            '${selection.item.appid}/${selection.item.contextId}/${selection.item.assetId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );

  Widget _side(bool mine) {
    final l = AppLocalizations.of(context);
    final selections = mine ? _give : _receive;
    return Card(
      child: Padding(
        padding: context.rInsets(all: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    mine ? l.tradeYourItems : l.tradeTheirItems,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${selections.fold<int>(0, (n, s) => n + s.amount)}'),
              ],
            ),
            const SizedBox(height: 8),
            for (final selection in selections)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(selection.item.name),
                subtitle: Text('× ${selection.amount}'),
                trailing: IconButton(
                  tooltip: l.commonCancel,
                  icon: const Icon(Icons.close),
                  onPressed: _busy || _unknown
                      ? null
                      : () => setState(() => selections.remove(selection)),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _busy || _unknown ? null : () => _pick(mine),
              icon: const Icon(Icons.add),
              label: Text(l.tradeSelectItems),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(l.tradeNewTitle)),
        body: ListView(
          padding: context.rSafeInsets(all: 16),
          children: [
            Text(
              widget.partner.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SelectableText('SteamID: ${widget.partner.steamId}'),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, size) => size.maxWidth > 760
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _side(true)),
                        const SizedBox(width: 12),
                        Expanded(child: _side(false)),
                      ],
                    )
                  : Column(children: [_side(true), _side(false)]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLength: 128,
              enabled: !_busy && !_unknown,
              decoration: InputDecoration(labelText: l.tradeNote),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_needsLogin)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => signInThen(
                        widget.account,
                        () => setState(() {
                          _needsLogin = false;
                          _error = null;
                        }),
                      ),
                child: Text(l.loginButton),
              ),
            if (_unknown)
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PendingScreen(account: widget.account),
                  ),
                ),
                child: Text(l.tradeOpenPending),
              ),
            if (!_unknown)
              FilledButton.icon(
                key: const ValueKey('trade-review'),
                onPressed: _busy || (_give.isEmpty && _receive.isEmpty)
                    ? null
                    : _review,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check),
                label: Text(l.tradeReview),
              ),
          ],
        ),
      ),
    );
  }
}
