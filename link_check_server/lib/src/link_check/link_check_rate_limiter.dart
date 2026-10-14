import 'dart:collection';

import 'link_check_config.dart';

/// Simple in-memory sliding-window rate limiter keyed by client identifier.
class LinkCheckRateLimiter {
  LinkCheckRateLimiter({
    this.maxRequests = LinkCheckConfig.rateLimitMaxRequests,
    this.window = LinkCheckConfig.rateLimitWindow,
  });

  final int maxRequests;
  final Duration window;

  final _requestsByKey = HashMap<String, Queue<DateTime>>();

  /// Returns true if the request is allowed and records it.
  bool tryAcquire(String clientKey) {
    final now = DateTime.now();
    final cutoff = now.subtract(window);
    final queue = _requestsByKey.putIfAbsent(clientKey, () => Queue());

    while (queue.isNotEmpty && queue.first.isBefore(cutoff)) {
      queue.removeFirst();
    }

    if (queue.length >= maxRequests) {
      return false;
    }

    queue.addLast(now);
    return true;
  }

  /// Clears stored state (for tests).
  void reset() {
    _requestsByKey.clear();
  }
}
