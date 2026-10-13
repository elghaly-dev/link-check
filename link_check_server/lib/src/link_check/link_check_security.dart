import 'dart:async';
import 'dart:io';

import 'link_check_config.dart';

/// Thrown when a URL fails validation before any outbound request is made.
class LinkCheckSecurityException implements Exception {
  LinkCheckSecurityException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Hostnames that must never be fetched, even before DNS resolution.
const _blockedHostnames = {
  'localhost',
  'localhost.localdomain',
  'metadata.google.internal',
  'metadata.goog',
};

/// Validates URLs and resolved addresses to mitigate SSRF and internal network access.
class LinkCheckSecurity {
  const LinkCheckSecurity();

  /// Parses and validates [rawUrl]. Returns a normalized [Uri] on success.
  Uri validateRequestUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw LinkCheckSecurityException('URL is required.');
    }
    if (trimmed.length > LinkCheckConfig.maxUrlLength) {
      throw LinkCheckSecurityException(
        'URL exceeds maximum length of ${LinkCheckConfig.maxUrlLength} characters.',
      );
    }

    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException {
      throw LinkCheckSecurityException('URL is not valid.');
    }

    if (!uri.hasScheme) {
      throw LinkCheckSecurityException('URL must include a scheme (http or https).');
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw LinkCheckSecurityException('Only http and https URLs are allowed.');
    }

    if (uri.userInfo.isNotEmpty) {
      throw LinkCheckSecurityException('URLs with embedded credentials are not allowed.');
    }

    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw LinkCheckSecurityException('URL must include a host name.');
    }

    if (uri.fragment.isNotEmpty) {
      // Fragments are not sent to servers; strip for fetching but keep validation on host.
    }

    final host = uri.host.toLowerCase();
    if (_blockedHostnames.contains(host)) {
      throw LinkCheckSecurityException('Target host is not allowed.');
    }

    if (host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      throw LinkCheckSecurityException('Target host is not allowed.');
    }

    if (uri.hasPort) {
      final port = uri.port;
      if (port <= 0 || port > 65535) {
        throw LinkCheckSecurityException('URL port is out of range.');
      }
    }

    _assertHostAllowed(host);

    return uri;
  }

  /// Resolves [uri]'s host and ensures every address is on the public Internet.
  Future<void> assertResolvableHostIsPublic(Uri uri) async {
    final host = uri.host;

    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      if (_isBlockedAddress(literal)) {
        throw LinkCheckSecurityException('Target address is not allowed.');
      }
      return;
    }

    List<InternetAddress> addresses;
    try {
      addresses = await InternetAddress.lookup(
        host,
        type: InternetAddressType.any,
      ).timeout(LinkCheckConfig.connectTimeout);
    } on SocketException {
      throw LinkCheckSecurityException('Could not resolve host name.');
    } on TimeoutException {
      throw LinkCheckSecurityException('DNS lookup timed out.');
    }

    if (addresses.isEmpty) {
      throw LinkCheckSecurityException('Could not resolve host name.');
    }

    for (final address in addresses) {
      if (_isBlockedAddress(address)) {
        throw LinkCheckSecurityException('Target resolves to a disallowed address.');
      }
    }
  }

  void _assertHostAllowed(String host) {
    final literal = InternetAddress.tryParse(host);
    if (literal != null && _isBlockedAddress(literal)) {
      throw LinkCheckSecurityException('Target address is not allowed.');
    }

    // Block common cloud metadata host patterns without DNS.
    if (host == '169.254.169.254') {
      throw LinkCheckSecurityException('Target address is not allowed.');
    }
  }

  /// Returns true if [address] is private, loopback, link-local, or otherwise internal.
  bool isBlockedAddress(InternetAddress address) => _isBlockedAddress(address);

  bool _isBlockedAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }

    if (address.type == InternetAddressType.IPv4) {
      final o = address.rawAddress;
      if (o[0] == 0) return true; // "this" network
      if (o[0] == 10) return true; // RFC1918
      if (o[0] == 127) return true; // loopback
      if (o[0] == 100 && o[1] >= 64 && o[1] <= 127) return true; // CGNAT
      if (o[0] == 169 && o[1] == 254) return true; // link-local / metadata
      if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return true; // RFC1918
      if (o[0] == 192 && o[1] == 168) return true; // RFC1918
      if (o[0] >= 224) return true; // multicast + reserved upper range
    }

    if (address.type == InternetAddressType.IPv6) {
      final b = address.rawAddress;
      // Unique local addresses fc00::/7
      if ((b[0] & 0xfe) == 0xfc) return true;
      // Link-local fe80::/10
      if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true;
    }

    return false;
  }
}
