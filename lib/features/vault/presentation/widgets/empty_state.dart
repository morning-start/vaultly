import 'package:flutter/material.dart';
import '../../../../ui/theme/tokens.dart';

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

  factory EmptyState.vault({VoidCallback? onAddPressed}) {
    return EmptyState(
      icon: Icons.shield_outlined,
      title: '保险库为空',
      subtitle: '还没有保存任何条目，点击添加按钮开始',
      actionLabel: '添加条目',
      onActionPressed: onAddPressed,
    );
  }

  factory EmptyState.search({String query = '', VoidCallback? onClearPressed}) {
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: '未找到结果',
      subtitle: query.isEmpty ? '请输入搜索关键词' : '没有找到包含 "$query" 的条目',
      actionLabel: query.isNotEmpty ? '清除搜索' : null,
      onActionPressed: onClearPressed,
    );
  }

  factory EmptyState.favorites({VoidCallback? onBrowsePressed}) {
    return EmptyState(
      icon: Icons.favorite_border_outlined,
      title: '没有收藏',
      subtitle: '收藏条目后会在这里显示',
      actionLabel: '浏览条目',
      onActionPressed: onBrowsePressed,
    );
  }

  factory EmptyState.tags({VoidCallback? onAddPressed}) {
    return EmptyState(
      icon: Icons.label_outlined,
      title: '没有标签',
      subtitle: '为条目添加标签以便分类管理',
      actionLabel: '添加标签',
      onActionPressed: onAddPressed,
    );
  }

  factory EmptyState.sync({VoidCallback? onSyncPressed}) {
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标容器（渐变背景）
            Container(
              width: AppTokens.stateIconContainer,
              height: AppTokens.stateIconContainer,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withAlpha(isDark ? 180 : 140),
                    colorScheme.primaryContainer.withAlpha(isDark ? 80 : 50),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: AppTokens.cardShadow(
                  colorScheme.primary,
                  opacity: 0.08,
                ),
              ),
              child: Icon(
                icon,
                size: AppTokens.stateIconSize,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXL),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTokens.spaceS),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null || customAction != null) ...[
              const SizedBox(height: AppTokens.spaceXL),
              customAction ??
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radiusM),
                      gradient: AppTokens.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: onActionPressed,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(actionLabel!),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceXL,
                          vertical: AppTokens.spaceM,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
