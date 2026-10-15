import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  User,
  Camera,
  Zap,
  Flame,
  GraduationCap,
  Save,
  LogOut,
  CheckCircle2,
  Calendar,
  Layers,
  Sparkles,
} from 'lucide-react';

interface ProfileScreenProps {
  onStartDailyChallenge: () => void;
}

export const ProfileScreen: React.FC<ProfileScreenProps> = ({ onStartDailyChallenge }) => {
  const { currentUser, updateProfile, updateProfileImage, logout, dailyChallenge, attemptHistory } = useApp();

  const [username, setUsername] = useState(currentUser?.username || '');
  const [fullName, setFullName] = useState(currentUser?.full_name || '');
  const [saveSuccess, setSaveSuccess] = useState(false);

  if (!currentUser) return null;

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim()) return;

    updateProfile({
      username: username.trim(),
      full_name: fullName.trim() || username.trim(),
    });

    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 2000);
  };

  const handlePhotoUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        updateProfileImage(reader.result);
      }
    };
    reader.readAsDataURL(file);
  };

  const totalQuestions = attemptHistory.reduce((acc, c) => acc + c.total_questions, 0);
  const totalCorrect = attemptHistory.reduce((acc, c) => acc + c.score, 0);
  const accuracy = totalQuestions > 0 ? Math.round((totalCorrect / totalQuestions) * 100) : 88;

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-6 animate-in fade-in duration-300">
      {/* Avatar Card */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-6 sm:p-8 text-center shadow-lg relative overflow-hidden">
        <div className="relative inline-block mx-auto mb-3">
          <div className="w-24 h-24 rounded-full bg-[#173A2E] border-2 border-[#52D6A6]/60 flex items-center justify-center text-[#52D6A6] text-3xl font-bold shadow-xl overflow-hidden">
            {currentUser.profile_image ? (
              <img
                src={currentUser.profile_image}
                alt={currentUser.username}
                className="w-full h-full object-cover"
              />
            ) : (
              <span>{(currentUser.full_name || currentUser.username)[0].toUpperCase()}</span>
            )}
          </div>

          <label
            htmlFor="profile-upload"
            className="absolute bottom-0 right-0 p-2 rounded-full bg-[#52D6A6] text-[#0B1020] cursor-pointer hover:bg-[#23B780] shadow-md transition"
            title="تغيير الصورة"
          >
            <Camera className="w-4 h-4" />
            <input
              id="profile-upload"
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handlePhotoUpload}
            />
          </label>
        </div>

        <h2 className="text-xl font-bold text-white tracking-tight">
          {currentUser.full_name || currentUser.username}
        </h2>
        <p className="text-xs text-[#9BB0D6] mt-0.5">@{currentUser.username}</p>
        <p className="text-xs text-[#7DB8FF] mt-0.5 font-semibold">رقم الطالب (ID): {currentUser.university_id}</p>

        <div className="mt-3 inline-block">
          {currentUser.role === 'owner' ? (
            <span className="bg-[#52D6A6]/20 border border-[#52D6A6]/50 text-[#52D6A6] text-xs font-bold px-3 py-1 rounded-full">
              مالك المنصة (Administrator)
            </span>
          ) : (
            <span className="bg-[#7DB8FF]/20 border border-[#7DB8FF]/50 text-[#7DB8FF] text-xs font-bold px-3 py-1 rounded-full">
              طالب — الفرقة {currentUser.academic_year}
            </span>
          )}
        </div>
      </div>

      {/* Stats KPI Row */}
      <div className="grid grid-cols-3 gap-3">
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-4 text-center">
          <div className="w-8 h-8 rounded-lg bg-[#7DB8FF]/15 text-[#7DB8FF] flex items-center justify-center mx-auto mb-1">
            <Zap className="w-4 h-4 fill-current" />
          </div>
          <span className="text-[11px] text-[#9BB0D6] block">النقاط</span>
          <span className="text-base sm:text-lg font-bold text-[#7DB8FF] block mt-0.5">
            {currentUser.xp} XP
          </span>
        </div>

        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-4 text-center">
          <div className="w-8 h-8 rounded-lg bg-[#FFC76A]/15 text-[#FFC76A] flex items-center justify-center mx-auto mb-1">
            <Flame className="w-4 h-4 fill-current" />
          </div>
          <span className="text-[11px] text-[#9BB0D6] block">السلسلة</span>
          <span className="text-base sm:text-lg font-bold text-[#FFC76A] block mt-0.5">
            {currentUser.streak} يوم
          </span>
        </div>

        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-4 text-center">
          <div className="w-8 h-8 rounded-lg bg-[#52D6A6]/15 text-[#52D6A6] flex items-center justify-center mx-auto mb-1">
            <GraduationCap className="w-4 h-4" />
          </div>
          <span className="text-[11px] text-[#9BB0D6] block">الفرقة</span>
          <span className="text-base sm:text-lg font-bold text-[#52D6A6] block mt-0.5">
            الثانية (2)
          </span>
        </div>
      </div>

      {/* Daily Challenge Snapshot */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="font-bold text-white text-sm flex items-center gap-2">
            <Calendar className="w-4 h-4 text-[#52D6A6]" />
            التحدي اليومي
          </h3>
          {dailyChallenge.completed ? (
            <span className="text-xs text-[#52D6A6] font-bold">تم إنجاز تحدي اليوم</span>
          ) : (
            <button
              onClick={onStartDailyChallenge}
              className="py-1 px-3 bg-[#52D6A6] text-[#0B1020] text-xs font-bold rounded-lg hover:bg-[#23B780] transition"
            >
              ابدأ التحدي (5 أسئلة)
            </button>
          )}
        </div>
        <p className="text-xs text-[#9BB0D6] leading-relaxed">
          {dailyChallenge.completed
            ? `أنهيت تحدي اليوم بنتيجة ${dailyChallenge.score}/${dailyChallenge.total_questions}. التحدي اختياري ويتجدد يومياً لمكافأتك بنقاط إضافية.`
            : `خمسة أسئلة سريعة من مقررك الدراسي (${dailyChallenge.subject} - المحاضرة ${dailyChallenge.lecture}). كل إجابة صحيحة تمنحك نقطة ومكافأة +25 XP.`}
        </p>
      </div>

      {/* Academic Performance Snapshot */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
        <h3 className="font-bold text-white text-sm flex items-center gap-2">
          <Layers className="w-4 h-4 text-[#7DB8FF]" />
          ملخص التقدم الأكاديمي
        </h3>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center text-xs">
          <div className="bg-[#1B2640] p-3 rounded-xl border border-[#2B3B5C]">
            <span className="text-base font-bold text-white block">{totalQuestions}</span>
            <span className="text-[#9BB0D6]">سؤال تم حله</span>
          </div>
          <div className="bg-[#1B2640] p-3 rounded-xl border border-[#2B3B5C]">
            <span className="text-base font-bold text-[#52D6A6] block">{totalCorrect}</span>
            <span className="text-[#9BB0D6]">إجابة صحيحة</span>
          </div>
          <div className="bg-[#1B2640] p-3 rounded-xl border border-[#2B3B5C]">
            <span className="text-base font-bold text-[#7DB8FF] block">{accuracy}%</span>
            <span className="text-[#9BB0D6]">متوسط الدقة</span>
          </div>
          <div className="bg-[#1B2640] p-3 rounded-xl border border-[#2B3B5C]">
            <span className="text-base font-bold text-[#FFC76A] block">{attemptHistory.length}</span>
            <span className="text-[#9BB0D6]">اختبار مكتمل</span>
          </div>
        </div>
      </div>

      {/* Edit Profile Form */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-4">
        <h3 className="font-bold text-white text-base flex items-center gap-2">
          <Sparkles className="w-4 h-4 text-[#52D6A6]" />
          تعديل بيانات الحساب
        </h3>

        <form onSubmit={handleSave} className="space-y-4 text-xs">
          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1.5">الاسم الكامل</label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3.5 py-2.5 text-white outline-none focus:border-[#52D6A6]"
            />
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1.5">اسم المستخدم (Username)</label>
            <input
              type="text"
              dir="ltr"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3.5 py-2.5 text-white outline-none focus:border-[#52D6A6]"
            />
          </div>

          <div>
            <label className="block text-[#9BB0D6] font-semibold mb-1.5">
              رقم الطالب الجامعي (غير قابل للتعديل)
            </label>
            <input
              type="text"
              disabled
              value={currentUser.university_id}
              className="w-full bg-[#1B2640] border border-[#2B3B5C] text-[#9BB0D6] rounded-xl px-3.5 py-2.5 outline-none cursor-not-allowed"
            />
          </div>

          <div className="pt-2">
            <button
              type="submit"
              className="w-full py-3 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-xs rounded-xl transition flex items-center justify-center gap-2 shadow-md cursor-pointer"
            >
              {saveSuccess ? (
                <>
                  <CheckCircle2 className="w-4 h-4" /> تم الحفظ بنجاح
                </>
              ) : (
                <>
                  <Save className="w-4 h-4" /> حفظ التعديلات
                </>
              )}
            </button>
          </div>
        </form>
      </div>

      {/* Logout Button */}
      <button
        onClick={logout}
        className="w-full py-3.5 rounded-xl border border-[#FF7E86] text-[#FF7E86] hover:bg-[#3C1F2B] font-bold text-xs transition flex items-center justify-center gap-2"
      >
        <LogOut className="w-4 h-4" />
        تسجيل الخروج من الحساب
      </button>
    </div>
  );
};
