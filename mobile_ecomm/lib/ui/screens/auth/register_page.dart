import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/models/user_model.dart';

/// Register Page - Role Selection Redirect
/// Automatically redirects to role-specific registration pages
class RegisterPage extends ConsumerStatefulWidget {
  final UserRole role;

  const RegisterPage({
    super.key,
    this.role = UserRole.buyer,
  });

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  @override
  void initState() {
    super.initState();
    // Auto-redirect to role-specific registration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectToRoleRegistration();
    });
  }

  void _redirectToRoleRegistration() {
    switch (widget.role) {
      case UserRole.buyer:
        context.go(AppRouter.registerBuyer);
        break;
      case UserRole.seller:
        context.go(AppRouter.registerSeller);
        break;
      case UserRole.rider:
        context.go(AppRouter.registerRider);
        break;
      case UserRole.admin:
        context.go(AppRouter.login);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Redirecting...'),
          ],
        ),
      ),
    );
  }
}
