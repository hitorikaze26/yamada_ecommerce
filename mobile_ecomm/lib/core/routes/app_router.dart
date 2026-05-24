import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../ui/screens/landing/landing_page.dart';
import '../../ui/screens/auth/login_page.dart';
import '../../ui/screens/auth/forgot_password_page.dart';
import '../../ui/screens/auth/reset_pin_page.dart';
import '../../ui/screens/auth/register_page.dart';
import '../../ui/screens/auth/buyer_register_page.dart';
import '../../ui/screens/auth/seller_register_page.dart';
import '../../ui/screens/auth/rider_register_page.dart';
import '../../ui/screens/auth/role_selection_page.dart';
import '../../ui/screens/home/home_page.dart';
import '../../ui/screens/product/product_detail_page.dart';
import '../../ui/screens/cart/cart_screen.dart';
import '../../ui/screens/checkout/checkout_screen.dart';
import '../../ui/screens/buyer/buyer_my_reviews_page.dart';
import '../../ui/screens/buyer/buyer_my_reports_page.dart';
import '../../ui/screens/buyer/help_center_page.dart';
import '../../ui/screens/order/order_detail_page.dart';
import '../../ui/screens/order/order_review_page.dart';
import '../../ui/screens/buyer/buyer_dashboard.dart';
import '../../ui/screens/buyer/buyer_shell.dart';
import '../../ui/screens/buyer/search_screen.dart';
import '../../ui/screens/buyer/wishlist_page.dart';
import '../../ui/screens/buyer/following_stores_page.dart';
import '../../ui/screens/buyer/recently_viewed_page.dart';
import '../../ui/screens/buyer/saved_addresses_page.dart';
import '../../ui/screens/buyer/coupons_page.dart';
import '../../ui/screens/buyer/buyer_settings_page.dart';
import '../../ui/screens/report/report_submit_screen.dart';
import '../../ui/screens/store/store_profile_page.dart';
import '../../core/report/report_navigation.dart';
import '../../ui/screens/seller/seller_dashboard.dart';
import '../../ui/screens/seller/seller_shell.dart';
import '../../ui/screens/seller/seller_orders_page.dart';
import '../../ui/screens/seller/seller_products_page.dart';
import '../../ui/screens/seller/seller_add_product_page.dart';
import '../../ui/screens/seller/seller_edit_product_page.dart';
import '../../ui/screens/seller/seller_browse_shell.dart';
import '../../ui/screens/seller/seller_account_page.dart';
import '../../ui/screens/seller/seller_shop_settings_page.dart';
import '../../ui/screens/seller/seller_edit_profile_page.dart';
import '../../ui/screens/seller/seller_settings_page.dart';
import '../../ui/screens/seller/seller_wallet_page.dart';
import '../../ui/screens/seller/seller_refunds_page.dart';
import '../../ui/screens/seller/seller_coupons_page.dart';
import '../../ui/screens/seller/seller_insights_hub_page.dart';
import '../../ui/screens/seller/analytics/seller_analytics_page.dart';
import '../../ui/screens/rider/rider_shell.dart';
import '../../ui/screens/rider/rider_dashboard.dart';
import '../../ui/screens/rider/rider_deliveries_page.dart';
import '../../ui/screens/rider/rider_earnings_page.dart';
import '../../ui/screens/rider/rider_history_page.dart';
import '../../ui/screens/rider/rider_profile_page.dart';
import '../../ui/screens/rider/rider_settings_page.dart';
import '../../ui/screens/admin/admin_dashboard.dart';
import '../../ui/screens/chat/chat_list_page.dart';
import '../../ui/screens/chat/chat_thread_page.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_notifier.dart';

