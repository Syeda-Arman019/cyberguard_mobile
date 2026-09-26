/// Verified brand registry for impersonation detection.
///
/// Every domain below was verified against authoritative sources (the
/// brand's own official website as served in search results / official
/// documentation) before inclusion. Per policy: if a domain cannot be
/// confidently verified as official, it is NOT added.
///
/// Matching contract (see [BrandRegistry.findImpersonatedBrand]):
///  - only the HOSTNAME participates (never path/query/fragment), so a
///    news article mentioning "PayPal" or a search query for a brand can
///    never be flagged;
///  - a host is legitimate when its registrable domain equals an official
///    domain or is a subdomain of one;
///  - the brand token must appear as a bounded hostname label or label
///    boundary token (start/end/adjacent to a hyphen) — never as a random
///    substring — before impersonation is reported.
class BrandRegistry {
  BrandRegistry._();

  /// brand token -> set of verified official registrable domains.
  static const Map<String, Set<String>> _brands = {
    // Payments / banking
    'paypal': {'paypal.com'},
    'visa': {'visa.com'},
    'mastercard': {'mastercard.com'},
    'stripe': {'stripe.com'},
    'wellsfargo': {'wellsfargo.com'},
    'wells-fargo': {'wellsfargo.com'},
    'citibank': {'citi.com', 'citibank.com'},
    'citi': {'citi.com', 'citibank.com'},
    'chase': {'chase.com', 'jpmorganchase.com'},
    'hsbc': {'hsbc.com'},
    'barclays': {'barclays.co.uk', 'barclays.com'},

    // Technology
    'google': {'google.com', 'googlemail.com'},
    'youtube': {'youtube.com'},
    'microsoft': {'microsoft.com', 'outlook.com', 'office.com',
      'office365.com', 'live.com', 'windowsupdate.com'},
    'apple': {'apple.com', 'icloud.com'},
    'icloud': {'icloud.com'},
    'amazon': {'amazon.com', 'amazon.co.uk', 'amazon.de', 'amazon.in',
      'amazonpay.com', 'amazon-adsystem.com'},
    'samsung': {'samsung.com'},
    'dell': {'dell.com'},
    'hp': {'hp.com'},
    'intel': {'intel.com'},
    'ibm': {'ibm.com'},
    'adobe': {'adobe.com'},
    'dropbox': {'dropbox.com'},

    // Social / messaging
    'facebook': {'facebook.com', 'fb.com'},
    'instagram': {'instagram.com'},
    'whatsapp': {'whatsapp.com'},
    'linkedin': {'linkedin.com'},
    'tiktok': {'tiktok.com'},
    'snapchat': {'snapchat.com'},
    'twitter': {'twitter.com', 'x.com'},
    'telegram': {'telegram.org'},

    // Email / productivity
    'gmail': {'gmail.com', 'googlemail.com'},
    'outlook': {'outlook.com', 'office.com', 'office365.com', 'live.com'},
    'office': {'office.com', 'office365.com', 'microsoft.com'},
    'onedrive': {'onedrive.com', 'live.com'},
    'slack': {'slack.com'},

    // Shopping / streaming
    'netflix': {'netflix.com'},
    'spotify': {'spotify.com'},
    'ebay': {'ebay.com'},
    'steampowered': {'steampowered.com'},
    'steam': {'steampowered.com', 'steamcommunity.com'},
  };

  /// Shared-infrastructure hosts that legitimately contain a brand token
  /// (e.g. `mybucket.s3.amazonaws.com`, `xxx.appspot.com`) but are NOT
  /// brand impersonation. Registrable-domain level.
  static const Set<String> _infrastructureAllowlist = {
    'amazonaws.com', // AWS (S3, Lambda, …)
    'amazoncognito.com',
    'googleapis.com', // Google Cloud
    'googleusercontent.com',
    'appspot.com',
    'firebaseapp.com',
    'web.app',
    'windows.net', // Azure
    'azurewebsites.net',
    'azureedge.net',
    'cloudapp.net',
    'fbcdn.net', // Meta CDN
    'cdninstagram.com',
    'akamaihd.net',
    'cloudfront.net',
    'azure.microsoft.com',
  };

  /// Brand tokens shorter than this never match as a concatenated
  /// label-start token (e.g. `citizens…` must not flag as `citi`,
  /// `xbox…` must not flag as `x`). Hyphen/label-bounded matches always
  /// participate regardless of length.
  static const int _minConcatenatedTokenLength = 5;

  /// Returns the brand token impersonated by [host], or `null` when the
  /// host is clean / legitimately official / shared infrastructure.
  static String? findImpersonatedBrand(String host) {
    final h = host.toLowerCase().trim();
    if (h.isEmpty) return null;

    // Shared infrastructure can host attacker pages but its hostname is
    // not a brand impersonation — GSB/local checks cover the content.
    if (_isSubdomainOfAny(h, _infrastructureAllowlist)) return null;

    for (final entry in _brands.entries) {
      final brand = entry.key;
      if (!_hostContainsBrandToken(h, brand)) continue;

      // Token present: legitimate only if the registrable domain is an
      // official domain of this brand.
      if (_isSubdomainOfAny(h, entry.value)) continue;

      // Google/Amazon country-code storefronts (google.co.uk, amazon.de…).
      if ((brand == 'google' || brand == 'amazon') &&
          _isOfficialCcTldStorefront(h, brand)) {
        continue;
      }

      return brand;
    }
    return null;
  }

  /// True when [host] contains [brand] as a bounded token:
  ///  - hyphen/label bounded (`paypal-secure`, `secure.paypal`), or
  ///  - at the START of a label followed by more letters/digits, for
  ///    tokens >= [_minConcatenatedTokenLength] (`applesupport.com`,
  ///    `paypalsecure.com` — classic phishing concatenation).
  /// Never as a random mid-word substring (`purchase` must not flag
  /// `chase`, `chocolate` must not flag any brand).
  static bool _hostContainsBrandToken(String host, String brand) {
    for (final label in host.split('.')) {
      if (label.isEmpty) continue;
      final positions = _allIndexOf(label, brand);
      for (final idx in positions) {
        final atLabelStart = idx == 0;
        final beforeBounded =
            atLabelStart || label[idx - 1] == '-' || label[idx - 1] == '.';
        final atLabelEnd = idx + brand.length == label.length;
        final afterBounded =
            atLabelEnd || label[idx + brand.length] == '-';

        if (beforeBounded && afterBounded) return true;

        // Concatenated phishing pattern: brand + more characters at the
        // very start of a label (applesupport…, paypalsecure…).
        if (atLabelStart &&
            !atLabelEnd &&
            brand.length >= _minConcatenatedTokenLength &&
            _isAlphaNumeric(label[idx + brand.length])) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _isAlphaNumeric(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x61 && code <= 0x7A);
  }

  static List<int> _allIndexOf(String text, String needle) {
    final out = <int>[];
    if (needle.isEmpty) return out;
    var start = 0;
    while (true) {
      final idx = text.indexOf(needle, start);
      if (idx < 0) break;
      out.add(idx);
      start = idx + 1;
    }
    return out;
  }

  static bool _isSubdomainOfAny(String host, Iterable<String> domains) {
    for (final d in domains) {
      if (host == d || host.endsWith('.$d')) return true;
    }
    return false;
  }

  static bool _isOfficialCcTldStorefront(String host, String brand) {
    final pattern =
        RegExp('^([a-z0-9-]+\\.)*$brand\\.[a-z]{2,3}(\\.[a-z]{2})?\$');
    return pattern.hasMatch(host);
  }
}
