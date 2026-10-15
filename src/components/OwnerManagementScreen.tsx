import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  FolderOpen,
  Users,
  Plus,
  Upload,
  FileText,
  Search,
  CheckCircle,
  Ban,
  Trash2,
  RefreshCw,
  Edit,
  ArrowLeft,
  BookOpen,
} from 'lucide-react';

interface OwnerManagementScreenProps {
  onBack: () => void;
}

export const OwnerManagementScreen: React.FC<OwnerManagementScreenProps> = ({ onBack }) => {
  const {
    years,
    subjects,
    lectures,
    materials,
    users,
    createYear,
    updateYear,
    deleteYear,
    createSubject,
    updateSubject,
    deleteSubject,
    createLecture,
    updateLecture,
    deleteLecture,
    uploadMaterial,
    replaceMaterial,
    retryMaterial,
    deleteMaterial,
    toggleStudentStatus,
  } = useApp();

  const [activeTab, setActiveTab] = useState<'academic' | 'students'>('academic');

  // Academic tab selection
  const [selectedYearId, setSelectedYearId] = useState<number>(years[1]?.id ?? years[0]?.id ?? 2);
  const subjectsInYear = subjects.filter((s) => s.academic_year === selectedYearId);
  const [selectedSubjectId, setSelectedSubjectId] = useState<number>(
    subjectsInYear[0]?.id ?? subjects[0]?.id ?? 3
  );

  const lecturesInSubject = lectures.filter((l) => l.subject_id === selectedSubjectId);
  const [selectedUploadLecture, setSelectedUploadLecture] = useState<number>(
    lecturesInSubject[0]?.id ?? 1
  );

  // File Upload Form state
  const [uploadType, setUploadType] = useState<'lecture' | 'section'>('lecture');
  const [sectionTitle, setSectionTitle] = useState('');
  const [materialTitle, setMaterialTitle] = useState('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploadMessage, setUploadMessage] = useState<string | null>(null);

  // Modal dialog states
  const [dialogState, setDialogState] = useState<{
    open: boolean;
    type: 'create_year' | 'edit_year' | 'create_subject' | 'edit_subject' | 'create_lecture' | 'edit_lecture' | 'confirm_delete';
    targetId?: number;
    title: string;
    field1?: string;
    field2?: string;
    field3?: string;
  }>({ open: false, type: 'create_year', title: '' });

  // Student Search & Filter
  const [studentSearch, setStudentSearch] = useState('');
  const [studentStatusFilter, setStudentStatusFilter] = useState<'all' | 'active' | 'blocked'>('all');
  const [studentPage, setStudentPage] = useState(1);
  const PAGE_SIZE = 8;

  const filteredStudents = users
    .filter((u) => u.role === 'student')
    .filter((u) => {
      const matchSearch =
        u.username.toLowerCase().includes(studentSearch.toLowerCase()) ||
        (u.full_name && u.full_name.toLowerCase().includes(studentSearch.toLowerCase())) ||
        u.university_id.includes(studentSearch);
      const matchStatus =
        studentStatusFilter === 'all'
          ? true
          : studentStatusFilter === 'active'
          ? u.is_active
          : !u.is_active;
      return matchSearch && matchStatus;
    });

  const paginatedStudents = filteredStudents.slice((studentPage - 1) * PAGE_SIZE, studentPage * PAGE_SIZE);
  const totalPages = Math.ceil(filteredStudents.length / PAGE_SIZE) || 1;

  // Handle File Upload Submit
  const handleUploadSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedFile) {
      setUploadMessage('يرجى اختيار ملف لرفعه');
      return;
    }

    uploadMaterial({
      academicYearId: selectedYearId,
      subjectId: selectedSubjectId,
      lectureId: selectedUploadLecture,
      title: materialTitle.trim() || selectedFile.name,
      materialType: uploadType,
      sectionTitle: uploadType === 'section' ? sectionTitle.trim() : undefined,
      filename: selectedFile.name,
      sizeBytes: selectedFile.size,
    });

    setSelectedFile(null);
    setMaterialTitle('');
    setSectionTitle('');
    setUploadMessage('تم رفع الملف بنجاح وتجهيزه لأسئلة الاختبارات والذكاء الاصطناعي.');
    setTimeout(() => setUploadMessage(null), 3000);
  };

  // Dialog actions
  const handleDialogSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const { type, targetId, field1, field2 } = dialogState;

    if (type === 'create_year') {
      const num = Number(field1) || 1;
      const name = field2 || `الفرقة ${num}`;
      createYear(num, name, num);
    } else if (type === 'edit_year' && targetId) {
      updateYear(targetId, { name: field2, year_number: Number(field1) });
    } else if (type === 'create_subject') {
      createSubject(selectedYearId, field1 || 'مادة جديدة', field2);
    } else if (type === 'edit_subject' && targetId) {
      updateSubject(targetId, { name: field1, code: field2 });
    } else if (type === 'create_lecture') {
      createLecture(selectedSubjectId, Number(field1) || 1, field2 || 'عنوان المحاضرة');
    } else if (type === 'edit_lecture' && targetId) {
      updateLecture(targetId, { lecture_number: Number(field1), title: field2 });
    }

    setDialogState({ ...dialogState, open: false });
  };

  const materialsInSubject = materials.filter(
    (m) => m.subject_id === selectedSubjectId || m.academic_year_id === selectedYearId
  );

  return (
    <div className="max-w-5xl mx-auto p-4 sm:p-6 space-y-5 animate-in fade-in duration-300">
      {/* Top Navigation */}
      <div className="flex items-center justify-between pb-3 border-b border-[#2B3B5C]">
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="p-2 rounded-xl bg-[#1B2640] border border-[#2B3B5C] text-[#DEEBFF] hover:text-[#52D6A6] transition"
            title="رجوع"
          >
            <ArrowLeft className="w-5 h-5 rtl:rotate-180" />
          </button>
          <div>
            <h2 className="text-lg font-bold text-white tracking-tight">إدارة المنصة والمقررات</h2>
            <p className="text-xs text-[#9BB0D6]">إعداد المواد الدراسية، رفع السلايدات، وإدارة الطلاب</p>
          </div>
        </div>

        {/* Tab switchers */}
        <div className="flex bg-[#1B2640] p-1 rounded-xl border border-[#2B3B5C]">
          <button
            onClick={() => setActiveTab('academic')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
              activeTab === 'academic' ? 'bg-[#52D6A6] text-[#0B1020]' : 'text-[#DEEBFF] hover:text-white'
            }`}
          >
            <FolderOpen className="w-3.5 h-3.5" />
            المواد والملفات
          </button>
          <button
            onClick={() => setActiveTab('students')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
              activeTab === 'students' ? 'bg-[#52D6A6] text-[#0B1020]' : 'text-[#DEEBFF] hover:text-white'
            }`}
          >
            <Users className="w-3.5 h-3.5" />
            حسابات الطلاب
          </button>
        </div>
      </div>

      {/* Tab 1: Academic & Materials Management */}
      {activeTab === 'academic' && (
        <div className="space-y-6">
          {/* Selectors and CRUD Actions */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Year Selector */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-bold text-[#DEEBFF]">الفرقة الدراسية:</label>
                  <button
                    onClick={() =>
                      setDialogState({
                        open: true,
                        type: 'create_year',
                        title: 'إضافة فرقة دراسية جديدة',
                        field1: '5',
                        field2: 'الفرقة الخامسة',
                      })
                    }
                    className="text-[11px] text-[#52D6A6] hover:underline flex items-center gap-1 font-semibold"
                  >
                    <Plus className="w-3 h-3" /> إضافة فرقة
                  </button>
                </div>
                <select
                  value={selectedYearId}
                  onChange={(e) => {
                    const yId = Number(e.target.value);
                    setSelectedYearId(yId);
                    const subjs = subjects.filter((s) => s.academic_year === yId);
                    if (subjs.length > 0) setSelectedSubjectId(subjs[0].id);
                  }}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-xl px-3.5 py-2.5 text-xs outline-none focus:border-[#52D6A6]"
                >
                  {years.map((y) => (
                    <option key={y.id} value={y.id}>
                      {y.name} (السنة {y.year_number})
                    </option>
                  ))}
                </select>
              </div>

              {/* Subject Selector */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-bold text-[#DEEBFF]">المادة المقررة:</label>
                  <button
                    onClick={() =>
                      setDialogState({
                        open: true,
                        type: 'create_subject',
                        title: 'إضافة مقرر جديد',
                        field1: '',
                        field2: '',
                      })
                    }
                    className="text-[11px] text-[#52D6A6] hover:underline flex items-center gap-1 font-semibold"
                  >
                    <Plus className="w-3 h-3" /> إضافة مادة
                  </button>
                </div>
                <select
                  value={selectedSubjectId}
                  onChange={(e) => setSelectedSubjectId(Number(e.target.value))}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-xl px-3.5 py-2.5 text-xs outline-none focus:border-[#52D6A6]"
                >
                  {subjectsInYear.length === 0 ? (
                    <option value="">لا توجد مواد في هذه الفرقة</option>
                  ) : (
                    subjectsInYear.map((s) => (
                      <option key={s.id} value={s.id}>
                        {s.name} {s.code ? `(${s.code})` : ''}
                      </option>
                    ))
                  )}
                </select>
              </div>
            </div>
          </div>

          {/* Upload Material Section */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-4">
            <h3 className="font-bold text-white text-sm flex items-center gap-2">
              <Upload className="w-4 h-4 text-[#52D6A6]" />
              رفع ملفات وسلايدات دراسية جديدة
            </h3>

            {uploadMessage && (
              <div className="p-3 bg-[#173A2E] border border-[#52D6A6]/50 rounded-xl text-xs text-[#52D6A6] font-semibold">
                {uploadMessage}
              </div>
            )}

            <form onSubmit={handleUploadSubmit} className="space-y-3.5 text-xs">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#9BB0D6] mb-1 font-semibold">ربط بالمحاضرة رقم:</label>
                  <select
                    value={selectedUploadLecture}
                    onChange={(e) => setSelectedUploadLecture(Number(e.target.value))}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-xl px-3 py-2 outline-none"
                  >
                    {Array.from({ length: 16 }, (_, i) => i + 1).map((n) => (
                      <option key={n} value={n}>
                        المحاضرة رقم {n}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[#9BB0D6] mb-1 font-semibold">نوع المحتوى المرفوع:</label>
                  <select
                    value={uploadType}
                    onChange={(e) => setUploadType(e.target.value as 'lecture' | 'section')}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-xl px-3 py-2 outline-none"
                  >
                    <option value="lecture">محاضرة رسمية (Lecture Slides)</option>
                    <option value="section">سكشن عملي (Lab / Section)</option>
                  </select>
                </div>
              </div>

              {uploadType === 'section' && (
                <div>
                  <label className="block text-[#DEEBFF] mb-1 font-semibold">عنوان أو اسم السكشن:</label>
                  <input
                    type="text"
                    value={sectionTitle}
                    onChange={(e) => setSectionTitle(e.target.value)}
                    placeholder="مثال: سكشن 1 - حل مسائل خطوط الأنابيب"
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#DEEBFF] mb-1 font-semibold">عنوان الملف في التطبيق:</label>
                  <input
                    type="text"
                    value={materialTitle}
                    onChange={(e) => setMaterialTitle(e.target.value)}
                    placeholder="مثال: سلايدات المحاضرة الأولى"
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>

                <div>
                  <label className="block text-[#DEEBFF] mb-1 font-semibold">اختيار الملف (PDF, DOCX, PPTX, TXT):</label>
                  <input
                    type="file"
                    accept=".pdf,.docx,.pptx,.txt"
                    onChange={(e) => setSelectedFile(e.target.files?.[0] || null)}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-1.5 text-white outline-none file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:bg-[#1B2640] file:text-[#52D6A6] file:font-bold"
                  />
                </div>
              </div>

              <button
                type="submit"
                className="py-2.5 px-5 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold rounded-xl transition flex items-center justify-center gap-2 shadow-md cursor-pointer"
              >
                <Upload className="w-4 h-4" />
                رفع ومعالجة الملف
              </button>
            </form>
          </div>

          {/* Uploaded Materials List */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
            <h3 className="font-bold text-white text-sm flex items-center gap-2">
              <FileText className="w-4 h-4 text-[#52D6A6]" />
              الملفات المرفوعة لمادة ({subjects.find((s) => s.id === selectedSubjectId)?.name}) ({materialsInSubject.length})
            </h3>

            {materialsInSubject.length === 0 ? (
              <div className="text-center py-8 text-[#9BB0D6] text-xs">
                لا توجد ملفات مرفوعة لهذه المادة بعد. استخدم نموذج الرفع أعلاه.
              </div>
            ) : (
              <div className="space-y-2.5">
                {materialsInSubject.map((mat) => (
                  <div
                    key={mat.id}
                    className="p-3.5 rounded-xl bg-[#1B2640] border border-[#2B3B5C] flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs"
                  >
                    <div>
                      <div className="font-bold text-white flex items-center gap-2">
                        <span>{mat.title}</span>
                        <span className="bg-[#52D6A6]/15 text-[#52D6A6] text-[10px] px-2 py-0.5 rounded font-bold">
                          {mat.material_type === 'section' ? 'سكشن' : 'محاضرة'}
                        </span>
                      </div>
                      <div className="text-[11px] text-[#9BB0D6] mt-1">
                        الملف: {mat.original_filename} • {mat.uploaded_at}
                      </div>
                    </div>

                    <div className="flex items-center gap-2 self-end sm:self-center">
                      <span className="bg-[#69E4A7]/15 text-[#69E4A7] text-[10px] font-bold px-2 py-1 rounded">
                        جاهز للشرح والأسئلة
                      </span>

                      <button
                        onClick={() => retryMaterial(mat.id)}
                        className="p-1.5 rounded-lg bg-[#23314F] text-[#DEEBFF] hover:text-[#52D6A6] transition"
                        title="إعادة معالجة"
                      >
                        <RefreshCw className="w-3.5 h-3.5" />
                      </button>

                      <button
                        onClick={() => deleteMaterial(mat.id)}
                        className="p-1.5 rounded-lg bg-[#23314F] text-[#FF7E86] hover:bg-[#3C1F2B] transition"
                        title="حذف الملف"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tab 2: Students Management */}
      {activeTab === 'students' && (
        <div className="space-y-4">
          {/* Search & Filter Bar */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-4 flex flex-col sm:flex-row gap-3">
            <div className="relative flex-1">
              <input
                type="text"
                value={studentSearch}
                onChange={(e) => {
                  setStudentSearch(e.target.value);
                  setStudentPage(1);
                }}
                placeholder="بحث بالاسم أو اسم المستخدم أو رقم الطالب (ID)..."
                className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl pr-9 pl-4 py-2.5 text-xs text-white outline-none focus:border-[#52D6A6]"
              />
              <Search className="w-4 h-4 text-[#9BB0D6] absolute right-3 top-3 pointer-events-none" />
            </div>

            <div className="flex items-center gap-2">
              <select
                value={studentStatusFilter}
                onChange={(e) => {
                  setStudentStatusFilter(e.target.value as 'all' | 'active' | 'blocked');
                  setStudentPage(1);
                }}
                className="bg-[#0B1020] border border-[#2B3B5C] text-white rounded-xl px-3 py-2 text-xs outline-none"
              >
                <option value="all">كل الحسابات</option>
                <option value="active">الحسابات النشطة فقط</option>
                <option value="blocked">الحسابات المحظورة فقط</option>
              </select>
            </div>
          </div>

          {/* Students List */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-right text-xs">
                <thead className="bg-[#1B2640] border-b border-[#2B3B5C] text-[#9BB0D6]">
                  <tr>
                    <th className="py-3 px-4 font-bold">الطالب</th>
                    <th className="py-3 px-4 font-bold">رقم الطالب (ID)</th>
                    <th className="py-3 px-4 font-bold">الفرقة</th>
                    <th className="py-3 px-4 font-bold">النقاط (XP)</th>
                    <th className="py-3 px-4 font-bold">الحالة</th>
                    <th className="py-3 px-4 font-bold text-center">إجراءات الحظر</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[#2B3B5C]/60 text-white">
                  {paginatedStudents.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="py-8 text-center text-[#9BB0D6]">
                        لا توجد حسابات مطابقة لمعايير البحث
                      </td>
                    </tr>
                  ) : (
                    paginatedStudents.map((std) => (
                      <tr key={std.uid} className="hover:bg-[#1B2640]/50 transition">
                        <td className="py-3 px-4">
                          <div className="flex items-center gap-2.5">
                            <div className="w-8 h-8 rounded-full bg-[#173A2E] text-[#52D6A6] font-bold flex items-center justify-center text-xs">
                              {(std.full_name || std.username)[0].toUpperCase()}
                            </div>
                            <div>
                              <div className="font-bold">{std.full_name || std.username}</div>
                              <div className="text-[10px] text-[#9BB0D6]">@{std.username}</div>
                            </div>
                          </div>
                        </td>
                        <td className="py-3 px-4 font-mono font-bold text-[#7DB8FF]">{std.university_id}</td>
                        <td className="py-3 px-4 text-[#DEEBFF]">الفرقة {std.academic_year}</td>
                        <td className="py-3 px-4 font-bold text-[#FFC76A]">{std.xp} XP</td>
                        <td className="py-3 px-4">
                          <span
                            className={`text-[10px] font-bold px-2 py-0.5 rounded-full inline-block ${
                              std.is_active ? 'bg-[#69E4A7]/15 text-[#69E4A7]' : 'bg-[#FF7E86]/15 text-[#FF7E86]'
                            }`}
                          >
                            {std.is_active ? 'نشط' : 'محظور'}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-center">
                          <button
                            onClick={() => toggleStudentStatus(std.uid)}
                            className={`px-3 py-1.5 rounded-lg font-bold text-[11px] transition inline-flex items-center gap-1.5 ${
                              std.is_active
                                ? 'bg-[#3C1F2B] text-[#FF7E86] hover:bg-[#FF7E86]/20'
                                : 'bg-[#173A2E] text-[#69E4A7] hover:bg-[#69E4A7]/20'
                            }`}
                          >
                            {std.is_active ? (
                              <>
                                <Ban className="w-3.5 h-3.5" /> حظر الطالب
                              </>
                            ) : (
                              <>
                                <CheckCircle className="w-3.5 h-3.5" /> إلغاء الحظر
                              </>
                            )}
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="p-3 border-t border-[#2B3B5C] flex items-center justify-between text-xs text-[#9BB0D6]">
                <button
                  disabled={studentPage <= 1}
                  onClick={() => setStudentPage((p) => p - 1)}
                  className="px-3 py-1 rounded-lg bg-[#1B2640] disabled:opacity-40"
                >
                  السابق
                </button>
                <span>
                  صفحة {studentPage} من {totalPages}
                </span>
                <button
                  disabled={studentPage >= totalPages}
                  onClick={() => setStudentPage((p) => p + 1)}
                  className="px-3 py-1 rounded-lg bg-[#1B2640] disabled:opacity-40"
                >
                  التالي
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Modal Dialog for Academic Add/Edit */}
      {dialogState.open && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl w-full max-w-md p-6 space-y-4 shadow-2xl animate-in fade-in">
            <h3 className="font-bold text-white text-base">{dialogState.title}</h3>

            <form onSubmit={handleDialogSubmit} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-[#DEEBFF] font-semibold mb-1">
                  {dialogState.type.includes('year') ? 'رقم الفرقة' : 'اسم المادة / رقم المحاضرة'}
                </label>
                <input
                  type="text"
                  required
                  value={dialogState.field1 || ''}
                  onChange={(e) => setDialogState({ ...dialogState, field1: e.target.value })}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none focus:border-[#52D6A6]"
                />
              </div>

              <div>
                <label className="block text-[#DEEBFF] font-semibold mb-1">
                  {dialogState.type.includes('year') ? 'اسم الفرقة' : 'رمز المادة / عنوان المحاضرة'}
                </label>
                <input
                  type="text"
                  required
                  value={dialogState.field2 || ''}
                  onChange={(e) => setDialogState({ ...dialogState, field2: e.target.value })}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none focus:border-[#52D6A6]"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-[#2B3B5C]">
                <button
                  type="button"
                  onClick={() => setDialogState({ ...dialogState, open: false })}
                  className="px-4 py-2 bg-[#1B2640] text-white rounded-xl font-semibold"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-[#52D6A6] text-[#0B1020] rounded-xl font-bold hover:bg-[#23B780] transition"
                >
                  حفظ
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
