import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_animations.dart';

/// Hero Button matching the web client's HeroButton component
/// Features a rounded, elevated style with primary gradient colors
class HeroButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool isSecondary;

  const HeroButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSecondary ? AppColors.secondary : AppColors.primary;
    final fgColor = isSecondary ? AppColors.secondaryForeground : AppColors.primaryForeground;

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: fgColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (icon != null) ...[
                      const SizedBox(width: 8),
                      Icon(icon, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    ).animate(
      effects: AppAnimations.bounce(delay: 0.1),
    );
  }
}

/// Shop Now Button with the special animated arrow design from web client
class ShopNowButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String text;

  const ShopNowButton({
    super.key,
    this.onPressed,
    this.text = 'Shop Now',
  });

  @override
  State<ShopNowButton> createState() => _ShopNowButtonState();
}

class _ShopNowButtonState extends State<ShopNowButton> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0.785398, // 45 degrees in radians
      end: 1.5708, // 90 degrees in radians
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isHovered = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isHovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppColors.rosewood,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.rosewood.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.text,
              style: const TextStyle(
                color: AppColors.charcoal,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _isHovered ? _rotationAnimation.value : 0.785398,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.offWhite,
                      border: Border.all(
                        color: _isHovered ? Colors.transparent : AppColors.rosewood,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_upward,
                      size: 16,
                      color: AppColors.rosewood,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).animate(
      effects: AppAnimations.fadeInUp(delay: 0.3),
    );
  }
}
