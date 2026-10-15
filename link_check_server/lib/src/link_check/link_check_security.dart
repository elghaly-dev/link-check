import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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
  /// [lookup] replaces DNS resolution (used by tests); defaults to the system
  /// resolver.
  const LinkCheckSecurity({this.lookup});

  final Future<List<InternetAddress>> Function(String host)? lookup;

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
      throw LinkCheckSecurityException(
        'URL must include a scheme (http or https).',
      );
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw LinkCheckSecurityException('Use an http or https URL.');
    }

    if (uri.userInfo.isNotEmpty) {
      throw LinkCheckSecurityException(
        'URLs with embedded credentials are not allowed.',
      );
    }

    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw LinkCheckSecurityException('URL must include a host name.');
    }

    final normalizedHost = normalizeHost(uri.host);
    uri = uri.replace(host: normalizedHost);

    final host = normalizedHost.toLowerCase();
    if (_blockedHostnames.contains(host)) {
      throw LinkCheckSecurityException('Target host is not allowed.');
    }

    if (host.endsWith('.localhost') ||
        host.endsWith('.local') ||
        host.endsWith('.internal')) {
      throw LinkCheckSecurityException('Target host is not allowed.');
    }

    _assertAllowedPort(uri);
    _assertHostAllowed(host);

    return uri;
  }

  /// Strips trailing dots and decodes alternative IPv4 host encodings.
  String normalizeHost(String host) {
    var value = host;
    if (value.endsWith('.')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.isEmpty) {
      return value;
    }

    final decimal = _tryParseDecimalIpv4Host(value);
    if (decimal != null) {
      return decimal;
    }

    final dotted = _tryParseAlternativeDottedIpv4(value);
    if (dotted != null) {
      return dotted;
    }

    return value;
  }

  /// Resolves [uri] once and returns a single public address used for TCP connect.
  Future<InternetAddress> resolveConnectAddress(Uri uri) async {
    final normalized = validateRequestUrl(uri.toString());
    final host = normalized.host;

    final literal = InternetAddress.tryParse(host);
    if (literal != null) {
      final canonical = _canonicalAddress(literal);
      if (_isBlockedAddress(canonical)) {
        throw LinkCheckSecurityException('Target address is not allowed.');
      }
      return canonical;
    }

    List<InternetAddress> addresses;
    try {
      final resolver =
          lookup ??
          (String name) =>
              InternetAddress.lookup(name, type: InternetAddressType.any);
      addresses = await resolver(host).timeout(LinkCheckConfig.connectTimeout);
    } on SocketException {
      throw LinkCheckSecurityException('Could not resolve host name.');
    } on TimeoutException {
      throw LinkCheckSecurityException('DNS lookup timed out.');
    }

    if (addresses.isEmpty) {
      throw LinkCheckSecurityException('Could not resolve host name.');
    }

    for (final address in addresses) {
      final canonical = _canonicalAddress(address);
      if (!_isBlockedAddress(canonical)) {
        return canonical;
      }
    }

    throw LinkCheckSecurityException(
      'Target resolves to a disallowed address.',
    );
  }

  /// Resolves [uri]'s host and ensures every address is on the public Internet.
  Future<void> assertResolvableHostIsPublic(Uri uri) async {
    await resolveConnectAddress(uri);
  }

  void _assertHostAllowed(String host) {
    final literal = InternetAddress.tryParse(host);
    if (literal != null && _isBlockedAddress(_canonicalAddress(literal))) {
      throw LinkCheckSecurityException('Target address is not allowed.');
    }

    if (host == '169.254.169.254') {
      throw LinkCheckSecurityException('Target address is not allowed.');
    }
  }

  void _assertAllowedPort(Uri uri) {
    final port = _effectivePort(uri);
    if (port != 80 && port != 443) {
      throw LinkCheckSecurityException('Use port 80 or 443.');
    }
  }

  int _effectivePort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }
    return uri.scheme == 'https' ? 443 : 80;
  }

  /// Returns true if [address] is private, loopback, link-local, or otherwise internal.
  bool isBlockedAddress(InternetAddress address) =>
      _isBlockedAddress(_canonicalAddress(address));

  InternetAddress _canonicalAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv6) {
      return address;
    }
    final mapped = _ipv4MappedAddress(address);
    return mapped ?? address;
  }

  InternetAddress? _ipv4MappedAddress(InternetAddress address) {
    if (address.type != InternetAddressType.IPv6) {
      return null;
    }
    final raw = address.rawAddress;
    final isMapped =
        raw[0] == 0 &&
        raw[1] == 0 &&
        raw[2] == 0 &&
        raw[3] == 0 &&
        raw[4] == 0 &&
        raw[5] == 0 &&
        raw[6] == 0 &&
        raw[7] == 0 &&
        raw[8] == 0 &&
        raw[9] == 0 &&
        raw[10] == 0xff &&
        raw[11] == 0xff;
    if (!isMapped) {
      return null;
    }
    return InternetAddress.fromRawAddress(
      Uint8List.fromList([raw[12], raw[13], raw[14], raw[15]]),
    );
  }

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

  String? _tryParseDecimalIpv4Host(String host) {
    if (!RegExp(r'^\d+$').hasMatch(host)) {
      return null;
    }
    final value = int.tryParse(host);
    if (value == null || value < 0 || value > 0xFFFFFFFF) {
      return null;
    }
    return '${(value >> 24) & 0xff}.${(value >> 16) & 0xff}.${(value >> 8) & 0xff}.${value & 0xff}';
  }

  String? _tryParseAlternativeDottedIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return null;
    }
    final octets = <int>[];
    for (final part in parts) {
      final octet = _parseIpv4Octet(part);
      if (octet == null) {
        return null;
      }
      octets.add(octet);
    }
    return octets.join('.');
  }

  int? _parseIpv4Octet(String part) {
    if (part.isEmpty) {
      return null;
    }
    if (part.startsWith('0x') || part.startsWith('0X')) {
      return int.tryParse(part.substring(2), radix: 16);
    }
    if (part.startsWith('0') && part.length > 1) {
      return int.tryParse(part, radix: 8);
    }
    return int.tryParse(part, radix: 10);
  }
}
