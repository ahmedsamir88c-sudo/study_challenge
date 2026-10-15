import React from 'react';
import { useApp } from '../context/AppContext';
import {
  ShieldAlert,
  Users,
  CheckCircle,
  BookOpen,
  Video,
  FileText,
  HelpCircle,
  Sparkles,
  ArrowRight,
  UserCheck,
} from 'lucide-react';

interface OwnerDashboardScreenProps {
  onOpenManagement: () => void;
  onOpenStudentView: () => void;
}

export const OwnerDashboardScreen: React.FC<OwnerDashboardScreenProps> = ({
  onOpenManagement,
  onOpenStudentView,
}) => {
  const { currentUser, users, subjects, lectures, materials } = useApp();

  const totalStudents = users.filter((u) => u.role === 'student').length;
  const activeStudents = users.filter((u) => u.role === 'student' && u.is_active).length;
  const totalSubjects = subjects.length;
  const totalLectures = lectures.length;
  const totalFiles = materials.length;
  const totalQuestions = 85;
  const totalSummaries = 16;

  const metrics = [
    { title: 'إجمالي الطلاب', value: totalStudents, icon: Users, color: 'text-[#7DB8FF]', bg: 'bg-[#7DB8FF]/15' },
    { title: 'طلاب نشطون', value: activeStudents, icon: CheckCircle, color: 'text-[#69E4A7]', bg: 'bg-[#69E4A7]/15' },
    { title: 'المواد الدراسية', value: totalSubjects, icon: BookOpen, color: 'text-[#FFC76A]', bg: 'bg-[#FFC76A]/15' },
    { title: 'المحاضرات', value: totalLectures, icon: Video, color: 'text-[#52D6A6]', bg: 'bg-[#52D6A6]/15' },
    { title: 'الملفات والسلايدات', value: totalFiles, icon: FileText, color: 'text-[#DEEBFF]', bg: 'bg-[#23314F]' },
    { title: 'بنك الأسئلة', value: totalQuestions, icon: HelpCircle, color: 'text-[#FF8A7A]', bg: 'bg-[#FF8A7A]/15' },
    { title: 'الملخصات الذكية', value: totalSummaries, icon: Sparkles, color: 'text-[#FFC76A]', bg: 'bg-[#FFC76A]/15' },
  ];

  return (
    <div className="max-w-5xl mx-auto p-4 sm:p-6 space-y-6 animate-in fade-in duration-300">
      {/* Welcome Banner */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-6 sm:p-7 shadow-lg flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-[#173A2E] border border-[#52D6A6]/40 flex items-center justify-center text-[#52D6A6] shadow-sm">
            <ShieldAlert className="w-7 h-7" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-[#9BB0D6]">مرحباً بك في</span>
              <span className="bg-[#52D6A6]/20 text-[#52D6A6] text-[10px] font-bold px-2 py-0.5 rounded-full">
                لوحة تحكم المالك
              </span>
            </div>
            <h2 className="text-xl sm:text-2xl font-bold text-white tracking-tight mt-0.5">
              {currentUser?.full_name || currentUser?.username}
            </h2>
            <p className="text-xs text-[#9BB0D6] mt-1">
              إدارة المقررات الدراسية، رفع السلايدات، ومراقبة حسابات الطلاب ونشاطهم
            </p>
          </div>
        </div>

        {/* Quick action buttons */}
        <div className="flex items-center gap-2.5">
          <button
            onClick={onOpenManagement}
            className="py-2.5 px-4 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] text-xs font-bold rounded-xl transition flex items-center gap-2 shadow-md cursor-pointer"
          >
            <span>إدارة المواد والطلاب</span>
            <ArrowRight className="w-4 h-4 rtl:rotate-180" />
          </button>
          <button
            onClick={onOpenStudentView}
            className="py-2.5 px-4 bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] text-[#DEEBFF] text-xs font-semibold rounded-xl transition flex items-center gap-2 cursor-pointer"
            title="تجربة التطبيق كطالب"
          >
            <UserCheck className="w-4 h-4 text-[#7DB8FF]" />
            <span>عرض واجهة الطالب</span>
          </button>
        </div>
      </div>

      {/* Metrics Grid */}
      <div>
        <h3 className="text-sm font-bold text-white mb-3 flex items-center gap-2">
          إحصائيات المنصة الكلية
        </h3>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3.5">
          {metrics.map((m, idx) => {
            const Icon = m.icon;
            return (
              <div
                key={idx}
                className="bg-[#141C2E] border border-[#2B3B5C] hover:border-[#52D6A6]/40 p-4 rounded-2xl shadow-sm transition space-y-2"
              >
                <div className={`w-9 h-9 rounded-xl ${m.bg} ${m.color} flex items-center justify-center`}>
                  <Icon className="w-5 h-5" />
                </div>
                <div>
                  <span className="text-2xl font-black text-white block">{m.value}</span>
                  <span className="text-xs text-[#9BB0D6] block mt-0.5">{m.title}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Recent Activity / Content Status */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Materials Summary */}
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex items-center justify-between">
            <h4 className="font-bold text-white text-sm flex items-center gap-2">
              <FileText className="w-4 h-4 text-[#52D6A6]" />
              أحدث الملفات والمواد المرفوعة
            </h4>
            <span className="text-xs text-[#52D6A6]">{materials.length} ملفات جاهزة</span>
          </div>

          <div className="divide-y divide-[#2B3B5C]/60 text-xs">
            {materials.slice(0, 4).map((mat) => (
              <div key={mat.id} className="py-2.5 flex items-center justify-between">
                <div>
                  <div className="font-semibold text-white">{mat.title}</div>
                  <div className="text-[11px] text-[#9BB0D6] mt-0.5">
                    {mat.original_filename} • {mat.uploaded_at}
                  </div>
                </div>
                <span className="bg-[#69E4A7]/15 text-[#69E4A7] text-[10px] font-bold px-2 py-0.5 rounded">
                  {mat.processing_status}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Student Accounts Activity */}
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex items-center justify-between">
            <h4 className="font-bold text-white text-sm flex items-center gap-2">
              <Users className="w-4 h-4 text-[#7DB8FF]" />
              حسابات الطلاب المسجلين
            </h4>
            <span className="text-xs text-[#7DB8FF]">{totalStudents} طلاب مسجلين</span>
          </div>

          <div className="divide-y divide-[#2B3B5C]/60 text-xs">
            {users
              .filter((u) => u.role === 'student')
              .slice(0, 4)
              .map((u) => (
                <div key={u.uid} className="py-2.5 flex items-center justify-between">
                  <div>
                    <div className="font-semibold text-white">
                      {u.full_name || u.username} (@{u.username})
                    </div>
                    <div className="text-[11px] text-[#9BB0D6] mt-0.5">
                      ID: {u.university_id} • الفرقة {u.academic_year} • {u.xp} XP
                    </div>
                  </div>
                  <span
                    className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                      u.is_active ? 'bg-[#69E4A7]/15 text-[#69E4A7]' : 'bg-[#FF7E86]/15 text-[#FF7E86]'
                    }`}
                  >
                    {u.is_active ? 'نشط' : 'محظور'}
                  </span>
                </div>
              ))}
          </div>
        </div>
      </div>
    </div>
  );
};
