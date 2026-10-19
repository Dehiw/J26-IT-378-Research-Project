import 'package:flutter/material.dart';

import '../utils/theme.dart';

class MainBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    backgroundColor: AppColors.bgPrimary,
    selectedItemColor: AppColors.hiveLow,
    unselectedItemColor: AppColors.textSecondary,
    showUnselectedLabels: true,
    selectedFontSize: 11,
    unselectedFontSize: 11,
    currentIndex: currentIndex,
    onTap: onTap,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
      BottomNavigationBarItem(
        icon: Icon(Icons.monitor_heart_outlined),
        label: 'Health',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.location_on_outlined),
        label: 'Relocate',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.graphic_eq_rounded),
        label: 'Acoustic',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.eco_outlined),
        label: 'Environment',
      ),
    ],
  );
}
