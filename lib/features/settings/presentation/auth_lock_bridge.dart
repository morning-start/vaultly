import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置页与认证模块之间的锁定动作桥
///
/// settings 不允许反向 import auth（依赖方向保持单向），
/// 由 main.dart 在应用启动时注入真实实现。
final authLockBridgeProvider = StateProvider<void Function()>((ref) {
  return () {};
});
