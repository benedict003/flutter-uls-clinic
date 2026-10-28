import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Every spelling these files have been saved under. The first that loads wins.
class BrandImages {
  const BrandImages._();

  static const List<String> seal = [
    'assets/images/uls_seal.png',
    'assets/images/uls-loggo.png',
    'assets/images/uls-logo.png',
  ];

  static const List<String> emblem = [
    'assets/images/uls-loggo.png',
    'assets/images/clinic_emblem.png',
    'assets/images/uls-logo.png',
  ];

  static const List<String> campus = [
    'assets/images/uls-campus.png',
    'assets/images/uls_campus.jpg',
    'assets/images/uls_campus.png',
  ];
}

// Kept so older imports keep compiling.
const String kSealAsset = 'assets/images/uls_loggo.png';
const String kEmblemAsset = 'assets/images/clinic_emblem.png';
const String kCampusAsset = 'assets/images/uls-campus.png';

/// Tries each candidate in order. Never throws; degrades to an icon (or nothing).
class BrandImage extends StatefulWidget {
  const BrandImage(
      this.candidates, {
        super.key,
        this.height,
        this.width,
        this.fit = BoxFit.contain,
        this.alignment = Alignment.center,
        this.fallbackIcon = Icons.local_hospital_outlined,
        this.cacheWidth,
        this.showFallback = true,
      });

  final List<String> candidates;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Alignment alignment;
  final IconData fallbackIcon;
  final int? cacheWidth;
  final bool showFallback;

  @override
  State<BrandImage> createState() => _BrandImageState();
}

class _BrandImageState extends State<BrandImage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final path = widget.candidates[_index];
    return Image.asset(
      path,
      height: widget.height,
      width: widget.width,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: widget.cacheWidth,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stack) {
        if (_index + 1 < widget.candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _index += 1);
          });
        } else {
          debugPrint('BrandImage: none of ${widget.candidates} loaded.');
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) {
    if (!widget.showFallback) return const SizedBox.shrink();
    final icon = Icon(
      widget.fallbackIcon,
      size: 24,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (widget.height == null && widget.width == null) return Center(child: icon);
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Center(child: icon),
    );
  }
}

/// Legacy single-path wrapper.
class SafeAsset extends StatelessWidget {
  const SafeAsset(
      this.path, {
        super.key,
        this.width,
        this.height,
        this.fit = BoxFit.contain,
        this.fallbackIcon = Icons.local_hospital_outlined,
        this.cacheWidth,
      });

  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) => BrandImage(
    [path],
    width: width,
    height: height,
    fit: fit,
    fallbackIcon: fallbackIcon,
    cacheWidth: cacheWidth,
  );
}

/// Campus photo behind app content, veiled so forms and lists stay readable.
/// Campus photo behind app content, with a translucent paper veil.
/// Defaults are tuned so the building is clearly visible but text stays readable.
class ClinicBackground extends StatelessWidget {
  const ClinicBackground({
    super.key,
    required this.child,
    this.veil = 0.72,
    this.showPhoto = true,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;

  /// 0.0 = raw photo, 1.0 = flat paper.
  final double veil;
  final bool showPhoto;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final base = (veil + 0.08).clamp(0.0, 1.0);
    final end = (veil + 0.04).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: ClinicColors.paper),
        if (showPhoto)
          BrandImage(
            BrandImages.campus,
            fit: BoxFit.cover,
            alignment: alignment,
            cacheWidth: 1200,
            showFallback: false,
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.fromRGBO(246, 248, 252, base),
                Color.fromRGBO(246, 248, 252, veil),
                Color.fromRGBO(246, 248, 252, end),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// App bar with the emblem beside the title. Leaves `leading` free for the
/// framework's back arrow.
PreferredSizeWidget clinicAppBar(
    String title, {
      List<Widget>? actions,
      PreferredSizeWidget? bottom,
      bool showEmblem = true,
    }) {
  return AppBar(
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showEmblem) ...[
          const BrandImage(BrandImages.emblem, height: 26),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
      ],
    ),
    actions: actions,
    bottom: bottom,
  );
}

/// Seal + emblem + titles for the login screen.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.onDark = false,
    this.showEmblem = true,
    this.compact = false,
  });

  final bool onDark;
  final bool showEmblem;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : ClinicColors.ink;
    final muted = onDark ? Colors.white70 : const Color(0xFF5A6478);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: BrandImage(
            BrandImages.seal,
            height: compact ? 54 : 80,
            fallbackIcon: Icons.school_outlined,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'University of La Salette, Inc.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: compact ? 14 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Health Services Department',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: compact ? 11.5 : 13),
        ),
        if (showEmblem) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: BrandImage(BrandImages.emblem, height: compact ? 22 : 30),
          ),
        ],
      ],
    );
  }
}

/// Navy gradient strip — the standard header inside a screen.
class BrandBanner extends StatelessWidget {
  const BrandBanner({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.image,
    this.imageHeight = 34,
    this.margin = EdgeInsets.zero,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<String>? image;
  final double imageHeight;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ClinicColors.navy, ClinicColors.navyDeep],
        ),
      ),
      child: Row(
        children: [
          BrandImage(
            image ?? BrandImages.emblem,
            height: imageHeight,
            fit: BoxFit.contain,
            fallbackIcon: Icons.local_hospital_outlined,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Faded seal behind content.
class SealWatermark extends StatelessWidget {
  const SealWatermark({super.key, this.opacity = 0.06, this.size = 240});

  final double opacity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Center(
          child: BrandImage(
            BrandImages.seal,
            width: size,
            height: size,
            showFallback: false,
          ),
        ),
      ),
    );
  }
}

/// On-brand list avatar.
class ClinicAvatar extends StatelessWidget {
  const ClinicAvatar({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final name = (label ?? '').trim();
    if (name.isEmpty) {
      return const CircleAvatar(backgroundColor: Colors.white, child: SizedBox.shrink());
    }
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : parts.first[0].toUpperCase();
    return CircleAvatar(
      backgroundColor: ClinicColors.navy,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}