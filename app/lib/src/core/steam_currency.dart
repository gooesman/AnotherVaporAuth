/// Steam's wallet and market amounts use hundredths even for currencies whose
/// ordinary cash denomination has no decimals. Unknown currency IDs are shown
/// explicitly instead of silently being presented as USD.
String formatSteamMoney(int minor, int currency) {
  const codes = {
    1: 'USD',
    2: 'GBP',
    3: 'EUR',
    4: 'CHF',
    5: 'RUB',
    6: 'PLN',
    7: 'BRL',
    8: 'JPY',
    9: 'NOK',
    10: 'IDR',
    11: 'MYR',
    12: 'PHP',
    13: 'SGD',
    14: 'THB',
    15: 'VND',
    16: 'KRW',
    17: 'TRY',
    18: 'UAH',
    19: 'MXN',
    20: 'CAD',
    21: 'AUD',
    22: 'NZD',
    23: 'CNY',
    24: 'INR',
    25: 'CLP',
    26: 'PEN',
    27: 'COP',
    28: 'ZAR',
    29: 'HKD',
    30: 'TWD',
    31: 'SAR',
    32: 'AED',
  };
  final magnitude = minor.abs();
  final amount =
      '${minor < 0 ? '-' : ''}${magnitude ~/ 100}.${(magnitude % 100).toString().padLeft(2, '0')}';
  return '${codes[currency] ?? 'Steam #$currency'} $amount';
}
