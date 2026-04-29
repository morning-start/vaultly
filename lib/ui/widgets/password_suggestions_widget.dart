import 'package:flutter/material.dart';
import '../../core/utils/password_policy.dart';

class PasswordSuggestionsWidget extends StatelessWidget {
  final String? title;
  final List<String> suggestions;

  const PasswordSuggestionsWidget({
    super.key,
    this.title,
    required this.suggestions,
  });

  factory PasswordSuggestionsWidget.policy({
    Key? key,
    String? title,
  }) {
    return PasswordSuggestionsWidget(
      key: key,
      title: title ?? '密码要求',
      suggestions: _getDefaultPolicySuggestions(),
    );
  }

  static List<String> _getDefaultPolicySuggestions() {
    return [
      '至少 ${PasswordPolicy.minLength} 个字符（推荐 ${PasswordPolicy.recommendedLength} 个）',
      if (PasswordPolicy.requireUppercase) '包含大写字母 (A-Z)',
      if (PasswordPolicy.requireLowercase) '包含小写字母 (a-z)',
      if (PasswordPolicy.requireDigits) '包含数字 (0-9)',
      if (PasswordPolicy.requireSpecialChars) '包含特殊字符 (!@#\$%)',
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
            ],
            ...suggestions.map((suggestion) => _buildSuggestionItem(context, suggestion)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
