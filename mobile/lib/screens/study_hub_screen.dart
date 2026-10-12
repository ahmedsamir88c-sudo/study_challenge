import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import 'quiz_screen.dart';
import 'quiz_setup_screen.dart';

class StudyHubScreen extends StatefulWidget {
  const StudyHubScreen({super.key});

  @override
  State<StudyHubScreen> createState() => _StudyHubScreenState();
}

class _StudyHubScreenState extends State<StudyHubScreen> {
  Map<String, dynamic> _challenge = {};
  List<Map<String, dynamic>> _reviewItems = [];
  List<Map<String, dynamic>> _plans = [];
  List<Map<String, dynamic>> _subjects = [];
  Map<String, dynamic> _report = {};
  Map<String, dynamic> _preferences = {};
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  int _reportDays = 7;
  bool _loading = true;
  String? _error;
  final Set<int> _revealedReviews = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _asMaps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : [];

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final responses = await Future.wait([
      ApiClient.instance.get(AppConstants.dailyChallengeUrl),
      ApiClient.instance.get(AppConstants.smartReviewUrl),
      ApiClient.instance.get(AppConstants.studyPlansUrl),
      ApiClient.instance.get(
        '${AppConstants.studyReportsUrl}?days=$_reportDays',
      ),
      ApiClient.instance.get(AppConstants.notificationsUrl),
      ApiClient.instance.get(AppConstants.studentPreferencesUrl),
      ApiClient.instance.get(AppConstants.studentAcademicHierarchyUrl),
    ]);
    if (!mounted) return;
    if (responses.any((response) => response.isAuthError)) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    final failed = responses
        .where((response) => !response.isSuccess)
        .firstOrNull;
    if (failed != null) {
      setState(() {
        _loading = false;
        _error = failed.errorMessage;
      });
      return;
    }
    final reviewBody = responses[1].body is Map
        ? Map<String, dynamic>.from(responses[1].body as Map)
        : <String, dynamic>{};
    final notificationBody = responses[4].body is Map
        ? Map<String, dynamic>.from(responses[4].body as Map)
        : <String, dynamic>{};
    final hierarchyBody = responses[6].body is Map
        ? Map<String, dynamic>.from(responses[6].body as Map)
        : <String, dynamic>{};
    setState(() {
      _challenge = responses[0].body is Map
          ? Map<String, dynamic>.from(responses[0].body as Map)
          : {};
      _reviewItems = _asMaps(reviewBody['results']);
      _plans = _asMaps(responses[2].body);
      _report = responses[3].body is Map
          ? Map<String, dynamic>.from(responses[3].body as Map)
          : {};
      _notifications = _asMaps(notificationBody['results']);
      _unreadCount = notificationBody['unread_count'] is int
          ? notificationBody['unread_count'] as int
          : 0;
      _preferences = responses[5].body is Map
          ? Map<String, dynamic>.from(responses[5].body as Map)
          : {};
      _subjects = _asMaps(hierarchyBody['subjects']);
      _loading = false;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _startDailyChallenge() async {
    final quiz = _challenge['quiz'];
    if (quiz is Map) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizScreen(quizData: Map<String, dynamic>.from(quiz)),
        ),
      );
      if (mounted) _load();
      return;
    }
    if (_challenge['started'] == true || _challenge['completed'] == true) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuizSetupScreen(isDailyChallenge: true),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _markReviewed(Map<String, dynamic> item) async {
    final id = item['id'];
    final response = await ApiClient.instance.post(
      AppConstants.smartReviewMarkUrl(id),
      const {},
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      await _load();
    } else {
      _showError(response.errorMessage);
    }
  }

