import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import '../screens/home_page.dart';
import '../screens/message_page.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  late int _selectedIndex;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const HomePage(),
      const _OffersPlaceHolder(),
      const MessagePage(),
      const _SettingsPlaceholder(),
    ];
    _selectedIndex = _normalizeIndex(widget.initialIndex);
  }

  int _normalizeIndex(int index) {
    if (index < 0) {
      return 0;
    }
    if (index >= _pages.length) {
      return _pages.length - 1;
    }
    return index;
  }

  void _handleTabChange(int index) {
    if (_selectedIndex == index) {
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: GNav(
            gap: 8,
            selectedIndex: _selectedIndex,
            onTabChange: _handleTabChange,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            tabs: const <GButton>[
              GButton(icon: Icons.home, text: 'Home'),
              GButton(icon: Icons.local_offer, text: 'Offers'),
              GButton(icon: Icons.message, text: 'Messages'),
              GButton(icon: Icons.settings, text: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Profile coming soon!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _OffersPlaceHolder extends StatelessWidget {
  const _OffersPlaceHolder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Offers coming soon!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
