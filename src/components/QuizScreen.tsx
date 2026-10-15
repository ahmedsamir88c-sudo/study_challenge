import React, { useState, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { QuizQuestion, QuizAttemptResult } from '../types';
import {
  Clock,
  Zap,
  X,
  CheckCircle2,
  AlertCircle,
  Trophy,
  ArrowRight,
  RotateCcw,
  BookOpen,
} from 'lucide-react';

interface QuizScreenProps {
  quizData: {
    quiz_id: string;
    questions: QuizQuestion[];
    subject: string;
    lecture: number;
  };
  onClose: () => void;
  onNewQuiz: () => void;
  isDailyChallenge?: boolean;
}

export const QuizScreen: React.FC<QuizScreenProps> = ({
  quizData,
  onClose,
  onNewQuiz,
  isDailyChallenge = false,
}) => {
  const { submitQuiz } = useApp();
  const { questions, subject, lecture, quiz_id } = quizData;

  const [currentIndex, setCurrentIndex] = useState(0);
  const [selectedOption, setSelectedOption] = useState<number | null>(null);
  const [answered, setAnswered] = useState(false);
  const [timeLeft, setTimeLeft] = useState(30);
  const [answersMap, setAnswersMap] = useState<Record<string, number | null>>({});
  const [result, setResult] = useState<QuizAttemptResult | null>(null);

  const currentQ = questions[currentIndex];

  // Timer effect
  useEffect(() => {
    if (result || answered) return;

    setTimeLeft(30);
    const interval = setInterval(() => {
      setTimeLeft((prev) => {
        if (prev <= 1) {
          clearInterval(interval);
          handleTimeUp();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [currentIndex, answered, result]);

  const handleTimeUp = () => {
    if (!answered) {
      handleSelectOption(-1);
    }
  };

  const handleSelectOption = (index: number) => {
    if (answered || result) return;
    setSelectedOption(index);
    setAnswered(true);
    setAnswersMap((prev) => ({
      ...prev,
      [currentQ.id.toString()]: index >= 0 ? index : null,
    }));
  };

  const handleNext = () => {
    if (currentIndex < questions.length - 1) {
      setCurrentIndex((prev) => prev + 1);
      setSelectedOption(null);
      setAnswered(false);
    } else {
      finishQuiz();
    }
  };

  const finishQuiz = () => {
    const formattedAnswers = questions.map((q) => ({
      question_id: q.id.toString(),
      selected_index: answersMap[q.id.toString()] ?? null,
    }));

    const finalResult = submitQuiz(
      quiz_id,
      subject,
      lecture,
      formattedAnswers,
      isDailyChallenge
    );
    setResult(finalResult);
  };

  // If Quiz Completed, Show Results View
  if (result) {
    const percentage = Math.round((result.score / result.total_questions) * 100);

    return (
      <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-6 animate-in fade-in duration-300">
        <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-6 sm:p-8 text-center shadow-xl">
          {/* Trophy Badge */}
          <div className="w-20 h-20 rounded-2xl bg-[#173A2E] border border-[#52D6A6]/40 text-[#FFC76A] flex items-center justify-center mx-auto mb-5 shadow-lg">
            <Trophy className="w-10 h-10 animate-bounce" />
          </div>

          <h2 className="text-2xl font-bold text-white tracking-tight">أحسنت! اكتمل الاختبار</h2>
          <p className="text-sm text-[#9BB0D6] mt-2">
            {percentage >= 70
              ? 'أداء رائع ومتميز في هذا التحدي! استمر في هذا المستوى العالي.'
              : 'أداء جيد، واصل المذاكرة والتدريب وستتحسن نتيجتك باستمرار.'}
          </p>

          {/* Metrics row */}
          <div className="grid grid-cols-2 gap-4 my-6">
            <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-xl p-4">
              <span className="text-xs text-[#9BB0D6] block">النتيجة والدرجة</span>
              <span className="text-2xl font-black text-white mt-1 block">
                {result.score} / {result.total_questions}
              </span>
              <span className="text-xs font-semibold text-[#52D6A6] mt-0.5 block">{percentage}%</span>
            </div>

            <div className="bg-[#1B2640] border border-[#2B3B5C] rounded-xl p-4">
              <span className="text-xs text-[#9BB0D6] block">النقاط المحصّلة</span>
              <span className="text-2xl font-black text-[#7DB8FF] mt-1 block">
                +{result.earned_xp} XP
              </span>
              <span className="text-xs text-[#9BB0D6] mt-0.5 block">أضيفت إلى رصيدك</span>
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex flex-col sm:flex-row gap-3">
            <button
              onClick={onClose}
              className="flex-1 py-3 px-4 rounded-xl bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-sm transition shadow-md"
            >
              العودة للرئيسية
            </button>
            <button
              onClick={onNewQuiz}
              className="flex-1 py-3 px-4 rounded-xl bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] text-white font-bold text-sm transition flex items-center justify-center gap-2"
            >
              <RotateCcw className="w-4 h-4 text-[#52D6A6]" />
              اختبار جديد
            </button>
          </div>
        </div>

        {/* Detailed Breakdown */}
        <div className="space-y-4">
          <h3 className="text-base font-bold text-white flex items-center gap-2">
            <BookOpen className="w-4 h-4 text-[#52D6A6]" />
            مراجعة وتفسير إجابات الأسئلة ({result.answers.length})
          </h3>

          <div className="space-y-3">
            {result.answers.map((ans, idx) => {
              const isCorrect = ans.is_correct;
              const userChosenText =
                ans.selected_index !== null && ans.selected_index >= 0
                  ? ans.options[ans.selected_index]
                  : 'لم تتم الإجابة (انتهى الوقت)';
              const correctText = ans.options[ans.correct_index];

              return (
                <div
                  key={idx}
                  className={`p-4 rounded-xl border bg-[#141C2E] transition ${
                    isCorrect ? 'border-[#52D6A6]/40' : 'border-[#FF7E86]/40'
                  }`}
                >
                  <div className="flex items-start justify-between gap-3">
                    <span className="text-xs font-bold text-[#9BB0D6] bg-[#1B2640] px-2 py-0.5 rounded-md">
                      سؤال {idx + 1}
                    </span>
                    <span
                      className={`text-xs font-bold px-2 py-0.5 rounded-full flex items-center gap-1 ${
                        isCorrect
                          ? 'bg-[#69E4A7]/15 text-[#69E4A7]'
                          : 'bg-[#FF7E86]/15 text-[#FF7E86]'
                      }`}
                    >
                      {isCorrect ? (
                        <>
                          <CheckCircle2 className="w-3.5 h-3.5" /> إجابة صحيحة
                        </>
                      ) : (
                        <>
                          <AlertCircle className="w-3.5 h-3.5" /> إجابة خاطئة
                        </>
                      )}
                    </span>
                  </div>

                  <p className="font-bold text-white text-sm mt-2.5 leading-relaxed">{ans.question}</p>

                  <div className="mt-3 space-y-1.5 text-xs">
                    <div className="flex items-center gap-2">
                      <span className="text-[#9BB0D6]">إجابتك:</span>
                      <span className={isCorrect ? 'text-[#69E4A7] font-semibold' : 'text-[#FF7E86] font-semibold'}>
                        {userChosenText}
                      </span>
                    </div>

                    {!isCorrect && (
                      <div className="flex items-center gap-2">
                        <span className="text-[#9BB0D6]">الإجابة النموذجية:</span>
                        <span className="text-[#69E4A7] font-semibold">{correctText}</span>
                      </div>
                    )}

                    {ans.explanation && (
                      <div className="mt-2 pt-2 border-t border-[#2B3B5C]/60 text-[#DEEBFF] bg-[#1B2640]/60 p-2.5 rounded-lg">
                        <span className="font-bold text-[#52D6A6] block mb-1">الشرح والتفسير العلمي:</span>
                        {ans.explanation}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    );
  }

  // Active Question View
  const progressPercent = ((currentIndex + 1) / questions.length) * 100;
  const isTimeCritical = timeLeft <= 10;

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-5 animate-in fade-in duration-300">
      {/* Top Header */}
      <div className="flex items-center justify-between pb-3 border-b border-[#2B3B5C]">
        <div className="flex items-center gap-2">
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-[#9BB0D6] hover:text-white hover:bg-[#1B2640] transition"
            title="إنهاء والعودة"
          >
            <X className="w-5 h-5" />
          </button>
          <div>
            <h3 className="font-bold text-white text-sm sm:text-base">
              السؤال {currentIndex + 1} من {questions.length}
            </h3>
            <span className="text-xs text-[#9BB0D6]">
              {subject} • المحاضرة {lecture}
            </span>
          </div>
        </div>

        {/* Timer & XP */}
        <div className="flex items-center gap-2">
          <div
            className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl border text-xs font-bold transition ${
              isTimeCritical
                ? 'bg-[#3C1F2B] border-[#FF7E86] text-[#FF7E86] animate-pulse'
                : 'bg-[#1B2640] border-[#2B3B5C] text-white'
            }`}
          >
            <Clock className="w-3.5 h-3.5" />
            <span>{timeLeft}s</span>
          </div>

          <div className="bg-[#7DB8FF]/10 border border-[#7DB8FF]/30 text-[#7DB8FF] px-2.5 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1">
            <Zap className="w-3.5 h-3.5 fill-[#7DB8FF]" />
            <span>+1 XP</span>
          </div>
        </div>
      </div>

      {/* Progress Bar */}
      <div className="w-full bg-[#1B2640] rounded-full h-2 overflow-hidden">
        <div
          className="bg-[#52D6A6] h-full transition-all duration-300"
          style={{ width: `${progressPercent}%` }}
        />
      </div>

      {/* Question Card */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-6 shadow-md">
        <span className="text-xs font-bold text-[#52D6A6] uppercase tracking-wide block mb-2">
          السؤال رقم {currentIndex + 1}
        </span>
        <h2 className="text-base sm:text-lg font-bold text-white leading-relaxed">
          {currentQ.question}
        </h2>
      </div>

      {/* Options List */}
      <div className="space-y-3">
        {currentQ.options.map((opt, index) => {
          const letter = String.fromCharCode(65 + index); // A, B, C, D
          const isSelected = selectedOption === index;

          return (
            <button
              key={index}
              onClick={() => handleSelectOption(index)}
              disabled={answered}
              className={`w-full p-4 rounded-xl border text-right transition flex items-center justify-between cursor-pointer ${
                isSelected
                  ? 'bg-[#1B2640] border-[#52D6A6] shadow-md ring-1 ring-[#52D6A6]'
                  : 'bg-[#141C2E] border-[#2B3B5C] hover:border-[#52D6A6]/50 text-white'
              } ${answered && !isSelected ? 'opacity-60 cursor-not-allowed' : ''}`}
            >
              <div className="flex items-center gap-3">
                <span
                  className={`w-8 h-8 rounded-lg flex items-center justify-center font-bold text-xs ${
                    isSelected ? 'bg-[#52D6A6] text-[#0B1020]' : 'bg-[#0B1020] text-[#9BB0D6]'
                  }`}
                >
                  {letter}
                </span>
                <span className="text-sm font-medium text-white">{opt}</span>
              </div>
              {isSelected && <CheckCircle2 className="w-5 h-5 text-[#52D6A6]" />}
            </button>
          );
        })}
      </div>

      {/* Next Question / Finish Button */}
      {answered && (
        <button
          onClick={handleNext}
          className="w-full py-3.5 px-4 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-sm rounded-xl transition flex items-center justify-center gap-2 shadow-lg animate-in fade-in"
        >
          <span>{currentIndex < questions.length - 1 ? 'السؤال التالي' : 'عرض النتيجة النهائية'}</span>
          <ArrowRight className="w-4 h-4 rtl:rotate-180" />
        </button>
      )}
    </div>
  );
};
