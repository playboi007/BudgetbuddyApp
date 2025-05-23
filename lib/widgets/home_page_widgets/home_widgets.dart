import 'package:budgetbuddy_app/provider/category_provider.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_type_dialog.dart';
import 'package:budgetbuddy_app/widgets/category widgets/category_form_dialog.dart';
import 'package:budgetbuddy_app/Mobile%20UI/notification_screen.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';
import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:budgetbuddy_app/data models/budget_models.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:budgetbuddy_app/provider/transaction_provider.dart';
import 'package:budgetbuddy_app/provider/notification_provider.dart';
import 'package:budgetbuddy_app/Mobile UI/category_report_page.dart';
import 'package:budgetbuddy_app/Mobile UI/transaction_calendar_page.dart';

const _loadingIndicator = Center(child: CircularProgressIndicator());
const _noTransactionsWidget = Center(child: Text(TextStrings.noTransactions));

class BalanceAndCategories extends StatefulWidget {
  const BalanceAndCategories({super.key});

  @override
  BalanceAndCategoriesState createState() => BalanceAndCategoriesState();
}

class BalanceAndCategoriesState extends State<BalanceAndCategories> {
  // Cache calculations
  static double _lastTotalAmount = 0;
  static int _lastCategoryCount = 0;
  static int _lastUpdateTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CategoryProvider.ensureInitialized(context);
    });
  }

  void _updateCachedValues(List<BudgetCategory> categories) {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Only recalculate every 2 seconds
    if (now - _lastUpdateTime < 2000) return;

    _lastTotalAmount = categories.fold(0, (sum, cat) => sum + cat.amount);
    _lastCategoryCount = categories.length;
    _lastUpdateTime = now;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Card(
            color: Appcolors.blue600,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final categories = provider.categories;
        _updateCachedValues(categories);

        // Use cached values instead of recalculating
        final totalAmount = _lastTotalAmount;
        final categoryCount = _lastCategoryCount;

        if (provider.error != null) {
          return Card(
            color: Appcolors.blue600,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Appcolors.white, size: 32),
                    const SizedBox(height: 8),
                    Text('Error loading categories',
                        style: const TextStyle(color: Appcolors.white)),
                    TextButton(
                      onPressed: () {
                        provider.loadCategories();
                      },
                      child: const Text('Retry',
                          style: TextStyle(color: Appcolors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: Card(
            color: Appcolors.blue600,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance Section
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 0, 0),
                              child: const Text(
                                TextStrings.balance,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Appcolors.textWhite54,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ksh ${totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Appcolors.textWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Categories Section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 0, 20, 0),
                            child: const Text(
                              TextStrings.categories,
                              style: TextStyle(
                                fontSize: 16,
                                color: Appcolors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(30, 0, 0, 0),
                            child: Text(
                              categoryCount.toString(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Appcolors.textWhite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                    child: ElevatedButton(
                      onPressed: () {
                        // Button action
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Appcolors.white,
                        foregroundColor: Appcolors.blue600,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
                        child: const Text(TextStrings.allocateFunds),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

//userInfo widget
class UserAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String name;

  const UserAppbar({
    super.key,
    required this.name,
  });

  static const Map<int, String> _messages = {
    5: 'Good Morning!',
    12: 'Good Afternoon!',
    17: 'Good Evening!',
    22: 'lovely night!',
  };

  static String _cachedGreeting = '';
  static int _lastCalculatedHour = -1;

  String _getGreeting() {
    final now = DateTime.now();
    if (now.hour != _lastCalculatedHour) {
      _lastCalculatedHour = now.hour;
      _cachedGreeting = _calculateGreeting();
    }
    return _cachedGreeting;
  }

  String _calculateGreeting() {
    final currentHour = DateTime.now().hour;
    final hours = _messages.keys.toList()..sort();
    for (int i = 0; i < hours.length; i++) {
      final startHour = hours[i];
      final endHour = i < hours.length - 1 ? hours[i + 1] : 24;
      if (currentHour >= startHour && currentHour < endHour) {
        return _messages[startHour]!;
      }
    }
    return _messages.values.first;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        // Use cached greeting
        final greeting = _getGreeting();
        return AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 12.0),
                child: Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Appcolors.blue100,
                    child: const Icon(
                      Icons.person,
                      color: Appcolors.blue,
                      size: 24,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: TtextTheme.lightText.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      name,
                      style: TtextTheme.lightText.bodyLarge,
                    )
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Calendar Icon Button
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionCalendarPage(),
                  ),
                );
              },
            ),
            // Notification Icon Button with Badge
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationScreen(),
                      ),
                    ).then((_) {
                      // Refresh notifications when returning from notification screen
                      notificationProvider.fetchNotifications();
                    });
                  },
                ),
                if (notificationProvider.unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Appcolors.notificationBadgeRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        notificationProvider.unreadCount > 9
                            ? '9+'
                            : notificationProvider.unreadCount.toString(),
                        style: const TextStyle(
                          color: Appcolors.notificationBadgeText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class TransactionView extends StatefulWidget {
  const TransactionView({super.key});

  @override
  TransactionViewState createState() => TransactionViewState();
}

class TransactionViewState extends State<TransactionView>
    with AutomaticKeepAliveClientMixin {
  //this is the icon data for the transaction categories
  static const Map<String, IconData> _categoryIcons = {
    'food': Icons.restaurant,
    'groceries': Icons.restaurant,
    'transport': Icons.directions_car,
    'transportation': Icons.directions_car,
    'shopping': Icons.shopping_cart,
    'entertainment': Icons.movie,
    'bills': Icons.receipt,
    'utilities': Icons.receipt,
    'savings': Icons.savings,
  };

  @override
  bool get wantKeepAlive => true;

  // Cache transaction items
  final Map<String, Widget> _itemCache = {};

  IconData _getIconForCategory(String categoryName) =>
      _categoryIcons[categoryName.toLowerCase()] ??
      Icons.account_balance_wallet;

  Widget _getCachedItem(Map<String, dynamic> transaction) {
    final key = '${transaction['id']}';
    return _itemCache.putIfAbsent(key, () {
      return TransactionItem(
        title: transaction['categoryName'] ?? 'Unknown',
        amount: 'Ksh.${transaction['amount'].toStringAsFixed(2)}',
        date: transaction['date'] != null
            ? _formatDate(transaction['date'])
            : 'Unknown date',
        icon: _getIconForCategory(transaction['categoryName']),
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    _itemCache.clear(); // Clear cache when widget is disposed
    _categoryIcons.clear(); // Clear icon cache
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return _loadingIndicator;
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TextStrings.transactions,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Appcolors.blue400),
            ),
            const SizedBox(height: 5),
            provider.recentTransactions.isEmpty
                ? _noTransactionsWidget
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.recentTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = provider.recentTransactions[index];
                      return _getCachedItem(
                          transaction as Map<String, dynamic>);
                    },
                  )
          ],
        );
      },
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Transaction Item Widget
class TransactionItem extends StatelessWidget {
  final String title;
  final String amount;
  final String date;
  final IconData icon;

  const TransactionItem(
      {super.key,
      required this.title,
      required this.amount,
      required this.date,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text('/$date', style: TextStyle(color: Appcolors.grey600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              amount.startsWith('-') ? Icons.remove : Icons.add,
              size: 16,
              color: amount.startsWith('-') ? Colors.red : Colors.blue,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  color: amount.startsWith('-') ? Colors.red : Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget that builds the category list
class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

  // Separate widget for add button
  static const _addButton = Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.add_circle_outline, size: 40, color: Appcolors.blue),
      SizedBox(height: 8),
      Text(TextStrings.addCategory,
          style: TextStyle(fontSize: 16, color: Appcolors.blue)),
    ],
  );

  // Cache category cards to prevent rebuilds
  static final Map<String, Widget> _cardCache = {};

  Widget _getCachedCard(BudgetCategory category) {
    return _cardCache.putIfAbsent(
      category.id,
      () => BuildCategoryCard(category: category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = provider.categories;

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Appcolors.error, size: 32),
                const SizedBox(height: 8),
                Text('Error loading categories: ${provider.error}'),
                TextButton(
                  onPressed: () {
                    provider.loadCategories();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (categories.isEmpty && !provider.isLoading) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No categories found'),
                TextButton(
                  onPressed: () => _showAddCategoryDialog(context, provider),
                  child: const Text('Add Category'),
                ),
              ],
            ),
          );
        }

        return RepaintBoundary(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1, // +1 for add button
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return _buildAddCategoryCard(context, provider);
                }
                return _getCachedCard(categories[index]);
              },
            ),
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog(BuildContext context, CategoryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => CategoryTypeDialog(
        onCategoryTypeSelected: (type) {
          showDialog(
            context: context,
            builder: (context) => CategoryFormDialog(
              categoryType: type,
              onSave: (newCategory) async {
                try {
                  await provider.addCategory({
                    'name': newCategory.name,
                    'amount': newCategory.amount,
                    'categoryType': newCategory.categoryType,
                    'goalAmount': newCategory.goalAmount,
                    'isLocked': newCategory.isLocked,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  // Refresh the category list
                  provider.loadCategories();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding category: $e')),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddCategoryCard(
      BuildContext context, CategoryProvider provider) {
    return Container(
      width: 160,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Appcolors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Appcolors.blue, width: 2),
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => CategoryTypeDialog(
              onCategoryTypeSelected: (type) {
                showDialog(
                  context: context,
                  builder: (context) => CategoryFormDialog(
                    categoryType: type,
                    onSave: (newCategory) async {
                      try {
                        await provider.addCategory({
                          'name': newCategory.name,
                          'amount': newCategory.amount,
                          'categoryType': newCategory.categoryType,
                          'goalAmount': newCategory.goalAmount,
                          'isLocked': newCategory.isLocked,
                        });
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        // Refresh the category list
                        provider.loadCategories();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error adding category: $e')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
          );
        },
        child: _addButton,
      ),
    );
  }
}

/// widget that builds the category card
class BuildCategoryCard extends StatelessWidget {
  final BudgetCategory category;

  const BuildCategoryCard({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final isSavings = category.categoryType.toLowerCase() == 'savings';
    final progress =
        isSavings && category.goalAmount != null && category.goalAmount! > 0
            ? (category.amount / category.goalAmount!).clamp(0.0, 1.0)
            : 0.0;
    int progressText(progress) => (progress * 100);

    return Hero(
      tag: 'category-${category.id}',
      child: Material(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryReportPage(
                  categoryId: category.id,
                  categoryName: category.name,
                ),
              ),
            );
          },
          child: Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Appcolors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Appcolors.grey.withValues(alpha: 0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSavings)
                      Tooltip(
                        message: category.isLocked ? 'Locked' : 'Unlocked',
                        child: Icon(
                          category.isLocked ? Icons.lock : Icons.lock_open,
                          size: 18,
                          color: category.isLocked
                              ? Appcolors.error
                              : Appcolors.success,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                //const SizedBox(height: 10),
                ///
                if (isSavings &&
                    category.goalAmount != null &&
                    category.goalAmount! > 0)
                  Center(
                    child: CircularPercentIndicator(
                      radius: 20,
                      lineWidth: 6,
                      percent: progress,
                      center: Text(
                        '$progressText.toStringAsFixed(0)%',
                        style: const TextStyle(fontSize: 14),
                      ),
                      progressColor: _getProgressColor(category),
                      backgroundColor: Appcolors.grey200,
                      circularStrokeCap: CircularStrokeCap.round,
                      animation: true,
                      animationDuration: 1000,
                    ),
                  ),
                if (!isSavings ||
                    category.goalAmount == null ||
                    category.goalAmount! <= 0)
                  Text(
                    category.formattedAmount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Appcolors.textGrey600,
                    ),
                  ),
                const SizedBox(height: 8),
                if (isSavings &&
                    category.goalAmount != null &&
                    category.goalAmount! > 0) ...[
                  Text(
                    '${TextStrings.saved} ${category.formattedAmount}',
                    style:
                        TextStyle(fontSize: 12, color: Appcolors.textGrey600),
                  ),
                  Text(
                    '${TextStrings.goal} ${category.goalAmount?.toStringAsFixed(2) ?? "0.00"}',
                    style:
                        TextStyle(fontSize: 12, color: Appcolors.textGrey600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(BudgetCategory category) {
    if (category.isLocked) return Appcolors.grey;
    final progress = category.amount / category.goalAmount!;
    return progress < 0.5
        ? Appcolors.progressOrange
        : progress < 0.8
            ? Appcolors.progressBlue
            : Appcolors.progressGreen;
  }
}
