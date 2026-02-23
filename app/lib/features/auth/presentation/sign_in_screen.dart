import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motomuse/features/auth/application/auth_providers.dart';
import 'package:motomuse/features/auth/domain/auth_exception.dart';
import 'package:motomuse/shared/widgets/textured_background.dart';

/// Sign-in screen.
///
/// Supports Google OAuth and email/password (sign-in and account creation).
/// Navigation to the authenticated shell happens automatically when
/// [authStateChangesProvider] emits a non-null user — the router handles it.
class SignInScreen extends ConsumerStatefulWidget {
  /// Creates the sign-in screen.
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// `true` while showing the "create account" form variant.
  bool _isCreatingAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final theme = Theme.of(context);

    // Show a snackbar whenever an auth operation fails.
    ref.listen<AsyncValue<void>>(authNotifierProvider, (_, next) {
      next.whenOrNull(
        error: (error, __) {
          final message = error is AuthException
              ? error.message
              : 'Sign-in failed. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
      );
    });

    return Scaffold(
      body: TexturedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).top -
                  MediaQuery.paddingOf(context).bottom,
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

                  // Google Sign-In
                  ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(authNotifierProvider.notifier)
                            .signInWithGoogle(),
                    child: isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue with Google'),
                  ),

                  const SizedBox(height: 24),

                  // Divider
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

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 12),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    onFieldSubmitted: isLoading ? null : (_) => _submitEmail(),
                  ),
                  const SizedBox(height: 24),

                  // Primary email action button
                  ElevatedButton(
                    onPressed: isLoading ? null : _submitEmail,
                    child: Text(
                      _isCreatingAccount ? 'Create Account' : 'Sign In',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Toggle between sign-in and create-account
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(
                              () =>
                                  _isCreatingAccount = !_isCreatingAccount,
                            ),
                    child: Text(
                      _isCreatingAccount
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Create one",
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitEmail() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final notifier = ref.read(authNotifierProvider.notifier);

    if (_isCreatingAccount) {
      notifier.createAccount(email: email, password: password);
    } else {
      notifier.signInWithEmail(email: email, password: password);
    }
  }
}
