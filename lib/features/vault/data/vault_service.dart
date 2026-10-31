import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vaultly_core/vaultly_core.dart';
/// 保险库服务
///
/// 负责加密存储、读取和维护保险库条目。
/// 采用单例模式，保证加密密钥、内存态条目列表和持久化状态一致。
///
/// 参考文档: wiki/03-模块设计/保险库模块.md
class VaultService {
  static const _keyVaultData = 'vault_data';

  /// 写前备份：始终保存「上一次成功写入的完整数据」
  static const _keyVaultDataPrev = 'vault_data.prev';

  /// 本地存储格式版本
  ///
  /// v1 → v2：条目增加 `deletedAt` 墓碑字段（ADR-006 R3）。
  /// 读取时高于本值一律拒绝（见 [VaultException.schemaVersionUnsupported]）。
  static const int currentSchemaVersion = 2;

  static VaultService? _instance;

  final FlutterSecureStorage _secureStorage;
  Uint8List? _encryptionKey;

  List<VaultEntry> _entries = [];

  /// 本次加载是否从写前备份恢复（主数据损坏）
  bool _recoveredFromPrevious = false;

  /// 主存储区当前是否处于损坏态
  ///
  /// 损坏时**不得**用坏数据覆盖写前备份，否则唯一可用的副本会被毁掉。
  bool _mainPayloadCorrupt = false;

  /// 是否因「本地数据版本过高」而拒绝工作
  ///
  /// 置位后所有写入都会被拒绝：读不懂的数据格式，写回去只会丢字段。
  bool _schemaVersionBlocked = false;

  /// 检测到的高版本号（用于错误文案）
  int? _blockedSchemaVersion;

  // 加密策略映射
  static const _encryptionStrategies = <EntryType, EntryEncryptionStrategy>{
    EntryType.login: LoginEncryptionStrategy(),
    EntryType.bankCard: BankCardEncryptionStrategy(),
    EntryType.secureNote: SecureNoteEncryptionStrategy(),
    EntryType.identity: IdentityEncryptionStrategy(),
  };

  /// 获取单例实例
  static VaultService get instance {
    _instance ??= VaultService._internal();
    return _instance!;
  }

