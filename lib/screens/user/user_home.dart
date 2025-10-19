import 'package:flutter/material.dart';
import 'package:medmind/screens/test_notification_screen.dart';
import 'package:medmind/screens/user/medicine/add_medicine.dart';
import '../../../core/constants.dart';

import 'medicine/medicine_list.dart';
import 'activity_screen.dart';
import 'notification_screen.dart';
import 'profile/profile_screen.dart';
import 'settings_screen.dart';

class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTab(),
    ActivityScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMedicineScreen()),
          );
        },
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            elevation: 0,
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home, 0),
                  _buildNavItem(Icons.bar_chart, 1),
                  const SizedBox(width: 48),
                  _buildNavItem(Icons.notifications, 2),
                  _buildNavItem(Icons.person, 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Icon(
          icon,
          size: 26,
          color: isSelected ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          "My Medicines",
          style: TextStyle(color: AppColors.textDark),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.textDark),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TestNotificationScreen()),
              );
            },
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: MedicineListScreen(),
      ),
    );
  }
}
