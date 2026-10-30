import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/failure_message.dart';
import '../../../core/session/session_end.dart';
import '../bloc/login_cubit.dart';
import '../bloc/session_cubit.dart';
import '../data/auth_repository.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => LoginCubit(context.read<AuthRepository>()),
    child: BlocListener<LoginCubit, LoginState>(
      listenWhen: (previous, current) => current.status == LoginStatus.success,
      // Handing the user to the session triggers the router's redirect.
      listener: (context, state) => context.read<SessionCubit>().signedIn(state.user!),
      child: const _LoginView(),
    ),
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  static const testUsername = 'emilys';
  static const testPassword = 'emilyspass';

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(username: _username.text, password: _password.text);
  }

  void _useTestAccount() {
    _username.text = testUsername;
    _password.text = testPassword;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<LoginCubit>().state;
    final submitting = state.status == LoginStatus.submitting;
    final expired =
        context.select((SessionCubit c) => c.state.endReason) == SessionEnd.expired && state.status == LoginStatus.idle;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.storefront_rounded, size: 56, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text('Welcome back', style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to browse the catalog',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      if (expired) ...[
                        _Banner(
                          text: 'Your session expired. Please sign in again.',
                          color: theme.colorScheme.secondaryContainer,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('login.username'),
                        controller: _username,
                        enabled: !submitting,
                        autofillHints: const [AutofillHints.username],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your username' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login.password'),
                        controller: _password,
                        enabled: !submitting,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                      ),
                      if (state.status == LoginStatus.failure && state.failure != null) ...[
                        const SizedBox(height: 16),
                        _Banner(
                          key: const Key('login.error'),
                          text: failureMessage(state.failure!),
                          color: theme.colorScheme.errorContainer,
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('login.submit'),
                        onPressed: submitting ? null : _submit,
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        child: submitting
                            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: submitting ? null : _useTestAccount,
                        child: const Text('Use test account ($testUsername)'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(12), child: Text(text)),
  );
}
