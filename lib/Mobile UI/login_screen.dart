import 'package:budgetbuddy_app/utils/constants/image_strings.dart';
import 'package:budgetbuddy_app/utils/constants/text_strings.dart';
import 'package:budgetbuddy_app/utils/theme/text_theme.dart';
import 'package:budgetbuddy_app/utils/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:budgetbuddy_app/Mobile UI/signup_screen.dart';
import 'package:budgetbuddy_app/utils/validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthenticationFlow extends StatelessWidget {
  const AuthenticationFlow({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: TappTheme.lightTheme,
      darkTheme: TappTheme.darkTheme,
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _keepSignedIn = false;

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  //login logicc which checks with the firebase
  Future<void> _loginWithEmail() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final credential =
            await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        //cchecks to see if email is verified
        if (!credential.user!.emailVerified) {
          await credential.user!.sendEmailVerification();
          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: 'Email not verified',
          );
        }

        if (!mounted) return;
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Login failed')),
        );
      }
    }
  }

  Future<void> _forgotPassword() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Please check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send password reset email'),
        ),
      );
    }
  }

  Future<void> _googleSignin() async {
    try {
      // Create a GoogleSignIn instance
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Get authentication details from request
      final GoogleSignInAuthentication? googleAuth =
          await googleUser?.authentication;

      // Create credentials for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );

      // Sign in with Firebase using Google credentials
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign in failed: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                TextStrings.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Welcome back to the app',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Email'),
                  Tab(text: 'Phone Number'),
                ],
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEmailLoginForm(),
                    _buildPhoneLoginForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'hello@example.com',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return TextStrings.inputEmail;
              }
              if (!Validators.isValidEmail(value)) {
                return TextStrings.validEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCommonFormElements(),
        ],
      ),
    );
  }

  Widget _buildPhoneLoginForm() {
    return Form(
      child: Column(
        children: [
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Text(
                '  +1  ',
                style: TextStyle(fontSize: 16),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return TextStrings.inputNum;
              }
              if (!Validators.isValidPhone(value)) {
                return TextStrings.numCount;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCommonFormElements(),
        ],
      ),
    );
  }

  Widget _buildCommonFormElements() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _keepSignedIn,
                  onChanged: (value) {
                    setState(() async {
                      _keepSignedIn = value ?? false;
                      await FirebaseAuth.instance.setPersistence(_keepSignedIn
                          ? Persistence.LOCAL
                          : Persistence.SESSION);
                    });
                  },
                ),
                const Text('Keep me signed in'),
              ],
            ),
            TextButton(
              onPressed: () async {
                if (_emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your email address'),
                    ),
                  );
                  return;
                }
                _forgotPassword();
              },
              child: Text(TextStrings.forPass),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _loginWithEmail,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            backgroundColor: Colors.blue,
          ),
          child: Text('Login', style: TtextTheme.darktText.bodyMedium),
        ),
        const SizedBox(height: 16),
        const Text('or sign in with'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            _googleSignin();
          }, //onpressed
          icon: Image.asset(CImageStrings.google, height: 24),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const CreateAccountScreen()),
            );
          },
          child: const Text.rich(
            TextSpan(
              text: "Don't have an account? ",
              children: [
                TextSpan(
                  text: TextStrings.crAcc,
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
