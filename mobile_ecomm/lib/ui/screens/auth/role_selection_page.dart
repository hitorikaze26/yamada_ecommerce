import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';
import '../../widgets/yamada_logo.dart';

/// Role Selection Page
/// Allows users to choose their role (Buyer, Seller, Rider) before authentication
/// Adapted from reference/screens/auth/role_selection_screen.dart
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const YamadaLogo(height: 80)
                    .animate()
                    .scale(duration: 600.ms, begin: const Offset(0.8, 0.8))
                    .fade(duration: 600.ms),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Welcome to Yamada',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideY(begin: 0.3, duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  'Choose your role to get started with the best shopping experience',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 300.ms)
                    .slideY(begin: 0.3, duration: 600.ms, delay: 300.ms),
                const SizedBox(height: 48),

                // Role Cards
                _RoleCard(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Get Started as Buyer',
                  description: 'Browse and buy amazing products from sellers',
                  color: AppColors.rosewood,
                  onTap: () => context.push('${AppRouter.login}?role=buyer'),
                  delay: 400.ms,
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.store_outlined,
                  title: 'Apply as Seller',
                  description: 'Start your shop and sell to thousands of buyers',
                  color: const Color(0xFF10B981),
                  onTap: () => context.push('${AppRouter.login}?role=seller'),
                  delay: 500.ms,
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.two_wheeler_outlined,
                  title: 'Apply as Rider',
                  description: 'Earn money by delivering orders in your area',
                  color: const Color(0xFF3B82F6),
                  onTap: () => context.push('${AppRouter.login}?role=rider'),
                  delay: 600.ms,
                ),
                const SizedBox(height: 48),

                // Footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'Already have an account? ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                    children: [
                      TextSpan(
                        text: 'Sign In',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.rosewood,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 700.ms)
                    .slideY(begin: 0.3, duration: 600.ms, delay: 700.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;
  final Duration delay;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    required this.delay,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isPressed ? widget.color : (isDark ? AppColors.darkBorder : AppColors.border),
            width: _isPressed ? 2 : 1,
          ),
          color: _isPressed
              ? widget.color.withOpacity(0.05)
              : (isDark ? AppColors.darkCard : AppColors.card),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward,
                color: widget.color,
                size: 20,
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 600.ms, delay: widget.delay)
          .slideY(begin: 0.3, duration: 600.ms, delay: widget.delay),
    );
  }
}
