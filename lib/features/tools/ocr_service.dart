import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? cardNumber;
  final String? cardHolderName;
  final int? expiryMonth;
  final int? expiryYear;

  OcrResult({
    this.cardNumber,
    this.cardHolderName,
    this.expiryMonth,
    this.expiryYear,
  });

  bool get hasAnyData =>
      cardNumber != null ||
      cardHolderName != null ||
      expiryMonth != null;
}

class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// 从图库选择图片并识别银行卡信息
  Future<OcrResult> scanFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return OcrResult();
    return _processImage(File(image.path));
  }

  /// 拍照识别银行卡信息
  Future<OcrResult> scanFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return OcrResult();
    return _processImage(File(image.path));
  }

  /// 处理图片进行 OCR 识别
  Future<OcrResult> _processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText =
          await _recognizer.processImage(inputImage);

      String? cardNumber;
      String? cardHolderName;
      int? expiryMonth;
      int? expiryYear;

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();

          // 尝试提取银行卡号（13-19位数字，可能含空格/连字符）
          cardNumber ??= _extractCardNumber(text);

          // 尝试提取有效期（MM/YY 或 MM/YYYY）
          if (expiryMonth == null || expiryYear == null) {
            final expiry = _extractExpiryDate(text);
            if (expiry != null) {
              expiryMonth = expiry.$1;
              expiryYear = expiry.$2;
            }
          }

          // 尝试提取持卡人姓名（全大写英文字母，2-4个词）
          cardHolderName ??= _extractCardHolderName(text);
        }
      }

      return OcrResult(
        cardNumber: cardNumber,
        cardHolderName: cardHolderName,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
      );
    } catch (e) {
      return OcrResult();
    }
  }

  /// 从文本中提取银行卡号
  String? _extractCardNumber(String text) {
    // 移除所有空格和连字符
    final cleaned = text.replaceAll(RegExp(r'[\s\-]'), '');

    // 银行卡号通常为 13-19 位纯数字
    if (RegExp(r'^\d{13,19}$').hasMatch(cleaned)) {
      return cleaned;
    }

    // 尝试匹配分组格式的卡号，如 "1234 5678 9012 3456"
    final groupedMatch = RegExp(
      r'(\d{4}\s?\d{4}\s?\d{4}\s?\d{4,7})',
    ).firstMatch(text);

    if (groupedMatch != null) {
      final number = groupedMatch.group(1)!.replaceAll(RegExp(r'\s'), '');
      if (RegExp(r'^\d{13,19}$').hasMatch(number)) {
        return number;
      }
    }

    return null;
  }

  /// 从文本中提取有效期
  (int, int)? _extractExpiryDate(String text) {
    // 匹配 MM/YY 或 MM/YYYY 格式
    final match = RegExp(
      r'(0[1-9]|1[0-2])\s*[/\\]\s*(\d{2,4})',
    ).firstMatch(text);

    if (match != null) {
      final month = int.tryParse(match.group(1)!);
      var year = int.tryParse(match.group(2)!);
      if (month != null && year != null) {
        if (year < 100) {
          year += 2000;
        }
        if (month >= 1 && month <= 12 && year >= 2020 && year <= 2100) {
          return (month, year);
        }
      }
    }
    return null;
  }

  /// 从文本中提取持卡人姓名
  String? _extractCardHolderName(String text) {
    // 持卡人姓名通常是大写英文字母，2-3个词
    final match = RegExp(r'^[A-Z\s\.]{3,40}$').firstMatch(text);
    if (match != null) {
      final name = match.group(0)!.trim();
      final words = name.split(RegExp(r'\s+'));
      if (words.length >= 2 && words.length <= 4) {
        return name;
      }
    }
    return null;
  }

  void dispose() {
    _recognizer.close();
  }
}
