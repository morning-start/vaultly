import 'package:flutter/material.dart';

/// 错误状态组件
///
/// 当发生错误时显示的错误状态组件，支持重试操作
///
/// 参考文档: [保险库模块设计](wiki/03-模块设计/保险库模块.md) 第 7.1 节 - 代码实现映射
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final String? retryLabel;
  final VoidCallback? onRetryPressed;
  final IconData icon;
  final Widget? customAction;

  const ErrorState({
    super.key,
    this.title = '出错了',
    this.message,
    this.retryLabel = '重试',
    this.onRetryPressed,
    this.icon = Icons.error_outline,
    this.customAction,
  });

  /// 创建网络错误状态
  factory ErrorState.network({
    String? message,
    VoidCallback? onRetryPressed,
  }) {
    return ErrorState(
      title: '网络错误',
      message: message ?? '无法连接到服务器，请检查网络连接',
      retryLabel: '重试',
      onRetryPressed: onRetryPressed,
      icon: Icons.wifi_off_outlined,
    );
  }

  /// 创建加载错误状态
  factory ErrorState.load({
    String? message,
    VoidCallback? onRetryPressed,
  }) {
    return ErrorState(
      title: '加载失败',
      message: message ?? '无法加载数据，请稍后重试',
      retryLabel: '重新加载',
      onRetryPressed: onRetryPressed,
      icon: Icons.refresh_outlined,
    );
  }

  /// 创建认证错误状态
  factory ErrorState.auth({
    String? message,
    VoidCallback? onLoginPressed,
  }) {
    return ErrorState(
      title: '认证失败',
      message: message ?? '登录已过期，请重新登录',
      retryLabel: '重新登录',
      onRetryPressed: onLoginPressed,
      icon: Icons.lock_outline,
    );
  }

  /// 创建解密错误状态
  factory ErrorState.decrypt({
    String? message,
    VoidCallback? onRetryPressed,
  }) {
    return ErrorState(
      title: '解密失败',
      message: message ?? '无法解密数据，密码可能不正确',
      retryLabel: '重试',
      onRetryPressed: onRetryPressed,
      icon: Icons.no_encryption_outlined,
    );
  }

  /// 创建同步错误状态
  factory ErrorState.sync({
    String? message,
    VoidCallback? onRetryPressed,
  }) {
    return ErrorState(
      title: '同步失败',
      message: message ?? '无法同步数据，请检查同步配置',
      retryLabel: '重试',
      onRetryPressed: onRetryPressed,
      icon: Icons.sync_problem_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(76),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetryPressed != null || customAction != null) ...[
              const SizedBox(height: 24),
              customAction ??
                  OutlinedButton.icon(
                    onPressed: onRetryPressed,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryLabel!),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 小型错误提示组件
///
/// 用于在页面内显示小型错误提示
class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onActionPressed;
  final String? actionLabel;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onActionPressed,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withAlpha(128),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 14,
              ),
            ),
          ),
          if (actionLabel != null && onActionPressed != null)
            TextButton(
              onPressed: onActionPressed,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onErrorContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(
                Icons.close,
                color: colorScheme.onErrorContainer,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
