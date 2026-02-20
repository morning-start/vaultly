import 'dart:math';
import 'password_policy.dart';

/// 密码生成器
///
/// 参考文档: wiki/03-模块设计/保险库模块.md 第 3.2 节
/// 生成符合安全要求的随机密码
class PasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _symbols = r'!@#$%^&*()_+-=[]{}|;:,.<>?';

  /// 生成随机密码
  ///
  /// [length] 密码长度（默认 16）
  /// [includeUppercase] 包含大写字母
  /// [includeLowercase] 包含小写字母
  /// [includeNumbers] 包含数字
  /// [includeSymbols] 包含特殊字符
  /// [excludeChars] 排除的字符
  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
    String? excludeChars,
  }) {
    String chars = '';
    if (includeLowercase) chars += _lowercase;
    if (includeUppercase) chars += _uppercase;
    if (includeNumbers) chars += _numbers;
    if (includeSymbols) chars += _symbols;

    if (excludeChars != null) {
      for (var c in excludeChars.split('')) {
        chars = chars.replaceAll(c, '');
      }
    }

    if (chars.isEmpty) {
      chars = _lowercase;
    }

    final random = Random.secure();
    
    // 确保每种字符类型至少出现一次
    final passwordChars = <String>[];
    
    if (includeLowercase) {
      passwordChars.add(_lowercase[random.nextInt(_lowercase.length)]);
    }
    if (includeUppercase) {
      passwordChars.add(_uppercase[random.nextInt(_uppercase.length)]);
    }
    if (includeNumbers) {
      passwordChars.add(_numbers[random.nextInt(_numbers.length)]);
    }
    if (includeSymbols) {
      passwordChars.add(_symbols[random.nextInt(_symbols.length)]);
    }

    // 填充剩余长度
    while (passwordChars.length < length) {
      passwordChars.add(chars[random.nextInt(chars.length)]);
    }

    // 打乱顺序
    passwordChars.shuffle(random);

    return passwordChars.join();
  }

  /// 生成易读密码（排除容易混淆的字符）
  static String generateReadable({int length = 16}) {
    // 排除容易混淆的字符: 0, O, o, 1, l, I
    const readableLowercase = 'abcdefghijkmnpqrstuvwxyz';
    const readableUppercase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const readableNumbers = '23456789';

    final random = Random.secure();
    final passwordChars = <String>[
      readableLowercase[random.nextInt(readableLowercase.length)],
      readableUppercase[random.nextInt(readableUppercase.length)],
      readableNumbers[random.nextInt(readableNumbers.length)],
    ];

    final allChars = readableLowercase + readableUppercase + readableNumbers;
    while (passwordChars.length < length) {
      passwordChars.add(allChars[random.nextInt(allChars.length)]);
    }

    passwordChars.shuffle(random);
    return passwordChars.join();
  }

  /// 生成密码短语（ memorable password）
  static String generatePassphrase({int wordCount = 4}) {
    const words = [
      'apple', 'banana', 'cherry', 'date', 'elderberry', 'fig', 'grape',
      'honeydew', 'kiwi', 'lemon', 'mango', 'nectarine', 'orange', 'papaya',
      'quince', 'raspberry', 'strawberry', 'tangerine', 'ugli', 'vanilla',
      'watermelon', 'xigua', 'yam', 'zucchini', 'azure', 'blue', 'cyan',
      'diamond', 'emerald', 'fuchsia', 'gold', 'indigo', 'jade', 'khaki',
      'lime', 'magenta', 'navy', 'olive', 'purple', 'red', 'silver',
      'teal', 'violet', 'white', 'yellow', 'amber', 'bronze', 'copper',
      'forest', 'mountain', 'ocean', 'river', 'sky', 'sun', 'moon',
      'star', 'cloud', 'rain', 'snow', 'wind', 'fire', 'earth',
      'eagle', 'falcon', 'hawk', 'owl', 'raven', 'sparrow', 'wolf',
      'bear', 'deer', 'fox', 'lion', 'tiger', 'zebra', 'horse',
    ];

    final random = Random.secure();
    final selectedWords = <String>[];

    for (int i = 0; i < wordCount; i++) {
      selectedWords.add(words[random.nextInt(words.length)]);
    }

    // 添加随机数字
    final number = random.nextInt(100);
    selectedWords.add(number.toString().padLeft(2, '0'));

    return selectedWords.join('-');
  }

  /// 计算密码强度
  ///
  /// 使用 PasswordPolicy 中的算法
  static int calculateStrength(String password) {
    return PasswordPolicy.calculateStrength(password);
  }

  /// 获取强度标签
  static String getStrengthLabel(int strength) {
    return PasswordPolicy.getStrengthLabel(strength);
  }

  /// 获取强度颜色
  static String getStrengthColor(int strength) {
    return PasswordPolicy.getStrengthColor(strength);
  }

  /// 验证密码是否符合要求
  static bool meetsRequirements(
    String password, {
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSymbols,
  }) {
    if (includeLowercase && !password.contains(RegExp(r'[a-z]'))) return false;
    if (includeUppercase && !password.contains(RegExp(r'[A-Z]'))) return false;
    if (includeNumbers && !password.contains(RegExp(r'[0-9]'))) return false;
    if (includeSymbols &&
        !password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) {
      return false;
    }
    return true;
  }

  /// 生成 PIN 码
  static String generatePin({int length = 6}) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => random.nextInt(10).toString(),
    ).join();
  }

  /// 生成符合特定网站要求的密码
  static String generateForWebsite({
    required int minLength,
    required int maxLength,
    required bool requireUppercase,
    required bool requireLowercase,
    required bool requireNumbers,
    required bool requireSymbols,
    String? excludedChars,
  }) {
    final length = (minLength + maxLength) ~/ 2;
    return generate(
      length: length.clamp(minLength, maxLength),
      includeUppercase: requireUppercase,
      includeLowercase: requireLowercase,
      includeNumbers: requireNumbers,
      includeSymbols: requireSymbols,
      excludeChars: excludedChars,
    );
  }
}
