import 'package:flutter/material.dart';
import '../utils/constants/savings_tips.dart';
import '../utils/constants/text_strings.dart';
import '../utils/theme/text_theme.dart';

class SavingsTipsPage extends StatelessWidget {
  const SavingsTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Group tips by category
    final Map<String, List<SavingsTip>> categorizedTips = {};
    for (var tip in SavingsTipsData.tips) {
      if (!categorizedTips.containsKey(tip.category)) {
        categorizedTips[tip.category] = [];
      }
      categorizedTips[tip.category]!.add(tip);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings Tips'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Smart Ways to Save',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore these tips to improve your savings habits',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Display tips by category
            ...categorizedTips.entries.map((entry) =>
                _buildCategorySection(context, entry.key, entry.value)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
      BuildContext context, String category, List<SavingsTip> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            category,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ...tips.map((tip) => _buildTipCard(context, tip)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTipCard(BuildContext context, SavingsTip tip) {
    // Convert hex color to Color object
    Color backgroundColor = _hexToColor(tip.backgroundColor);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: backgroundColor.withValues(alpha: 0.2),
                  radius: 24,
                  child: Icon(
                    _getIconData(tip.iconName),
                    color: backgroundColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    tip.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tip.description,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to convert hex color string to Color
  Color _hexToColor(String hexString) {
    final hexColor = hexString.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'calculate':
        return Icons.calculate;
      case 'autorenew':
        return Icons.autorenew;
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      case 'account_balance':
        return Icons.account_balance;
      case 'find_in_page':
        return Icons.find_in_page;
      case 'savings':
        return Icons.savings;
      case 'trending_up':
        return Icons.trending_up;
      case 'favorite':
        return Icons.favorite;
      default:
        return Icons.lightbulb_outline;
    }
  }
}