class AppRouter {
  static const String landing = '/';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String resetPin = '/reset-pin';
  static const String register = '/register';
  static const String registerBuyer = '/register/buyer';
  static const String registerSeller = '/register/seller';
  static const String registerRider = '/register/rider';
  static const String home = '/home';
  static const String product = '/product';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String buyerDashboard = '/buyer';
  static const String sellerDashboard = '/seller';
  static const String sellerOrders = '/seller/orders';
  static const String sellerProducts = '/seller/products';
  static const String sellerAddProduct = '/seller/products/new';
  static String sellerEditProduct(String productId) =>
      '/seller/products/$productId/edit';
  static const String sellerInsights = '/seller/insights';
  static const String sellerFeedback = '/seller/feedback';
  static const String sellerInsightsHub = '/seller/insights-hub';
  static const String sellerBrowse = '/seller/browse';
  static const String sellerBrowseSearch = '/seller/browse/search';
  static const String sellerBrowseCart = '/seller/browse/cart';
  /// Account hub (bottom nav). Legacy `/seller/profile` redirects here.
  static const String sellerAccount = '/seller/account';
  static const String sellerProfile = '/seller/account';
  static const String sellerShopSettings = '/seller/shop-settings';
  /// Full-screen editor — must not nest under account shell tab.
  static const String sellerEditProfile = '/seller/edit-profile';
  static const String sellerSettings = '/seller/settings';
  static const String sellerAnalytics = '/seller/analytics';
  static const String sellerWallet = '/seller/wallet';
  static const String sellerRefunds = '/seller/refunds';
  static const String sellerCoupons = '/seller/coupons';
  static const String riderDashboard = '/rider';
  static const String riderDeliveries = '/rider/deliveries';
  static const String riderProfile = '/rider/profile';
  static const String riderSettings = '/rider/settings';
  static const String riderEarnings = '/rider/earnings';
  static const String riderHistory = '/rider/history';
  static const String adminDashboard = '/admin';
  static const String orders = '/orders';
  /// Buyer order detail — use [push] so back returns to the orders list.
  static const String buyerOrderDetail = '/order';
  static String buyerOrderPath(String orderId) => '$buyerOrderDetail/$orderId';
  static const String orderReview = '/order-review';
  static String orderReviewPath(String orderId) => '$orderReview/$orderId';
  static const String search = '/search';
  static const String storeProfile = '/store';
  static String storePath(String storeId) => '$storeProfile/$storeId';
  static const String myReviews = '/my-reviews';
  static const String myReports = '/my-reports';
  static const String reportSubmit = '/report/submit';
  static const String help = '/help';
  static const String wishlist = '/wishlist';
  static const String followingStores = '/following-stores';
  static const String recentlyViewed = '/recently-viewed';
  static const String addresses = '/addresses';
  static const String coupons = '/coupons';
  static const String settings = '/settings';
  static const String chat = '/chat';
  static String chatThreadPath(String conversationId) => '$chat/$conversationId';

  /// Seller account routes allowed while store is pending approval.
  static const Set<String> sellerAccountOnlyRoutes = {
    sellerAccount,
    sellerEditProfile,
    sellerSettings,
  };

  static bool isSellerAccountOnlyRoute(String location) {
    return sellerAccountOnlyRoutes.contains(location);
  }

  /// Rider routes allowed while account is pending admin approval.
  static const Set<String> riderPendingOnlyRoutes = {
    riderDashboard,
    riderProfile,
    riderSettings,
  };

  static bool isRiderPendingOnlyRoute(String location) {
    return riderPendingOnlyRoutes.contains(location);
  }

  /// Cart route that keeps seller browse chrome when shopping as a seller.
  static String cartPathFor(String location) {
    if (location == sellerBrowse ||
        location.startsWith('$sellerBrowse/')) {
      return sellerBrowseCart;
    }
    return cart;
  }

