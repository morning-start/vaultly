import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../domain/sync_models.dart';

/// 同步配置存储仓库
///
/// 负责配置的持久化和缓存管理。
class SyncConfigRepository {
  static const _keyWebDavUrl = 'webdav_url';
  static const _keyWebDavUsername = 'webdav_username';
  static const _keyWebDavPassword = 'webdav_password';
  static const _keyLastSyncTime = 'webdav_last_sync';
  static const _keyLastUploadKeyTag = 'webdav_last_upload_key_tag';

  /// 指纹方案版本：前缀不匹配的旧值一律视为「未知」
  ///
  /// v2 = HKDF(masterSecret, "vaultly/key-tag")；v1（无前缀）= 校验值再哈希。
  static const _keyTagScheme = '2';
  static const _keySyncHistory = 'webdav_sync_history';

  final FlutterSecureStorage _secureStorage;

  // 内存缓存
  SyncConfig? _cachedConfig;
  bool? _cachedIsConfigured;
  DateTime? _configCacheTime;
  static const _cacheValidityDuration = Duration(seconds: 30);

  SyncConfigRepository({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 检查缓存是否有效
  bool get _isCacheValid {
    if (_configCacheTime == null || _cachedConfig == null) return false;
    return DateTime.now().difference(_configCacheTime!) < _cacheValidityDuration;
  }

  /// 获取缓存的配置
  SyncConfig? getCachedConfig() {
    if (_cachedConfig != null && _isCacheValid) {
      return _cachedConfig;
    }
    return null;
  }

  /// 检查是否已配置 WebDAV
  Future<bool> isConfigured() async {
    if (_cachedIsConfigured != null && _isCacheValid) {
      return _cachedIsConfigured!;
    }

    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    final isConfigured = url != null &&
        url.isNotEmpty &&
        username != null &&
        password != null;

    _cachedIsConfigured = isConfigured;
    _configCacheTime = DateTime.now();

    return isConfigured;
  }

  /// 快速检查是否已配置（同步方法）
  bool isConfiguredSync() {
    return _cachedIsConfigured ?? false;
  }

  /// 获取同步配置
  Future<SyncConfig?> getConfig() async {
    if (_cachedConfig != null && _isCacheValid) {
      return _cachedConfig;
    }

    final url = await _secureStorage.read(key: _keyWebDavUrl);
    final username = await _secureStorage.read(key: _keyWebDavUsername);
    final password = await _secureStorage.read(key: _keyWebDavPassword);

    if (url == null || username == null || password == null) {
      return null;
    }

    final config = SyncConfig(
      id: 'webdav_default',
      serverUrl: url,
      username: username,
      password: password,
    );

    _cachedConfig = config;
    _configCacheTime = DateTime.now();

    return config;
  }

  /// 保存同步配置
  Future<void> saveConfig(SyncConfig config) async {
    await _secureStorage.write(key: _keyWebDavUrl, value: config.serverUrl);
    await _secureStorage.write(key: _keyWebDavUsername, value: config.username);
    await _secureStorage.write(key: _keyWebDavPassword, value: config.password ?? '');

    _cachedConfig = config;
    _cachedIsConfigured = true;
    _configCacheTime = DateTime.now();
  }

  /// 清除配置
  Future<void> clearConfig() async {
    await _secureStorage.delete(key: _keyWebDavUrl);
    await _secureStorage.delete(key: _keyWebDavUsername);
    await _secureStorage.delete(key: _keyWebDavPassword);
    await _secureStorage.delete(key: _keyLastSyncTime);
    await _secureStorage.delete(key: _keyLastUploadKeyTag);
    _cachedConfig = null;
    _cachedIsConfigured = null;
    _configCacheTime = null;
  }

  /// 清除内存缓存
  void clearCache() {
    _cachedConfig = null;
    _cachedIsConfigured = null;
    _configCacheTime = null;
  }

  /// 获取最后同步时间
  Future<DateTime?> getLastSyncTime() async {
    final timeStr = await _secureStorage.read(key: _keyLastSyncTime);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// 更新最后同步时间
  Future<void> updateLastSyncTime(DateTime time) async {
    await _secureStorage.write(
      key: _keyLastSyncTime,
      value: time.toIso8601String(),
    );
  }

  /// 记录本次上传所用密钥体系的指纹
  ///
  /// 用于检测「云端备份还是旧主密码加密的」：改主密码后指纹变化，
  /// 与云端那份不一致时提示用户重新上传。
  Future<void> updateLastUploadKeyTag(String tag) async {
    await _secureStorage.write(
      key: _keyLastUploadKeyTag,
      value: '$_keyTagScheme:$tag',
    );
  }

  /// 读取最近一次上传所用的密钥指纹
  ///
  /// 返回 null 表示未知：尚未上传过、无方案前缀（v4.0.1 及更早写入的旧值），
  /// 或指纹方案已变更。方案变更后旧值不再可比，一律当作未知——
  /// 宁可漏报「备份过期」，也不能误报（误报会把用户引向无意义的重传）。
  Future<String?> getLastUploadKeyTag() async {
    final raw = await _secureStorage.read(key: _keyLastUploadKeyTag);
    if (raw == null || raw.isEmpty) return null;

    final separator = raw.indexOf(':');
    if (separator <= 0) return null;
    if (raw.substring(0, separator) != _keyTagScheme) return null;

    final tag = raw.substring(separator + 1);
    return tag.isEmpty ? null : tag;
  }

  /// 获取同步历史
  Future<List<SyncHistory>> getSyncHistory({int limit = 50}) async {
    try {
      final historyJson = await _secureStorage.read(key: _keySyncHistory);
      if (historyJson == null) return [];

      final List<dynamic> historyList = jsonDecode(historyJson);
      final histories = historyList
          .map((e) => SyncHistory.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return histories.take(limit).toList();
    } catch (e) {
      debugPrint('获取同步历史失败: $e');
      return [];
    }
  }

  /// 清除同步历史
  Future<void> clearSyncHistory() async {
    await _secureStorage.delete(key: _keySyncHistory);
  }

  /// 保存同步历史
  Future<void> saveSyncHistory(SyncResult result) async {
    try {
      final history = await getSyncHistory(limit: 100);
      final newEntry = SyncHistory(
        id: const Uuid().v4(),
        timestamp: DateTime.now(),
        success: result.success,
        added: result.added,
        updated: result.updated,
        deleted: result.deleted,
        conflicts: result.conflicts.length,
        errorMessage: result.errorMessage,
      );

      history.insert(0, newEntry);

      // 只保留最近100条
      final limitedHistory = history.take(100).toList();
      await _secureStorage.write(
        key: _keySyncHistory,
        value: jsonEncode(limitedHistory.map((e) => e.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('保存同步历史失败: $e');
    }
  }
}
