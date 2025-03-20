//this will contain reusable text strings like celebratory messages, error messages, etc.

class TextStrings {
  TextStrings._();

  static const String appName = "BUDGETBUDDY";

  static const String passwordregex =
      "Password must contain uppercase, lowercase, number and special symbol";

//app bar names
  static const String featCat = "Featured Categories";
  static const String finEd = "Financial Education";
  static const String notifs = 'Notifications';
  static const String quizPage = 'Quiz';
  static const String SaveRepo = "Savings Report";

  static const String savingsGoalNew =
      "Please provide a name for your savings category";
  static const String savingsAmount =
      "Please provide an amount for your savings goal";
  static const String savingsGoalAmount =
      'Please enter a target amount you want to achieve';

  //loginscreen
  static const String crAcc = 'Create an account';
  static const String inputEmail = "Please enter your email";
  static const String validEmail = "Please enter valid email";
  static const String inputNum = 'Please enter your phone number';
  static const String numCount = 'Phone number must be 9 digits';
  static const String forPass = "Forgot your Password?";

  //new category form
  static const String startAmount =
      "What would you like your start amount to be:";
  static const String goalAmount = "How much do you wanna save";
  static const String lock =
      "Would you like to lock this goal till you reach your full amount";
  static const String freqReminder =
      "How would you like to be reminded to save?";
  static const String createCat = "Create this Goal";

  //settings page
  static const String deleteAccMessage =
      "'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.'";
  static const String logoutMessage = "Are you sure you want to log out?";
  static const String downloaddataText =
      'You can download all your personal data including transaction history, budget categories, and account information.';

  //category_report page
  static const String gp = "Goal Progress";
  static const String gr = 'Goal reached!';

  //quiz page screen
  static const String correctAns = "Great job! You got the correct answer";

  //error messages
  static const String categoryError = "error adding category:";

  //course provider messages
  static const String featCour = "Featured Courses";

  //notifications
}
