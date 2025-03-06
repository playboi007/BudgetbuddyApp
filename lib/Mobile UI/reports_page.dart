import 'package:budgetbuddy_app/states/analytics_provider.dart';
import 'package:budgetbuddy_app/widgets/charts/pie_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AnalyticsProvider>().loadCategoryBreakdown();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports', style: TtextTheme.lightText.titleMedium),
      ),
      body: Consumer<AnalyticsProvider>(builder: (context, provider, _) {
        if (provider.categoryBreakdown == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return CategoryPieChart(data: provider.categoryBreakdown!);
      }),
    );
  }
}
