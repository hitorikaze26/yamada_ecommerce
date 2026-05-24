import 'package:flutter/material.dart';

/// Brand logo from [assets/images/logo/logo.png].
class YamadaLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;

  const YamadaLogo({
    super.key,
    this.height = 40,
    this.width,
    this.fit = BoxFit.contain,
  });

  static const String assetPath = 'assets/images/logo/logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          height: height,
          width: width ?? height,
          child: Icon(
            Icons.storefront_outlined,
            size: height * 0.7,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}
