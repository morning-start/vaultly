import 'package:flutter/material.dart';
import '../../ui/theme/tokens.dart';

/// 等宽文本
///
/// 用于一切机密值（密码 / TOTP / 卡号 / 密钥），
/// `0/O`、`1/l/I` 清晰可辨。
class MonoText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool selectable;

  const MonoText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final effective = (style ?? const TextStyle()).copyWith(
      fontFamily: AppTokens.monoFamily,
      fontFamilyFallback: const ['Consolas', 'Menlo', 'monospace'],
    );

    if (selectable) {
      return SelectableText(
        data,
        style: effective,
        maxLines: maxLines,
        textAlign: textAlign,
      );
    }

    return Text(
      data,
      style: effective,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
