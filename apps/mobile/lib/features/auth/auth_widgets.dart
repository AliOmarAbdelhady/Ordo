import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/config.dart';

/// Shared brand header for auth screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_awesome_outlined, size: 30, color: Colors.white),
        ),
        const SizedBox(height: OrdoSpacing.xl),
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(color: cs.onSecondary, fontSize: 15, height: 1.4)),
      ],
    );
  }
}

class DemoHint extends StatelessWidget {
  final VoidCallback onUse;
  const DemoHint({super.key, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(OrdoSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(OrdoRadius.md),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, size: 18, color: OrdoColors.warning),
          const SizedBox(width: OrdoSpacing.sm),
          Expanded(
            child: Text('Try the demo: $demoEmail / $demoPassword',
                style: TextStyle(fontSize: 13, color: cs.onSecondary)),
          ),
          TextButton(onPressed: onUse, child: const Text('Fill')),
        ],
      ),
    );
  }
}
