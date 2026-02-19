import 'dart:math';

class PasswordGenerator {
  static const String _lowercase = 'abcdefghijklmnopqrstuvwxyz';
  static const String _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _numbers = '0123456789';
  static const String _symbols = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

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
    final password = List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    if (!_meetsRequirements(
      password,
      includeUppercase: includeUppercase,
      includeLowercase: includeLowercase,
      includeNumbers: includeNumbers,
      includeSymbols: includeSymbols,
    )) {
      return generate(
        length: length,
        includeUppercase: includeUppercase,
        includeLowercase: includeLowercase,
        includeNumbers: includeNumbers,
        includeSymbols: includeSymbols,
        excludeChars: excludeChars,
      );
    }

    return password;
  }

  static bool _meetsRequirements(
    String password, {
    required bool includeUppercase,
    required bool includeLowercase,
    required bool includeNumbers,
    required bool includeSymbols,
  }) {
    if (includeLowercase && !password.contains(RegExp(r'[a-z]'))) return false;
    if (includeUppercase && !password.contains(RegExp(r'[A-Z]'))) return false;
    if (includeNumbers && !password.contains(RegExp(r'[0-9]'))) return false;
    if (includeSymbols && !password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) return false;
    return true;
  }

  static int calculateStrength(String password) {
    if (password.isEmpty) return 0;

    int score = 0;

    if (password.length >= 8) score += 10;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 20;

    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score += 15;

    if (_isCommonPassword(password)) score -= 30;
    if (_hasRepeatingChars(password)) score -= 10;
    if (_hasSequentialChars(password)) score -= 10;

    return score.clamp(0, 100);
  }

  static String getStrengthLabel(int strength) {
    if (strength < 20) return '非常弱';
    if (strength < 40) return '弱';
    if (strength < 60) return '中等';
    if (strength < 80) return '强';
    return '非常强';
  }

  static bool _isCommonPassword(String password) {
    const commonPasswords = [
      'password', '123456', 'qwerty', 'abc123', 'letmein',
      'welcome', 'admin', 'login', 'passw0rd', '1234567890',
    ];
    return commonPasswords.contains(password.toLowerCase());
  }

  static bool _hasRepeatingChars(String password) {
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  static bool _hasSequentialChars(String password) {
    const sequences = ['123', 'abc', 'xyz', 'qwerty', 'asdf'];
    final lower = password.toLowerCase();
    for (final seq in sequences) {
      if (lower.contains(seq)) return true;
    }
    return false;
  }
}
