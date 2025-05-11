import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import '../services/course_provider.dart';
import '../data models/course_model.dart';
import 'course_detail_page.dart';
import 'savings_tips_page.dart';
import '../utils/constants/savings_tips.dart';

class FinancialEducationPage extends StatefulWidget {
  const FinancialEducationPage({super.key});

  @override
  FinancialEducationPageState createState() => FinancialEducationPageState();
}

class FinancialEducationPageState extends State<FinancialEducationPage> {
  @override
  void initState() {
    super.initState();
    // Fetch courses when the page is initialized
    Future.microtask(() =>
        GetIt.I<CourseProvider>().loadCourses());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(TextStrings.finEd),
        elevation: 0,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, courseProvider, child) {
          if (courseProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (courseProvider.error != null) {
            return Center(child: Text('Error: ${courseProvider.error}'));
          }

          if (courseProvider.courses.isEmpty) {
            return const Center(
              child: Text('No courses available. Check back later!'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Learn to manage your finances better',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                buildTipsSection(context),
                const SizedBox(height: 24),

                Text(
                  "DIVE INTO THE INTERACTIVE COURSES",
                  style: TtextTheme.lightText.titleLarge,
                ),
                const SizedBox(height: 8),

                const Text(
                  'Explore our interactive courses to improve your financial knowledge',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Text(
                  TextStrings.featCour,
                  style: TtextTheme.lightText.titleMedium,
                ),
                const SizedBox(height: 16),
                ...courseProvider.courses.map((course) => CourseCard(
                      course: course,
                      onTap: () {
                        courseProvider.setCurrentCourse(course);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                CourseDetailPage(course: course),
                          ),
                        );
                      },
                    )),
                //const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget buildTipsSection(BuildContext context) {
  // Get a subset of tips to display in the carousel
  final featuredTips = SavingsTipsData.tips.take(3).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Savings Tips',
            style: TtextTheme.lightText.titleMedium,
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavingsTipsPage(),
                ),
              );
            },
            child: const Text('View All'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Quick tips to help you save more effectively',
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: featuredTips.length,
          itemBuilder: (context, index) {
            final tip = featuredTips[index];
            // Convert hex color to Color object
            Color backgroundColor = _hexToColor(tip.backgroundColor);

            return Container(
              width: 280,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavingsTipsPage(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  backgroundColor.withValues(alpha: 0.2),
                              radius: 20,
                              child: Icon(
                                _getIconData(tip.iconName),
                                color: backgroundColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tip.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Text(
                            tip.description,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              tip.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: backgroundColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

// Helper method to convert hex color string to Color
Color _hexToColor(String hexString) {
  final hexColor = hexString.replaceAll('#', '');
  return Color(int.parse('FF$hexColor', radix: 16));
}

// Helper method to get icon data from string
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

class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: Image.network(
                course.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, size: 50),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.description,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: course.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getProgressColor(course.progress),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(course.progress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${course.completedLessons}/${course.totalLessons} lessons completed',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (course.lastAccessedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last accessed: ${_formatDate(course.lastAccessedAt!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.7) return Colors.orange;
    return Colors.green;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
