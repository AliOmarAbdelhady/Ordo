import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import 'auth_widgets.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});
  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  int _strength(String p) {
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'[0-9]').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
            _name.text.trim(),
            _email.text.trim(),
            _username.text.trim().toLowerCase(),
            _password.text,
          );
    } on ApiException catch (e) {
      _toast(e.message, true);
    } catch (_) {
      _toast('Could not create account. Try again.', true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, bool err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? Theme.of(context).colorScheme.error : null,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/login'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: OrdoSpacing.lg),
                const AuthHeader(title: 'Create your account', subtitle: 'Start organizing your time and your groups.'),
                const SizedBox(height: OrdoSpacing.xxl),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: OrdoSpacing.md),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: OrdoSpacing.md),
                TextFormField(
                  controller: _username,
                  decoration: const InputDecoration(labelText: 'Username', prefixText: '@'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final u = v?.trim().toLowerCase() ?? '';
                    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(u)) return '3-20 chars: letters, numbers, _';
                    return null;
                  },
                ),
                const SizedBox(height: OrdoSpacing.md),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
                ),
                const SizedBox(height: OrdoSpacing.sm),
                _StrengthBar(value: _strength(_password.text)),
                const SizedBox(height: OrdoSpacing.xl),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create account'),
                ),
                const SizedBox(height: OrdoSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(onPressed: () => context.go('/login'), child: const Text('Log in')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int value; // 0..4
  const _StrengthBar({required this.value});

  @override
  Widget build(BuildContext context) {
    final labels = ['Too short', 'Weak', 'Okay', 'Good', 'Strong'];
    final colors = [
      Colors.grey,
      OrdoColors.danger,
      OrdoColors.warning,
      OrdoColors.success,
      OrdoColors.success,
    ];
    final i = value.clamp(0, 4);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (i) / 4,
            minHeight: 4,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            color: colors[i],
          ),
        ),
        const SizedBox(height: 4),
        Text(labels[i], style: TextStyle(fontSize: 12, color: colors[i], fontWeight: FontWeight.w600)),
      ],
    );
  }
}
