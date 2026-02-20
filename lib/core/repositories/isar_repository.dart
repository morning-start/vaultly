import 'local_storage_repository.dart';

/// 存储仓库（兼容旧接口）
///
/// 现在使用 LocalStorageRepository 实现
class IsarRepository {
  static LocalStorageRepository? _instance;

  /// 获取存储实例
  static Future<LocalStorageRepository> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }
    _instance = await LocalStorageRepository.getInstance();
    return _instance!;
  }

  /// 关闭存储（现在不需要特殊处理）
  static Future<void> close() async {
    _instance = null;
  }

  /// 检查是否已初始化
  static bool get isInitialized => LocalStorageRepository.isInitialized;
}
