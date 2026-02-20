import 'package:flutter/material.dart';

/// 空状态占位组件
///
/// 当列表为空或没有数据时显示的占位组件
///
/// 参考文档: [保险库模块设计](wiki/03-模块设计/保险库模块.md) 第 7.1 节 - 代码实现映射
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Widget? customAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionPressed,
    this.customAction,
  });

  /// 创建保险库空状态
  factory EmptyState.vault({
    VoidCallback? onAddPressed,
  }) {
    return EmptyState(
      icon: Icons.shield_outlined,
      title: '保险库为空',
      subtitle: '还没有保存任何条目，点击添加按钮开始',
      actionLabel: '添加条目',
      onActionPressed: onAddPressed,
    );
  }

  /// 创建搜索结果空状态
  factory EmptyState.search({
    String query = '',
    VoidCallback? onClearPressed,
  }) {
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: '未找到结果',
      subtitle: query.isEmpty ? '请输入搜索关键词' : '没有找到包含 "$query" 的条目',
      actionLabel: query.isNotEmpty ? '清除搜索' : null,
      onActionPressed: onClearPressed,
    );
  }

  /// 创建收藏空状态
  factory EmptyState.favorites({
    VoidCallback? onBrowsePressed,
  }) {
    return EmptyState(
      icon: Icons.favorite_border_outlined,
      title: '没有收藏',
      subtitle: '收藏条目后会在这里显示',
      actionLabel: '浏览条目',
      onActionPressed: onBrowsePressed,
    );
  }

  /// 创建标签空状态
  factory EmptyState.tags({
    VoidCallback? onAddPressed,
  }) {
    return EmptyState(
      icon: Icons.label_outlined,
      title: '没有标签',
      subtitle: '为条目添加标签以便分类管理',
      actionLabel: '添加标签',
      onActionPressed: onAddPressed,
    );
  }

  /// 创建同步空状态
  factory EmptyState.sync({
    VoidCallback? onSyncPressed,
  }) {
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: '未配置同步',
      subtitle: '配置 WebDAV 同步以备份您的数据',
      actionLabel: '配置同步',
      onActionPressed: onSyncPressed,
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
                color: colorScheme.primaryContainer.withAlpha(76),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: colorScheme.primary,
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
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null || customAction != null) ...[
              const SizedBox(height: 24),
              customAction ??
                  FilledButton.icon(
                    onPressed: onActionPressed,
                    icon: const Icon(Icons.add),
                    label: Text(actionLabel!),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
