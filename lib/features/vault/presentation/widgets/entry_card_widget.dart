import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/vault_entry.dart';
import 'entry_type_helper.dart';
import '../../../../ui/theme/tokens.dart';

class EntryCardWidget extends StatefulWidget {
  final VaultEntry entry;
  final VoidCallback onTap;

  const EntryCardWidget({
    super.key,
    required this.entry,
    required this.onTap,
  });

  @override
  State<EntryCardWidget> createState() => _EntryCardWidgetState();
}

class _EntryCardWidgetState extends State<EntryCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.animFast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final typeColor = EntryTypeHelper.getColor(widget.entry.type);
    final typeName = EntryTypeHelper.getName(widget.entry.type);

    final tagText = widget.entry.tags.isNotEmpty
        ? widget.entry.tags.take(3).join(' · ')
        : typeName;
    final timeText = DateFormat('MM-dd HH:mm').format(widget.entry.updatedAt);

    return ScaleAnimatedWidget(
      animation: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.spaceS),
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppTokens.animFast,
            decoration: BoxDecoration(
              color: _isPressed
                  ? colorScheme.surfaceContainerLow
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusL),
              border: Border.all(
                color: _isPressed
                    ? typeColor.withAlpha(80)
                    : colorScheme.outlineVariant.withAlpha(60),
                width: _isPressed ? 1.5 : 1,
              ),
              boxShadow: _isPressed
                  ? AppTokens.cardShadow(typeColor, opacity: 0.05)
                  : AppTokens.cardShadow(colorScheme.outline, opacity: 0.04),
            ),
            child: Row(
              children: [
                // 左侧渐变装饰条
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        typeColor,
                        typeColor.withAlpha(140),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTokens.radiusL),
                      bottomLeft: Radius.circular(AppTokens.radiusL),
                    ),
                  ),
                ),
                // 类型徽章
                Container(
                  width: AppTokens.iconBadgeSize,
                  height: AppTokens.iconBadgeSize,
                  margin: const EdgeInsets.all(AppTokens.spaceM),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        typeColor.withAlpha(50),
                        typeColor.withAlpha(25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusM),
                  ),
                  child: Icon(
                    EntryTypeHelper.getIcon(widget.entry.type),
                    color: typeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceM),
                // 标题与副标题
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTokens.spaceM,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: AppTokens.spaceXS),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                tagText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                      ' · $timeText',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant.withAlpha(150),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceS),
                // 收藏星标
                AnimatedSwitcher(
                  duration: AppTokens.animNormal,
                  child: Icon(
                    widget.entry.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    key: ValueKey(widget.entry.isFavorite),
                    size: 24,
                    color: widget.entry.isFavorite
                        ? const Color(0xFFF59E0B)
                        : colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceM),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScaleAnimatedWidget extends AnimatedWidget {
  final Widget child;
  final Animation<double> animation;

  const ScaleAnimatedWidget({
    super.key,
    required this.animation,
    required this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: animation.value,
      child: child,
    );
  }
}
