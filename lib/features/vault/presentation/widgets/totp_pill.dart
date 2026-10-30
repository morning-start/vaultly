import 'dart:async';

import 'package:flutter/material.dart';

import '../../../tools/totp_service.dart';
import '../../../../ui/theme/tokens.dart';
import '../../../../ui/theme/vaultly_colors.dart';

/// 列表行尾的 TOTP 迷你胶囊
///
/// 对齐原型 `.totp-pill`：主色浅底、等宽字号、左侧 30 秒环形倒计时。
/// 每秒刷新一次；密钥无效时静默隐藏，不影响列表渲染。
class TotpPill extends StatefulWidget {
  final String secret;

  const TotpPill({super.key, required this.secret});

  @override
  State<TotpPill> createState() => _TotpPillState();
}

class _TotpPillState extends State<TotpPill> {
  static final _service = TOTPService();

  Timer? _timer;
  String _code = '';
  int _remaining = 30;
  bool _valid = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(_refresh),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    try {
      _code = _service.generateTOTP(widget.secret);
      _remaining = _service.getRemainingSeconds();
      _valid = true;
    } catch (_) {
      _valid = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_valid || _code.length != 6) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 6, right: 10),
      decoration: BoxDecoration(
        color: colorScheme.primarySoft,
        borderRadius: BorderRadius.circular(AppTokens.radiusStadium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: _remaining / 30,
              strokeWidth: 2.5,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withAlpha(60),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_code.substring(0, 3)} ${_code.substring(3)}',
            style: TextStyle(
              fontFamily: AppTokens.monoFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