  /// 私有构造函数
  VaultService._internal({
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// 工厂构造函数 - 返回单例实例
  factory VaultService({FlutterSecureStorage? secureStorage}) {
    _instance ??= VaultService._internal(secureStorage: secureStorage);
    return _instance!;
  }

  /// 重置单例（主要用于测试）
  static void reset() {
    _instance = null;
  }

  /// 全部条目（**含墓碑**，即已删除待同步的条目）
  ///
  /// 持久化与云端同步都必须用这个列表，否则删除无法传播到其他设备。
  /// UI 展示请用 [activeEntries]。
  List<VaultEntry> get entries => List.unmodifiable(_entries);

  /// 活跃条目（不含墓碑）——展示用
  List<VaultEntry> get activeEntries =>
      List.unmodifiable(_entries.where((e) => !e.isDeleted));

  /// 回收站内容（墓碑，按删除时间倒序）
  List<VaultEntry> get trashedEntries {
    final trashed = _entries.where((e) => e.isDeleted).toList()
      ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return List.unmodifiable(trashed);
  }

  /// 本地数据是否因版本过高被拒绝读取（此时禁止写入）
  bool get isSchemaVersionBlocked => _schemaVersionBlocked;

  /// 本次加载是否从写前备份恢复
  ///
  /// 为 true 说明主数据读不出来、已回退到上一次成功写入的副本。
  /// UI 应明确告知用户「请检查最近一次修改」，因为丢失的是最后一次写入的内容。
  bool get recoveredFromPrevious => _recoveredFromPrevious;

  /// 设置当前会话的加密密钥。
  ///
  /// 解锁后由认证模块注入，后续的读写、加密和解密都依赖该密钥。
  void setEncryptionKey(Uint8List key) {
    _encryptionKey = key;
  }

  /// 从安全存储加载整个保险库。
  ///
  /// 数据在存储层以 JSON 形式保存，敏感字段会被单独加密后再序列化。
  ///
  /// 主存储区读不出来时（解析/解密失败）自动回退到写前备份，
  /// 并把 [recoveredFromPrevious] 置为 true 供 UI 提示；
  /// 两份都读不出来才抛 [VaultException.decryptionFailed]。
  Future<void> loadVault() async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    _recoveredFromPrevious = false;
    _mainPayloadCorrupt = false;
    _schemaVersionBlocked = false;
    _blockedSchemaVersion = null;

    final raw = await _secureStorage.read(key: _keyVaultData);
    if (raw == null || raw.isEmpty) {
      _entries = [];
      return;
    }

    try {
      _entries = _decodePayload(raw);
      return;
    } on VaultException catch (e) {
      // 版本过高必须直接失败：绝不能回退到写前备份再继续写盘。
      // 那会把「新版本写入的数据」替换成一份旧快照，等于静默回滚数据（C2）。
      if (e.code == VaultException.codeSchemaVersionUnsupported) {
        _entries = [];
        _schemaVersionBlocked = true;
        _blockedSchemaVersion = _detectSchemaVersionOf(raw);
        rethrow;
      }
      final recovered = await _recoverFromPrevious(e);
      if (recovered != null) {
        _entries = recovered;
        return;
      }
      _entries = [];
      throw VaultException.decryptionFailed(e, StackTrace.current);
    } catch (e, stackTrace) {
      final recovered = await _recoverFromPrevious(e);
      if (recovered != null) {
        _entries = recovered;
        return;
      }
      // 解密/解析失败时不能把内存态当作可信数据：一旦后续 saveVault 执行，
      // 可能用不完整的内容覆盖持久化数据。抛出让调用方停止写入。
      _entries = [];
      throw VaultException.decryptionFailed(e, stackTrace);
    }
  }

  /// 主数据不可用时尝试写前备份；成功返回条目列表，否则返回 null。
  ///
  /// 写前备份同样是「更高版本」时照样拒绝：两份数据来自新版本就都读不懂，
  /// 不能因为主区坏了就退回一份同样读不懂的快照，更不能允许之后写回。
  Future<List<VaultEntry>?> _recoverFromPrevious(Object cause) async {
    final previous = await _secureStorage.read(key: _keyVaultDataPrev);
    if (previous == null || previous.isEmpty) return null;

    try {
      final entries = _decodePayload(previous);
      _recoveredFromPrevious = true;
      // 主区仍是坏的：在它被修好之前，不要用坏数据覆盖好备份
      _mainPayloadCorrupt = true;
      debugPrint('VaultService: 主数据不可用，已从写前备份恢复 ${entries.length} 条');
      return entries;
    } on VaultException catch (backupError) {
      if (backupError.code == VaultException.codeSchemaVersionUnsupported) {
        _entries = [];
        _schemaVersionBlocked = true;
        _blockedSchemaVersion =
            _detectSchemaVersionOf(previous) ?? _blockedSchemaVersion;
        rethrow;
      }
      debugPrint('VaultService: 写前备份不可用 ($cause): $backupError');
      return null;
    } catch (backupError) {
      debugPrint('VaultService: 写前备份不可用 ($cause): $backupError');
      return null;
    }
  }

  /// 序列化 + 字段级加密，得到可直接落盘的完整数据。
  ///
  /// 返回 (负载, 期望条目数)：写盘前会剔除超龄墓碑，因此回读校验必须
  /// 与「剔除之后」的条数比较，否则每一次过期的保存都会被误判为坏数据。
  (String, int) _encodePayload({DateTime? now}) {
    final retained = pruneExpiredTombstones(_entries, now: now);

    // 直接使用策略返回的加密 JSON 持久化；
    // 不能再经过 entry.toJson()，否则密文字段会被丢弃。
    final entriesJson = retained.map(_encryptEntry).toList();

    final payload = jsonEncode({
      'schemaVersion': currentSchemaVersion,
      'entries': entriesJson,
      'updatedAt': DateTime.now().toIso8601String(),
    });

    return (payload, retained.length);
  }

  /// 解析 + 解密落盘数据
  ///
  /// 版本闸门（ADR-006 §3.5 C2，fail-closed）：
  /// - 缺 `schemaVersion` → 视为 v1（旧的本地数据，无墓碑），按默认值读；
  /// - 高于 [currentSchemaVersion] → 抛
  ///   [VaultException.schemaVersionUnsupported]，**不尝试解析**。
  List<VaultEntry> _decodePayload(String payload) {
    final data = jsonDecode(payload) as Map<String, dynamic>;

    final version = data['schemaVersion'] as int? ?? 1;
    if (version > currentSchemaVersion) {
      throw VaultException.schemaVersionUnsupported(
        found: version,
        supported: currentSchemaVersion,
      );
    }

    // 先解密原始持久化 JSON（密文字段在这里），
    // 再按条目类型恢复具体模型，便于兼容不同字段结构。
    final entriesJson = data['entries'] as List<dynamic>;

    return entriesJson
        .map((e) => _decryptPersistedJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 尽力读出负载里的 `schemaVersion`（只解析明文头，不解密条目），
  /// 仅用于给用户一个准确的错误文案。
  int? _detectSchemaVersionOf(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) return data['schemaVersion'] as int?;
    } catch (_) {
      // 解析不出来就算了，错误文案退回默认值
    }
    return null;
  }

  /// 写前回读校验：确认刚序列化出的数据能被完整解析并解密。
  ///
  /// 这是「拒绝写入坏数据」的闸门——宁可本次保存失败，也不能把
  /// 无法读回的内容写进主存储区，否则下一次启动就是数据丢失。
  void _verifyPayload(String payload, int expectedCount) {
    final List<VaultEntry> decoded;
    try {
      decoded = _decodePayload(payload);
    } catch (e) {
      throw VaultException.writeVerificationFailed('回读失败 ($e)');
    }

    if (decoded.length != expectedCount) {
      throw VaultException.writeVerificationFailed(
        '条目数不一致：写入 $expectedCount 条，回读 ${decoded.length} 条',
      );
    }
  }

  /// 将当前内存中的保险库写回安全存储。
  ///
  /// 写入顺序（任一步失败都不会破坏主存储区）：
  /// 1. 序列化并**回读校验**，不合格直接放弃本次保存
  /// 2. 把当前主数据留作写前备份 `vault_data.prev`
  /// 3. 最后才写主存储区 `vault_data`
  Future<void> saveVault() async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    // 数据版本比本应用新时禁止写回：读不懂就不许覆盖（C2）
    if (_schemaVersionBlocked) {
      throw VaultException.schemaVersionUnsupported(
        found: _blockedSchemaVersion ?? currentSchemaVersion + 1,
        supported: currentSchemaVersion,
      );
    }

    final (payload, expectedCount) = _encodePayload();

    // 1) 写前校验：不合格就抛错，主存储区保持不变
    _verifyPayload(payload, expectedCount);

    // 2) 留存写前备份
    final previous = await _secureStorage.read(key: _keyVaultData);
    if (!_mainPayloadCorrupt && previous != null && previous.isNotEmpty) {
      // 主数据是好的：把它留作回退副本
      await _secureStorage.write(key: _keyVaultDataPrev, value: previous);
    } else {
      // 首次写入，或主数据曾损坏（旧的不可用）：
      // 用刚校验过的新数据兜底，保证 .prev 始终是一份可读的完整数据
      await _secureStorage.write(key: _keyVaultDataPrev, value: payload);
    }

    // 3) 最后写主存储区——放在最后，前面任何失败都不会动到它
    await _secureStorage.write(key: _keyVaultData, value: payload);
    _mainPayloadCorrupt = false;
  }

