import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/camera_server/presentation/pages/camera_server_page.dart';
import 'features/stream_client/presentation/pages/stream_client_page.dart';

class BabyMonitorApp extends StatelessWidget {
  const BabyMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baby Monitor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = const [
    CameraServerPage(),
    StreamClientPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            activeIcon: Icon(Icons.camera),
            label: 'Servidor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.connected_tv),
            activeIcon: Icon(Icons.connected_tv),
            label: 'Cliente',
          ),
        ],
      ),
    );
  }
}