  Future<void> _savePlan({
    Map<String, dynamic>? plan,
    required String title,
    required String minutes,
    required String sessions,
    required String startDate,
    required String endDate,
    required String notes,
    int? subjectId,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'target_minutes_per_day': int.tryParse(minutes),
      'sessions_per_week': int.tryParse(sessions),
      'start_date': startDate.trim(),
      'end_date': endDate.trim().isEmpty ? null : endDate.trim(),
      'notes': notes.trim(),
      'subject': subjectId,
    };
    final response = plan == null
        ? await ApiClient.instance.post(AppConstants.studyPlansUrl, body)
        : await ApiClient.instance.patch(
            AppConstants.studyPlanUrl(plan['id']),
            body,
          );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      Navigator.of(context).pop();
      await _load();
    } else {
      _showError(response.errorMessage);
    }
  }

  Future<void> _showPlanDialog({Map<String, dynamic>? plan}) async {
    final titleController = TextEditingController(
      text: plan?['title']?.toString() ?? '',
    );
    final minutesController = TextEditingController(
      text: plan?['target_minutes_per_day']?.toString() ?? '30',
    );
    final sessionsController = TextEditingController(
      text: plan?['sessions_per_week']?.toString() ?? '5',
    );
    final startController = TextEditingController(
      text:
          plan?['start_date']?.toString() ??
          DateTime.now().toIso8601String().substring(0, 10),
    );
    final endController = TextEditingController(
      text: plan?['end_date']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: plan?['notes']?.toString() ?? '',
    );
    int? subjectId = plan?['subject'] as int?;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(plan == null ? 'إنشاء خطة مذاكرة' : 'تعديل الخطة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'اسم الخطة'),
                ),
                DropdownButtonFormField<int?>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(
                    labelText: 'المادة (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('كل المواد'),
                    ),
                    ..._subjects.map(
                      (subject) => DropdownMenuItem<int?>(
                        value: subject['id'] as int,
                        child: Text(subject['name']?.toString() ?? ''),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => subjectId = value),
                ),
                TextField(
                  controller: minutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'دقائق المذاكرة يوميًا',
                  ),
                ),
                TextField(
                  controller: sessionsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'جلسات أسبوعيًا',
                  ),
                ),
                TextField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ البداية (YYYY-MM-DD)',
                  ),
                ),
                TextField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'تاريخ النهاية (اختياري)',
                  ),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => _savePlan(
                plan: plan,
                title: titleController.text,
                minutes: minutesController.text,
                sessions: sessionsController.text,
                startDate: startController.text,
                endDate: endController.text,
                notes: notesController.text,
                subjectId: subjectId,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    minutesController.dispose();
    sessionsController.dispose();
    startController.dispose();
    endController.dispose();
    notesController.dispose();
  }

  Future<void> _deletePlan(Map<String, dynamic> plan) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الخطة'),
        content: Text('هل تريد حذف "${plan['title']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    final response = await ApiClient.instance.delete(
      AppConstants.studyPlanUrl(plan['id']),
    );
    if (!mounted) return;
    if (response.isSuccess) {
      await _load();
    } else if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else {
      _showError(response.errorMessage);
    }
  }

  Future<void> _setPlanActive(Map<String, dynamic> plan, bool active) async {
    final response = await ApiClient.instance.patch(
      AppConstants.studyPlanUrl(plan['id']),
      {'is_active': active},
    );
    if (!mounted) return;
    if (response.isSuccess) {
      await _load();
    } else if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else {
      _showError(response.errorMessage);
    }
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            children: [
              ListTile(
                title: const Text('الإشعارات'),
                subtitle: Text('غير المقروء: $_unreadCount'),
                trailing: TextButton(
                  onPressed: _unreadCount == 0
                      ? null
                      : () async {
                          final response = await ApiClient.instance.post(
                            AppConstants.notificationsReadAllUrl,
                            const {},
                          );
                          if (!mounted || !sheetContext.mounted) return;
                          if (response.isAuthError) {
                            context.read<AuthProvider>().forceLogout();
                          } else if (response.isSuccess) {
                            Navigator.pop(sheetContext);
                            _load();
                          } else {
                            _showError(response.errorMessage);
                          }
                        },
                  child: const Text('تحديد الكل كمقروء'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(child: Text('لا توجد إشعارات بعد.'))
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return ListTile(
                            leading: Icon(
                              notification['is_read'] == true
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                              color: notification['is_read'] == true
                                  ? AppColors.textMuted
                                  : AppColors.secondary,
                            ),
                            title: Text(
                              notification['title']?.toString() ?? 'إشعار',
                            ),
                            subtitle: Text(
                              notification['body']?.toString() ?? '',
                            ),
                            onTap: notification['is_read'] == true
                                ? null
                                : () async {
                                    final response = await ApiClient.instance
                                        .post(
                                          AppConstants.notificationReadUrl(
                                            notification['id'],
                                          ),
                                          const {},
                                        );
                                    if (!mounted || !sheetContext.mounted) {
                                      return;
                                    }
                                    if (response.isAuthError) {
                                      context
                                          .read<AuthProvider>()
                                          .forceLogout();
                                    } else if (response.isSuccess) {
                                      Navigator.pop(sheetContext);
                                      _load();
                                    } else {
                                      _showError(response.errorMessage);
                                    }
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPreferences() async {
    final studyGoal = TextEditingController(
      text: _preferences['study_goal_minutes']?.toString() ?? '60',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إعدادات الدراسة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _preferenceSwitch(
                'تفعيل الإشعارات',
                'notifications_enabled',
                setDialogState,
              ),
              _preferenceSwitch(
                'تذكير التحدي اليومي',
                'daily_challenge_reminders',
                setDialogState,
              ),
              _preferenceSwitch(
                'تقارير التقدم الأسبوعية',
                'weekly_progress_reports',
                setDialogState,
              ),
              TextField(
                controller: studyGoal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'هدف المذاكرة اليومي (دقيقة)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                final goal = int.tryParse(studyGoal.text);
                if (goal == null || goal < 5 || goal > 600) {
                  _showError('هدف الدراسة يجب أن يكون بين 5 و600 دقيقة.');
                  return;
                }
                final updated = {
                  'notifications_enabled':
                      _preferences['notifications_enabled'] == true,
                  'daily_challenge_reminders':
                      _preferences['daily_challenge_reminders'] == true,
                  'weekly_progress_reports':
                      _preferences['weekly_progress_reports'] == true,
                  'study_goal_minutes': goal,
                };
                final response = await ApiClient.instance.patch(
                  AppConstants.studentPreferencesUrl,
                  updated,
                );
                if (!mounted || !dialogContext.mounted) return;
                if (response.isAuthError) {
                  context.read<AuthProvider>().forceLogout();
                } else if (response.isSuccess) {
                  setState(
                    () => _preferences = Map<String, dynamic>.from(
                      response.body as Map,
                    ),
                  );
                  Navigator.pop(dialogContext);
                } else {
                  _showError(response.errorMessage);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    studyGoal.dispose();
  }

  Widget _preferenceSwitch(
    String label,
    String key,
    StateSetter setDialogState,
  ) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: _preferences[key] == true,
    onChanged: (value) =>
        setDialogState(() => _preferences = {..._preferences, key: value}),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('دراستي'),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: _openNotifications,
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: _openPreferences,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'التحدي اليومي'),
            Tab(text: 'المراجعة الذكية'),
            Tab(text: 'خطة الدراسة'),
            Tab(text: 'التقارير'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorView()
          : TabBarView(
              children: [
                _challengeView(),
                _reviewView(),
                _plansView(),
                _reportView(),
              ],
            ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );

  Widget _challengeView() {
    final completed = _challenge['completed'] == true;
    final started = _challenge['started'] == true;
    final bonus = _challenge['bonus_xp'] ?? 25;
    final goal = _challenge['goal_questions'] ?? 10;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: AppColors.secondary,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تحدي ${_challenge['date'] ?? ''}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    completed
                        ? 'أكملت التحدي بنتيجة ${_challenge['score']}/${_challenge['total_questions']}.'
                        : 'أجب عن $goal سؤالًا لتحصل على $bonus XP إضافية.',
                  ),
                  if (started && !completed) ...[
                    const SizedBox(height: 8),
                    Text(
                      'المادة: ${_challenge['subject']} • المحاضرة ${_challenge['lecture']}',
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: completed ? null : _startDailyChallenge,
                      icon: Icon(
                        completed
                            ? Icons.check_circle_outline
                            : started
                            ? Icons.play_arrow
                            : Icons.flag_outlined,
                      ),
                      label: Text(
                        completed
                            ? 'تم إنجاز تحدي اليوم'
                            : started
                            ? 'متابعة التحدي'
                            : 'ابدأ التحدي',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _infoCard(
            'كيف يعمل التحدي؟',
            'اختر المادة والمحاضرة، ثم أكمل اختبارًا من 10 أسئلة. '
                'تُحسب الدرجة ونقاط الخبرة على الخادم، وتُضاف مكافأة التحدي مرة واحدة.',
            Icons.info_outline,
          ),
        ],
      ),
    );
  }

  Widget _reviewView() {
    final dueItems = _reviewItems
        .where((item) => item['reviewed_at'] == null)
        .toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(
            'بحاجة إلى مراجعة: ${dueItems.length}',
            'تظهر هنا الأسئلة التي أخطأت فيها في اختباراتك السابقة.',
            Icons.psychology_outlined,
          ),
          if (_reviewItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('لا توجد أسئلة للمراجعة بعد. استمر في الاختبارات!'),
            ),
          ..._reviewItems.map(_reviewCard),
        ],
      ),
    );
  }

  Widget _reviewCard(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final revealed = _revealedReviews.contains(id);
    final options = item['options'] is List
        ? item['options'] as List
        : const [];
    final answerIndex = item['correct_index'] as int? ?? -1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item['subject'] ?? ''} • محاضرة ${item['lecture'] ?? ''}',
              style: const TextStyle(color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Text(item['question']?.toString() ?? ''),
            if (revealed) ...[
              const SizedBox(height: 8),
              if (answerIndex >= 0 && answerIndex < options.length)
                Text(
                  'الإجابة: ${options[answerIndex]}',
                  style: const TextStyle(color: AppColors.success),
                ),
              if (item['explanation']?.toString().isNotEmpty == true)
                Text(item['explanation'].toString()),
            ],
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    if (revealed) {
                      _revealedReviews.remove(id);
                    } else {
                      _revealedReviews.add(id);
                    }
                  }),
                  child: Text(revealed ? 'إخفاء الإجابة' : 'إظهار الإجابة'),
                ),
                if (item['reviewed_at'] == null)
                  FilledButton.tonal(
                    onPressed: () => _markReviewed(item),
                    child: const Text('تمت المراجعة'),
                  )
                else
                  Text('تمت المراجعة ${item['review_count']} مرة'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _plansView() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => _showPlanDialog(),
          icon: const Icon(Icons.add),
          label: const Text('إنشاء خطة مذاكرة'),
        ),
        const SizedBox(height: 12),
        if (_plans.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('لم تنشئ خطة بعد. حدد هدفك اليومي وابدأ.'),
          ),
        ..._plans.map(
          (plan) => Card(
            child: ListTile(
              title: Text(plan['title']?.toString() ?? ''),
              subtitle: Text(
                '${plan['subject_name']?.toString().isNotEmpty == true ? '${plan['subject_name']} • ' : ''}'
                '${plan['target_minutes_per_day']} دقيقة يوميًا • '
                '${plan['sessions_per_week']} جلسات أسبوعيًا\n'
                '${plan['start_date']}${plan['end_date'] == null ? '' : ' — ${plan['end_date']}'}',
              ),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showPlanDialog(plan: plan);
                  if (value == 'delete') _deletePlan(plan);
                  if (value == 'toggle') {
                    _setPlanActive(plan, plan['is_active'] != true);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      plan['is_active'] == true ? 'إيقاف الخطة' : 'تفعيل الخطة',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _reportView() {
    final summary = _report['summary'] is Map
        ? Map<String, dynamic>.from(_report['summary'] as Map)
        : const <String, dynamic>{};
    final subjects = _asMaps(_report['subjects']);
    final daily = _asMaps(_report['daily']);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _reportDays,
            decoration: const InputDecoration(labelText: 'الفترة'),
            items: const [
              DropdownMenuItem(value: 7, child: Text('آخر 7 أيام')),
              DropdownMenuItem(value: 30, child: Text('آخر 30 يومًا')),
              DropdownMenuItem(value: 90, child: Text('آخر 90 يومًا')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _reportDays = value);
              _load();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metric('اختبارات', summary['quizzes'] ?? 0),
              _metric('أسئلة', summary['questions'] ?? 0),
              _metric('الدقة', '${summary['accuracy_percent'] ?? 0}%'),
              _metric('XP', summary['xp'] ?? 0),
              _metric('أيام نشطة', summary['active_days'] ?? 0),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'التقدم حسب المادة',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (subjects.isEmpty) const Text('لا توجد نتائج خلال هذه الفترة.'),
          ...subjects.map(
            (subject) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(subject['subject']?.toString() ?? ''),
              subtitle: Text(
                '${subject['quizzes']} اختبارات • '
                '${subject['correct']}/${subject['questions']} إجابة صحيحة',
              ),
              trailing: Text('${subject['xp'] ?? 0} XP'),
            ),
          ),
          const SizedBox(height: 12),
          Text('النشاط اليومي', style: Theme.of(context).textTheme.titleMedium),
          if (daily.isEmpty) const Text('لا يوجد نشاط مسجل في هذه الفترة.'),
          ...daily.map(
            (day) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(day['date']?.toString() ?? ''),
              trailing: Text('${day['quizzes']} اختبارات • ${day['xp']} XP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, Object value) => SizedBox(
    width: 104,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  Widget _infoCard(String title, String description, IconData icon) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.secondary),
      title: Text(title),
      subtitle: Text(description),
    ),
  );
}
