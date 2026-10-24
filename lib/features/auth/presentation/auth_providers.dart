import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_service.dart';
import '../data/biometric_service.dart';
import '../domain/auth_notifier.dart';
import '../domain/auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final biometricService = ref.watch(biometricServiceProvider);
  return AuthService(biometricService: biometricService);
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

/// 会话密钥通道：认证模块发布，保险库模块消费。
///
/// 位于 auth/presentation 层的顶层组装文件中，
/// 是两个 feature 之间唯一允许的耦合点（依赖倒置：双方只依赖本文件）。
final sessionKeyBridgeProvider =
    Provider<SessionKeyBridge>((ref) => SessionKeyBridge());

/// 会话密钥桥
///
/// AuthNotifier 通过 [publish]/[revoke] 写入，
/// VaultNotifier 通过 [key] / [onPublished] / [onRevoked] 消费。
class SessionKeyBridge {
  Uint8List? _key;
  final List<void Function(Uint8List key)> _publishedListeners = [];
  final List<void Function()> _revokedListeners = [];

  /// 当前会话密钥（可能已被清零回收）
  Uint8List? get key => _key;

  void publish(Uint8List key) {
    _key = key;
    for (final listener in List.of(_publishedListeners)) {
      listener(key);
    }
  }

  void revoke() {
    _key = null;
    for (final listener in List.of(_revokedListeners)) {
      listener();
    }
  }

  void onPublished(void Function(Uint8List key) listener) {
    _publishedListeners.add(listener);
  }

  void onRevoked(void Function() listener) {
    _revokedListeners.add(listener);
  }

  void removeListeners({
    void Function(Uint8List key)? published,
    void Function()? revoked,
  }) {
    if (published != null) _publishedListeners.remove(published);
    if (revoked != null) _revokedListeners.remove(revoked);
  }
}

/// 认证状态提供者
///
/// 密钥生命周期通过 [SessionKeyBridge] 与保险库解耦：
/// - 解锁/设置密码/改密成功 → publish 密钥；
/// - 锁定/清除数据 → revoke 密钥。
/// auth 模块不 import vault 模块，依赖方向保持单向。
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final biometricService = ref.watch(biometricServiceProvider);
  final bridge = ref.watch(sessionKeyBridgeProvider);

  return AuthNotifier(
    authService,
    biometricService,
    keyPublisher: bridge.publish,
    keyRevoker: bridge.revoke,
  );
});
