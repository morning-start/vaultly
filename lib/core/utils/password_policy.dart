/// 密码策略
///
/// 参考文档: wiki/03-模块设计/认证模块.md 第 5.1 节
/// 定义主密码的复杂度要求和验证规则
class PasswordPolicy {
  // 长度要求
  static const int minLength = 8;
  static const int maxLength = 128;
  static const int recommendedLength = 12;

  // 字符类型要求
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireDigits = true;
  static const bool requireSpecialChars = false; // 建议但非强制

  // 特殊字符集
  static const String specialChars = r'!@#$%^&*()_+-=[]{}|;:,.<>?';

  /// 验证密码是否符合策略
  ///
  /// 返回验证结果，包含是否通过和失败原因列表
  static PasswordValidationResult validate(String password) {
    final failures = <String>[];

    // 检查长度
    if (password.length < minLength) {
      failures.add('密码长度至少为 $minLength 个字符');
    }
    if (password.length > maxLength) {
      failures.add('密码长度不能超过 $maxLength 个字符');
    }

    // 检查字符类型
    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      failures.add('密码必须包含至少一个大写字母');
    }
    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      failures.add('密码必须包含至少一个小写字母');
    }
    if (requireDigits && !password.contains(RegExp(r'[0-9]'))) {
      failures.add('密码必须包含至少一个数字');
    }
    if (requireSpecialChars &&
        !password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
      failures.add('密码必须包含至少一个特殊字符');
    }

    // 检查常见密码（简单检查）
    if (_isCommonPassword(password)) {
      failures.add('密码过于常见，请使用更复杂的密码');
    }

    // 检查重复字符
    if (_hasExcessiveRepeatedChars(password)) {
      failures.add('密码包含过多重复字符');
    }

    // 检查连续字符
    if (_hasSequentialChars(password)) {
      failures.add('密码包含连续字符序列（如 123、abc）');
    }

    return PasswordValidationResult(
      isValid: failures.isEmpty,
      failures: failures,
      strength: calculateStrength(password),
    );
  }

  /// 计算密码强度
  ///
  /// 返回 0-100 的分数
  /// 参考: wiki/保险库模块.md 第 6.2 节
  static int calculateStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    // 长度加分
    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 20;
    if (password.length >= 20) score += 10;

    // 字符类型加分
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
      score += 15;
    }

    // 额外加分
    if (password.length >= 12 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'))) {
      score += 10;
    }

    // 扣分项
    if (_isCommonPassword(password)) score -= 30;
    if (_hasExcessiveRepeatedChars(password)) score -= 10;
    if (_hasSequentialChars(password)) score -= 10;

    // 确保分数在 0-100 范围内
    return score.clamp(0, 100);
  }

  /// 获取强度标签
  static String getStrengthLabel(int strength) {
    if (strength < 20) return '非常弱';
    if (strength < 40) return '弱';
    if (strength < 60) return '中等';
    if (strength < 80) return '强';
    return '非常强';
  }

  /// 获取强度颜色
  static String getStrengthColor(int strength) {
    if (strength < 20) return 'red';
    if (strength < 40) return 'orange';
    if (strength < 60) return 'yellow';
    if (strength < 80) return 'lightGreen';
    return 'green';
  }

  /// 检查是否为常见密码
  static bool _isCommonPassword(String password) {
    final commonPasswords = {
      'password',
      '123456',
      '12345678',
      'qwerty',
      'abc123',
      'monkey',
      'letmein',
      'dragon',
      '111111',
      'baseball',
      'iloveyou',
      'trustno1',
      'sunshine',
      'princess',
      'admin',
      'welcome',
      'shadow',
      'ashley',
      'football',
      'jesus',
      'michael',
      'ninja',
      'mustang',
      'password1',
      '123456789',
      'adobe123',
      'admin123',
      'letmein1',
      'photoshop',
      '1234567',
      'master',
      'hello123',
      'freedom',
      'whatever',
      'qazwsx',
      '654321',
      'jordan23',
      'harley',
      'password123',
      'p@ssw0rd',
      'passw0rd',
      'qwerty123',
      'lovely',
      'michael1',
      'joshua',
      'maggie',
      'buster',
      'daniel',
      'andrew',
      'hello',
      'access',
      'love',
      'pussy',
      '696969',
      'qwertyuiop',
      '123321',
      'matthew',
      'amanda',
      'orange',
      'testing',
      'test123',
    };

    final lowerPassword = password.toLowerCase();
    return commonPasswords.contains(lowerPassword) ||
        commonPasswords.any((common) => lowerPassword.contains(common));
  }

  /// 检查是否有过多重复字符
  static bool _hasExcessiveRepeatedChars(String password) {
    // 检查是否有 3 个以上相同字符连续出现
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  /// 检查是否有连续字符序列
  static bool _hasSequentialChars(String password) {
    const sequences = [
      'abcdefghijklmnopqrstuvwxyz',
      'zyxwvutsrqponmlkjihgfedcba',
      '0123456789',
      '9876543210',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ];

    final lowerPassword = password.toLowerCase();
    for (final seq in sequences) {
      for (int i = 0; i < seq.length - 2; i++) {
        final pattern = seq.substring(i, i + 3);
        if (lowerPassword.contains(pattern)) {
          return true;
        }
      }
    }
    return false;
  }

  /// 生成密码建议
  static List<String> generateSuggestions(String password) {
    final suggestions = <String>[];

    if (password.length < 12) {
      suggestions.add('建议密码长度至少 12 个字符');
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      suggestions.add('添加大写字母');
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      suggestions.add('添加小写字母');
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      suggestions.add('添加数字');
    }
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
      suggestions.add('添加特殊字符增强安全性');
    }

    return suggestions;
  }
}

/// 密码验证结果
class PasswordValidationResult {
  final bool isValid;
  final List<String> failures;
  final int strength;

  PasswordValidationResult({
    required this.isValid,
    required this.failures,
    required this.strength,
  });

  /// 获取第一个错误信息
  String? get firstError => failures.isNotEmpty ? failures.first : null;

  /// 获取所有错误信息
  String get allErrors => failures.join('\n');
}
