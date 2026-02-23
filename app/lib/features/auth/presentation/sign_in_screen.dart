import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motomuse/core/routing/app_router.dart';
import 'package:motomuse/shared/widgets/textured_background.dart';

/// Sign-in screen. Placeholder — Firebase Auth wired up in Phase 1.
class SignInScreen extends StatelessWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: TexturedBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'MotoMuse',
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'The road chooses its riders.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  // TODO(auth): wire up Google Sign-In
                  onPressed: () => context.go(AppRoutes.garage),
                  child: const Text('Continue with Google'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  // TODO(auth): wire up Facebook Sign-In
                  onPressed: () => context.go(AppRoutes.garage),
                  child: const Text('Continue with Facebook'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or', style: theme.textTheme.bodyMedium),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  // TODO(auth): wire up email/password sign-in
                  onPressed: () => context.go(AppRoutes.garage),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
