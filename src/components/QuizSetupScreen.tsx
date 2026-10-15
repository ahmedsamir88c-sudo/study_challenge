import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { QuizQuestion } from '../types';
import {
  Trophy,
  BookOpen,
  Video,
  ListOrdered,
  Gauge,
  Play,
  CheckCircle2,
  AlertCircle,
  Sparkles,
} from 'lucide-react';

interface QuizSetupScreenProps {
  onStartQuiz: (quizData: { quiz_id: string; questions: QuizQuestion[]; subject: string; lecture: number }) => void;
  initialSubject?: string;
  isDailyChallenge?: boolean;
}

export const QuizSetupScreen: React.FC<QuizSetupScreenProps> = ({
  onStartQuiz,
  initialSubject,
  isDailyChallenge = false,
}) => {
  const { subjects, createQuiz } = useApp();

  const [selectedSubject, setSelectedSubject] = useState<string>(
    initialSubject || 'Computer Architecture'
  );
  const [selectedLecture, setSelectedLecture] = useState<number | null>(1);
  const [selectedCount, setSelectedCount] = useState<number | null>(isDailyChallenge ? 5 : 10);
  const [selectedDifficulty, setSelectedDifficulty] = useState<'easy' | 'medium' | 'hard'>('medium');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const QUESTION_COUNTS = [5, 10, 20, 25, 30, 40, 50];

  const difficultyOptions = [
    { key: 'easy' as const, label: 'سهل', desc: 'مفاهيم أساسية وتعاريف', xp: 1, color: 'text-[#69E4A7]' },
    { key: 'medium' as const, label: 'متوسط', desc: 'تطبيقات ومسائل نموذجية', xp: 1, color: 'text-[#7DB8FF]' },
    { key: 'hard' as const, label: 'صعب', desc: 'مسائل تحليل وتصميم متقدمة', xp: 1, color: 'text-[#FF7E86]' },
  ];

  const currentDiff = difficultyOptions.find((d) => d.key === selectedDifficulty) || difficultyOptions[1];
  const calculatedMaxXp = (selectedCount || 0) * currentDiff.xp;

  const isFormComplete = selectedSubject && selectedLecture !== null && selectedCount !== null;

  const handleStart = () => {
    if (!isFormComplete) {
      setErrorMessage('يرجى إكمال جميع خطوات إعداد الاختبار أولاً');
      return;
    }

    const quiz = createQuiz(selectedSubject, selectedLecture!, selectedCount!, selectedDifficulty, isDailyChallenge);
    if (!quiz || quiz.questions.length === 0) {
      setErrorMessage('عذراً، لا توجد أسئلة كافية متاحة لهذه المحاضرة حالياً.');
      return;
    }

    onStartQuiz({
      ...quiz,
      subject: selectedSubject,
      lecture: selectedLecture!,
    });
  };

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-2xl p-5 flex items-center gap-4 shadow-lg">
        <div className="w-14 h-14 rounded-2xl bg-[#173A2E] border border-[#52D6A6]/30 flex items-center justify-center text-[#7DB8FF] flex-shrink-0">
          <Trophy className="w-7 h-7" />
        </div>
        <div>
          <h2 className="text-xl font-bold text-white tracking-tight flex items-center gap-2">
            جهّز تحدّيك المخصص!
            <Sparkles className="w-4 h-4 text-[#FFC76A]" />
          </h2>
          <p className="text-sm text-[#7DB8FF] mt-1">
            {calculatedMaxXp > 0
              ? `يمكنك كسب حتى ${calculatedMaxXp} نقطة في هذا الاختبار`
              : 'اختر المادة والمحاضرة للبدء في حصد النقاط واختبار معلوماتك'}
          </p>
        </div>
      </div>

      {errorMessage && (
        <div className="p-3.5 bg-[#3C1F2B] border border-[#FF7E86]/50 rounded-xl flex items-center gap-3 text-xs text-[#FF7E86]">
          <AlertCircle className="w-5 h-5 flex-shrink-0" />
          <span>{errorMessage}</span>
        </div>
      )}

      {/* Step 1: Subject Selection */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
        <div className="flex items-center gap-2.5">
          <span className="w-7 h-7 rounded-full bg-[#52D6A6]/20 border border-[#52D6A6] text-[#52D6A6] text-xs font-bold flex items-center justify-center">
            1
          </span>
          <h3 className="font-bold text-white text-base">الخطوة الأولى: اختر اسم المادة</h3>
          <span className="text-[#FF7E86] text-sm">*</span>
        </div>
        <p className="text-xs text-[#9BB0D6] pr-9">المواد المعتمدة في مقرراتك الدراسية</p>

        <div className="pt-1">
          <div className="relative">
            <select
              value={selectedSubject}
              onChange={(e) => {
                setSelectedSubject(e.target.value);
                setSelectedLecture(1);
              }}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] text-white rounded-xl px-4 py-3 text-sm appearance-none cursor-pointer outline-none transition"
            >
              {Array.from(new Set(subjects.map((s) => s.name))).map((name) => (
                <option key={name} value={name} className="bg-[#141C2E]">
                  {name}
                </option>
              ))}
            </select>
            <BookOpen className="w-4 h-4 text-[#9BB0D6] absolute left-4 top-3.5 pointer-events-none" />
          </div>
        </div>
      </div>

      {/* Step 2: Lecture Selection */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
        <div className="flex items-center gap-2.5">
          <span className="w-7 h-7 rounded-full bg-[#52D6A6]/20 border border-[#52D6A6] text-[#52D6A6] text-xs font-bold flex items-center justify-center">
            2
          </span>
          <h3 className="font-bold text-white text-base">الخطوة الثانية: اختر رقم المحاضرة</h3>
          <span className="text-[#FF7E86] text-sm">*</span>
        </div>
        <p className="text-xs text-[#9BB0D6] pr-9">
          المحاضرات المتاحة: (1 إلى 16) لمادة {selectedSubject}
        </p>

        <div className="pt-1">
          <div className="relative">
            <select
              value={selectedLecture ?? 1}
              onChange={(e) => setSelectedLecture(Number(e.target.value))}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] text-white rounded-xl px-4 py-3 text-sm appearance-none cursor-pointer outline-none transition"
            >
              {Array.from({ length: 16 }, (_, i) => i + 1).map((num) => (
                <option key={num} value={num} className="bg-[#141C2E]">
                  المحاضرة رقم ({num})
                </option>
              ))}
            </select>
            <Video className="w-4 h-4 text-[#9BB0D6] absolute left-4 top-3.5 pointer-events-none" />
          </div>
        </div>
      </div>

      {/* Step 3: Question Count */}
      {!isDailyChallenge ? (
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
          <div className="flex items-center gap-2.5">
            <span className="w-7 h-7 rounded-full bg-[#52D6A6]/20 border border-[#52D6A6] text-[#52D6A6] text-xs font-bold flex items-center justify-center">
              3
            </span>
            <h3 className="font-bold text-white text-base">الخطوة الثالثة: اختر عدد الأسئلة</h3>
            <span className="text-[#FF7E86] text-sm">*</span>
          </div>

          <div className="grid grid-cols-4 sm:grid-cols-7 gap-2 pt-1">
            {QUESTION_COUNTS.map((cnt) => {
              const isSelected = selectedCount === cnt;
              return (
                <button
                  key={cnt}
                  type="button"
                  onClick={() => setSelectedCount(cnt)}
                  className={`py-2.5 px-3 rounded-xl text-xs font-bold border transition ${
                    isSelected
                      ? 'bg-[#52D6A6] text-[#0B1020] border-[#52D6A6] shadow-md'
                      : 'bg-[#0B1020] text-[#DEEBFF] border-[#2B3B5C] hover:border-[#52D6A6]/50'
                  }`}
                >
                  {cnt} سؤال
                </button>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <ListOrdered className="w-5 h-5 text-[#FFC76A]" />
              <span className="font-bold text-white text-sm">التحدي اليومي: 5 أسئلة</span>
            </div>
            <span className="text-xs text-[#52D6A6] bg-[#173A2E] px-2.5 py-1 rounded-full font-semibold">
              +25 XP إضافية عند النجاح
            </span>
          </div>
        </div>
      )}

      {/* Step 4: Difficulty */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-5 shadow-sm space-y-3">
        <div className="flex items-center gap-2.5">
          <span className="w-7 h-7 rounded-full bg-[#52D6A6]/20 border border-[#52D6A6] text-[#52D6A6] text-xs font-bold flex items-center justify-center">
            4
          </span>
          <h3 className="font-bold text-white text-base">الخطوة الرابعة: اختر مستوى الصعوبة</h3>
          <span className="text-[#FF7E86] text-sm">*</span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
          {difficultyOptions.map((diff) => {
            const isSelected = selectedDifficulty === diff.key;
            return (
              <button
                key={diff.key}
                type="button"
                onClick={() => setSelectedDifficulty(diff.key)}
                className={`p-3.5 rounded-xl border text-right transition flex items-center justify-between ${
                  isSelected
                    ? 'bg-[#1B2640] border-[#52D6A6] shadow-md'
                    : 'bg-[#0B1020] border-[#2B3B5C] hover:border-[#52D6A6]/40'
                }`}
              >
                <div>
                  <div className={`text-sm font-bold ${diff.color}`}>{diff.label}</div>
                  <div className="text-[11px] text-[#9BB0D6] mt-0.5">{diff.desc}</div>
                </div>
                <Gauge className={`w-5 h-5 ${diff.color}`} />
              </button>
            );
          })}
        </div>
      </div>

      {/* Summary Card */}
      {isFormComplete && (
        <div className="bg-[#1B2640] border border-[#52D6A6]/40 rounded-2xl p-5 shadow-md space-y-3">
          <div className="flex items-center gap-2 text-[#52D6A6]">
            <CheckCircle2 className="w-5 h-5" />
            <h4 className="font-bold text-sm">ملخص الاختبار المحدد</h4>
          </div>

          <div className="divide-y divide-[#2B3B5C]/60 text-xs">
            <div className="py-2 flex justify-between">
              <span className="text-[#9BB0D6]">المادة الدراسية:</span>
              <span className="text-white font-semibold">{selectedSubject}</span>
            </div>
            <div className="py-2 flex justify-between">
              <span className="text-[#9BB0D6]">المحاضرة:</span>
              <span className="text-white font-semibold">المحاضرة رقم {selectedLecture}</span>
            </div>
            <div className="py-2 flex justify-between">
              <span className="text-[#9BB0D6]">عدد الأسئلة:</span>
              <span className="text-white font-semibold">{selectedCount} أسئلة</span>
            </div>
            <div className="py-2 flex justify-between">
              <span className="text-[#9BB0D6]">مستوى الصعوبة:</span>
              <span className={`font-semibold ${currentDiff.color}`}>{currentDiff.label}</span>
            </div>
            <div className="py-2 flex justify-between items-center text-sm font-bold">
              <span className="text-white">أقصى نقاط ممكنة:</span>
              <span className="text-[#7DB8FF] text-base">+{calculatedMaxXp} نقطة</span>
            </div>
          </div>
        </div>
      )}

      {/* Start Button */}
      <button
        onClick={handleStart}
        disabled={!isFormComplete}
        className={`w-full py-4 rounded-xl text-base font-bold flex items-center justify-center gap-2 shadow-xl transition ${
          isFormComplete
            ? 'bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] cursor-pointer'
            : 'bg-[#23314F] text-[#7286B1] cursor-not-allowed'
        }`}
      >
        <Play className="w-5 h-5 fill-current" />
        {isFormComplete ? 'ابدأ الاختبار الآن' : 'أكمل الخطوات أعلاه للبدء'}
      </button>
    </div>
  );
};