  /// 加密单个条目，返回可直接持久化的 JSON（敏感字段为密文）。
  Map<String, dynamic> _encryptEntry(VaultEntry entry) {
    final strategy = _encryptionStrategies[entry.type];
    if (_encryptionKey != null && strategy != null) {
      return strategy.encryptFields(entry, _encryptionKey!);
    }
    return entry.toJson();
  }

  /// 解密持久化 JSON 并重建条目对象。
  VaultEntry _decryptPersistedJson(Map<String, dynamic> json) {
    final strategy = _encryptionStrategies[entryTypeFromJson(json)];

    if (_encryptionKey != null && strategy != null) {
      // 直接解密原始持久化 JSON —— 密文字段只存在于这里。
      strategy.decryptFields(json, _encryptionKey!);
    }

    return parseVaultEntry(json);
  }

  /// 用新密钥重加密当前内存中的全部条目并持久化。
  ///
  /// 前置条件：内存态已经用**旧密钥**解开（明文条目在内存里）。
  /// 写盘失败时回滚服务层密钥，避免出现「磁盘是旧密钥、内存是新密钥」的不一致。
  Future<void> rekeyTo(Uint8List newKey) async {
    if (_encryptionKey == null) {
      throw VaultException.keyNotSet();
    }

    final previousKey = _encryptionKey;
    _encryptionKey = newKey;

    try {
      await saveVault();
    } catch (e) {
      _encryptionKey = previousKey;
      rethrow;
    }
  }

