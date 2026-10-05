import 'package:flutter/material.dart';

import '../core/app_theme.dart';

import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<Map<String, dynamic>> sources;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
    this.sources = const [],
  }) : time = time ?? DateTime.now();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  late final List<String> _availableSubjects;
  String? _selectedSubject;
  int _selectedLecture = 1;
  String _selectedSummaryType = 'quick';
  bool _isTyping = false;
  bool _isSummarizing = false;

  static const _summaryTypes = {
    'quick': 'سريع',
    'detailed': 'تفصيلي',
    'exam': 'للامتحان',
    'key_points': 'نقاط مهمة',
    'definitions': 'تعريفات',
  };

  final List<String> _quickPrompts = [
    'اشرح مفهومًا من المحاضرة',
    'لخص أهم أفكار المادة',
    'راجع تعريفًا من المحتوى',
  ];

  @override
  void initState() {
    super.initState();
    final academicYear = context.read<AuthProvider>().user?.academicYear ?? 1;
    _availableSubjects = AppConstants.academicYearSubjects[academicYear] ?? [];
    _selectedSubject = _availableSubjects.isEmpty
        ? null
        : _availableSubjects.first;
    _messages.add(
      _ChatMessage(
        text: 'اختر المادة واسأل عن محتوى محاضراتها وملفاتها الدراسية.',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? customText]) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty || _isTyping || _isSummarizing) return;
    if (_selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مواد متاحة لهذه الفرقة.')),
      );
      return;
    }

    if (customText == null) {
      _textController.clear();
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final response = await ApiClient.instance.post(AppConstants.aiChatUrl, {
        'message': text,
        'subject': _selectedSubject,
      });

      String botReply = 'عذراً، حدث خطأ في معالجة طلبك.';
      List<Map<String, dynamic>> sources = [];
      if (response.isSuccess && response.body is Map) {
        botReply = response.body['reply']?.toString() ?? botReply;
        final rawSources = response.body['sources'];
        if (rawSources is List) {
          sources = rawSources
              .whereType<Map>()
              .map((source) => Map<String, dynamic>.from(source))
              .toList();
        }
      } else {
        botReply = response.errorMessage;
      }

      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(text: botReply, isUser: false, sources: sources),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: AppConstants.connectionErrorMessage,
              isUser: false,
            ),
          );
          _isTyping = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _generateSummary() async {
    if (_selectedSubject == null || _isTyping || _isSummarizing) return;

    setState(() => _isSummarizing = true);
    try {
      final response = await ApiClient.instance.post(
        AppConstants.aiSummaryUrl,
        {
          'subject': _selectedSubject,
          'lecture': _selectedLecture,
          'summary_type': _selectedSummaryType,
        },
        timeout: const Duration(seconds: 120),
      );
      if (!mounted) return;

      if (response.isSuccess && response.body is Map) {
        final summary = response.body['summary']?.toString() ?? '';
        final rawSources = response.body['sources'];
        final sources = rawSources is List
            ? rawSources
                  .whereType<Map>()
                  .map((source) => Map<String, dynamic>.from(source))
                  .toList()
            : <Map<String, dynamic>>[];
        setState(() {
          _messages.add(
            _ChatMessage(text: summary, isUser: false, sources: sources),
          );
        });
        _scrollToBottom();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(response.errorMessage)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppConstants.connectionErrorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSummarizing = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppColors.secondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المساعد الذكي للدراسة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'مساعد أكاديمي حسب محتوى مقرراتك',
                  style: TextStyle(color: AppColors.success, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSubjectSelector(),
          _buildSummaryControls(),

          // ─── Messages List ────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // ─── Typing Indicator ────────────────────────────
          if (_isTyping || _isSummarizing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isSummarizing
                        ? 'جاري تلخيص المحاضرة...'
                        : 'جاري تحليل محتوى المادة...',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // ─── Quick Prompts ───────────────────────────────
          if (_messages.length <= 2)
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return ActionChip(
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                    label: Text(
                      _quickPrompts[i],
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: () => _sendMessage(_quickPrompts[i]),
                  );
                },
              ),
            ),

          const SizedBox(height: 8),

          // ─── Input Bar ───────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                        ),
                        textDirection: TextDirection.rtl,
                        decoration: const InputDecoration(
                          hintText: 'اسأل عن محاضرات المادة المختارة...',
                          hintTextDirection: TextDirection.rtl,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'إرسال السؤال',
                    onPressed: _isTyping || _isSummarizing
                        ? null
                        : () => _sendMessage(),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: AppColors.secondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'المادة',
            style: TextStyle(color: AppColors.textSubtle, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubject,
                isExpanded: true,
                hint: const Text('لا توجد مواد متاحة'),
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _availableSubjects
                    .map(
                      (subject) => DropdownMenuItem(
                        value: subject,
                        child: Text(
                          AppConstants.subjectLabels[subject] ?? subject,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isTyping || _isSummarizing
                    ? null
                    : (subject) {
                        if (subject == null || subject == _selectedSubject) {
                          return;
                        }
                        setState(() {
                          _selectedSubject = subject;
                          _selectedLecture = 1;
                          _messages
                            ..clear()
                            ..add(
                              _ChatMessage(
                                text:
                                    'تم اختيار $subject. اسأل عن محتوى محاضراتها وملفاتها.',
                                isUser: false,
                              ),
                            );
                        });
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryControls() {
    final lectureCount =
        AppConstants.subjectLectureCounts[_selectedSubject] ?? 0;
    if (lectureCount == 0) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: const Icon(Icons.summarize_outlined),
        title: const Text('تلخيص محاضرة'),
        subtitle: Text(
          'محاضرة $_selectedLecture • ${_summaryTypes[_selectedSummaryType]}',
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedLecture,
                  decoration: const InputDecoration(labelText: 'المحاضرة'),
                  items: List.generate(
                    lectureCount,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('محاضرة ${index + 1}'),
                    ),
                  ),
                  onChanged: _isTyping || _isSummarizing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedLecture = value);
                          }
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedSummaryType,
                  decoration: const InputDecoration(labelText: 'نوع الملخص'),
                  items: _summaryTypes.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _isTyping || _isSummarizing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedSummaryType = value);
                          }
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isTyping || _isSummarizing ? null : _generateSummary,
              icon: _isSummarizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isSummarizing ? 'جاري إعداد الملخص...' : 'إنشاء الملخص',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(18),
            topEnd: const Radius.circular(18),
            bottomStart: isUser
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomEnd: isUser
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          border: isUser ? null : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isUser ? AppColors.background : AppColors.text,
                fontSize: 14,
                height: 1.45,
                fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
              ),
              textDirection: Directionality.of(context),
            ),
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              const Text(
                'المصادر',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ...msg.sources.map((source) {
                final fileName = source['file_name']?.toString() ?? '';
                final lecture = source['lecture_number']?.toString();
                final page = source['page_number']?.toString();
                final sourceLabel = [
                  fileName,
                  if (lecture != null) 'محاضرة $lecture',
                  if (page != null) 'صفحة $page',
                ].join(' • ');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.description_outlined,
                        color: AppColors.secondary,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sourceLabel,
                          style: const TextStyle(
                            color: AppColors.textSubtle,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                '${msg.time.hour.toString().padLeft(2, '0')}:${msg.time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: isUser ? AppColors.textDisabled : AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
