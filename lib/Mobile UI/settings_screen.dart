import 'dart:convert';
import 'dart:io';

import 'package:budgetbuddy_app/Mobile UI/splash_screen.dart';
import 'package:budgetbuddy_app/services/theme_provider.dart';
import 'package:budgetbuddy_app/utils/constants/colors.dart';
import 'package:budgetbuddy_app/utils/constants/settings_strings.dart';
import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  //ignore: unused_field
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    //ignore: unused_local_variable
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Section
          _buildSectionHeader(SettingsStrings.profile),
          _buildProfileCard(),
          const SizedBox(height: 16),

          // Payment Methods Section
          _buildSectionHeader(SettingsStrings.paymentMethods),
          _buildPaymentMethodsCard(),
          const SizedBox(height: 16),

          // App Settings Section
          _buildSectionHeader(SettingsStrings.appSettings),
          _buildSettingsCard(),
          const SizedBox(height: 16),

          // Privacy Section
          _buildSectionHeader(SettingsStrings.privacy),
          _buildPrivacyCard(),
          const SizedBox(height: 16),

          // About Section
          _buildSectionHeader(SettingsStrings.about),
          _buildAboutCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Appcolors.textWhite : Appcolors.textBlack,
            ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Avatar and Info
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    user?.displayName?.isNotEmpty == true
                        ? user!.displayName![0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'User',
                        style: TtextTheme.lightText.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'No email',
                        style: TtextTheme.lightText.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // Navigate to profile edit screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Profile Management Options
            _buildSettingsTile(
              'View Profile',
              Icons.person,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Account Security',
              Icons.security,
              () {
                // Navigate to security settings
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingsTile(
              'M-Pesa',
              Icons.account_balance_wallet,
              () {
                _showMpesaSetupDialog();
              },
              trailing: const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
            ),
            const Divider(),
            _buildSettingsTile(
              'Add Payment Method',
              Icons.add_circle_outline,
              () {
                // Show payment method options
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Transaction History',
              Icons.history,
              () {
                // Navigate to transaction history
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Find the theme toggle in your settings screen and replace it with:

            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: themeProvider.isDarkMode,
                  onChanged: (value) {
                    themeProvider.toggleTheme();
                  },
                  secondary: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Theme.of(context).iconTheme.color,
                  ),
                );
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Notifications'),
              secondary: const Icon(Icons.notifications),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                // Implement notifications toggle logic
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Language',
              Icons.language,
              () {
                // Show language options
              },
              trailing: const Text('English'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingsTile(
              'Privacy Policy',
              Icons.privacy_tip,
              () {
                // Show privacy policy
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Download My Data',
              Icons.download,
              () {
                _showDownloadDataDialog();
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Manage Permissions',
              Icons.perm_device_information,
              () {
                // Navigate to permissions management
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingsTile(
              'Test Splash Screen',
              Icons.replay,
              () async {
                // Reset first_time flag and navigate to splash screen
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('first_time', true);
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SplashScreen()),
                );
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'App Version',
              Icons.info,
              () {},
              trailing: const Text('1.0.0'),
            ),
            const Divider(),
            _buildSettingsTile(
              'Terms of Service',
              Icons.description,
              () {
                // Show terms of service
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Help & Support',
              Icons.help,
              () {
                // Navigate to help center
              },
            ),
            const Divider(),
            _buildSettingsTile(
              'Log Out',
              Icons.logout,
              () {
                _showLogoutConfirmationDialog();
              },
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String title, IconData icon, VoidCallback onTap,
      {Widget? trailing, Color? textColor, Color? iconColor}) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? Theme.of(context).primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showMpesaSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Up M-Pesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your M-Pesa phone number',
                prefixText: '+254 ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            const Text(
              'We will send a verification code to this number to link your M-Pesa account.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement M-Pesa verification logic
              Navigator.pop(context);
              _showMpesaVerificationDialog();
            },
            child: const Text('VERIFY'),
          ),
        ],
      ),
    );
  }

  void _showMpesaVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify M-Pesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the verification code sent to your phone'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Verification Code',
                hintText: 'Enter 6-digit code',
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement verification logic
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('M-Pesa account linked successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  void _showDownloadDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Your Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(TextStrings.downloaddataText),
            SizedBox(height: 16),
            Text(
              'The data will be saved to your device as a JSON file.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Implement data download logic
              Navigator.pop(context);

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // Get user data
                // ignore: unused_local_variable
                final userData = await _downloadUserData();

                // Close loading indicator
                if (!mounted) return;
                Navigator.pop(context);

                // Show success message with file path
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Download Complete'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your data has been downloaded successfully!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The file contains your transactions, categories, notifications, and course progress.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                // Close loading indicator
                if (!mounted) return;
                Navigator.pop(context);

                // Show error message
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to download data: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('DOWNLOAD'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(TextStrings.logoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement logout logic
              FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );
  }

  // Method to download user data
  Future<Map<String, dynamic>> _downloadUserData() async {
    if (user == null) throw Exception('User not authenticated');

    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final String userId = user!.uid;
    final Map<String, dynamic> userData = {};

    try {
      // Get user profile information
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        userData['profile'] = userDoc.data();
      }

      // Get user categories
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .get();

      final List<Map<String, dynamic>> categories = [];
      final List<Map<String, dynamic>> allTransactions = [];

      // Process each category and its transactions
      for (var categoryDoc in categoriesSnapshot.docs) {
        final categoryData = categoryDoc.data();
        final categoryId = categoryDoc.id;

        // Add category to the list
        categories.add({
          'id': categoryId,
          ...categoryData,
        });

        // Get transactions for this category
        final transactionsSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('categories')
            .doc(categoryId)
            .collection('transactions')
            .get();

        // Process transactions
        for (var transactionDoc in transactionsSnapshot.docs) {
          final transactionData = transactionDoc.data();
          allTransactions.add({
            'id': transactionDoc.id,
            'categoryId': categoryId,
            'categoryName': categoryData['name'] ?? 'Unknown',
            ...transactionData,
          });
        }
      }

      userData['categories'] = categories;
      userData['transactions'] = allTransactions;

      // Get monthly summaries
      final monthlySummariesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('monthlySummaries')
          .get();

      final List<Map<String, dynamic>> monthlySummaries = [];
      for (var summaryDoc in monthlySummariesSnapshot.docs) {
        monthlySummaries.add({
          'id': summaryDoc.id,
          ...summaryDoc.data(),
        });
      }

      userData['monthlySummaries'] = monthlySummaries;

      // Get weekly reports
      final weeklyReportsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyReports')
          .get();

      final List<Map<String, dynamic>> weeklyReports = [];
      for (var reportDoc in weeklyReportsSnapshot.docs) {
        weeklyReports.add({
          'id': reportDoc.id,
          ...reportDoc.data(),
        });
      }

      userData['weeklyReports'] = weeklyReports;

      // Get notifications
      final notificationsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .get();

      final List<Map<String, dynamic>> notifications = [];
      for (var notificationDoc in notificationsSnapshot.docs) {
        notifications.add({
          'id': notificationDoc.id,
          ...notificationDoc.data(),
        });
      }

      userData['notifications'] = notifications;

      // Get course progress
      final courseProgressSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('courseProgress')
          .get();

      final List<Map<String, dynamic>> courseProgress = [];
      for (var progressDoc in courseProgressSnapshot.docs) {
        courseProgress.add({
          'id': progressDoc.id,
          ...progressDoc.data(),
        });
      }

      userData['courseProgress'] = courseProgress;

      final directory = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/budgetbuddy_data_$dateStr.json';

      final file = File(filePath);
      await file.writeAsString(jsonEncode(userData));

      if (kDebugMode) {
        print('Data saved to: $filePath');
      }

      return userData;
    } catch (e) {
      throw Exception('Failed to download data: $e');
    }
  }
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current user data
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
    _phoneController.text = user?.phoneNumber ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'User',
                    style: TtextTheme.lightText.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'No email',
                    style: TtextTheme.lightText.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Profile Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personal Information',
                    style: TtextTheme.lightText.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    enabled: false, // Email can't be changed
                  ),
                  const SizedBox(height: 16),

                  // Phone Field
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updateProfile,
                      child: const Text('SAVE CHANGES'),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Danger Zone
                  Text(
                    'Danger Zone',
                    style: TtextTheme.lightText.titleLarge
                        ?.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 16),

                  // Delete Account Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _showDeleteAccountDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('DELETE ACCOUNT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Update display name
        await user?.updateDisplayName(_nameController.text);

        // Show success message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } catch (e) {
        // Show error message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text(
          TextStrings.deleteAccMessage,
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: _deleteAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount() async {
    try {
      // Delete user account
      await user?.delete();

      // Navigate back to login screen
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      // Show error message
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
  }
}
