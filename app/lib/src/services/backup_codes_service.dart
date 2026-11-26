import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/backup_codes.dart';
import '../core/jwt.dart';
import '../core/models/steam_guard_account.dart';
import 'steam_api_client.dart';
import 'steam_network.dart';

/// Steam's two-step emergency login-code Web API. This is separate from the
/// authenticator removal/recovery APIs; none of those methods are called here.
///
/// Original implementations (not a published stability guarantee from Valve):
/// https://github.com/ValvePython/steam/blob/26166e047b66a7be10bdf3c90e2e14de9283ab5a/steam/guard.py#L268
/// https://github.com/x15rte/steamguard-pc/blob/be60726d7a141fb5b526f1eb5810dcd55118487f/tests/test_enrollment.py#L153
///
/// No retries, logging, persistence, or fallback to a destructive 2FA endpoint.
/// The UI must call each step only after an explicit user action.
class BackupCodesService {
  BackupCodesService({Dio? dio})
    : _dio =
          dio ??
          SteamNetwork.createDio(
            BaseOptions(connectTimeout: const Duration(seconds: 20)),
          );

  static const endpoint =
      'https://api.steampowered.com/ITwoFactorService/CreateEmergencyCodes/v1/';
  final Dio _dio;

  void dispose() => _dio.close(force: true);

  Future<BackupCodesChallenge> requestSms(
    SteamGuardAccount account, {
    CancelToken? cancelToken,
  }) async {
    final steamId = account.steamId;
    final response = await _request(account, cancelToken: cancelToken);
    _checkAccount(account, steamId);
    // An unexplained empty object is not evidence that an SMS was sent. The
    // known first-step response has status:1; x-eresult:1 is also explicit OK.
    if (!response.ok || response.data.containsKey('codes')) {
      throw const BackupCodesException(BackupCodesError.invalidResponse);
    }
    return BackupCodesChallenge(
      steamId: steamId,
      phoneHint: _maskedPhoneHint(response.data['phone_number_hint']),
    );
  }

  Future<List<String>> generate(
    SteamGuardAccount account,
    BackupCodesChallenge challenge,
    String smsCode, {
    CancelToken? cancelToken,
  }) async {
    _checkAccount(account, challenge.steamId);
    final code = smsCode.trim();
    // Do not silently strip characters or manufacture a code. Preserve leading
    // zeros and let Steam validate the actual length/content of the SMS.
    if (code.isEmpty ||
        code.length > 64 ||
        !RegExp(r'^[a-zA-Z0-9]+$').hasMatch(code)) {
      throw const BackupCodesException(BackupCodesError.invalidCode);
    }
    final response = await _request(
      account,
      code: code,
      cancelToken: cancelToken,
    );
    _checkAccount(account, challenge.steamId);
    final codes = response.data['codes'];
    // Codes are strings, never integers: a leading zero is significant. There
    // is deliberately no assumed count or fixed digit length.
    if (codes is! List ||
        codes.isEmpty ||
        codes.length > 100 ||
        codes.any(
          (value) =>
              value is! String ||
              !RegExp(r'^[a-zA-Z0-9-]{4,32}$').hasMatch(value),
        )) {
      throw const BackupCodesException(BackupCodesError.invalidResponse);
    }
    final result = codes.cast<String>();
    if (result.toSet().length != result.length) {
      throw const BackupCodesException(BackupCodesError.invalidResponse);
    }
    return List<String>.unmodifiable(result);
  }

  static void _checkAccount(SteamGuardAccount account, int steamId) {
    if (steamId <= 0 || account.steamId != steamId) {
      throw const BackupCodesException(BackupCodesError.authenticationRequired);
    }
  }

  static String _token(SteamGuardAccount account) {
    final token = account.session.accessToken;
    if (account.steamId <= 0 || token == null || token.trim().isEmpty) {
      throw const BackupCodesException(BackupCodesError.authenticationRequired);
    }
    // Read-only consistency check, not JWT signature verification. Older
    // opaque OAuth tokens remain supported; Steam validates authentication.
    final subject = decodeJwtPayload(token)?['sub'];
    if (subject != null && subject.toString() != account.steamId.toString()) {
      throw const BackupCodesException(BackupCodesError.authenticationRequired);
    }
    return token;
  }

