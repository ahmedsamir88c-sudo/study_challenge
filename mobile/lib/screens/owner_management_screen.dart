import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class OwnerManagementScreen extends StatefulWidget {
  const OwnerManagementScreen({super.key});

  @override
  State<OwnerManagementScreen> createState() => _OwnerManagementScreenState();
}

class _OwnerManagementScreenState extends State<OwnerManagementScreen> {
  List<Map<String, dynamic>> _years = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _lectures = [];
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _students = [];
  int? _selectedYear;
  int? _selectedSubject;
  bool _academicLoading = true;
  bool _studentsLoading = true;
  String _studentSearch = '';
  String _studentStatus = '';
  String _uploadMaterialType = 'lecture';
  final TextEditingController _sectionTitleController = TextEditingController();
  int _studentPage = 1;
  int _studentCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAcademicData();
    _loadStudents();
  }

  @override
  void dispose() {
    _sectionTitleController.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicData() async {
    setState(() {
      _academicLoading = true;
      _error = null;
    });
    final responses = await Future.wait([
      ApiClient.instance.get(AppConstants.academicYearsUrl),
      ApiClient.instance.get(AppConstants.academicSubjectsUrl),
      ApiClient.instance.get(AppConstants.academicMaterialsUrl),
    ]);
    if (!mounted) return;
    if (responses.any((response) => response.isAuthError)) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    final failed = responses.firstWhere(
      (response) => !response.isSuccess,
      orElse: () => responses.first,
    );
    if (responses.any((response) => !response.isSuccess)) {
      setState(() {
        _academicLoading = false;
        _error = failed.errorMessage;
      });
      return;
    }
    final years = _mapsFrom(responses[0].body);
    final subjects = _mapsFrom(responses[1].body);
    setState(() {
      _years = years;
      _subjects = subjects;
      _materials = _mapsFrom(responses[2].body);
      _selectedYear = years.any((year) => year['id'] == _selectedYear)
          ? _selectedYear
          : (years.isEmpty ? null : years.first['id'] as int?);
      _selectedSubject =
          _subjectsForSelectedYear.any(
            (subject) => subject['id'] == _selectedSubject,
          )
          ? _selectedSubject
          : (_subjectsForSelectedYear.isEmpty
                ? null
                : _subjectsForSelectedYear.first['id'] as int?);
      _academicLoading = false;
    });
    await _loadLectures();
  }

  List<Map<String, dynamic>> _mapsFrom(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : [];

  List<Map<String, dynamic>> get _subjectsForSelectedYear => _subjects
      .where(
        (subject) =>
            (subject['academic_year'] ?? subject['year_number'])?.toString() ==
            _selectedYear?.toString(),
      )
      .toList();

  Future<void> _loadLectures() async {
    final subjectId = _selectedSubject;
    if (subjectId == null) {
      if (mounted) setState(() => _lectures = []);
      return;
    }
    final response = await ApiClient.instance.get(
      '${AppConstants.academicLecturesUrl}?subject_id=$subjectId',
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    if (!response.isSuccess) {
      _showMessage(response.errorMessage);
      return;
    }
    final lectures = _mapsFrom(response.body);
    setState(() {
      _lectures = lectures;
      if (!_lectures.any((lecture) => lecture['id'] == _uploadLecture)) {
        _uploadLecture = null;
      }
    });
  }

  Future<void> _loadStudents() async {
    setState(() => _studentsLoading = true);
    final query = Uri(
      queryParameters: {
        'search': _studentSearch,
        if (_studentStatus.isNotEmpty) 'status': _studentStatus,
        'page': '$_studentPage',
        'page_size': '25',
      },
    ).query;
    final response = await ApiClient.instance.get(
      '${AppConstants.ownerStudentsUrl}?$query',
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    if (response.isSuccess && response.body is Map) {
      final body = Map<String, dynamic>.from(response.body as Map);
      setState(() {
        _students = _mapsFrom(body['results']);
        _studentCount = body['count'] is int ? body['count'] as int : 0;
        _studentsLoading = false;
      });
    } else {
      setState(() => _studentsLoading = false);
      _showMessage(response.errorMessage);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickAndUpload() async {
    if (_selectedSubject == null) {
      _showMessage('أنشئ أو اختر مادة أولاً.');
      return;
    }
    final sectionTitle = _sectionTitleController.text.trim();
    if (_uploadLecture == null) {
      _showMessage('اختر المحاضرة التي يتبعها الملف أولاً.');
      return;
    }
    if (_uploadMaterialType == 'section' && sectionTitle.isEmpty) {
      _showMessage('اكتب اسم السكشن قبل رفع الملف.');
      return;
    }
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'pptx', 'txt'],
      allowMultiple: true,
      withData: true,
    );
    if (selection == null || selection.files.isEmpty || !mounted) return;
    if (selection.files.any((file) => file.bytes == null)) {
      _showMessage('تعذرت قراءة أحد الملفات المحددة.');
      return;
    }
    final titleController = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رفع مواد دراسية'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'عنوان (اختياري عند رفع ملف واحد)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, titleController.text),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || !mounted) return;
    final files = selection.files
        .map(
          (file) => ApiFile(
            fieldName: 'files',
            filename: file.name,
            bytes: file.bytes!,
          ),
        )
        .toList();
    final response = await ApiClient.instance.postFiles(
      AppConstants.academicMaterialUploadUrl,
      fields: {
        'academic_year_id': '$_selectedYear',
        'subject_id': '$_selectedSubject',
        'lecture_id': '$_uploadLecture',
        'material_type': _uploadMaterialType,
        if (_uploadMaterialType == 'section') 'section_title': sectionTitle,
        if (title.trim().isNotEmpty) 'title': title.trim(),
      },
      files: files,
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      final errors = response.body is Map ? response.body['errors'] : null;
      _showMessage(
        errors is List && errors.isNotEmpty
            ? 'تم رفع بعض الملفات، وتعذر رفع: ${errors.join('، ')}'
            : 'تم رفع الملفات، ويجري تجهيزها للشرح وإنشاء الأسئلة.',
      );
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<void> _retryMaterial(Map<String, dynamic> material) async {
    final response = await ApiClient.instance.post(
      AppConstants.academicMaterialRetryUrl(material['id'] as int),
      const {},
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage('بدأت إعادة معالجة الملف.');
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<void> _downloadMaterial(Map<String, dynamic> material) async {
    final response = await ApiClient.instance.getFile(
      AppConstants.academicMaterialDownloadUrl(material['id'] as int),
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
      return;
    }
    final bytes = response.bytes;
    if (!response.isSuccess || bytes == null) {
      _showMessage(response.errorMessage);
      return;
    }
    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'حفظ الملف الدراسي',
      fileName: material['original_filename']?.toString() ?? 'study-material',
      bytes: bytes,
    );
    if (mounted && savedPath != null) {
      _showMessage('تم حفظ الملف.');
    }
  }

  Future<void> _replaceMaterial(Map<String, dynamic> material) async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'docx', 'pptx', 'txt'],
      withData: true,
    );
    final file = selection?.files.singleOrNull;
    if (file == null || file.bytes == null || !mounted) return;
    final response = await ApiClient.instance.postFiles(
      AppConstants.academicMaterialReplaceUrl(material['id'] as int),
      fields: const {},
      files: [
        ApiFile(fieldName: 'file', filename: file.name, bytes: file.bytes!),
      ],
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage('تم استبدال الملف، وهو ينتظر إعداد خدمة معالجة المحتوى.');
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    final confirmed = await _confirm(
      'حذف الملف',
      'هل تريد حذف "${material['title']}"؟',
    );
    if (!confirmed) return;
    final response = await ApiClient.instance.delete(
      AppConstants.academicMaterialUrl(material['id'] as int),
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage('تم حذف الملف.');
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<void> _changeStudentStatus(Map<String, dynamic> student) async {
    final currentlyActive = student['is_active'] == true;
    final confirmed = await _confirm(
      currentlyActive ? 'حظر الطالب' : 'إلغاء الحظر',
      currentlyActive
          ? 'سيُمنع ${student['full_name'] ?? student['username']} من استخدام الحساب.'
          : 'سيُعاد تفعيل حساب ${student['full_name'] ?? student['username']}.',
    );
    if (!confirmed) return;
    final response = await ApiClient.instance.post(
      AppConstants.ownerStudentStatusUrl(student['uid'] ?? student['id']),
      {'is_active': !currentlyActive, 'reason': 'إجراء من لوحة المالك'},
    );
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage(currentlyActive ? 'تم حظر الطالب.' : 'تم إلغاء حظر الطالب.');
      await _loadStudents();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنصة'),
        bottom: const TabBar(
          tabs: [
            Tab(
              icon: Icon(Icons.folder_open_outlined),
              text: 'المواد والملفات',
            ),
            Tab(icon: Icon(Icons.people_outline), text: 'الطلاب'),
          ],
        ),
      ),
      body: TabBarView(children: [_buildAcademicTab(), _buildStudentsTab()]),
    ),
  );

  Widget _buildAcademicTab() {
    if (_academicLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _errorState(_error!, _loadAcademicData);
    }
    final subjects = _subjectsForSelectedYear;
    final materials = _materials
        .where(
          (item) =>
              item['subject_id']?.toString() == _selectedSubject?.toString() ||
              item['subject']?.toString() == _selectedSubject?.toString(),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: _loadAcademicData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedYear,
                  decoration: const InputDecoration(labelText: 'الفرقة'),
                  items: _years
                      .map(
                        (year) => DropdownMenuItem<int>(
                          value: year['id'] as int,
                          child: Text(year['name']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedYear = id;
                      _selectedSubject = _subjectsForSelectedYear.isEmpty
                          ? null
                          : _subjectsForSelectedYear.first['id'] as int?;
                      _lectures = [];
                      _uploadLecture = null;
                    });
                    _loadLectures();
                  },
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إدارة الفرق',
                onSelected: (action) {
                  switch (action) {
                    case 'create':
                      _createYear();
                      break;
                    case 'edit':
                      if (_selectedYear != null) {
                        _editYear(
                          _years.firstWhere(
                            (year) => year['id'] == _selectedYear,
                          ),
                        );
                      }
                      break;
                    case 'delete':
                      if (_selectedYear != null) {
                        _deleteAcademicItem(
                          _years.firstWhere(
                            (year) => year['id'] == _selectedYear,
                          ),
                          type: 'year',
                        );
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'create',
                    child: Text('إضافة فرقة'),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    enabled: _selectedYear != null,
                    child: const Text('تعديل الفرقة المختارة'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    enabled: _selectedYear != null,
                    child: const Text('حذف الفرقة المختارة'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedSubject,
                  decoration: const InputDecoration(labelText: 'المادة'),
                  items: subjects
                      .map(
                        (subject) => DropdownMenuItem<int>(
                          value: subject['id'] as int,
                          child: Text(
                            '${subject['name']?.toString() ?? ''} '
                            '(${subject['lecture_count'] ?? 16} محاضرة)',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() => _selectedSubject = id);
                    _loadLectures();
                  },
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إدارة المواد والمحاضرات',
                onSelected: (action) {
                  switch (action) {
                    case 'create_subject':
                      _createSubject();
                      break;
                    case 'edit_subject':
                      if (_selectedSubject != null) {
                        _editSubject(
                          _subjects.firstWhere(
                            (subject) => subject['id'] == _selectedSubject,
                          ),
                        );
                      }
                      break;
                    case 'delete_subject':
                      if (_selectedSubject != null) {
                        _deleteAcademicItem(
                          _subjects.firstWhere(
                            (subject) => subject['id'] == _selectedSubject,
                          ),
                          type: 'subject',
                        );
                      }
                      break;
                    case 'create_lecture':
                      _createLecture();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'create_subject',
                    enabled: _selectedYear != null,
                    child: const Text('إضافة مادة'),
                  ),
                  PopupMenuItem(
                    value: 'edit_subject',
                    enabled: _selectedSubject != null,
                    child: const Text('تعديل المادة المختارة'),
                  ),
                  PopupMenuItem(
                    value: 'delete_subject',
                    enabled: _selectedSubject != null,
                    child: const Text('حذف المادة المختارة'),
                  ),
                  PopupMenuItem(
                    value: 'create_lecture',
                    enabled: _selectedSubject != null,
                    child: const Text('إضافة محاضرة'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          if (_selectedYear != null) ...[
            const SizedBox(height: 8),
            Text(
              'الفرق الدراسية',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            ..._years.map(
              (year) => ListTile(
                dense: true,
                title: Text(year['name']?.toString() ?? ''),
                subtitle: Text('السنة ${year['year_number'] ?? '—'}'),
                selected: year['id'] == _selectedYear,
                onTap: () {
                  setState(() {
                    _selectedYear = year['id'] as int?;
                    _selectedSubject = _subjectsForSelectedYear.isEmpty
                        ? null
                        : _subjectsForSelectedYear.first['id'] as int?;
                    _lectures = [];
                    _uploadLecture = null;
                  });
                  _loadLectures();
                },
                trailing: IconButton(
                  tooltip: 'تعديل الفرقة',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editYear(year),
                ),
              ),
            ),
          ],
          if (_lectures.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _uploadLecture,
              decoration: const InputDecoration(
                labelText: 'المحاضرة المرتبطة بالملف',
              ),
              items: [
                ..._lectures.map(
                  (lecture) => DropdownMenuItem<int>(
                    value: lecture['id'] as int,
                    child: Text(lecture['title']?.toString() ?? ''),
                  ),
                ),
              ],
              onChanged: (id) => setState(() {
                _uploadLecture = id;
              }),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _uploadMaterialType,
            decoration: const InputDecoration(labelText: 'نوع المحتوى المرفوع'),
            items: const [
              DropdownMenuItem(value: 'lecture', child: Text('محاضرة')),
              DropdownMenuItem(value: 'section', child: Text('سكشن')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _uploadMaterialType = value;
                if (value == 'lecture') _sectionTitleController.clear();
              });
            },
          ),
          if (_uploadMaterialType == 'section') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _sectionTitleController,
              decoration: const InputDecoration(
                labelText: 'اسم السكشن',
                hintText: 'مثال: سكشن 1 - تطبيقات المحاضرة',
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _pickAndUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('اختيار ورفع ملفات'),
          ),
          if (_selectedSubject != null) ...[
            const SizedBox(height: 16),
            Text(
              'المحاضرات (${_lectures.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (_lectures.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا توجد محاضرات لهذه المادة بعد.'),
              ),
            ..._lectures.map(
              (lecture) => Card(
                child: ListTile(
                  title: Text(lecture['title']?.toString() ?? 'محاضرة'),
                  subtitle: Text(
                    'المحاضرة ${lecture['lecture_number'] ?? '—'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'إدارة المحاضرة',
                    onSelected: (action) {
                      if (action == 'edit') {
                        _editLecture(lecture);
                      } else {
                        _deleteAcademicItem(lecture, type: 'lecture');
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                      PopupMenuItem(value: 'delete', child: Text('حذف')),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'الملفات (${materials.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (materials.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('لا توجد ملفات لهذه المادة بعد.'),
            ),
          ...materials.map(_materialCard),
        ],
      ),
    );
  }

  int? _uploadLecture;

  Widget _materialCard(Map<String, dynamic> material) {
    final processing = material['processing_status']?.toString() ?? 'UNKNOWN';
    final sectionTitle = material['section_title']?.toString() ?? '';
    final materialType = material['material_type']?.toString() ?? 'lecture';
    final statusLabel = switch (processing) {
      'UPLOADED' => 'بانتظار المعالجة',
      'PROCESSING' => 'تتم معالجة المحتوى',
      'READY' => 'جاهز للشرح والأسئلة',
      'FAILED' => 'فشلت المعالجة',
      _ => processing,
    };
    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file_outlined),
        title: Text(
          materialType == 'section' && sectionTitle.isNotEmpty
              ? 'سكشن: $sectionTitle'
              : material['title']?.toString() ?? 'ملف',
        ),
        subtitle: Text(
          '${material['original_filename'] ?? ''}\n'
          'الحالة: $statusLabel'
          '${material['processing_error']?.toString().isNotEmpty == true ? '\n${material['processing_error']}' : ''}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'retry') _retryMaterial(material);
            if (action == 'download') _downloadMaterial(material);
            if (action == 'replace') _replaceMaterial(material);
            if (action == 'delete') _deleteMaterial(material);
          },
          itemBuilder: (_) => [
            if (processing == 'FAILED')
              const PopupMenuItem(
                value: 'retry',
                child: Text('إعادة المعالجة'),
              ),
            const PopupMenuItem(value: 'download', child: Text('تنزيل الملف')),
            const PopupMenuItem(value: 'replace', child: Text('استبدال الملف')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'بحث عن طالب',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'بحث',
                    onPressed: () {
                      _studentPage = 1;
                      _loadStudents();
                    },
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onChanged: (value) => _studentSearch = value.trim(),
                onSubmitted: (_) {
                  _studentPage = 1;
                  _loadStudents();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _studentStatus,
              items: const [
                DropdownMenuItem(value: '', child: Text('الكل')),
                DropdownMenuItem(value: 'active', child: Text('نشط')),
                DropdownMenuItem(value: 'blocked', child: Text('محظور')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _studentStatus = value;
                  _studentPage = 1;
                });
                _loadStudents();
              },
            ),
          ],
        ),
      ),
      Expanded(
        child: _studentsLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStudents,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _students.length,
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    final active = student['is_active'] == true;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (student['full_name'] ?? student['username'])
                                  .toString()
                                  .characters
                                  .firstOrNull ??
                              '?',
                        ),
                      ),
                      title: Text(
                        student['full_name']?.toString().isNotEmpty == true
                            ? student['full_name'].toString()
                            : student['username']?.toString() ?? 'طالب',
                      ),
                      subtitle: Text(
                        'الرقم الجامعي: ${student['university_id'] ?? '—'} • '
                        'السنة: ${student['academic_year'] ?? '—'} • '
                        'النقاط: ${student['xp_points'] ?? 0}',
                      ),
                      trailing: IconButton(
                        tooltip: active ? 'حظر الطالب' : 'إلغاء الحظر',
                        onPressed: () => _changeStudentStatus(student),
                        icon: Icon(
                          active ? Icons.block_outlined : Icons.check_circle,
                          color: active ? AppColors.warning : AppColors.success,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _studentPage <= 1
                  ? null
                  : () {
                      setState(() => _studentPage--);
                      _loadStudents();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '$_studentPage / ${(_studentCount / 25).ceil().clamp(1, 999)}',
            ),
            IconButton(
              onPressed: _studentPage * 25 >= _studentCount
                  ? null
                  : () {
                      setState(() => _studentPage++);
                      _loadStudents();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _errorState(String message, Future<void> Function() retry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );

  Future<void> _createYear() async {
    final values = await _showFieldsDialog('إضافة فرقة دراسية', const [
      ('year_number', 'رقم الفرقة', true),
      ('name', 'اسم الفرقة', false),
      ('order', 'الترتيب', true),
    ]);
    if (values == null) return;
    final response = await ApiClient.instance.post(
      AppConstants.academicYearsUrl,
      {
        'year_number': int.tryParse(values['year_number'] ?? ''),
        'name': values['name'],
        'order': int.tryParse(values['order'] ?? ''),
      },
    );
    await _afterCreate(response);
  }

  Future<void> _editYear(Map<String, dynamic> year) async {
    final values = await _showFieldsDialog('تعديل الفرقة الدراسية', const [
      ('year_number', 'رقم الفرقة', true),
      ('name', 'اسم الفرقة', false),
      ('order', 'الترتيب', true),
    ], initialValues: year);
    if (values == null) return;
    await _saveAcademicUpdate(AppConstants.academicYearUrl(year['id'] as int), {
      'year_number': int.tryParse(values['year_number'] ?? ''),
      'name': values['name'],
      'order': int.tryParse(values['order'] ?? ''),
    });
  }

  Future<void> _createSubject() async {
    final values = await _showFieldsDialog(
      'إضافة مادة',
      const [
        ('name', 'اسم المادة', false),
        ('code', 'رمز المادة (اختياري)', false),
        ('description', 'الوصف (اختياري)', false),
      ],
      requiredKeys: const {'name'},
    );
    if (values == null || _selectedYear == null) return;
    final response = await ApiClient.instance.post(
      AppConstants.academicSubjectsUrl,
      {
        'academic_year': _selectedYear,
        'name': values['name'],
        'code': values['code'],
        'description': values['description'],
      },
    );
    await _afterCreate(response);
  }

  Future<void> _editSubject(Map<String, dynamic> subject) async {
    final values = await _showFieldsDialog(
      'تعديل المادة',
      const [
        ('name', 'اسم المادة', false),
        ('code', 'رمز المادة (اختياري)', false),
        ('description', 'الوصف (اختياري)', false),
        ('order', 'الترتيب', true),
      ],
      initialValues: subject,
      requiredKeys: const {'name', 'order'},
    );
    if (values == null) return;
    await _saveAcademicUpdate(
      AppConstants.academicSubjectUrl(subject['id'] as int),
      {
        'name': values['name'],
        'code': values['code'],
        'description': values['description'],
        'order': int.tryParse(values['order'] ?? ''),
      },
    );
  }

  Future<void> _createLecture() async {
    final values = await _showFieldsDialog(
      'إضافة محاضرة',
      const [
        ('title', 'عنوان المحاضرة', false),
        ('lecture_number', 'رقم المحاضرة', true),
        ('description', 'الوصف (اختياري)', false),
      ],
      requiredKeys: const {'title', 'lecture_number'},
    );
    if (values == null || _selectedSubject == null) return;
    final response = await ApiClient.instance.post(
      AppConstants.academicLecturesUrl,
      {
        'subject': _selectedSubject,
        'title': values['title'],
        'lecture_number': int.tryParse(values['lecture_number'] ?? ''),
        'description': values['description'],
      },
    );
    await _afterCreate(response);
  }

  Future<void> _editLecture(Map<String, dynamic> lecture) async {
    final values = await _showFieldsDialog(
      'تعديل المحاضرة',
      const [
        ('title', 'عنوان المحاضرة', false),
        ('lecture_number', 'رقم المحاضرة', true),
        ('description', 'الوصف (اختياري)', false),
        ('order', 'الترتيب', true),
      ],
      initialValues: lecture,
      requiredKeys: const {'title', 'lecture_number', 'order'},
    );
    if (values == null) return;
    await _saveAcademicUpdate(
      AppConstants.academicLectureUrl(lecture['id'] as int),
      {
        'title': values['title'],
        'lecture_number': int.tryParse(values['lecture_number'] ?? ''),
        'description': values['description'],
        'order': int.tryParse(values['order'] ?? ''),
      },
    );
  }

  Future<void> _saveAcademicUpdate(
    String url,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiClient.instance.patch(url, body);
    await _afterCreate(response);
  }

  Future<void> _deleteAcademicItem(
    Map<String, dynamic> item, {
    required String type,
  }) async {
    final id = item['id'];
    if (id is! int) return;
    final name = item['name'] ?? item['title'] ?? 'العنصر';
    final impact = switch (type) {
      'year' => 'سيؤدي ذلك إلى حذف جميع المواد والمحاضرات والملفات التابعة لهذه الفرقة.',
      'subject' =>
        'سيؤدي ذلك إلى حذف جميع المحاضرات والملفات التابعة لهذه المادة.',
      _ => 'سيؤدي ذلك إلى حذف الملفات والمحتوى المرتبط بهذه المحاضرة.',
    };
    final confirmed = await _confirm(
      'حذف $name؟',
      '$impact لا يمكن التراجع عن هذا الإجراء.',
    );
    if (!confirmed) return;
    final url = switch (type) {
      'year' => AppConstants.academicYearUrl(id),
      'subject' => AppConstants.academicSubjectUrl(id),
      _ => AppConstants.academicLectureUrl(id),
    };
    final response = await ApiClient.instance.delete(url);
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage('تم الحذف بنجاح.');
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }

  Future<Map<String, String>?> _showFieldsDialog(
    String title,
    List<(String, String, bool)> fields, {
    Map<String, dynamic> initialValues = const {},
    Set<String>? requiredKeys,
  }) async {
    final controllers = <String, TextEditingController>{
      for (final (key, _, _) in fields)
        key: TextEditingController(text: initialValues[key]?.toString() ?? ''),
    };
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (key, label, numeric) in fields)
                TextField(
                  controller: controllers[key],
                  keyboardType: numeric ? TextInputType.number : null,
                  decoration: InputDecoration(labelText: label),
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
            onPressed: () => Navigator.pop(dialogContext, {
              for (final entry in controllers.entries)
                entry.key: entry.value.text.trim(),
            }),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    for (final controller in controllers.values) {
      controller.dispose();
    }
    final required = requiredKeys ?? fields.map((field) => field.$1).toSet();
    if (result != null &&
        required.any((key) => result[key]?.trim().isEmpty ?? true)) {
      _showMessage('يرجى ملء الحقول المطلوبة.');
      return null;
    }
    return result;
  }

  Future<void> _afterCreate(ApiResponse response) async {
    if (!mounted) return;
    if (response.isAuthError) {
      context.read<AuthProvider>().forceLogout();
    } else if (response.isSuccess) {
      _showMessage('تم الحفظ بنجاح.');
      await _loadAcademicData();
    } else {
      _showMessage(response.errorMessage);
    }
  }
}
