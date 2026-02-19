import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TOTPService {
  static const int _defaultDigits = 6;
  static const int _defaultPeriod = 30;

  String generateTOTP(String secret, {int digits = _defaultDigits, int period = _defaultPeriod}) {
    final counter = _getTimeCounter(period);
    return _generateHOTP(secret, counter, digits);
  }

  bool validateTOTP(String code, String secret, {int window = 1, int digits = _defaultDigits, int period = _defaultPeriod}) {
    if (code.length != digits) return false;
    
    final counter = _getTimeCounter(period);
    
    for (int i = -window; i <= window; i++) {
      final expectedCode = _generateHOTP(secret, counter + i, digits);
      if (expectedCode == code) {
        return true;
      }
    }
    
    return false;
  }

  TOTPConfig? parseOTPAuthURI(String uri) {
    try {
      if (!uri.startsWith('otpauth://totp/')) {
        return null;
      }

      final parsedUri = Uri.parse(uri);
      final path = parsedUri.path;
      final query = parsedUri.queryParameters;

      String? secret = query['secret'];
      if (secret == null || secret.isEmpty) return null;

      String issuer = query['issuer'] ?? '';
      String accountName = path.substring(1);

      if (issuer.isEmpty && accountName.contains(':')) {
        final parts = accountName.split(':');
        issuer = parts[0];
        accountName = parts[1];
      }

      final digits = int.tryParse(query['digits'] ?? '') ?? _defaultDigits;
      final period = int.tryParse(query['period'] ?? '') ?? _defaultPeriod;
      final algorithm = _parseAlgorithm(query['algorithm']);

      return TOTPConfig(
        secret: secret.toUpperCase(),
        issuer: issuer,
        accountName: accountName,
        digits: digits,
        period: period,
        algorithm: algorithm,
      );
    } catch (_) {
      return null;
    }
  }

  String generateOTPAuthURI(TOTPConfig config) {
    final params = <String, String>{
      'secret': config.secret,
      'issuer': config.issuer,
      'digits': config.digits.toString(),
      'period': config.period.toString(),
      'algorithm': _algorithmToString(config.algorithm),
    };

    return Uri(
      scheme: 'otpauth',
      host: 'totp',
      path: '/${config.issuer}:${config.accountName}',
      queryParameters: params,
    ).toString();
  }

  int getRemainingSeconds({int period = _defaultPeriod}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return period - (now % period);
  }

  int _getTimeCounter(int period) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now ~/ period;
  }

  String _generateHOTP(String secret, int counter, int digits) {
    final key = _base32Decode(secret);
    final counterBytes = _intToBytes(counter);
    
    final hmac = Hmac(sha1, key);
    final digest = hmac.convert(counterBytes);
    final hash = digest.bytes;
    
    final offset = hash[hash.length - 1] & 0x0F;
    final binary = ((hash[offset] & 0x7F) << 24) |
        ((hash[offset + 1] & 0xFF) << 16) |
        ((hash[offset + 2] & 0xFF) << 8) |
        (hash[offset + 3] & 0xFF);
    
    final otp = binary % _pow10(digits);
    return otp.toString().padLeft(digits, '0');
  }

  Uint8List _intToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      bytes[i] = value & 0xFF;
      value >>= 8;
    }
    return bytes;
  }

  Uint8List _base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final cleanInput = input.toUpperCase().replaceAll('=', '').replaceAll(' ', '');
    
    final output = <int>[];
    var buffer = 0;
    var bitsLeft = 0;
    
    for (int i = 0; i < cleanInput.length; i++) {
      final char = cleanInput[i];
      final value = alphabet.indexOf(char);
      if (value < 0) continue;
      
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      
      if (bitsLeft >= 8) {
        output.add((buffer >> (bitsLeft - 8)) & 0xFF);
        bitsLeft -= 8;
      }
    }
    
    return Uint8List.fromList(output);
  }

  int _pow10(int n) {
    int result = 1;
    for (int i = 0; i < n; i++) {
      result *= 10;
    }
    return result;
  }

  Algorithm _parseAlgorithm(String? algo) {
    switch (algo?.toUpperCase()) {
      case 'SHA256':
        return Algorithm.sha256;
      case 'SHA512':
        return Algorithm.sha512;
      default:
        return Algorithm.sha1;
    }
  }

  String _algorithmToString(Algorithm algo) {
    switch (algo) {
      case Algorithm.sha1:
        return 'SHA1';
      case Algorithm.sha256:
        return 'SHA256';
      case Algorithm.sha512:
        return 'SHA512';
    }
  }
}

class TOTPConfig {
  final String secret;
  final String issuer;
  final String accountName;
  final int digits;
  final int period;
  final Algorithm algorithm;

  TOTPConfig({
    required this.secret,
    required this.issuer,
    required this.accountName,
    this.digits = 6,
    this.period = 30,
    this.algorithm = Algorithm.sha1,
  });
}

enum Algorithm {
  sha1,
  sha256,
  sha512,
}