  /// 新增条目并刷新持久化数据。
  ///
  /// 模型不可变：这里生成刷新时间戳后的新实例入列，调用方持有的原实例不变。
  Future<String> addEntry(VaultEntry entry) async {
    final stamped = entry.withUpdatedTimestamp();
    _entries.add(stamped);
    await saveVault();
    return stamped.id;
  }

  /// 更新已有条目并刷新持久化数据。
  Future<void> updateEntry(VaultEntry entry) async {
    final index = _entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) {
      throw VaultException.notFound(entry.id);
    }

    _entries[index] = entry.withUpdatedTimestamp();
    await saveVault();
  }

  /// 删除指定条目（移入回收站）并刷新持久化数据。
  ///
  /// ADR-006 R3：删除**不是**从列表里抹掉，而是打上 `deletedAt` 墓碑
  /// 并刷新 `updatedAt`，让它作为一次「更新」参与同步；回收站 UI 可恢复。
  /// 墓碑本身也会在超过 [kTombstoneRetention] 后被物理清除。
  ///
  /// 条目不存在或已是墓碑时静默忽略（与旧的宽松语义一致），
  /// 避免重复删除把 `deletedAt` 越推越远、把回收站里的条目一直续期。
  Future<void> deleteEntry(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1 || _entries[index].isDeleted) return;

    _entries[index] = markEntryDeleted(_entries[index]);
    await saveVault();
  }

  /// 从回收站恢复条目并刷新持久化数据。
  ///
  /// 恢复同样刷新 `updatedAt`，才能盖过其他设备上可能存在的墓碑。
  Future<void> restoreEntry(String id) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index == -1 || !_entries[index].isDeleted) return;

    _entries[index] = clearEntryDeletion(_entries[index]);
    await saveVault();
  }

  /// 物理清除单个条目（回收站里的「彻底删除」，不可恢复）
  Future<void> purgeEntry(String id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length == before) return;

    await saveVault();
  }

  /// 清空回收站
  Future<int> purgeAllTrashed() async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.isDeleted);
    final removed = before - _entries.length;
    if (removed > 0) await saveVault();
    return removed;
  }

  /// 物理清除已超过保留期的墓碑（返回清除条数）。
  ///
  /// 注意：日常写入已经在 [_encodePayload] 里顺带剔除超龄墓碑，
  /// 这个方法是给「需要立刻回收」的场景（如回收站里的剩余天数显示为 0）用的。
  Future<int> purgeExpiredTombstones({DateTime? now}) async {
    final before = _entries.length;
    _entries = pruneExpiredTombstones(_entries, now: now);
    final removed = before - _entries.length;
    if (removed > 0) await saveVault();
    return removed;
  }

  /// 原子替换全部条目并持久化一次。
  ///
  /// 供恢复/导入流程使用，避免逐条增删导致每条都全量写盘。
  Future<void> replaceAllEntries(List<VaultEntry> newEntries) async {
    _entries = List.of(newEntries);
    await saveVault();
  }

  /// 获取单个条目。
  Future<VaultEntry?> getEntry(String id) async {
    for (final entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// 获取全部条目。
  Future<List<VaultEntry>> getAllEntries() async {
    return List.unmodifiable(_entries);
  }

  /// 切换收藏状态并持久化。
  ///
  /// 条目不存在时静默忽略（与旧语义一致）。
  Future<void> toggleFavorite(String entryId) async {
    final index = _entries.indexWhere((e) => e.id == entryId);
    if (index != -1) {
      _entries[index] =
          _entries[index].copyWith(isFavorite: !_entries[index].isFavorite);
      await saveVault();
    }
  }
}
