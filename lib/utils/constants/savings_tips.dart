// This file contains savings tips data for the financial education page

class SavingsTip {
  final String id;
  final String title;
  final String description;
  final String category; // Beginner, Intermediate, Advanced
  final String iconName; // Name of the icon to display
  final String backgroundColor; // Hex color code for the background

  const SavingsTip({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.iconName,
    required this.backgroundColor,
  });
}

class SavingsTipsData {
  static const List<SavingsTip> tips = [
    // Beginner Tips
    SavingsTip(
      id: 'tip1',
      title: '50/30/20 Rule',
      description:
          'Allocate 50% of your income to needs, 30% to wants, and 20% to savings and debt repayment.',
      category: 'Beginner',
      iconName: 'calculate',
      backgroundColor: '#4CAF50', // Green
    ),
    SavingsTip(
      id: 'tip2',
      title: 'Automate Savings',
      description:
          'Set up automatic transfers to your savings account on payday to save before you spend.',
      category: 'Beginner',
      iconName: 'autorenew',
      backgroundColor: '#2196F3', // Blue
    ),
    SavingsTip(
      id: 'tip3',
      title: '24-Hour Rule',
      description:
          'Wait 24 hours before making non-essential purchases to avoid impulse buying.',
      category: 'Beginner',
      iconName: 'hourglass_empty',
      backgroundColor: '#FFC107', // Amber
    ),

    // Intermediate Tips
    SavingsTip(
      id: 'tip4',
      title: 'Zero-Based Budgeting',
      description:
          'Assign every dollar of income to a specific category until you reach zero, ensuring all money has a purpose.',
      category: 'Intermediate',
      iconName: 'account_balance',
      backgroundColor: '#9C27B0', // Purple
    ),
    SavingsTip(
      id: 'tip5',
      title: 'Expense Audit',
      description:
          'Review all subscriptions and recurring expenses quarterly to eliminate unused services.',
      category: 'Intermediate',
      iconName: 'find_in_page',
      backgroundColor: '#FF5722', // Deep Orange
    ),

    // Advanced Tips
    SavingsTip(
      id: 'tip6',
      title: 'Pay Yourself First',
      description:
          'Treat savings as a non-negotiable expense by setting aside money for financial goals before other expenses.',
      category: 'Advanced',
      iconName: 'savings',
      backgroundColor: '#3F51B5', // Indigo
    ),
    SavingsTip(
      id: 'tip7',
      title: 'Multiple Income Streams',
      description:
          'Develop side hustles or passive income sources to accelerate your savings goals.',
      category: 'Advanced',
      iconName: 'trending_up',
      backgroundColor: '#E91E63', // Pink
    ),
    SavingsTip(
      id: 'tip8',
      title: 'Value-Based Spending',
      description:
          'Align your spending with your personal values to ensure your money goes toward what truly matters to you.',
      category: 'Advanced',
      iconName: 'favorite',
      backgroundColor: '#009688', // Teal
    ),
  ];
}
