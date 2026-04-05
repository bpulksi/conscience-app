import 'dart:async';
import 'package:flutter/services.dart';

/// Bridges Flutter UI with native Android (AccessibilityService) and
/// iOS (Screen Time API) implementations.
///
/// Usage:
///   final bridge = NativeBridge();
///   await bridge.requestPermissions();
///   bridge.avatarStageStream.listen((stage) => setState(() => _stage = stage));
class NativeBridge {
  static const _channel = MethodChannel('conscience/screenTime');
  static const _eventChannel = EventChannel('conscience/avatarEvents');

  // Singleton
  static final NativeBridge _instance = NativeBridge._internal();
  factory NativeBridge() => _instance;
  NativeBridge._internal();

  Stream<AvatarStage>? _stageStream;

  /// Live stream of avatar mood updates from the native layer.
  Stream<AvatarStage> get avatarStageStream {
    _stageStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => _parseStage(event as String));
    return _stageStream!;
  }

  /// Request all necessary permissions for the current platform.
  /// Returns a [PermissionStatus] indicating what was granted.
  Future<PermissionStatus> requestPermissions() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermissions');
      return _parsePermissionStatus(result ?? 'denied');
    } on PlatformException catch (e) {
      print('Permission request failed: ${e.message}');
      return PermissionStatus.denied;
    }
  }

  /// Open the OS settings screen for accessibility (Android) or
  /// Screen Time (iOS). Call if [requestPermissions] returns [PermissionStatus.needsSettings].
  Future<void> openPermissionSettings() async {
    await _channel.invokeMethod('openPermissionSettings');
  }

  /// Pass the user's Vice App config down to native layer.
  /// [packageNames] = Android package names
  /// [bundleIds] = iOS bundle identifiers
  /// [dailyLimitMinutes] = daily cap
  Future<void> configureMonitoring({
    required List<String> packageNames,
    required List<String> bundleIds,
    required int dailyLimitMinutes,
    required bool toughLove,
  }) async {
    await _channel.invokeMethod('configureMonitoring', {
      'packageNames': packageNames,
      'bundleIds': bundleIds,
      'dailyLimitMinutes': dailyLimitMinutes,
      'toughLove': toughLove,
    });
  }

  /// Grant a temporary extension (called after friend approves request).
  Future<void> grantExtension({int durationMinutes = 10}) async {
    await _channel.invokeMethod('grantExtension', {
      'durationMinutes': durationMinutes,
    });
  }

  /// Lift all blocks (called after a wellness session completes).
  Future<void> resetBlock() async {
    await _channel.invokeMethod('resetBlock');
  }

  /// Check if there's a pending deep link from the iOS Shield action extension.
  /// Returns 'rechargeHub', 'askFriend', or null.
  Future<String?> consumePendingDeepLink() async {
    return await _channel.invokeMethod<String>('consumePendingDeepLink');
  }

  AvatarStage _parseStage(String raw) {
    switch (raw.toUpperCase()) {
      case 'IMPATIENT':
        return AvatarStage.impatient;
      case 'FURIOUS':
        return AvatarStage.furious;
      default:
        return AvatarStage.zen;
    }
  }

  PermissionStatus _parsePermissionStatus(String raw) {
    switch (raw) {
      case 'granted':
        return PermissionStatus.granted;
      case 'needsSettings':
        return PermissionStatus.needsSettings;
      default:
        return PermissionStatus.denied;
    }
  }
}

enum AvatarStage { zen, impatient, furious }

enum PermissionStatus { granted, needsSettings, denied }
