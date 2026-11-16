import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MiokoLogo extends StatelessWidget {
  const MiokoLogo({super.key, this.size = 64});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/logo_mioko.svg',
    width: size,
    height: size,
  );
}

// Outline brand glyphs from Tabler Icons (MIT), tinted by the ambient IconTheme like Material icons
class BrandIcon extends StatelessWidget {
  const BrandIcon._(this._path, {this.size, this.color, this.filled = false});

  const BrandIcon.telegram({Key? key, double? size, Color? color})
    : this._(_telegram, size: size, color: color);
  const BrandIcon.vk({Key? key, double? size, Color? color})
    : this._(_vk, size: size, color: color, filled: true);
  const BrandIcon.github({Key? key, double? size, Color? color})
    : this._(_github, size: size, color: color);

  final String _path;
  final double? size;
  final Color? color;
  final bool filled;

  static const _telegram = 'M15 10l-4 4l6 6l4 -16l-18 7l4 2l2 6l3 -4';
  static const _vk =
      'M14 19h-4a8 8 0 0 1 -8 -8v-5h4v5a4 4 0 0 0 4 4h0v-9h4v4.5l.03 0a4.531 4.531 0 0 0 3.97 -4.496h4l-.342 1.711a6.858 6.858 0 0 1 -3.658 4.789h0a5.34 5.34 0 0 1 3.566 4.111l.434 2.389h0h-4a4.531 4.531 0 0 0 -3.97 -4.496v4.5z';
  static const _github =
      'M9 19c-4.3 1.4 -4.3 -2.5 -6 -3m12 5v-3.5c0 -1 .1 -1.4 -.5 -2c2.8 -.3 5.5 -1.4 5.5 -6a4.6 4.6 0 0 0 -1.3 -3.2a4.2 4.2 0 0 0 -.1 -3.2s-1.1 -.3 -3.5 1.3a12.3 12.3 0 0 0 -6.2 0c-2.4 -1.6 -3.5 -1.3 -3.5 -1.3a4.2 4.2 0 0 0 -.1 3.2a4.6 4.6 0 0 0 -1.3 3.2c0 4.6 2.7 5.7 5.5 6c-.6 .6 -.6 1.2 -.5 2v3.5';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final s = size ?? iconTheme.size ?? 24;
    final c =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${filled ? '#000' : 'none'}" '
      'stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
      '<path d="$_path"/></svg>',
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
    );
  }
}

class WaveLogo extends StatelessWidget {
  const WaveLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/mioko_wave.svg',
    width: size,
    height: size,
  );
}

class PearlShell extends StatelessWidget {
  const PearlShell({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/pearls_shell.svg',
    width: size,
    height: size,
  );
}

class PearlIcon extends StatelessWidget {
  const PearlIcon({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/images/pearls.svg', width: size, height: size);
}
