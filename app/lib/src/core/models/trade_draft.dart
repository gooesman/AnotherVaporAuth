import 'steam_friend.dart';
import 'steam_item.dart';

/// Selection retains its inventory owner so a UI mix-up cannot silently swap
/// the direction of assets when the offer is serialized.
class TradeSelection {
  final String ownerSteamId;
  final InventoryItem item;
  final int amount;
  const TradeSelection({
    required this.ownerSteamId,
    required this.item,
    this.amount = 1,
  });

  String get key => '${item.appid}/${item.contextId}/${item.assetId}';
  Map<String, dynamic> toJson() => {
    'appid': item.appid,
    'contextid': item.contextId,
    'assetid': item.assetId,
    'amount': amount,
  };
}

class TradeDraft {
  final String fromSteamId;
  final String partnerSteamId;
  final List<TradeSelection> give;
  final List<TradeSelection> receive;
  final String message;
  TradeDraft({
    required this.fromSteamId,
    required this.partnerSteamId,
    required List<TradeSelection> give,
    required List<TradeSelection> receive,
    this.message = '',
  }) : give = List.unmodifiable(give),
       receive = List.unmodifiable(receive);

  void validate(String ownSteamId) {
    if (ownSteamId != fromSteamId) {
      throw TradeAccountMismatch();
    }
    if (!isIndividualSteamId(ownSteamId) ||
        !isIndividualSteamId(partnerSteamId) ||
        partnerSteamId == ownSteamId) {
      throw ArgumentError('Invalid trade partner');
    }
    if (give.isEmpty && receive.isEmpty) {
      throw ArgumentError('Select at least one item');
    }
    if (give.length > 256 || receive.length > 256 || message.length > 128) {
      throw ArgumentError('Trade offer is too large');
    }
    for (final side in [(give, ownSteamId), (receive, partnerSteamId)]) {
      final seen = <String>{};
      for (final selection in side.$1) {
        final item = selection.item;
        bool positive(String value) => RegExp(r'^[1-9]\d*$').hasMatch(value);
        if (selection.ownerSteamId != side.$2 ||
            !item.tradable ||
            item.appid <= 0 ||
            !positive(item.contextId) ||
            !positive(item.assetId) ||
            selection.amount < 1 ||
            selection.amount > item.amount ||
            !seen.add(selection.key)) {
          throw ArgumentError('Invalid or duplicate trade item');
        }
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'newversion': true,
    'version': give.length + receive.length + 1,
    'me': {
      'assets': give.map((s) => s.toJson()).toList(),
      'currency': <Object>[],
      'ready': false,
    },
    'them': {
      'assets': receive.map((s) => s.toJson()).toList(),
      'currency': <Object>[],
      'ready': false,
    },
  };
}

class TradeAccountMismatch extends ArgumentError {
  TradeAccountMismatch() : super('The sending account changed');
}

class TradeSendResult {
  final String offerId;
  final bool needsMobileConfirmation;
  final bool needsEmailConfirmation;
  const TradeSendResult({
    required this.offerId,
    this.needsMobileConfirmation = false,
    this.needsEmailConfirmation = false,
  });
}

/// A reply without an offer id is ambiguous; callers must not automatically
/// resend. Steam may already have created the first offer.
class TradeSendUnconfirmed implements Exception {
  final Object? cause;
  final TradeSendAttempt? attempt;
  const TradeSendUnconfirmed({this.cause, this.attempt});
}

/// Read-only reconciliation context. Never persisted and never used to replay
/// the write. Missing/incomplete baseline means a matching old offer cannot be
/// safely attributed to this attempt.
class TradeSendAttempt {
  final TradeDraft draft;
  final int startedAt;
  final int finishedAt;
  final Set<String>? previousOfferIds;
  TradeSendAttempt({
    required this.draft,
    required this.startedAt,
    required this.finishedAt,
    Set<String>? previousOfferIds,
  }) : previousOfferIds = previousOfferIds == null
           ? null
           : Set.unmodifiable(previousOfferIds);
}

/// The connection failed before Steam could receive any HTTP request bytes.
class TradeSendNotSent implements Exception {
  final Object cause;
  const TradeSendNotSent(this.cause);
}

/// Steam explicitly rejected the request but omitted a useful diagnostic.
class TradeSendRejected implements Exception {
  const TradeSendRejected();
}
