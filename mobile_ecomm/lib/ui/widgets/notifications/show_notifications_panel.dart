import 'package:flutter/material.dart';
import 'notifications_panel.dart';

void showNotificationsPanel(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const NotificationsPanel(),
  );
}
