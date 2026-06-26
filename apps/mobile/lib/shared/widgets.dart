import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'format.dart';

export 'format.dart';

class OAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final Color? ring;
  const OAvatar({super.key, this.imageUrl, this.name, this.radius = 20, this.ring});

  @override
  Widget build(BuildContext context) {
    final bg = name != null ? Color(colorFromString(name!)) : OrdoAccent.blue.light;
    final child = (imageUrl != null && imageUrl!.isNotEmpty)
        ? CircleAvatar(
            radius: radius,
            backgroundColor: Colors.transparent,
            backgroundImage: CachedNetworkImageProvider(imageUrl!),
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: bg,
            child: Text(
              initials(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: radius * 0.85,
              ),
            ),
          );
    if (ring != null) {
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring!, width: 2)),
        child: child,
      );
    }
    return child;
  }
}

class OAvatarStack extends StatelessWidget {
  final List<String> names;
  final List<String?> images;
  final double radius;
  final double overlap;
  final int max;
  const OAvatarStack({super.key, required this.names, this.images = const [], this.radius = 16, this.overlap = 8, this.max = 4});

  @override
  Widget build(BuildContext context) {
    final shown = names.length > max ? max : names.length;
    final extra = names.length - shown;
    return SizedBox(
      height: radius * 2,
      width: shown * (radius * 2 - overlap) + (extra > 0 ? radius * 2 - overlap : 0),
      child: Stack(
        children: [
          for (int i = 0; i < shown; i++)
            Positioned(
              left: i * (radius * 2 - overlap),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                ),
                child: OAvatar(name: names[i], imageUrl: i < images.length ? images[i] : null, radius: radius - 2),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown * (radius * 2 - overlap),
              child: CircleAvatar(
                radius: radius - 2,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                child: Text('+$extra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Group "avatar" — a colored rounded square with an emoji/initial.
class OGroupAvatar extends StatelessWidget {
  final String? emoji;
  final String? name;
  final String accent;
  final double size;
  const OGroupAvatar({super.key, this.emoji, this.name, this.accent = 'blue', this.size = 44});

  @override
  Widget build(BuildContext context) {
    final a = OrdoAccent.byName(accent);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a.primary(isDark), a.primary(isDark).withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji ?? initials(name),
        style: TextStyle(fontSize: size * 0.46, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Segmented control (for Day / Week / Month, tabs, etc.).
class OSegmented<T> extends StatelessWidget {
  final List<T> segments;
  final T value;
  final String Function(T) label;
  final void Function(T) onChanged;
  final double height;
  const OSegmented({super.key, required this.segments, required this.value, required this.label, required this.onChanged, this.height = 38});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(OrdoRadius.md),
      ),
      child: Row(
        children: [
          for (final s in segments)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s == value ? cs.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(OrdoRadius.sm),
                    boxShadow: s == value ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))] : null,
                  ),
                  child: Text(
                    label(s),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: s == value ? FontWeight.w700 : FontWeight.w500,
                      color: s == value ? cs.onSurface : cs.onSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class OCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool bordered;
  const OCard({super.key, required this.child, this.padding = const EdgeInsets.all(OrdoSpacing.lg), this.onTap, this.color, this.bordered = true});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(OrdoRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OrdoRadius.lg),
        child: Container(
          padding: padding,
          decoration: bordered
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(OrdoRadius.lg),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                )
              : null,
          child: child,
        ),
      ),
    );
  }
}

class OBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  const OBadge({super.key, required this.label, this.color, this.textColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final hasColor = color != null;
    final c = color ?? Theme.of(context).colorScheme.surfaceContainer;
    final tc = textColor ?? Theme.of(context).colorScheme.onSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(OrdoRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: hasColor ? c : tc), const SizedBox(width: 3)],
          Text(label, style: TextStyle(color: hasColor ? c : tc, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

class ODot extends StatelessWidget {
  final Color color;
  final double size;
  const ODot(this.color, {super.key, this.size = 8});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class OSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const OSkeleton({super.key, this.width = double.infinity, this.height = 14, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

class OSkeletonBox extends StatelessWidget {
  final Widget child;
  const OSkeletonBox(this.child, {super.key});
  @override
  Widget build(BuildContext context) => ShimmerEffect(child: child);
}

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  const ShimmerEffect({super.key, required this.child});
  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainer;
    final highlight = Theme.of(context).colorScheme.surface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          blendMode: BlendMode.srcOver,
          shaderCallback: (rect) {
            final dx = _c.value * rect.width * 2 - rect.width;
            return LinearGradient(
              begin: Alignment.topLeft,
              colors: [base, highlight, base],
              stops: const [0, 0.5, 1],
              transform: GradientRotation(0),
            ).createShader(Rect.fromLTWH(dx, 0, rect.width, rect.height));
          },
          child: widget.child,
        );
      },
    );
  }
}

class OEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const OEmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(OrdoSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: cs.surfaceContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 30, color: cs.onSecondary),
          ),
          const SizedBox(height: OrdoSpacing.lg),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: cs.onSecondary), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: OrdoSpacing.lg), action!],
        ],
      ),
    );
  }
}

class OSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const OSectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.lg, OrdoSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSecondary, letterSpacing: 0.4)),
          if (actionLabel != null)
            TextButton(onPressed: onAction, style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// A labeled text field.
class OField extends StatelessWidget {
  final String label;
  final Widget child;
  const OField({super.key, required this.label, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSecondary))),
      child,
    ]);
  }
}

Future<bool> confirm(BuildContext context, {required String title, String? message, String confirmText = 'Confirm', bool danger = false}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message != null ? Text(message) : null,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return res ?? false;
}

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Priority → color for task chips.
Color priorityColor(String priority, bool dark) {
  switch (priority) {
    case 'URGENT':
      return dark ? OrdoColors.dangerDark : OrdoColors.danger;
    case 'HIGH':
      return dark ? OrdoColors.warningDark : OrdoColors.warning;
    case 'MEDIUM':
      return dark ? OrdoAccent.cyan.dark : OrdoAccent.cyan.light;
    default:
      return dark ? OrdoAccent.slate.dark : OrdoAccent.slate.light;
  }
}
