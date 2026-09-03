import 'package:flutter/material.dart';
import '../theme/palette.dart';

/// ============================================================
/// PRAssist shared UI kit — small, reusable, animated widgets.
/// ============================================================

/// Fades + slides its child in, optionally delayed for stagger effects.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.duration = const Duration(milliseconds: 650),
    this.curve = Curves.easeOutCubic,
    this.offset = const Offset(0, 26),
  });

  final Widget child;
  final int delayMs;
  final Duration duration;
  final Curve curve;
  final Offset offset;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(parent: _controller, curve: widget.curve);
    _opacity = Tween<double>(begin: 0, end: 1).animate(curved);
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero)
        .animate(curved);
    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _opacity.value,
        child: FractionalTranslation(
            translation: _slide.value, child: child),
      ),
      child: widget.child,
    );
  }
}

/// Wraps a child with a springy press-down scale effect.
class AnimatedScaleTap extends StatefulWidget {
  const AnimatedScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;

  @override
  State<AnimatedScaleTap> createState() => _AnimatedScaleTapState();
}

class _AnimatedScaleTapState extends State<AnimatedScaleTap> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Primary call-to-action — gradient pill with press + loading animation.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.gradient = AppPalette.brandGradient,
    this.height = 52,
    this.textStyle,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final Gradient gradient;
  final double height;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final button = AnimatedScaleTap(
      onTap: enabled ? onPressed : null,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: loading ? const LinearGradient(colors: [Color(0xFF7E8AA0), Color(0xFF707C94)]) : gradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: enabled
              ? [BoxShadow(color: AppPalette.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
              : null,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, color: Colors.white, size: 19), const SizedBox(width: 8)],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: textStyle ??
                          const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
      ),
    );
    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Frosted-glass style card that adapts to the active theme.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.color,
    this.gradient,
    this.radius = 20,
    this.border = true,
    this.glow = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool border;
  final bool glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final BoxDecoration decoration = BoxDecoration(
      color: color,
      gradient: gradient != null
          ? gradient
          : (color == null
              ? LinearGradient(
                  colors: [AppPalette.cardOf(context), AppPalette.cardAltOf(context)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null),
      borderRadius: BorderRadius.circular(radius),
      border: border ? Border.all(color: AppPalette.borderOf(context), width: 1) : null,
      boxShadow: glow
          ? [BoxShadow(color: AppPalette.primary.withValues(alpha: 0.16), blurRadius: 26, offset: const Offset(0, 10))]
          : [BoxShadow(color: Colors.black.withValues(alpha: light ? 0.05 : 0.35), blurRadius: 18, offset: const Offset(0, 8))],
    );
    final base = Container(
      margin: margin,
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return base;
    return AnimatedScaleTap(onTap: onTap, child: base);
  }
}

/// Glowing verdict pill with icon + short label.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({
    super.key,
    required this.verdict,
    this.compact = false,
    this.showLabel = true,
  });

  final String? verdict;
  final bool compact;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final color = AppPalette.verdictColor(verdict);
    final icon = AppPalette.verdictIcon(verdict);
    final label = AppPalette.verdictLabel(verdict);
    final text = (verdict ?? 'PENDING').toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 8 : 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.2),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 16, spreadRadius: -2, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 16 : 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: compact ? 11 : 14, letterSpacing: 0.6)),
              if (showLabel && !compact)
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Smoothly counts up to [value] whenever it changes.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 950),
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final Duration duration;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(value),
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}

/// Animated ambient gradient orbs behind its child (bottom layer).
class GlowStack extends StatefulWidget {
  const GlowStack({super.key, required this.child});

  final Widget child;

  @override
  State<GlowStack> createState() => _GlowStackState();
}

class _GlowStackState extends State<GlowStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(double size, List<Color> colors) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors, stops: const [0, 1]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -80 + 90 * t,
                  top: -90 + 70 * t,
                  child: _orb(300, [
                    AppPalette.primary.withValues(alpha: 0.20),
                    AppPalette.primary.withValues(alpha: 0),
                  ]),
                ),
                Positioned(
                  right: -90 + 70 * (1 - t),
                  bottom: -50 + 80 * t,
                  child: _orb(340, [
                    AppPalette.secondary.withValues(alpha: 0.16),
                    AppPalette.secondary.withValues(alpha: 0),
                  ]),
                ),
                Positioned(
                  right: 40 - 60 * t,
                  top: -70,
                  child: _orb(200, [
                    AppPalette.accentPink.withValues(alpha: 0.12),
                    AppPalette.accentPink.withValues(alpha: 0),
                  ]),
                ),
              ],
            );
          },
        ),
        widget.child,
      ],
    );
  }
}

/// Pulse placeholder used while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    this.height = 18,
    this.radius = 10,
    this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color? color;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.color ?? AppPalette.textSecondary(context).withValues(alpha: 0.14);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: 0.45 + 0.3 * _c.value,
        child: child,
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Small-caps section header with optional trailing action.
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.title, this.icon, this.trailing});

  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppPalette.primary),
          const SizedBox(width: 7),
        ],
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppPalette.textSecondary(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Segmented control with a sliding active pill.
class PillTabs extends StatelessWidget {
  const PillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppPalette.cardAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.borderOf(context)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == i ? AppPalette.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: index == i
                        ? [BoxShadow(color: AppPalette.primary.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: index == i ? Colors.white : AppPalette.textSecondary(context),
                      fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
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

/// A single destination for [AnimatedNavBar].
class NavItem {
  const NavItem(this.icon, this.label, {this.activeIcon});

  final IconData icon;
  final IconData? activeIcon;
  final String label;
}

/// Floating glass bottom-navigation bar with a sliding gradient pill.
class AnimatedNavBar extends StatelessWidget {
  const AnimatedNavBar({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: 0.94)
            : const Color(0xFF10162A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppPalette.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: light ? 0.08 : 0.45),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final seg = constraints.maxWidth / items.length;
          return SizedBox(
            height: 60,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutBack,
                  left: index * seg + 6,
                  width: seg - 12,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppPalette.brandGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.primary.withValues(alpha: 0.42),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(i),
                          child: AnimatedOpacity(
                            opacity: index == i ? 1 : 0.6,
                            duration: const Duration(milliseconds: 220),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  index == i ? (items[i].activeIcon ?? items[i].icon) : items[i].icon,
                                  color: index == i ? Colors.white : AppPalette.textSecondary(context),
                                  size: index == i ? 22 : 20,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  items[i].label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: index == i ? FontWeight.w700 : FontWeight.w500,
                                    color: index == i ? Colors.white : AppPalette.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}