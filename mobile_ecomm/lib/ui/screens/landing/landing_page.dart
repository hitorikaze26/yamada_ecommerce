import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/routes/app_router.dart';

/// Mobile Landing Page
/// Clean, simplified version focused on mobile UX
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverToBoxAdapter(
              child: _buildAppBar(context),
            ),

            // Hero Section
            SliverToBoxAdapter(
              child: _buildHeroSection(context, isDark),
            ),

            // Portal Cards Section
            SliverToBoxAdapter(
              child: _buildPortalSection(context, isDark),
            ),

            // Why Shop Section
            SliverToBoxAdapter(
              child: _buildWhyShopSection(context, isDark),
            ),

            // Footer
            SliverToBoxAdapter(
              child: _buildFooter(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo only - centered
          Image.asset(
            'assets/images/logo/logo.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to circle with Y
              return Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.rosewood,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    'Y',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .slideY(begin: 0.2, duration: 600.ms);
  }

  Widget _buildHeroSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'Y',
                      style: TextStyle(
                        color: AppColors.rosewood,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Yamada Collections',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.rosewood,
                      ),
                ),
              ],
            ),
          ).animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, duration: 600.ms),

          const SizedBox(height: 32),

          // Main Title - Mobile optimized
          Text(
            'Style Your Way',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                  height: 1.2,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 100.ms)
            .slideY(begin: 0.2, duration: 600.ms, delay: 100.ms),

          const SizedBox(height: 12),

          // Subtitle
          Text(
            'Shop curated women\'s fashion — elegant dresses to everyday essentials.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.mutedForeground,
                  height: 1.5,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),

          const SizedBox(height: 32),

          // Get Started Button - Full width on mobile
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(AppRouter.home),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text(
                'Start Shopping',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosewood,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 300.ms)
            .slideY(begin: 0.2, duration: 600.ms, delay: 300.ms),

          const SizedBox(height: 12),

          // Secondary: Create Account
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push(AppRouter.registerBuyer),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rosewood,
                side: BorderSide(color: AppColors.rosewood),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 400.ms)
            .slideY(begin: 0.2, duration: 600.ms, delay: 400.ms),

          const SizedBox(height: 24),

          // Have an account?
          TextButton(
            onPressed: () => context.push('${AppRouter.login}?role=buyer'),
            child: Text(
              'Already have an account? Log in',
              style: TextStyle(
                color: AppColors.mutedForeground,
                fontSize: 14,
              ),
            ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 500.ms),
        ],
      ),
    );
  }

  Widget _buildPortalSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? const Color(0xFF05060A) : AppColors.offWhite,
      child: Column(
        children: [
          // Section Title
          Text(
            'Join Yamada',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.charcoal,
                ),
          ).animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            'Partner or deliver with us',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 100.ms),
          const SizedBox(height: 20),

          // Deliver Card
          _buildPortalCard(
            context: context,
            isDark: isDark,
            title: 'Deliver with Us',
            description:
                'Deliver orders, track earnings, and maximize your delivery schedule with flexible work.',
            icon: Icons.local_shipping_outlined,
            buttonText: 'Rider Registration',
            onButtonPressed: () =>
                context.push('${AppRouter.register}?role=rider'),
            delay: 0.1,
          ),

          const SizedBox(height: 12),

          // Partner Card
          _buildPortalCard(
            context: context,
            isDark: isDark,
            title: 'Partner with Yamada',
            description:
                'Open your shop, upload products, manage inventory, and reach fashion-forward customers.',
            icon: Icons.store_outlined,
            buttonText: 'Seller Registration',
            onButtonPressed: () =>
                context.push('${AppRouter.register}?role=seller'),
            delay: 0.2,
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String description,
    required IconData icon,
    required String buttonText,
    required VoidCallback onButtonPressed,
    required double delay,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF020617) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF1f2933) : AppColors.warmGray,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.rosewood.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.rosewood,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkForeground
                                : AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onButtonPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rosewood,
                side: BorderSide(color: AppColors.rosewood),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: Duration(milliseconds: (delay * 1000).toInt()))
      .slideY(begin: 0.2, duration: 600.ms, delay: Duration(milliseconds: (delay * 1000).toInt()));
  }

  Widget _buildWhyShopSection(BuildContext context, bool isDark) {
    final features = [
      {
        'title': 'Trendy & Curated Collections',
        'description':
            'From chic dresses to activewear – everything is handpicked to match your look.',
        'icon': Icons.shopping_bag,
      },
      {
        'title': 'Secure & Seamless Shopping',
        'description':
            'Safe checkout, verified sellers, and real-time order tracking.',
        'icon': Icons.verified_user,
      },
      {
        'title': 'Fast Nationwide Delivery',
        'description': 'Quick, reliable shipping handled by trusted riders.',
        'icon': Icons.local_shipping,
      },
      {
        'title': 'Genuine Sellers & Quality Products',
        'description':
            'Verified partners to give you an authentic and worry-free shopping experience.',
        'icon': Icons.verified,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? const Color(0xFF05060A) : Colors.white,
      child: Column(
        children: [
          // Title
          Text(
            'Why Shop With Us',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkForeground : AppColors.charcoal,
                ),
          ).animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, duration: 600.ms),

          const SizedBox(height: 8),

          Text(
            'Discover the Yamada difference',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ).animate()
            .fadeIn(duration: 600.ms, delay: 100.ms),

          const SizedBox(height: 24),

          // Features Container
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: index < features.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            feature['icon'] as IconData,
                            color: AppColors.rosewood,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature['title'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppColors.charcoal,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                feature['description'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ).animate()
                  .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 100 + (index * 100)))
                  .slideY(begin: 0.2, duration: 600.ms, delay: Duration(milliseconds: 100 + (index * 100)));
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? AppColors.darkCard : AppColors.card,
      child: Column(
        children: [
          // Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo/logo.png',
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.rosewood,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'Y',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Copyright
          Text(
            '© ${DateTime.now().year} Yamada. All rights reserved.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          ),
        ],
      ),
    );
  }
}
