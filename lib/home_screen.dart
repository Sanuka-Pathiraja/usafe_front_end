import 'package:flutter/material.dart';
import 'dart:async';
import 'config.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isPanic = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
             child: Container(
               decoration: const BoxDecoration(
                 gradient: RadialGradient(
                   center: Alignment(0, -0.4),
                   radius: 1.2,
                   colors: [AppColors.bgLight, AppColors.bgDark],
                 )
               ),
             ),
          ),
          SafeArea(
            child: IndexedStack(
              index: _index,
              children: [
                _buildHomeContent(),
                const Center(child: Text("Map Feature Coming Soon", style: TextStyle(color: Colors.white))),
                const ContactsScreen(),
                const ProfileScreen(), 
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // SAFE PILL
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.success.withOpacity(0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.circle, color: AppColors.success, size: 10),
            const SizedBox(width: 8),
            Text("Status: SAFE", style: TextStyle(color: AppColors.success.withOpacity(0.9), fontWeight: FontWeight.bold))
          ]),
        ),
        const Spacer(),
        // PULSING SOS BUTTON
        GestureDetector(
          onTap: () => setState(() => _isPanic = !_isPanic),
          child: Stack(alignment: Alignment.center, children: [
            ScaleTransition(scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController), child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.2)))), 
            Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: _isPanic ? [Colors.redAccent, Colors.red] : [AppColors.primary, Colors.cyan]), boxShadow: [BoxShadow(color: (_isPanic ? AppColors.alert : AppColors.primary).withOpacity(0.4), blurRadius: 30)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_isPanic ? Icons.notifications_active : Icons.touch_app, size: 48, color: Colors.white), Text(_isPanic ? "SOS ACTIVE" : "SOS", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))])),
          ]),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.9), borderRadius: BorderRadius.circular(25), border: Border.all(color: AppColors.glassBorder)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navIcon(Icons.shield, 0),
          _navIcon(Icons.map, 1),
          _navIcon(Icons.people, 2),
          _navIcon(Icons.person, 3),
        ],
      ),
    );
  }

  Widget _navIcon(IconData icon, int index) {
    final active = _index == index;
    return IconButton(
      icon: Icon(icon, color: active ? AppColors.primary : AppColors.textSub, size: 28),
      onPressed: () => setState(() => _index = index),
    );
  }
}