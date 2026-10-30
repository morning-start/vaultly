import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/theme/vaultly_colors.dart';

/// 轻量成功反馈（原型 `.toast`）
///
/// 底部胶囊、玻璃模糊底 + 强描边、accent 勾选图标，1.6s 自动消失，
/// 不抢占焦点、不打断输入。错误/异步任务结果仍走 SnackBar。
class AppToast {
  AppToast._();

  static OverlayEntry? _current;

  /// 显示轻量提示
  static void show(BuildContext context, String message, {IconData? icon}) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _current = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        icon: icon ?? Icons.check_rounded,
        onDismissed: () => dismiss(),
      ),
    );
    overlay.insert(_current!);
  }

  /// 立即关闭当前提示
  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final VoidCallback onDismissed;

  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.onDismissed,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _visible = false);
      Future.delayed(AppTokens.animNormal, widget.onDismissed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: 118 + bottomInset),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: AppTokens.animFast,
          curve: AppTokens.easeStandard,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, 0.3),
            duration: AppTokens.animFast,
            curve: AppTokens.easeStandard,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.toastSurface.withAlpha(245),
                    borderRadius: BorderRadius.circular(
                      AppTokens.radiusStadium,
                    ),
                    border: Border.all(color: colorScheme.hairlineStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, size: 16, color: colorScheme.accent),
                      const SizedBox(width: AppTokens.spaceS),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(
                          widget.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
