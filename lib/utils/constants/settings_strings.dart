// This file contains all text strings used in the settings screen

class SettingsStrings {
  SettingsStrings._();

  // Section Headers
  static const String profile = "Profile";
  static const String paymentMethods = "Payment Methods";
  static const String appSettings = "App Settings";
  static const String privacy = "Privacy";
  static const String about = "About";

  // Profile Section
  static const String viewProfile = "View Profile";
  static const String accountSecurity = "Account Security";
  static const String personalInformation = "Personal Information";
  static const String fullName = "Full Name";
  static const String email = "Email";
  static const String phoneNumber = "Phone Number";
  static const String saveChanges = "SAVE CHANGES";
  static const String dangerZone = "Danger Zone";
  static const String deleteAccount = "DELETE ACCOUNT";
  static const String profileUpdated = "Profile updated successfully";
  static const String errorUpdatingProfile = "Error updating profile: ";

  // Payment Methods Section
  static const String mPesa = "M-Pesa";
  static const String addPaymentMethod = "Add Payment Method";
  static const String transactionHistory = "Transaction History";
  static const String setupMPesa = "Set Up M-Pesa";
  static const String phoneNumberLabel = "Phone Number";
  static const String phoneNumberHint = "Enter your M-Pesa phone number";
  static const String phonePrefix = "+254 ";
  static const String verificationMessage =
      "We will send a verification code to this number to link your M-Pesa account.";
  static const String cancel = "CANCEL";
  static const String verify = "VERIFY";
  static const String verifyMPesa = "Verify M-Pesa";
  static const String enterVerificationCode =
      "Enter the verification code sent to your phone";
  static const String verificationCode = "Verification Code";
  static const String verificationCodeHint = "Enter 6-digit code";
  static const String confirm = "CONFIRM";
  static const String mpesaLinked = "M-Pesa account linked successfully!";

  // App Settings Section
  static const String darkMode = "Dark Mode";
  static const String notifications = "Notifications";
  static const String language = "Language";
  static const String english = "English";

  // Privacy Section
  static const String privacyPolicy = "Privacy Policy";
  static const String downloadMyData = "Download My Data";
  static const String managePermissions = "Manage Permissions";
  static const String downloadYourData = "Download Your Data";
  static const String dataJsonFile =
      "The data will be saved to your device as a JSON file.";
  static const String download = "DOWNLOAD";
  static const String downloadComplete = "Download Complete";
  static const String downloadSuccess =
      "Your data has been downloaded successfully!";
  static const String downloadDetails =
      "The file contains your transactions, categories, notifications, and course progress.";
  static const String ok = "OK";
  static const String failedToDownload = "Failed to download data: ";

  // About Section
  static const String testSplashScreen = "Test Splash Screen";
  static const String appVersion = "App Version";
  static const String versionNumber = "1.0.0";
  static const String termsOfService = "Terms of Service";
  static const String helpAndSupport = "Help & Support";
  static const String logOut = "Log Out";

  // Error Messages
  static const String pleaseEnterName = "Please enter your name";
  static const String userNotAuthenticated = "User not authenticated";
  static const String failedToDownloadData = "Failed to download data: ";
}
