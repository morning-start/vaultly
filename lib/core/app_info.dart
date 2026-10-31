/// 应用版本信息
///
/// 版本号在构建时注入（见 `.github/workflows/build-android.yml` 的
/// `--dart-define=APP_VERSION=...`，取值就是触发构建的标签名，如 `v4.0.1`），
/// 与同一处传入的 `--build-name` 保持一致。
///
/// 这样做的原因：曾经在设置页硬编码 `2.4.1`，实际发到 4.0.0 时页面仍显示
/// 2.4.1，用户看到的版本号是假的。版本号只能有一个来源——构建时的标签。
class AppInfo {
  const AppInfo._();

  /// 未注入时显示开发版标识，而不是一个会过期的假版本号
  static const String devVersion = '开发版';

  /// 当前构建的版本标识
  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: devVersion,
  );

  /// 是否为注入了版本号的正规构建
  static bool get isReleaseBuild => version != devVersion;
}
