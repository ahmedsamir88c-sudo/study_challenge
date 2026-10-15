import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { StudyPlan } from '../types';
import {
  Zap,
  Brain,
  Calendar,
  BarChart3,
  CheckCircle2,
  Eye,
  EyeOff,
  Plus,
  Play,
  Trash2,
  Edit,
  Clock,
  Sparkles,
  Info,
  Layers,
} from 'lucide-react';

interface StudyHubScreenProps {
  onStartDailyChallenge: () => void;
}

export const StudyHubScreen: React.FC<StudyHubScreenProps> = ({ onStartDailyChallenge }) => {
  const {
    dailyChallenge,
    reviewItems,
    markReviewed,
    studyPlans,
    savePlan,
    deletePlan,
    togglePlanActive,
    attemptHistory,
    subjects,
  } = useApp();

  const [activeTab, setActiveTab] = useState<'challenge' | 'review' | 'plans' | 'reports'>('challenge');
  const [revealedAnswers, setRevealedAnswers] = useState<Set<number>>(new Set());

  // Plan modal state
  const [isPlanModalOpen, setIsPlanModalOpen] = useState(false);
  const [editingPlan, setEditingPlan] = useState<StudyPlan | null>(null);
  const [planTitle, setPlanTitle] = useState('');
  const [planSubjectId, setPlanSubjectId] = useState<number | null>(null);
  const [planMinutes, setPlanMinutes] = useState(30);
  const [planSessions, setPlanSessions] = useState(5);
  const [planStartDate, setPlanStartDate] = useState(new Date().toISOString().slice(0, 10));
  const [planEndDate, setPlanEndDate] = useState('');
  const [planNotes, setPlanNotes] = useState('');

  // Report period
  const [reportDays, setReportDays] = useState(30);

  const toggleRevealAnswer = (id: number) => {
    setRevealedAnswers((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const openPlanDialog = (plan?: StudyPlan) => {
    if (plan) {
      setEditingPlan(plan);
      setPlanTitle(plan.title);
      setPlanSubjectId(plan.subject_id ?? null);
      setPlanMinutes(plan.target_minutes_per_day);
      setPlanSessions(plan.sessions_per_week);
      setPlanStartDate(plan.start_date);
      setPlanEndDate(plan.end_date || '');
      setPlanNotes(plan.notes || '');
    } else {
      setEditingPlan(null);
      setPlanTitle('');
      setPlanSubjectId(subjects[0]?.id ?? null);
      setPlanMinutes(30);
      setPlanSessions(5);
      setPlanStartDate(new Date().toISOString().slice(0, 10));
      setPlanEndDate('');
      setPlanNotes('');
    }
    setIsPlanModalOpen(true);
  };

  const handleSavePlanSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!planTitle.trim()) return;

    const subjectObj = subjects.find((s) => s.id === planSubjectId);

    savePlan({
      id: editingPlan?.id,
      title: planTitle.trim(),
      subject_id: planSubjectId,
      subject_name: subjectObj?.name,
      target_minutes_per_day: Number(planMinutes) || 30,
      sessions_per_week: Number(planSessions) || 5,
      start_date: planStartDate,
      end_date: planEndDate.trim() ? planEndDate.trim() : null,
      notes: planNotes.trim(),
    });

    setIsPlanModalOpen(false);
  };

  // Report calculations based on actual attempts
  const totalQuizzes = attemptHistory.length;
  const totalQuestionsSolved = attemptHistory.reduce((acc, cur) => acc + cur.total_questions, 0);
  const totalCorrect = attemptHistory.reduce((acc, cur) => acc + cur.score, 0);
  const totalAccuracy = totalQuestionsSolved > 0 ? Math.round((totalCorrect / totalQuestionsSolved) * 100) : 85;
  const totalXpEarned = attemptHistory.reduce((acc, cur) => acc + cur.earned_xp, 0);

  const dueReviews = reviewItems.filter((item) => !item.reviewed_at);

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6 space-y-5 animate-in fade-in duration-300">
      {/* Tab Navigation */}
      <div className="flex border-b border-[#2B3B5C] overflow-x-auto">
        <button
          onClick={() => setActiveTab('challenge')}
          className={`flex items-center gap-2 py-3 px-4 text-xs sm:text-sm font-bold border-b-2 transition whitespace-nowrap ${
            activeTab === 'challenge'
              ? 'border-[#52D6A6] text-[#52D6A6]'
              : 'border-transparent text-[#9BB0D6] hover:text-white'
          }`}
        >
          <Zap className="w-4 h-4" />
          التحدي اليومي
        </button>

        <button
          onClick={() => setActiveTab('review')}
          className={`flex items-center gap-2 py-3 px-4 text-xs sm:text-sm font-bold border-b-2 transition whitespace-nowrap ${
            activeTab === 'review'
              ? 'border-[#52D6A6] text-[#52D6A6]'
              : 'border-transparent text-[#9BB0D6] hover:text-white'
          }`}
        >
          <Brain className="w-4 h-4" />
          المراجعة الذكية
          {dueReviews.length > 0 && (
            <span className="bg-[#FFC76A] text-[#0B1020] text-[10px] font-black px-1.5 py-0.2 rounded-full">
              {dueReviews.length}
            </span>
          )}
        </button>

        <button
          onClick={() => setActiveTab('plans')}
          className={`flex items-center gap-2 py-3 px-4 text-xs sm:text-sm font-bold border-b-2 transition whitespace-nowrap ${
            activeTab === 'plans'
              ? 'border-[#52D6A6] text-[#52D6A6]'
              : 'border-transparent text-[#9BB0D6] hover:text-white'
          }`}
        >
          <Calendar className="w-4 h-4" />
          خطة الدراسة ({studyPlans.length})
        </button>

        <button
          onClick={() => setActiveTab('reports')}
          className={`flex items-center gap-2 py-3 px-4 text-xs sm:text-sm font-bold border-b-2 transition whitespace-nowrap ${
            activeTab === 'reports'
              ? 'border-[#52D6A6] text-[#52D6A6]'
              : 'border-transparent text-[#9BB0D6] hover:text-white'
          }`}
        >
          <BarChart3 className="w-4 h-4" />
          التقارير والإحصائيات
        </button>
      </div>

      {/* Tab 1: Daily Challenge View */}
      {activeTab === 'challenge' && (
        <div className="space-y-4 animate-in fade-in">
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-6 shadow-md space-y-4">
            <div className="w-12 h-12 rounded-xl bg-[#FFC76A]/10 border border-[#FFC76A]/30 text-[#FFC76A] flex items-center justify-center">
              <Zap className="w-6 h-6 fill-current" />
            </div>

            <div>
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-bold text-white">تحدي يوم {dailyChallenge.date}</h3>
                {dailyChallenge.completed && (
                  <span className="bg-[#69E4A7]/15 border border-[#69E4A7]/40 text-[#69E4A7] text-xs font-bold px-3 py-1 rounded-full flex items-center gap-1">
                    <CheckCircle2 className="w-3.5 h-3.5" /> تم الإنجاز
                  </span>
                )}
              </div>
              <p className="text-xs sm:text-sm text-[#9BB0D6] mt-1.5 leading-relaxed">
                {dailyChallenge.completed
                  ? `أكملت التحدي اليومي بنجاح وحصلت على ${dailyChallenge.score} من ${dailyChallenge.total_questions} أسئلة! مكافأة +25 XP أضيفت لحسابك.`
                  : `أجب عن ${dailyChallenge.goal_questions} أسئلة في مادة ${dailyChallenge.subject} (المحاضرة ${dailyChallenge.lecture}) لتحصل على ${dailyChallenge.bonus_xp} XP إضافية.`}
              </p>
            </div>

            <button
              onClick={onStartDailyChallenge}
              disabled={dailyChallenge.completed}
              className={`w-full py-3.5 px-4 rounded-xl text-sm font-bold flex items-center justify-center gap-2 transition shadow-lg ${
                dailyChallenge.completed
                  ? 'bg-[#1B2640] border border-[#2B3B5C] text-[#9BB0D6] cursor-not-allowed'
                  : 'bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] cursor-pointer'
              }`}
            >
              <Play className="w-4 h-4 fill-current" />
              {dailyChallenge.completed ? 'تم إنجاز تحدي اليوم' : 'ابدأ التحدي اليومي الآن'}
            </button>
          </div>

          <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-2xl p-5 flex gap-3 text-xs leading-relaxed text-[#DEEBFF]">
            <Info className="w-5 h-5 text-[#7DB8FF] flex-shrink-0 mt-0.5" />
            <div>
              <h4 className="font-bold text-white mb-1">كيف يعمل التحدي اليومي؟</h4>
              <p className="text-[#9BB0D6]">
                يتجدد التحدي يومياً باختيار 5 أسئلة منسقة من مقرراتك وسلايدات المحاضرات. إجابتك
                الصحيحة ترفع سلسلة أيام المذاكرة اليومية وتمنحك مكافأة XP تميزك في لوحة المتصدرين.
              </p>
            </div>
          </div>
        </div>
      )}

      {/* Tab 2: Smart Review View (Spaced Repetition) */}
      {activeTab === 'review' && (
        <div className="space-y-4 animate-in fade-in">
          <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-2xl p-4 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <Brain className="w-5 h-5 text-[#52D6A6]" />
              <span className="text-sm font-bold text-white">
                أسئلة بحاجة إلى مراجعة: {dueReviews.length}
              </span>
            </div>
            <span className="text-xs text-[#9BB0D6]">تكرار متباعد لتثبيت الأخطاء السابقة</span>
          </div>

          {reviewItems.length === 0 ? (
            <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-8 text-center text-[#9BB0D6] text-xs sm:text-sm">
              لا توجد أسئلة للمراجعة حالياً. عند إجابة أي سؤال بشكل خاطئ في الاختبارات، سيظهر هنا
              تلقائياً لمراجعته.
            </div>
          ) : (
            <div className="space-y-3">
              {reviewItems.map((item) => {
                const isRevealed = revealedAnswers.has(item.id);
                const isReviewed = item.reviewed_at !== null;
                const correctText = item.options[item.correct_index];

                return (
                  <div
                    key={item.id}
                    className={`bg-[#141C2E] border rounded-2xl p-5 shadow-sm space-y-3 transition ${
                      isReviewed ? 'border-[#2B3B5C]/60 opacity-80' : 'border-[#FFC76A]/40'
                    }`}
                  >
                    <div className="flex items-center justify-between text-xs">
                      <span className="text-[#FFC76A] font-bold">
                        {item.subject} • المحاضرة {item.lecture}
                      </span>
                      {isReviewed ? (
                        <span className="text-[#52D6A6] font-semibold flex items-center gap-1">
                          <CheckCircle2 className="w-3.5 h-3.5" /> تمت المراجعة ({item.review_count} مرة)
                        </span>
                      ) : (
                        <span className="text-[#FF7E86] bg-[#FF7E86]/10 px-2 py-0.5 rounded font-bold">
                          بانتظار المراجعة
                        </span>
                      )}
                    </div>

                    <p className="text-sm font-bold text-white leading-relaxed">{item.question}</p>

                    {isRevealed && (
                      <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-xl p-3.5 text-xs space-y-1.5 animate-in fade-in">
                        <div className="text-[#52D6A6] font-bold">الإجابة الصحيحة: {correctText}</div>
                        {item.explanation && (
                          <div className="text-[#DEEBFF] leading-relaxed pt-1 border-t border-[#2B3B5C]/60">
                            {item.explanation}
                          </div>
                        )}
                      </div>
                    )}

                    <div className="flex items-center gap-2 pt-1">
                      <button
                        onClick={() => toggleRevealAnswer(item.id)}
                        className="py-1.5 px-3 bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] text-[#DEEBFF] text-xs font-semibold rounded-lg transition flex items-center gap-1.5"
                      >
                        {isRevealed ? (
                          <>
                            <EyeOff className="w-3.5 h-3.5" /> إخفاء الإجابة
                          </>
                        ) : (
                          <>
                            <Eye className="w-3.5 h-3.5" /> إظهار الإجابة
                          </>
                        )}
                      </button>

                      {!isReviewed && (
                        <button
                          onClick={() => markReviewed(item.id)}
                          className="py-1.5 px-3 bg-[#52D6A6]/20 hover:bg-[#52D6A6]/30 border border-[#52D6A6]/40 text-[#52D6A6] text-xs font-bold rounded-lg transition flex items-center gap-1.5"
                        >
                          <CheckCircle2 className="w-3.5 h-3.5" /> تم استيعاب المعلومة
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* Tab 3: Study Plans View */}
      {activeTab === 'plans' && (
        <div className="space-y-4 animate-in fade-in">
          <div className="flex items-center justify-between">
            <h3 className="font-bold text-white text-base">خطط وجداول المذاكرة</h3>
            <button
              onClick={() => openPlanDialog()}
              className="py-2 px-3.5 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] text-xs font-bold rounded-xl transition flex items-center gap-1.5 shadow-md"
            >
              <Plus className="w-4 h-4" />
              إنشاء خطة مذاكرة
            </button>
          </div>

          {studyPlans.length === 0 ? (
            <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-8 text-center text-[#9BB0D6] text-xs sm:text-sm">
              لم تنشئ أي خطة مذاكرة بعد. حدد أهدافك الأسبوعية والمواد لبدء جدول منظم.
            </div>
          ) : (
            <div className="space-y-3">
              {studyPlans.map((plan) => (
                <div
                  key={plan.id}
                  className={`bg-[#141C2E] border rounded-2xl p-5 shadow-sm flex flex-col sm:flex-row sm:items-center justify-between gap-4 transition ${
                    plan.is_active ? 'border-[#2B3B5C] hover:border-[#52D6A6]/40' : 'border-[#2B3B5C]/40 opacity-60'
                  }`}
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <h4 className="font-bold text-white text-base">{plan.title}</h4>
                      <span
                        className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                          plan.is_active ? 'bg-[#52D6A6]/20 text-[#52D6A6]' : 'bg-[#9BB0D6]/20 text-[#9BB0D6]'
                        }`}
                      >
                        {plan.is_active ? 'نشطة' : 'متوقفة'}
                      </span>
                    </div>

                    <p className="text-xs text-[#9BB0D6]">
                      {plan.subject_name ? `${plan.subject_name} • ` : ''}
                      {plan.target_minutes_per_day} دقيقة يومياً • {plan.sessions_per_week} جلسات أسبوعياً
                    </p>

                    <p className="text-[11px] text-[#7DB8FF]">
                      الفترة: {plan.start_date} {plan.end_date ? `إلى ${plan.end_date}` : ''}
                    </p>

                    {plan.notes && <p className="text-xs text-[#DEEBFF] italic mt-1">{plan.notes}</p>}
                  </div>

                  <div className="flex items-center gap-2 self-end sm:self-center">
                    <button
                      onClick={() => togglePlanActive(plan.id)}
                      className="p-2 rounded-lg bg-[#1B2640] border border-[#2B3B5C] text-xs text-[#DEEBFF] hover:border-[#52D6A6]/50 transition"
                      title={plan.is_active ? 'إيقاف الخطة' : 'تفعيل الخطة'}
                    >
                      {plan.is_active ? 'إيقاف' : 'تفعيل'}
                    </button>
                    <button
                      onClick={() => openPlanDialog(plan)}
                      className="p-2 rounded-lg bg-[#1B2640] border border-[#2B3B5C] text-[#DEEBFF] hover:text-[#52D6A6] transition"
                      title="تعديل"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => deletePlan(plan.id)}
                      className="p-2 rounded-lg bg-[#1B2640] border border-[#2B3B5C] text-[#FF7E86] hover:bg-[#3C1F2B] transition"
                      title="حذف"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Tab 4: Reports View */}
      {activeTab === 'reports' && (
        <div className="space-y-5 animate-in fade-in">
          {/* Period selector */}
          <div className="flex items-center justify-between bg-[#1B2640] border border-[#2B3B5C] p-3 rounded-xl">
            <span className="text-xs font-bold text-white flex items-center gap-2">
              <Calendar className="w-4 h-4 text-[#52D6A6]" />
              الفترة الزمنية للتقرير:
            </span>
            <select
              value={reportDays}
              onChange={(e) => setReportDays(Number(e.target.value))}
              className="bg-[#0B1020] border border-[#2B3B5C] text-white rounded-lg px-3 py-1.5 text-xs outline-none"
            >
              <option value={7}>آخر 7 أيام</option>
              <option value={30}>آخر 30 يوماً</option>
              <option value={90}>آخر 90 يوماً</option>
            </select>
          </div>

          {/* Metric KPI cards */}
          <div className="grid grid-cols-2 sm:grid-cols-5 gap-3">
            <div className="bg-[#141C2E] border border-[#2B3B5C] p-4 rounded-xl text-center">
              <span className="text-2xl font-black text-white block">{totalQuizzes}</span>
              <span className="text-xs text-[#9BB0D6] mt-1 block">الاختبارات</span>
            </div>
            <div className="bg-[#141C2E] border border-[#2B3B5C] p-4 rounded-xl text-center">
              <span className="text-2xl font-black text-[#52D6A6] block">{totalQuestionsSolved}</span>
              <span className="text-xs text-[#9BB0D6] mt-1 block">الأسئلة المحلولة</span>
            </div>
            <div className="bg-[#141C2E] border border-[#2B3B5C] p-4 rounded-xl text-center">
              <span className="text-2xl font-black text-[#7DB8FF] block">{totalAccuracy}%</span>
              <span className="text-xs text-[#9BB0D6] mt-1 block">معدل الدقة</span>
            </div>
            <div className="bg-[#141C2E] border border-[#2B3B5C] p-4 rounded-xl text-center">
              <span className="text-2xl font-black text-[#FFC76A] block">+{totalXpEarned}</span>
              <span className="text-xs text-[#9BB0D6] mt-1 block">نقاط XP</span>
            </div>
            <div className="bg-[#141C2E] border border-[#2B3B5C] p-4 rounded-xl text-center col-span-2 sm:col-span-1">
              <span className="text-2xl font-black text-white block">12 يوم</span>
              <span className="text-xs text-[#9BB0D6] mt-1 block">أيام النشاط</span>
            </div>
          </div>

          {/* Subject Breakdown */}
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 space-y-4">
            <h4 className="font-bold text-white text-sm flex items-center gap-2">
              <Layers className="w-4 h-4 text-[#52D6A6]" />
              التقدم ومعدل الدقة حسب المادة
            </h4>

            <div className="space-y-3">
              {[
                { name: 'Computer Architecture', total: 45, correct: 41, percent: 91 },
                { name: 'Data Structure and Algorithms', total: 35, correct: 29, percent: 83 },
                { name: 'Digital Logic Design', total: 30, correct: 26, percent: 87 },
              ].map((subj, idx) => (
                <div key={idx} className="space-y-1.5">
                  <div className="flex items-center justify-between text-xs font-semibold">
                    <span className="text-white">{subj.name}</span>
                    <span className="text-[#52D6A6]">{subj.correct}/{subj.total} سؤال ({subj.percent}%)</span>
                  </div>
                  <div className="w-full bg-[#1B2640] rounded-full h-2 overflow-hidden">
                    <div
                      className="bg-[#52D6A6] h-full rounded-full transition-all duration-300"
                      style={{ width: `${subj.percent}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Plan Create/Edit Modal */}
      {isPlanModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl w-full max-w-md p-6 space-y-4 shadow-2xl animate-in fade-in">
            <h3 className="font-bold text-white text-base">
              {editingPlan ? 'تعديل خطة المذاكرة' : 'إنشاء خطة مذاكرة جديدة'}
            </h3>

            <form onSubmit={handleSavePlanSubmit} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-[#DEEBFF] font-semibold mb-1">اسم الخطة *</label>
                <input
                  type="text"
                  required
                  value={planTitle}
                  onChange={(e) => setPlanTitle(e.target.value)}
                  placeholder="مثال: مراجعة الميدتيرم لمادة معمارية الحاسوب"
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none focus:border-[#52D6A6]"
                />
              </div>

              <div>
                <label className="block text-[#DEEBFF] font-semibold mb-1">المادة المرتبطة (اختياري)</label>
                <select
                  value={planSubjectId ?? ''}
                  onChange={(e) => setPlanSubjectId(e.target.value ? Number(e.target.value) : null)}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                >
                  <option value="">كل المواد</option>
                  {subjects.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#DEEBFF] font-semibold mb-1">دقائق المذاكرة يومياً</label>
                  <input
                    type="number"
                    min={10}
                    max={360}
                    value={planMinutes}
                    onChange={(e) => setPlanMinutes(Number(e.target.value))}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>

                <div>
                  <label className="block text-[#DEEBFF] font-semibold mb-1">جلسات أسبوعياً</label>
                  <input
                    type="number"
                    min={1}
                    max={7}
                    value={planSessions}
                    onChange={(e) => setPlanSessions(Number(e.target.value))}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[#DEEBFF] font-semibold mb-1">تاريخ البداية</label>
                  <input
                    type="date"
                    value={planStartDate}
                    onChange={(e) => setPlanStartDate(e.target.value)}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>

                <div>
                  <label className="block text-[#DEEBFF] font-semibold mb-1">تاريخ النهاية</label>
                  <input
                    type="date"
                    value={planEndDate}
                    onChange={(e) => setPlanEndDate(e.target.value)}
                    className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[#DEEBFF] font-semibold mb-1">ملاحظات إضافية</label>
                <textarea
                  rows={2}
                  value={planNotes}
                  onChange={(e) => setPlanNotes(e.target.value)}
                  placeholder="ملاحظات حول الفصول والمسائل المطلوب حلها..."
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-xl px-3 py-2 text-white outline-none resize-none"
                />
              </div>

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-[#2B3B5C]">
                <button
                  type="button"
                  onClick={() => setIsPlanModalOpen(false)}
                  className="px-4 py-2 bg-[#1B2640] text-white rounded-xl font-semibold"
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  className="px-5 py-2 bg-[#52D6A6] text-[#0B1020] rounded-xl font-bold hover:bg-[#23B780] transition"
                >
                  حفظ الخطة
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
