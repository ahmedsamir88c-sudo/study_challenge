import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../services/api_client.dart';
import '../widgets/app_components.dart';
import 'quiz_setup_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final int? initialYear;
  const LeaderboardScreen({super.key, this.initialYear});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // ثابت: الفرقة الثانية فقط
  static const int _fixedYear = 2;

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final url = '${AppConstants.leaderboardUrl}?year=$_fixedYear';
      final response = await ApiClient.instance.get(url);

      if (response.isSuccess &&
          response.body is Map &&
          response.body['leaderboard'] is List) {
        final list = response.body['leaderboard'] as List;
        setState(() {
          _students = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 24),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة المتصدرين',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الفرقة الثانية',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadLeaderboard,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Podium ──────────────────────────────────
                  _buildPodium(),
                  const SizedBox(height: 20),

                  // ─── Empty State ──────────────────────────────
                  if (_students.isEmpty) ...[
                    _buildEmptyNoticeCard(),
                    const SizedBox(height: 20),
                  ] else ...[
                    // ─── Ranking List ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ترتيب الفرقة الثانية',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_students.length} متسابق',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      _students.length,
                      (i) => _buildStudentTile(_students[i]),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  // ─── Podium ──────────────────────────────────────────────────
  Widget _buildPodium() {
    final first = _students.isNotEmpty ? _students[0] : null;
    final second = _students.length > 1 ? _students[1] : null;
    final third = _students.length > 2 ? _students[2] : null;

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
      color: AppColors.surfaceElevated,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Column(
        children: [
          // Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text(
                'منصة الصدارة — الفرقة الثانية',
                style: TextStyle(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Podium Places
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPodiumPlace(
                student: second,
                rank: 2,
                avatarColor: AppColors.accent,
                height: 120,
                icon: Icons.workspace_premium_rounded,
              ),
              _buildPodiumPlace(
                student: first,
                rank: 1,
                avatarColor: AppColors.accent,
                height: 155,
                isWinner: true,
                icon: Icons.military_tech_rounded,
              ),
              _buildPodiumPlace(
                student: third,
                rank: 3,
                avatarColor: AppColors.secondary,
                height: 100,
                icon: Icons.workspace_premium_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumPlace({
    required Map<String, dynamic>? student,
    required int rank,
    required Color avatarColor,
    required double height,
    required IconData icon,
    bool isWinner = false,
  }) {
    final hasStudent = student != null;
    final name = hasStudent
        ? (student['full_name'] ?? student['username'] ?? 'طالب')
        : 'شاغر';
    final xp = hasStudent ? (student['xp'] ?? student['xp_points'] ?? 0) : 0;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isWinner)
            const Icon(
              Icons.emoji_events_rounded,
              color: AppColors.accent,
              size: 30,
            )
          else
            Icon(icon, color: avatarColor, size: 22),
          const SizedBox(height: 6),

          CircleAvatar(
            radius: isWinner ? 28 : 24,
            backgroundColor: hasStudent
                ? avatarColor.withValues(alpha: 0.25)
                : AppColors.surfaceVariant,
            child: CircleAvatar(
              radius: isWinner ? 24 : 20,
              backgroundColor: hasStudent ? avatarColor : AppColors.border,
              child: hasStudent
                  ? Text(
                      name.toString().isNotEmpty
                          ? name.toString()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(height: 6),

          Text(
            name.toString(),
            style: TextStyle(
              color: hasStudent ? Colors.white : AppColors.textMuted,
              fontSize: 13,
              fontWeight: hasStudent ? FontWeight.bold : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),

          Text(
            hasStudent ? '$xp نقطة' : '0 نقطة',
            style: TextStyle(
              color: hasStudent ? avatarColor : AppColors.textDisabled,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            height: height,
            width: 72,
            decoration: BoxDecoration(
              color: avatarColor.withValues(alpha: hasStudent ? 0.18 : 0.06),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              border: Border.all(
                color: avatarColor.withValues(alpha: hasStudent ? 0.6 : 0.25),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '#$rank',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: hasStudent ? 0.95 : 0.6,
                    ),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  hasStudent ? 'متصدر' : 'متاح',
                  style: TextStyle(
                    color: avatarColor.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Empty State ──────────────────────────────────────────────
  Widget _buildEmptyNoticeCard() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.military_tech_outlined,
              color: AppColors.accent,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا يوجد متصدرين الآن',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'المراكز الثلاثة الأولى متاحة!\nابدأ الاختبار واحصل على نقاط لتكون الأول.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizSetupScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'ابدأ واكسب نقاط',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Student Tile ─────────────────────────────────────────────
  Widget _buildStudentTile(Map<String, dynamic> student) {
    final rank = student['rank'] as int? ?? 1;
    final name = student['full_name'] ?? student['username'] ?? 'طالب';
    final uid = student['university_id'] ?? '';
    final xp = student['xp'] ?? student['xp_points'] ?? 0;
    final isMe = student['is_current_user'] == true;

    Color rankColor = AppColors.textMuted;
    if (rank == 1) rankColor = AppColors.accent;
    if (rank == 2) rankColor = AppColors.secondary;
    if (rank == 3) rankColor = AppColors.textMuted;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: isMe ? AppColors.surfaceElevated : AppColors.surface,
      borderColor: isMe ? AppColors.primary : AppColors.border,
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryContainer,
            child: Text(
              name.toString().isNotEmpty
                  ? name.toString()[0].toUpperCase()
                  : 'U',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'أنت',
                          style: TextStyle(
                            color: AppColors.background,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: $uid',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Points
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.accent,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  '$xp',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
