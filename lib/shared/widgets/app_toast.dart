import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';

/// 轻量成功反馈
///
/// 取代复制类操作的 SnackBar：底部浮动、图标+文字、1.6s 自动消失、
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
        icon: icon ?? Icons.check_circle_rounded,
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

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96),
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: AppTokens.animFast,
            curve: AppTokens.easeStandard,
            child: AnimatedSlide(
              offset: _visible ? Offset.zero : const Offset(0, 0.3),
              duration: AppTokens.animFast,
              curve: AppTokens.easeStandard,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceL,
                    vertical: AppTokens.spaceM,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.inverseSurface,
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusStadium),
                    boxShadow: AppTokens.cardShadow(Colors.black, opacity: 0.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon,
                          size: 18, color: colorScheme.onInverseSurface),
                      const SizedBox(width: AppTokens.spaceS),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: colorScheme.onInverseSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
