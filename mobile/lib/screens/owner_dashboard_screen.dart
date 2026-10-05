import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await ApiClient.instance.get(
      AppConstants.ownerDashboardUrl,
    );
    if (!mounted) return;

    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }

    if (response.isSuccess && response.body is Map) {
      setState(() {
        _dashboard = Map<String, dynamic>.from(response.body as Map);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _errorMessage = response.statusCode == 403
          ? 'ليس لديك صلاحية لعرض لوحة المالك.'
          : response.errorMessage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _dashboard?['metrics'] is Map
        ? Map<String, dynamic>.from(_dashboard!['metrics'] as Map)
        : const <String, dynamic>{};
    final owner = _dashboard?['owner'] is Map
        ? Map<String, dynamic>.from(_dashboard!['owner'] as Map)
        : const <String, dynamic>{};
    final displayName = owner['username']?.toString() ?? 'Owner';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('لوحة المالك'),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildWelcome(displayName),
            const SizedBox(height: 22),
            if (_isLoading && _dashboard == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _dashboard == null)
              _buildErrorState()
            else
              _buildMetrics(metrics),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(String displayName) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.admin_panel_settings_outlined, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحبًا بك',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, color: AppColors.secondary),
        ],
      ),
    );
  }

  Widget _buildMetrics(Map<String, dynamic> metrics) {
    final items = <({String title, String key, IconData icon})>[
      (
        title: 'إجمالي الطلاب',
        key: 'total_students',
        icon: Icons.people_outline,
      ),
      (
        title: 'طلاب نشطون',
        key: 'active_students',
        icon: Icons.verified_user_outlined,
      ),
      (title: 'المواد', key: 'total_subjects', icon: Icons.menu_book_outlined),
      (
        title: 'المحاضرات',
        key: 'total_lectures',
        icon: Icons.library_books_outlined,
      ),
      (title: 'الملفات', key: 'total_files', icon: Icons.folder_outlined),
      (title: 'الأسئلة', key: 'total_questions', icon: Icons.quiz_outlined),
      (
        title: 'الملخصات',
        key: 'total_summaries',
        icon: Icons.summarize_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final value = metrics[item.key] ?? 0;
            return AppMetricCard(
              title: item.title,
              value: value.toString(),
              icon: item.icon,
            );
          },
        );
      },
    );
  }

  Widget _buildErrorState() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 32,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'تعذر تحميل لوحة المالك.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSubtle),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
