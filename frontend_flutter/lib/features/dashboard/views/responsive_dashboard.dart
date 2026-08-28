import 'package:flutter/material.dart';
import 'desktop_dashboard.dart';
import 'tablet_dashboard.dart';
import 'mobile_dashboard.dart';

class ResponsiveDashboard extends StatelessWidget {
  const ResponsiveDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 1024) {
          return const DesktopDashboard();
        } else if (constraints.maxWidth > 650) {
          return const TabletDashboard();
        } else {
          return const MobileDashboard();
        }
      },
    );
  }
}