  Future<_BackupResponse> _request(
    SteamGuardAccount account, {
    String? code,
    CancelToken? cancelToken,
  }) async {
    final token = _token(account);
    try {
      final response = await _dio.post<String>(
        endpoint,
        // ValvePython's WebAPI transport sends POST parameters as form data.
        // Keeping the credential out of the URL also avoids URI/history leaks.
        data: {'access_token': token, 'code': ?code},
        cancelToken: cancelToken,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          headers: SteamApiClient.steamMobileHeaders,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) {
        throw const BackupCodesException(
          BackupCodesError.authenticationRequired,
        );
      }
      if (status == 429) {
        throw const BackupCodesException(BackupCodesError.rateLimited);
      }
      if (status < 200 || status >= 300) {
        throw const BackupCodesException(BackupCodesError.rejected);
      }
      final rawResult = response.headers.value('x-eresult');
      final headerResult = rawResult == null ? null : int.tryParse(rawResult);
      if (rawResult != null && headerResult == null) {
        throw const BackupCodesException(BackupCodesError.invalidResponse);
      }
      _checkResult(headerResult);
      final body = response.data;
      if (body == null || body.isEmpty || body.length > 64 * 1024) {
        throw const BackupCodesException(BackupCodesError.invalidResponse);
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> ||
          decoded['response'] is! Map<String, dynamic>) {
        throw const BackupCodesException(BackupCodesError.invalidResponse);
      }
      final data = decoded['response'] as Map<String, dynamic>;
      var ok = headerResult == 1;
      // A success header must not mask a business-level rejection in the body.
      for (final object in [decoded, data]) {
        for (final key in ['status', 'eresult']) {
          if (!object.containsKey(key)) continue;
          final raw = object[key];
          final value = raw is int ? raw : int.tryParse('$raw');
          if (value == null) {
            throw const BackupCodesException(BackupCodesError.invalidResponse);
          }
          _checkResult(value);
          ok = true;
        }
        if (object.containsKey('success')) {
          final success = object['success'];
          if (success != true && success != 1 && success != '1') {
            throw const BackupCodesException(BackupCodesError.rejected);
          }
          ok = true;
        }
        if (object['error'] != null &&
            object['error'] != false &&
            object['error'] != '') {
          throw const BackupCodesException(BackupCodesError.rejected);
        }
      }
      return _BackupResponse(data, ok: ok);
    } on BackupCodesException {
      rethrow;
    } on DioException catch (error) {
      // Do not retain or interpolate DioException: it owns the secret request
      // body and could expose the credential/SMS to a generic error/log view.
      throw BackupCodesException(
        error.type == DioExceptionType.cancel
            ? BackupCodesError.cancelled
            : BackupCodesError.network,
      );
    } catch (_) {
      throw const BackupCodesException(BackupCodesError.invalidResponse);
    }
  }

  static void _checkResult(int? result) {
    if (result == null || result == 1) return;
    final error = switch (result) {
      5 || 21 || 27 || 77 || 126 => BackupCodesError.authenticationRequired,
      25 || 84 || 87 || 95 || 96 || 97 => BackupCodesError.rateLimited,
      65 || 71 || 88 || 89 || 94 => BackupCodesError.invalidCode,
      123 => BackupCodesError.phoneRequired,
      _ => BackupCodesError.rejected,
    };
    throw BackupCodesException(error);
  }

  static String? _maskedPhoneHint(Object? value) {
    // Optional hint only. Never expose an unexpected full phone number or
    // arbitrary HTML/error data as a claimed delivery destination.
    if (value is! String ||
        value.length > 48 ||
        !RegExp(r'^[+0-9*•xX() -]+$').hasMatch(value) ||
        !RegExp(r'[*•xX]').hasMatch(value) ||
        RegExp(r'\d').allMatches(value).length > 4) {
      return null;
    }
    return value;
  }
}

class _BackupResponse {
  final Map<String, dynamic> data;
  final bool ok;

  _BackupResponse(this.data, {required this.ok});
}