  static GoRouter createRouter(WidgetRef ref) {
    return GoRouter(
      initialLocation: home,
      debugLogDiagnostics: true,
      redirect: (context, state) {
        final authState = ref.read(authProvider);
        final isAuthenticated = authState.isAuthenticated;
        final isCheckingAuth = authState.isCheckingAuth;

        // Don't redirect while checking auth state
        if (isCheckingAuth) return null;

        final location = state.uri.path;

        // Canonical buyer orders list lives in profile shell tab.
        if (location == orders) {
          final status = state.uri.queryParameters['status'];
          if (status != null && status.isNotEmpty) {
            return '$buyerDashboard?tab=orders&status=$status';
          }
          return '$buyerDashboard?tab=orders';
        }

        final isSellerBrowseRoute = location == sellerBrowse ||
            location.startsWith('$sellerBrowse/');

        // Public routes that don't require authentication
        final publicRoutes = [
          landing,
          home,
          login,
          forgotPassword,
          resetPin,
          register,
          registerBuyer,
          registerSeller,
          registerRider,
          roleSelection,
          product,
          search,
          cart,
        ];

        // Check if current route is public
        final isPublicRoute = publicRoutes.any((route) =>
          location == route || location.startsWith('$route/'),
        );

        // Get user role for role-based redirects
        final userRole = authState.user?.role;

        // Redirect authenticated users away from auth pages to their role-specific dashboard
        if (isAuthenticated && (location == login || location == register || location == landing || location == roleSelection)) {
          switch (userRole) {
            case UserRole.seller:
              return authState.isVerified
                  ? sellerDashboard
                  : sellerAccount;
            case UserRole.rider:
              return '/rider';
            case UserRole.admin:
              return '/admin';
            case UserRole.buyer:
            default:
              return home;
          }
        }

        // Allow access to public routes
        if (isPublicRoute || isSellerBrowseRoute) {
          // Redirect authenticated users on home to their role-specific dashboard
          if (isAuthenticated && location == home && !isSellerBrowseRoute) {
            return _dashboardForRole(userRole, isVerified: authState.isVerified);
          }
          return null;
        }

        // Redirect unauthenticated users trying to access protected routes
        // Allow browsing public pages without authentication
        final protectedRoutes = [
          buyerDashboard,
          checkout,
          buyerOrderDetail,
          wishlist,
          followingStores,
          recentlyViewed,
          addresses,
          coupons,
          settings,
          myReviews,
          myReports,
          reportSubmit,
          help,
          sellerDashboard,
          sellerOrders,
          sellerProducts,
          sellerAccount,
          sellerAnalytics,
          riderDashboard,
          adminDashboard,
          chat,
        ];
        final isProtectedRoute = protectedRoutes.any((route) =>
          location == route || location.startsWith('$route/'),
        );

        if (!isAuthenticated && isProtectedRoute) {
          return '$login?role=buyer';
        }

        // Role-based access control for role-specific sections
        if (isAuthenticated) {
          // Seller routes: only sellers allowed
          final isSellerRoute = location == sellerDashboard ||
              location.startsWith('$sellerDashboard/');
          if (isSellerRoute && userRole != UserRole.seller) {
            return _dashboardForRole(userRole, isVerified: authState.isVerified);
          }

          // Rider routes: only riders allowed
          final isRiderRoute = location == riderDashboard ||
              location.startsWith('$riderDashboard/');
          if (isRiderRoute && userRole != UserRole.rider) {
            return _dashboardForRole(userRole, isVerified: authState.isVerified);
          }

          // Admin routes: only admins allowed
          final isAdminRoute = location == adminDashboard ||
              location.startsWith('$adminDashboard/');
          if (isAdminRoute && userRole != UserRole.admin) {
            return _dashboardForRole(userRole, isVerified: authState.isVerified);
          }

          // Buyer/checkout routes: sellers and riders should use their own dashboards
          final isBuyerOrderDetail = location.startsWith('$buyerOrderDetail/');
          final isBuyerOnlyRoute = location == buyerDashboard ||
              location == checkout ||
              isBuyerOrderDetail ||
              location == wishlist ||
              location == followingStores ||
              location == recentlyViewed ||
              location == addresses ||
              location == coupons ||
              location == settings ||
              location == myReviews ||
              location == myReports ||
              location == help;
          if (isBuyerOnlyRoute &&
              (userRole == UserRole.seller || userRole == UserRole.rider)) {
            if (userRole == UserRole.seller &&
                (location == cart || location == checkout)) {
              return null;
            }
            return _dashboardForRole(userRole, isVerified: authState.isVerified);
          }

          // Chat is shared across buyer, seller, rider
          final isChatRoute =
              location == chat || location.startsWith('$chat/');
          if (isChatRoute && !isAuthenticated) {
            return '$login?role=buyer';
          }

          // Unapproved sellers: account pages only
          if (userRole == UserRole.seller && !authState.isVerified) {
            final isSellerRoute = location == sellerDashboard ||
                location.startsWith('$sellerDashboard/');
            if (isSellerRoute && !isSellerAccountOnlyRoute(location)) {
              return sellerAccount;
            }
          }

          // Unapproved riders: dashboard, profile, and settings only
          if (userRole == UserRole.rider && !authState.isVerified) {
            final isRiderRoute = location == riderDashboard ||
                location.startsWith('$riderDashboard/');
            if (isRiderRoute && !isRiderPendingOnlyRoute(location)) {
              return riderDashboard;
            }
          }

          // Unapproved buyers: block checkout
          if (!authState.isVerified &&
              location == checkout &&
              userRole != UserRole.seller &&
              userRole != UserRole.rider &&
              userRole != UserRole.admin) {
            return '$cart?pending=1';
          }
        }

        return null;
      },
      routes: [
        GoRoute(
          path: landing,
          builder: (context, state) => const LandingPage(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) {
            final roleParam = state.uri.queryParameters['role'];
            final role = _parseRole(roleParam);
            return LoginPage(role: role);
          },
        ),
        GoRoute(
          path: forgotPassword,
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: resetPin,
          builder: (context, state) {
            final email = state.uri.queryParameters['email'] ?? '';
            final channel = state.uri.queryParameters['channel'] ?? 'email';
            return ResetPinPage(email: email, channel: channel);
          },
        ),
        GoRoute(
          path: register,
          builder: (context, state) {
            final roleParam = state.uri.queryParameters['role'];
            final role = _parseRole(roleParam);
            return RegisterPage(role: role);
          },
        ),
        GoRoute(
          path: registerBuyer,
          builder: (context, state) => const BuyerRegisterPage(),
        ),
        GoRoute(
          path: registerSeller,
          builder: (context, state) => const SellerRegisterPage(),
        ),
        GoRoute(
          path: registerRider,
          builder: (context, state) => const RiderRegisterPage(),
        ),
        GoRoute(
          path: roleSelection,
          builder: (context, state) => const RoleSelectionPage(),
        ),
        GoRoute(
          path: '$product/:slug',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            return ProductDetailPage(slug: slug);
          },
        ),
        GoRoute(
          path: '$storeProfile/:storeId',
          builder: (context, state) {
            final storeId = state.pathParameters['storeId'] ?? '';
            final isOwner = state.uri.queryParameters['owner'] == '1';
            return StoreProfilePage(storeId: storeId, isOwner: isOwner);
          },
        ),
        // Buyer shop routes — shared bottom navigation (home, search, cart, profile)
        ShellRoute(
          builder: (context, state, child) => BuyerShell(child: child),
          routes: [
            GoRoute(
              path: home,
              builder: (context, state) => const HomePage(),
            ),
            GoRoute(
              path: search,
              builder: (context, state) => SearchScreen(
                initialCategoryId: state.uri.queryParameters['category'],
              ),
            ),
            GoRoute(
              path: cart,
              builder: (context, state) => const CartScreen(),
            ),
            GoRoute(
              path: buyerDashboard,
              builder: (context, state) {
                final tab = state.uri.queryParameters['tab'];
                final status = state.uri.queryParameters['status'];
                if (tab == 'orders') {
                  return BuyerDashboard(
                    embeddedInShell: true,
                    initialTab: 1,
                    initialOrderFilter: status,
                  );
                }
                return const BuyerDashboard(embeddedInShell: true);
              },
            ),
          ],
        ),
        GoRoute(
          path: checkout,
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: myReviews,
          builder: (context, state) => const BuyerMyReviewsPage(),
        ),
        GoRoute(
          path: myReports,
          builder: (context, state) => const BuyerMyReportsPage(),
        ),
        GoRoute(
          path: reportSubmit,
          builder: (context, state) {
            final args = reportSubmitArgsFromExtra(state.extra);
            if (args == null || !args.hasRequiredContext) {
              return const Scaffold(
                body: Center(child: Text('Invalid report context')),
              );
            }
            return ReportSubmitScreen(args: args);
          },
        ),
        GoRoute(
          path: help,
          builder: (context, state) => const HelpCenterPage(),
        ),
        GoRoute(
          path: '$buyerOrderDetail/:orderId',
          name: 'buyerOrderDetail',
          builder: (context, state) {
            final id = state.pathParameters['orderId'] ?? '';
            return OrderDetailPage(orderId: id);
          },
        ),
        GoRoute(
          path: '$orderReview/:orderId',
          name: 'orderReview',
          builder: (context, state) {
            final id = state.pathParameters['orderId'] ?? '';
            final fromConfirm =
                state.uri.queryParameters['fromConfirm'] == '1';
            return OrderReviewPage(orderId: id, fromConfirm: fromConfirm);
          },
        ),
        GoRoute(
          path: wishlist,
          builder: (context, state) => const WishlistPage(),
        ),
        GoRoute(
          path: followingStores,
          builder: (context, state) => const FollowingStoresPage(),
        ),
        GoRoute(
          path: recentlyViewed,
          builder: (context, state) => const RecentlyViewedPage(),
        ),
        GoRoute(
          path: addresses,
          builder: (context, state) => const SavedAddressesPage(),
        ),
        GoRoute(
          path: coupons,
          builder: (context, state) => const CouponsPage(),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const BuyerSettingsPage(),
        ),
        // Seller routes with shell navigation
        ShellRoute(
          builder: (context, state, child) => SellerShell(child: child),
          routes: [
            GoRoute(
              path: sellerDashboard,
              builder: (context, state) => const SellerDashboard(),
            ),
            GoRoute(
              path: sellerOrders,
              builder: (context, state) => const SellerOrdersPage(),
            ),
            GoRoute(
              path: sellerProducts,
              builder: (context, state) => const SellerProductsPage(),
            ),
            GoRoute(
              path: sellerAccount,
              builder: (context, state) => const SellerAccountPage(),
            ),
            GoRoute(
              path: sellerAnalytics,
              builder: (context, state) => const SellerAnalyticsPage(),
            ),
          ],
        ),
        // Add product — full-screen, outside shell so no bottom nav bar
        GoRoute(
          path: sellerAddProduct,
          builder: (context, state) => const SellerAddProductPage(),
        ),
        GoRoute(
          path: '/seller/products/:productId/edit',
          builder: (context, state) {
            final id = state.pathParameters['productId'] ?? '';
            return SellerEditProductPage(productId: id);
          },
        ),
        GoRoute(
          path: sellerEditProfile,
          builder: (context, state) {
            final initial = state.extra is SellerProfileFormData
                ? state.extra! as SellerProfileFormData
                : const SellerProfileFormData();
            return SellerEditProfilePage(initial: initial);
          },
        ),
        GoRoute(
          path: sellerInsightsHub,
          builder: (context, state) {
            final tab = state.uri.queryParameters['tab'];
            final index = tab == 'reviews' ? 1 : 0;
            return SellerInsightsHubPage(initialTabIndex: index);
          },
        ),
        GoRoute(
          path: sellerInsights,
          redirect: (_, __) => sellerInsightsHub,
        ),
        GoRoute(
          path: sellerFeedback,
          redirect: (_, __) => '$sellerInsightsHub?tab=reviews',
        ),
        GoRoute(
          path: sellerShopSettings,
          builder: (context, state) => const SellerShopSettingsPage(),
        ),
        GoRoute(
          path: sellerWallet,
          builder: (context, state) => const SellerWalletPage(),
        ),
        GoRoute(
          path: sellerRefunds,
          builder: (context, state) => const SellerRefundsPage(),
        ),
        GoRoute(
          path: sellerCoupons,
          builder: (context, state) => const SellerCouponsPage(),
        ),
        ShellRoute(
          builder: (context, state, child) => SellerBrowseShell(child: child),
          routes: [
            GoRoute(
              path: sellerBrowse,
              builder: (context, state) =>
                  const HomePage(hideMessagingHeader: true),
            ),
            GoRoute(
              path: sellerBrowseSearch,
              builder: (context, state) => SearchScreen(
                initialCategoryId: state.uri.queryParameters['category'],
              ),
            ),
            GoRoute(
              path: sellerBrowseCart,
              builder: (context, state) => const CartScreen(),
            ),
          ],
        ),
        // Settings — full-screen, outside shell
        GoRoute(
          path: sellerSettings,
          builder: (context, state) => const SellerSettingsPage(),
        ),
        // Rider routes with shell navigation
        ShellRoute(
          builder: (context, state, child) => RiderShell(child: child),
          routes: [
            GoRoute(
              path: riderDashboard,
              builder: (context, state) => const RiderDashboard(),
            ),
            GoRoute(
              path: riderDeliveries,
              builder: (context, state) => const RiderDeliveriesPage(),
            ),
            GoRoute(
              path: riderEarnings,
              builder: (context, state) => const RiderEarningsPage(),
            ),
            GoRoute(
              path: riderHistory,
              builder: (context, state) => const RiderHistoryPage(),
            ),
            GoRoute(
              path: riderProfile,
              builder: (context, state) => const RiderProfilePage(),
            ),
          ],
        ),
        GoRoute(
          path: riderSettings,
          builder: (context, state) => const RiderSettingsPage(),
        ),
        GoRoute(
          path: adminDashboard,
          builder: (context, state) => const AdminDashboard(),
        ),
        GoRoute(
          path: chat,
          builder: (context, state) => const ChatListPage(),
        ),
        GoRoute(
          path: '$chat/:conversationId',
          builder: (context, state) {
            final id = state.pathParameters['conversationId'] ?? '';
            return ChatThreadPage(conversationId: id);
          },
        ),
      ],
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'seller':
        return UserRole.seller;
      case 'rider':
        return UserRole.rider;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.buyer;
    }
  }

  /// Returns the correct dashboard route for a given role.
  static String _dashboardForRole(UserRole? role, {bool isVerified = true}) {
    switch (role) {
      case UserRole.seller:
        return isVerified ? sellerDashboard : sellerAccount;
      case UserRole.rider:
        return riderDashboard;
      case UserRole.admin:
        return adminDashboard;
      default:
        return home;
    }
  }
}
