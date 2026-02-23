import 'package:flutter/material.dart';
import 'package:vortex/views/recent_view.dart';
import 'package:vortex/views/home_view.dart';

class MainWrapperView extends StatefulWidget {
  const MainWrapperView({Key? key}) : super(key: key);

  @override
  State<MainWrapperView> createState() => _MainWrapperViewState();
}

class _MainWrapperViewState extends State<MainWrapperView> {
  int _currentIndex = 1; // Start on 'Files' tab as per original plan

  final List<Widget> _pages = const [RecentView(), HomeView()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time),
            label: 'Recent',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Files'),
        ],
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
