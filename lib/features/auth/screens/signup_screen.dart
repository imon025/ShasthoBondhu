import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/custom_text_field.dart';
import '../../dashboard/screens/dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Controllers for text fields
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController();
  final _emailController = TextEditingController();
  final _ailmentsController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.65, curve: Curves.easeOut)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _emailController.dispose();
    _ailmentsController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final ageStr = _ageController.text.trim();
    final gender = _genderController.text.trim();
    final ailments = _ailmentsController.text.trim();

    if (email.isEmpty || password.isEmpty || fullName.isEmpty || ageStr.isEmpty || gender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid age')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sign up user in Supabase Auth
      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'age': age,
          'gender': gender,
          'ailments': ailments,
          'account_type': 0,
        },
      );

      final user = response.user;
      if (user != null) {
        // Try inserting into profiles. If email confirmation is ON, RLS might block this.
        try {
          await Supabase.instance.client.from('profiles').insert({
            'id': user.id,
            'full_name': fullName,
            'age': age,
            'gender': gender,
            'email': email,
            'ailments': ailments,
            'account_type': 0, 
          });
        } catch (insertError) {
          debugPrint('Profile insert error (might be RLS): $insertError');
          // We don't block the UI here, as the user was successfully created in Auth
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Go back to login
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up failed. Please try again.'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Centered vertically
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: () => Navigator.pop(context),
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Create Account',
                          style: Theme.of(context).textTheme.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join ShasthoBondhu today',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey[600],
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 30),
                        // The Auth Panel
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: _fullNameController,
                                label: 'Full Name',
                                hint: 'Enter your full name',
                                prefixIcon: Icons.person_outline,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _ageController,
                                label: 'Age',
                                hint: 'Years',
                                keyboardType: TextInputType.number,
                                prefixIcon: Icons.calendar_today_outlined,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _genderController,
                                label: 'Gender',
                                hint: 'Male / Female',
                                prefixIcon: Icons.wc_outlined,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hint: 'farazi@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _ailmentsController,
                                label: 'Present ailments/symptoms',
                                hint: 'Briefly describe your current health condition...',
                                maxLines: 3,
                                prefixIcon: Icons.medical_information_outlined,
                              ),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hint: 'Minimum 6 characters',
                                obscureText: true,
                                prefixIcon: Icons.lock_outline,
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56, // Match input field height
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleSignup,
                                  child: _isLoading 
                                    ? const SizedBox(
                                        height: 20, 
                                        width: 20, 
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      ) 
                                    : const Text('Sign Up'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              "Already have an account?",
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Login Instead'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
