import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../shared/widgets.dart';

/// OTP verification for phone/email. In development the issued code is returned
/// by the API under `devCode` (no SMS provider) and prefilled for convenience;
/// in production it would be delivered out-of-band.
class OtpPage extends ConsumerStatefulWidget {
  final String target; // phone | email
  final String value;
  final String purpose;
  const OtpPage({super.key, required this.target, required this.value, this.purpose = 'signup'});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _code = TextEditingController();
  String? _devCode;
  bool _busy = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      final code = await ref.read(apiClientProvider).requestOtp(widget.target, widget.value, widget.purpose);
      setState(() => _devCode = code.isEmpty ? null : code);
      if (code.isNotEmpty) _code.text = code;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      toast(context, 'Enter the code', error: true);
      return;
    }
    setState(() => _verifying = true);
    try {
      // Authenticated verify: validates the code AND marks the contact verified
      // server-side (the public verifyOtp only checked the code).
      await ref
          .read(apiClientProvider)
          .verifyContact(widget.target, widget.value, _code.text.trim(), widget.purpose);
      if (!mounted) return;
      // Refresh the cached user so the verified flags update in the UI.
      ref.invalidate(authControllerProvider);
      toast(context, 'Verified ✓');
      context.go('/today');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OrdoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_outlined, size: 48),
              const SizedBox(height: OrdoSpacing.md),
              Text('Enter the code sent to', style: Theme.of(context).textTheme.titleMedium),
              Text(widget.value, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (_devCode != null) ...[
                const SizedBox(height: OrdoSpacing.sm),
                Text('Dev code: $_devCode', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
              const SizedBox(height: OrdoSpacing.lg),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '••••••'),
              ),
              const SizedBox(height: OrdoSpacing.md),
              FilledButton(onPressed: _verifying ? null : _verify, child: _verifying ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify')),
              const SizedBox(height: OrdoSpacing.sm),
              TextButton(onPressed: _busy ? null : _request, child: Text(_busy ? 'Sending…' : 'Resend code')),
            ],
          ),
        ),
      ),
    );
  }
}
