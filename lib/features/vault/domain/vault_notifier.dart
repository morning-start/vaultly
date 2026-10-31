import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/vault_entry.dart';
import '../data/vault_service.dart';
import '../../../core/exceptions/app_exception.dart';

/// 保险库状态
///
/// [entries] 为已解密的内存态条目（不可变列表）。
class VaultState {
  /// 是否已完成首次加载
  final bool isLoaded;

  /// 条目变更序号：每次写操作递增，派生 Provider 依赖它做缓存失效
  final int revision;

  /// 只读条目快照
  final List<VaultEntry> entries;

  /// 最近一次操作错误（展示后清除）
  final String? error;

  /// 本次加载是否从写前备份恢复（主数据损坏）
  final bool recoveredFromBackup;

  const VaultState({
    this.isLoaded = false,
    this.revision = 0,
    this.entries = const [],
    this.error,
    this.recoveredFromBackup = false,
  });

  VaultState copyWith({
    bool? isLoaded,
    int? revision,
    List<VaultEntry>? entries,
    String? error,
    bool? recoveredFromBackup,
    bool clearError = false,
  }) =>
      VaultState(
        isLoaded: isLoaded ?? this.isLoaded,
        revision: revision ?? this.revision,
        entries: entries ?? this.entries,
        error: clearError ? null : (error ?? this.error),
        recoveredFromBackup: recoveredFromBackup ?? this.recoveredFromBackup,
      );
}

/// 保险库状态管理器
///
/// 应用内唯一的条目数据源：
/// - 解锁后调用 [unlock] 注入密钥并加载；
/// - 所有写操作经过此处，成功后同步刷新内存态并递增 revision，
///   下游 Provider 自动失效重建，无需手动通知。
class VaultNotifier extends StateNotifier<VaultState> {
  final VaultService _service;

  VaultNotifier(this._service) : super(const VaultState());

  /// 是否已完成首次加载（供外部决定 unlock vs rotateKey）
  bool get isLoaded => state.isLoaded;

  int get _nextRevision => state.revision + 1;

  /// 解锁/密钥变更时加载保险库。
  ///
  /// 幂等：重复以相同密钥调用不会重复加载。
  Future<void> unlock(Uint8List encryptionKey) async {
    _service.setEncryptionKey(encryptionKey);
    await _reload();
  }

  /// 密钥轮换（修改主密码）后，用新密钥重加密并持久化全部数据。
  Future<void> rotateKey(Uint8List newKey) async {
    _service.setEncryptionKey(newKey);
    await _service.saveVault();
    state = state.copyWith(revision: _nextRevision);
  }

  Future<void> _reload() async {
    try {
      await _service.loadVault();
      state = state.copyWith(
        isLoaded: true,
        revision: _nextRevision,
        entries: _service.entries,
        recoveredFromBackup: _service.recoveredFromPrevious,
        error: null,
      );
    } on AppException catch (e) {
      state = state.copyWith(isLoaded: true, error: e.message);
    } on Exception catch (e) {
      state = state.copyWith(isLoaded: true, error: e.toString());
    }
  }

  /// 写操作的统一包装：执行 → 失败回滚内存态 → 成功刷新快照。
  Future<bool> _mutate(Future<void> Function() action) async {
    final snapshot = _service.entries;
    try {
      await action();
      state = state.copyWith(
        revision: _nextRevision,
        entries: _service.entries,
        clearError: true,
      );
      return true;
    } on AppException catch (e) {
      await _rollback(snapshot);
      state = state.copyWith(error: e.message);
      return false;
    } on Exception catch (e) {
      await _rollback(snapshot);
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// 持久化失败时回滚服务层内存态，避免内存与磁盘不一致。
  Future<void> _rollback(List<VaultEntry> snapshot) async {
    try {
      await _service.replaceAllEntries(snapshot);
    } on Exception {
      // 回滚失败（如密钥已失效）：保持现状，下次加载时从磁盘恢复
    }
  }

  /// 手动重载（错误恢复/外部恢复后调用）。
  Future<void> reload() => _reload();

  /// 锁定：密钥被回收时清空内存态条目，敏感数据不驻留内存。
  void lock() {
    state = const VaultState();
  }

  Future<bool> addEntry(VaultEntry entry) =>
      _mutate(() => _service.addEntry(entry));

  Future<bool> updateEntry(VaultEntry entry) =>
      _mutate(() => _service.updateEntry(entry));

  Future<bool> deleteEntry(String id) =>
      _mutate(() => _service.deleteEntry(id));

  Future<bool> replaceAllEntries(List<VaultEntry> entries) =>
      _mutate(() => _service.replaceAllEntries(entries));

  Future<bool> toggleFavorite(String entryId) =>
      _mutate(() => _service.toggleFavorite(entryId));

  /// 清除错误提示
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }
}
