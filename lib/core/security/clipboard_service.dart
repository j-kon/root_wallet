import 'dart:async';
import 'package:flutter/services.dart';

/// Service responsible for managing clipboard operations with security controls.
/// Supports auto-clearing sensitive data (such as seed words) after a specified duration,
/// preventing sensitive information from lingering in system clipboards or sync clips.
class ClipboardService {
  ClipboardService({
    this.defaultSensitiveTimeout = const Duration(seconds: 60),
    ClipboardData Function(String text)? clipboardDataFactory,
    Future<void> Function(ClipboardData data)? setDataHandler,
    Future<ClipboardData?> Function(String format)? getDataHandler,
  })  : _setData = setDataHandler ?? Clipboard.setData,
        _getData = getDataHandler ?? Clipboard.getData;

  final Duration defaultSensitiveTimeout;
  final Future<void> Function(ClipboardData data) _setData;
  final Future<ClipboardData?> Function(String format) _getData;

  Timer? _clearTimer;
  String? _lastCopiedSensitive;

  /// Copies sensitive text (e.g. recovery mnemonic) to the clipboard and schedules an auto-clear.
  Future<void> copySensitive(
    String text, {
    Duration? timeout,
  }) async {
    _clearTimer?.cancel();
    _lastCopiedSensitive = text;
    await _setData(ClipboardData(text: text));

    final effectiveTimeout = timeout ?? defaultSensitiveTimeout;
    _clearTimer = Timer(effectiveTimeout, () async {
      await clearIfMatches(text);
    });
  }

  /// Copies non-sensitive public text (e.g. bitcoin addresses, transaction IDs).
  Future<void> copyPublic(String text) async {
    _clearTimer?.cancel();
    _lastCopiedSensitive = null;
    await _setData(ClipboardData(text: text));
  }

  /// Clears the clipboard if it still contains [expectedText].
  Future<void> clearIfMatches(String expectedText) async {
    try {
      final currentData = await _getData(Clipboard.kTextPlain);
      if (currentData?.text == expectedText) {
        await _setData(const ClipboardData(text: ''));
        if (_lastCopiedSensitive == expectedText) {
          _lastCopiedSensitive = null;
        }
      }
    } catch (_) {
      // Ignore clipboard access issues
    }
  }

  /// Unconditionally clears the clipboard.
  Future<void> clearClipboard() async {
    _clearTimer?.cancel();
    _lastCopiedSensitive = null;
    await _setData(const ClipboardData(text: ''));
  }

  void dispose() {
    _clearTimer?.cancel();
  }
}
