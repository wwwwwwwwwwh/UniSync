import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'widgets/pixel_button.dart';
import 'widgets/pixel_input.dart';
import 'widgets/pixel_card.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final supabase = Supabase.instance.client;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  
  bool isSignUp = false;
  bool loading = false;
  bool showInputs = false; // Controls whether input panel is visible

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid credentials.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      if (isSignUp) {
        final confirm = confirmPassCtrl.text.trim();
        if (pass != confirm) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Passwords do not match.')),
           );
           setState(() => loading = false);
           return;
        }

        final res = await supabase.auth.signUp(email: email, password: pass);
        
        // Force manual login flow even if auto-login happened
        if (res.session != null) {
          await supabase.auth.signOut();
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('Account created! Please sign in.'),
             backgroundColor: AppColors.secondary,
           ),
        );
        setState(() => isSignUp = false); // Switch to sign in view
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pass);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (_) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unexpected error occurred.'), backgroundColor: Colors.redAccent),
         );
       }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image - Responsive (Portrait vs Landscape)
          Builder(
            builder: (context) {
              final size = MediaQuery.of(context).size;
              final isLandscape = size.aspectRatio > 1.0;
              final bgImage = isLandscape 
                  ? 'assets/images/horizontal_bg.png' 
                  : 'assets/images/school_library_bg.png';

              return SizedBox(
                height: double.infinity,
                width: double.infinity,
                child: Image.asset(
                  bgImage,
                  fit: BoxFit.cover, 
                  alignment: Alignment.topCenter, 
                ),
              );
            }
          ),
          
          // 2. Dark Overlay if inputs are shown (to focus attention)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: showInputs ? 0.6 : 0.0, 
            child: Container(color: Colors.black),
          ),

          // 3. Main Content
          SafeArea(
            child: Column(
              children: [
                // Spacer to push button down (Image contains title)
                const Spacer(), 

                // Floating "Start" Button (Hidden when inputs shown)
                if (!showInputs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PixelButton(
                           text: 'START',
                           onPressed: () => setState(() => showInputs = true),
                           width: 160,
                           height: 60,
                           color: AppColors.secondary,
                           textColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 5. Floating Input Panel (Animated popup)
          if (showInputs)
             Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: PixelCard(
                  backgroundColor: AppColors.surface,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSignUp ? 'New Adventurer' : 'Welcome Back',
                              style: AppTextStyles.pixelHeader,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => showInputs = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      PixelInput(hintText: 'Email', controller: emailCtrl),
                      const SizedBox(height: 12),
                      PixelInput(hintText: 'Password', controller: passCtrl, obscureText: true),
                      if (isSignUp) ...[
                        const SizedBox(height: 12),
                        PixelInput(hintText: 'Confirm Password', controller: confirmPassCtrl, obscureText: true),
                      ],
                      const SizedBox(height: 24),

                      PixelButton(
                        text: loading 
                              ? 'LOADING...' 
                              : (isSignUp ? 'CREATE ACCOUNT' : 'ENTER WORLD'),
                        onPressed: loading ? () {} : _submit,
                        color: AppColors.primary,
                        textColor: AppColors.surface,
                      ),
                      const SizedBox(height: 12),
                      
                      TextButton(
                        onPressed: () => setState(() => isSignUp = !isSignUp),
                        child: Text(
                          isSignUp ? 'Already have a key? Sign In.' : 'No key? Create one.',
                          style: AppTextStyles.pixelBody.copyWith(fontSize: 12, color: AppColors.shadow),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
