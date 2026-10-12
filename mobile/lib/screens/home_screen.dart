import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'ai_chat_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';
import 'quiz_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  int _profileRevision = 0;
  Map<String, dynamic>? _profileData;
  bool _hasShownNoLecturesNotice = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final response = await ApiClient.instance.get(AppConstants.meUrl);
    if (!mounted) return;

    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }

    if (response.isSuccess && response.body is Map<String, dynamic>) {
      final profileData = response.body as Map<String, dynamic>;
      setState(() {
        _profileData = profileData;
      });
    }

    final academicYear =
        int.tryParse(_profileData?['academic_year']?.toString() ?? '') ??
        context.read<AuthProvider>().user?.academicYear;
    if (academicYear == 1 || academicYear == 3 || academicYear == 4) {
      _showNoLecturesNotice();
    }
  }

  void _showNoLecturesNotice() {
    if (_hasShownNoLecturesNotice) return;
    _hasShownNoLecturesNotice = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تنبيه'),
          content: const Text('لا توجد أي محاضرات الآن لهذه الفرقة.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final academicYear =
        int.tryParse(
          _profileData?['academic_year']?.toString() ??
              user?.academicYear?.toString() ??
              '1',
        ) ??
        1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              Color(0xFF111A2D),
            ],
          ),
        ),
        child: IndexedStack(
          index: _currentTabIndex,
          children: [
            // 0 - الاختبار
            const QuizSetupScreen(),
            // 1 - المساعد الذكي
            const AIChatScreen(),
            // 2 - المتصدرين
            LeaderboardScreen(initialYear: academicYear),
            // 3 - ملفي
            ProfileScreen(key: ValueKey(_profileRevision)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(220),
          border: Border(
            top: BorderSide(color: AppColors.border.withAlpha(180), width: 1),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, -8),
              blurRadius: 20,
            ),
          ],
        ),
        child: NavigationBar(
          height: 72,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primaryContainer,
          shadowColor: Colors.transparent,
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentTabIndex = index;
              if (index == 3) _profileRevision++;
            });
            if (index == 3) {
              _loadProfile();
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz_rounded),
              label: 'اختبار',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'المساعد',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard_rounded),
              label: 'المتصدرون',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'ملفي',
            ),
          ],
        ),
      ),
    );
  }
}
