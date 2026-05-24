import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routes/app_router.dart';
import '../../../data/models/notification_model.dart';

void navigateFromNotification(BuildContext context, AppNotification n) {
  final page = (n.page ?? '').trim().toLowerCase();

  switch (page) {
    case '/orders':
      context.go('${AppRouter.buyerDashboard}?tab=orders');
      break;
    case '/buyer':
    case '/buyer/profile':
      context.go(AppRouter.buyerDashboard);
      break;
    case '/seller':
    case '/seller/dashboard':
      context.go(AppRouter.sellerDashboard);
      break;
    case '/seller/products':
      context.go(AppRouter.sellerProducts);
      break;
    case '/rider/dashboard':
      context.go(AppRouter.riderDashboard);
      break;
    default:
      break;
  }
}
