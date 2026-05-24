import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animation configurations matching the web client's animations
class AppAnimations {
  // Durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);

  // Curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.elasticOut;
  static const Curve decelerate = Curves.decelerate;

  /// Fade in up animation (like web client's fadeInUp)
  static List<Effect<dynamic>> fadeInUp({
    double delay = 0,
    double duration = 0.6,
    double yOffset = 24,
  }) {
    return [
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
      SlideEffect(
        begin: Offset(0, yOffset / 100),
        end: Offset.zero,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
    ];
  }

  /// Fade in animation (like web client's fadeIn)
  static List<Effect<dynamic>> fadeIn({
    double delay = 0,
    double duration = 0.8,
  }) {
    return [
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
    ];
  }

  /// Scale animation with spring effect
  static List<Effect<dynamic>> scaleIn({
    double delay = 0,
    double duration = 0.5,
    double begin = 0.8,
  }) {
    return [
      ScaleEffect(
        begin: Offset(begin, begin),
        end: const Offset(1.0, 1.0),
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: spring,
      ),
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
    ];
  }

  /// Slide in from left
  static List<Effect<dynamic>> slideInLeft({
    double delay = 0,
    double duration = 0.5,
  }) {
    return [
      SlideEffect(
        begin: const Offset(-0.3, 0),
        end: Offset.zero,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
    ];
  }

  /// Slide in from right
  static List<Effect<dynamic>> slideInRight({
    double delay = 0,
    double duration = 0.5,
  }) {
    return [
      SlideEffect(
        begin: const Offset(0.3, 0),
        end: Offset.zero,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: Duration(milliseconds: (duration * 1000).toInt()),
        curve: easeOut,
      ),
    ];
  }

  /// Bounce animation for buttons and interactive elements
  static List<Effect<dynamic>> bounce({
    double delay = 0,
  }) {
    return [
      ScaleEffect(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1.0, 1.0),
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 400),
        curve: spring,
      ),
    ];
  }

  /// Shimmer loading animation
  static List<Effect<dynamic>> shimmer({
    double delay = 0,
  }) {
    return [
      ShimmerEffect(
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 1200),
        color: Colors.white.withOpacity(0.3),
      ),
    ];
  }

  /// Hero card entrance animation
  static List<Effect<dynamic>> heroCardEntrance({
    double delay = 0,
    int index = 0,
  }) {
    return [
      ...fadeInUp(
        delay: delay + (index * 0.1),
        duration: 0.6,
      ),
    ];
  }

  /// Staggered list animation
  static List<Effect<dynamic>> staggeredItem({
    required int index,
    double baseDelay = 0.1,
  }) {
    return [
      ...fadeInUp(
        delay: baseDelay + (index * 0.1),
        duration: 0.5,
      ),
    ];
  }

  /// Focus-in contract animation (like web client's hero text)
  static List<Effect<dynamic>> focusInContract({
    double delay = 0.1,
  }) {
    return [
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 800),
        curve: easeOut,
      ),
      BlurEffect(
        begin: const Offset(6, 6),
        end: Offset.zero,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 800),
        curve: easeOut,
      ),
    ];
  }

  /// Pulse animation for attention
  static List<Effect<dynamic>> pulse({
    double delay = 0,
  }) {
    return [
      ScaleEffect(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.05, 1.05),
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 600),
        curve: easeInOut,
      ),
      ScaleEffect(
        begin: const Offset(1.05, 1.05),
        end: const Offset(1.0, 1.0),
        delay: Duration(milliseconds: ((delay * 1000) + 600).toInt()),
        duration: const Duration(milliseconds: 600),
        curve: easeInOut,
      ),
    ];
  }

  /// Carousel slide animation
  static List<Effect<dynamic>> carouselSlide({
    double delay = 0,
  }) {
    return [
      FadeEffect(
        begin: 0,
        end: 1,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 500),
        curve: easeOut,
      ),
    ];
  }

  /// Remove animation (for cart items)
  static List<Effect<dynamic>> removeLeft({
    double delay = 0,
  }) {
    return [
      SlideEffect(
        begin: Offset.zero,
        end: const Offset(-1, 0),
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 300),
        curve: easeInOut,
      ),
      FadeEffect(
        begin: 1,
        end: 0,
        delay: Duration(milliseconds: (delay * 1000).toInt()),
        duration: const Duration(milliseconds: 300),
        curve: easeInOut,
      ),
    ];
  }
}

/// Extension to easily apply animations to widgets
extension AnimationExtension on Widget {
  Widget animateFadeInUp({
    double delay = 0,
    double duration = 0.6,
  }) {
    return animate(
      effects: AppAnimations.fadeInUp(
        delay: delay,
        duration: duration,
      ),
    );
  }

  Widget animateFadeIn({
    double delay = 0,
    double duration = 0.8,
  }) {
    return animate(
      effects: AppAnimations.fadeIn(
        delay: delay,
        duration: duration,
      ),
    );
  }

  Widget animateScaleIn({
    double delay = 0,
    double begin = 0.8,
  }) {
    return animate(
      effects: AppAnimations.scaleIn(
        delay: delay,
        begin: begin,
      ),
    );
  }

  Widget animateStaggered({
    required int index,
    double baseDelay = 0.1,
  }) {
    return animate(
      effects: AppAnimations.staggeredItem(
        index: index,
        baseDelay: baseDelay,
      ),
    );
  }

  Widget animateFocusIn({
    double delay = 0.1,
  }) {
    return animate(
      effects: AppAnimations.focusInContract(
        delay: delay,
      ),
    );
  }
}
