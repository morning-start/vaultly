import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// 基于内存 Map 的 FlutterSecureStorage 平台 mock。
///
/// VaultService 通过 `const FlutterSecureStorage()` 委托到
/// `FlutterSecureStoragePlatform.instance`，测试中替换该静态实例即可，
/// 无需 mock method channel。
class MockSecureStorage extends FlutterSecureStoragePlatform {
  final Map<String, String> store = {};

  /// 注入故障用：置 true 时下一次 write 抛 PlatformException（模拟写盘失败）。
  bool failNextWrite = false;

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw PlatformException(code: 'mock_write_failed', message: '注入的写失败');
    }
    store[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    store.clear();
  }
}

/// 构造一个确定的 32 字节测试密钥（非随机，保证测试可复现）。
Uint8List testKey({int seed = 42}) =>
    Uint8List.fromList(List.generate(32, (i) => (i + seed) % 256));

/// 读取并解析 VaultService 持久化的 JSON（模拟磁盘数据检查）。
Map<String, dynamic> persistedVaultJson(MockSecureStorage storage) {
  final raw = storage.store['vault_data'];
  if (raw == null) throw StateError('vault_data 未持久化');
  return jsonDecode(raw) as Map<String, dynamic>;
}
