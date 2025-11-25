// lib/screens/main_layout.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_theme.dart';
import 'home_page.dart';
import 'patient_list_page.dart';
import 'team_management_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;
  late AnimationController _navAnimationController;
  late Animation<double> _navSlideAnimation;

  static const List<_NavItem> _navItems = [
    _NavItem(
      icon: Icons.dashboard_rounded,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
      color: AppTheme.primaryBlue,
    ),
    _NavItem(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'Pacientes',
      color: AppTheme.accentTeal,
    ),
    _NavItem(
      icon: Icons.group_outlined,
      activeIcon: Icons.group_rounded,
      label: 'Equipe',
      color: AppTheme.successGreen,
    ),
  ];

  static final List<Widget> _pages = <Widget>[
    const HomePage(),
    const PatientListPage(),
    const TeamManagementPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _navAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _navSlideAnimation = Tween<double>(
      begin: 100,
      end: 0,
    ).animate(CurvedAnimation(
      parent: _navAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Inicia a animação da barra de navegação
    Future.delayed(const Duration(milliseconds: 500), () {
      _navAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _navAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      // Feedback tátil
      HapticFeedback.lightImpact();

      setState(() {
        _selectedIndex = index;
      });

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralGray50,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: _navSlideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _navSlideAnimation.value),
            child: _buildModernBottomNavBar(),
          );
        },
      ),
    );
  }

  Widget _buildModernBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.neutralGray300.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return _buildNavItem(item, index, isSelected);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: isSelected ? 1 : 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [item.color.withOpacity(0.2), item.color.withOpacity(0.1)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? Border.all(color: item.color.withOpacity(0.3), width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isSelected ? LinearGradient(
                      colors: [item.color, item.color.withOpacity(0.8)],
                    ) : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? Colors.white : AppTheme.neutralGray400,
                    size: 20,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(
                    width: isSelected ? 8 + (item.label.length * 7.0) : 0,
                    child: isSelected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: item.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.clip,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Classe auxiliar para definir itens da navegação
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}