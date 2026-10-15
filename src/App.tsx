import React, { useState } from 'react';
import { useApp } from './context/AppContext';
import { Navbar } from './components/Navbar';
import { QuizSetupScreen } from './components/QuizSetupScreen';
import { QuizScreen } from './components/QuizScreen';
import { AIChatScreen } from './components/AIChatScreen';
import { StudyHubScreen } from './components/StudyHubScreen';
import { LeaderboardScreen } from './components/LeaderboardScreen';
import { ProfileScreen } from './components/ProfileScreen';
import { OwnerDashboardScreen } from './components/OwnerDashboardScreen';
import { OwnerManagementScreen } from './components/OwnerManagementScreen';
import { LoginScreen } from './components/LoginScreen';
import { SignUpScreen } from './components/SignUpScreen';
import { NotificationsModal } from './components/NotificationsModal';
import { PreferencesModal } from './components/PreferencesModal';
import { QuizQuestion } from './types';
import {
  HelpCircle,
  Bot,
  BookOpen,
  Trophy,
  User,
  ShieldCheck,
} from 'lucide-react';

export const AppContent: React.FC = () => {
  const { currentUser, dailyChallenge } = useApp();

  // Navigation tab state: 0 = Quiz, 1 = AI, 2 = Study Hub, 3 = Leaderboard, 4 = Profile
  const [currentTab, setCurrentTab] = useState<number>(0);
  const [isAuthSignUp, setIsAuthSignUp] = useState<boolean>(false);

  // Active Quiz State
  const [activeQuiz, setActiveQuiz] = useState<{
    quiz_id: string;
    questions: QuizQuestion[];
    subject: string;
    lecture: number;
    isDailyChallenge?: boolean;
  } | null>(null);

  // Owner View state
  const [ownerMode, setOwnerMode] = useState<'dashboard' | 'management' | 'student_preview'>('dashboard');

  // Modals state
  const [isNotificationsOpen, setIsNotificationsOpen] = useState<boolean>(false);
  const [isPreferencesOpen, setIsPreferencesOpen] = useState<boolean>(false);

  // If not logged in, show auth screens
  if (!currentUser) {
    if (isAuthSignUp) {
      return <SignUpScreen onGoToLogin={() => setIsAuthSignUp(false)} />;
    }
    return <LoginScreen onGoToSignUp={() => setIsAuthSignUp(true)} />;
  }

  // Handle starting daily challenge from StudyHub or Profile
  const handleStartDailyChallenge = () => {
    if (dailyChallenge.quiz) {
      setActiveQuiz({
        ...dailyChallenge.quiz,
        subject: dailyChallenge.subject,
        lecture: dailyChallenge.lecture,
        isDailyChallenge: true,
      });
      setCurrentTab(0);
    }
  };

  // If logged in as Owner and not previewing student mode
  if (currentUser.role === 'owner' && ownerMode !== 'student_preview') {
    return (
      <div className="min-h-screen bg-[#0B1020] text-[#F3F7FF] flex flex-col">
        <Navbar
          onOpenNotifications={() => setIsNotificationsOpen(true)}
          onOpenPreferences={() => setIsPreferencesOpen(true)}
        />

        <main className="flex-1 pb-16">
          {ownerMode === 'management' ? (
            <OwnerManagementScreen onBack={() => setOwnerMode('dashboard')} />
          ) : (
            <OwnerDashboardScreen
              onOpenManagement={() => setOwnerMode('management')}
              onOpenStudentView={() => setOwnerMode('student_preview')}
            />
          )}
        </main>

        <NotificationsModal
          isOpen={isNotificationsOpen}
          onClose={() => setIsNotificationsOpen(false)}
        />
        <PreferencesModal
          isOpen={isPreferencesOpen}
          onClose={() => setIsPreferencesOpen(false)}
        />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[#0B1020] text-[#F3F7FF] flex flex-col">
      <Navbar
        onOpenNotifications={() => setIsNotificationsOpen(true)}
        onOpenPreferences={() => setIsPreferencesOpen(true)}
      />

      {/* Owner preview alert bar if owner is previewing student interface */}
      {currentUser.role === 'owner' && (
        <div className="bg-[#173A2E] border-b border-[#52D6A6]/30 px-4 py-2 flex items-center justify-between text-xs text-[#52D6A6]">
          <span className="flex items-center gap-2 font-semibold">
            <ShieldCheck className="w-4 h-4" />
            أنت تشاهد واجهة الطالب (وضع المعاينة). يمكنك تجربة الاختبارات ومحادثة المساعد.
          </span>
          <button
            onClick={() => setOwnerMode('dashboard')}
            className="px-3 py-1 bg-[#52D6A6] text-[#0B1020] rounded-lg font-bold hover:bg-[#23B780] transition"
          >
            الرجوع للوحة المالك
          </button>
        </div>
      )}

      {/* Main Tab Content */}
      <main className="flex-1 pb-24">
        {/* If user is taking an active quiz */}
        {activeQuiz ? (
          <QuizScreen
            quizData={activeQuiz}
            onClose={() => setActiveQuiz(null)}
            onNewQuiz={() => setActiveQuiz(null)}
            isDailyChallenge={activeQuiz.isDailyChallenge}
          />
        ) : (
          <>
            {currentTab === 0 && (
              <QuizSetupScreen
                onStartQuiz={(data) => setActiveQuiz(data)}
              />
            )}
            {currentTab === 1 && <AIChatScreen />}
            {currentTab === 2 && (
              <StudyHubScreen onStartDailyChallenge={handleStartDailyChallenge} />
            )}
            {currentTab === 3 && (
              <LeaderboardScreen onStartQuizTab={() => setCurrentTab(0)} />
            )}
            {currentTab === 4 && (
              <ProfileScreen onStartDailyChallenge={handleStartDailyChallenge} />
            )}
          </>
        )}
      </main>

      {/* Bottom Navigation Bar */}
      <nav className="fixed bottom-0 left-0 right-0 bg-[#141C2E]/95 backdrop-blur-md border-t border-[#2B3B5C] z-30 shadow-2xl">
        <div className="max-w-xl mx-auto flex items-center justify-around py-2.5 px-2">
          <button
            onClick={() => {
              setActiveQuiz(null);
              setCurrentTab(0);
            }}
            className={`flex flex-col items-center gap-1 transition px-3 py-1 rounded-xl ${
              currentTab === 0 && !activeQuiz
                ? 'text-[#52D6A6]'
                : 'text-[#9BB0D6] hover:text-[#DEEBFF]'
            }`}
          >
            <div
              className={`p-1 rounded-xl transition ${
                currentTab === 0 && !activeQuiz ? 'bg-[#173A2E]' : ''
              }`}
            >
              <HelpCircle className="w-5 h-5" />
            </div>
            <span className="text-[11px] font-bold">اختبار</span>
          </button>

          <button
            onClick={() => {
              setActiveQuiz(null);
              setCurrentTab(1);
            }}
            className={`flex flex-col items-center gap-1 transition px-3 py-1 rounded-xl ${
              currentTab === 1 ? 'text-[#52D6A6]' : 'text-[#9BB0D6] hover:text-[#DEEBFF]'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${currentTab === 1 ? 'bg-[#173A2E]' : ''}`}>
              <Bot className="w-5 h-5" />
            </div>
            <span className="text-[11px] font-bold">المساعد</span>
          </button>

          <button
            onClick={() => {
              setActiveQuiz(null);
              setCurrentTab(2);
            }}
            className={`flex flex-col items-center gap-1 transition px-3 py-1 rounded-xl ${
              currentTab === 2 ? 'text-[#52D6A6]' : 'text-[#9BB0D6] hover:text-[#DEEBFF]'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${currentTab === 2 ? 'bg-[#173A2E]' : ''}`}>
              <BookOpen className="w-5 h-5" />
            </div>
            <span className="text-[11px] font-bold">دراستي</span>
          </button>

          <button
            onClick={() => {
              setActiveQuiz(null);
              setCurrentTab(3);
            }}
            className={`flex flex-col items-center gap-1 transition px-3 py-1 rounded-xl ${
              currentTab === 3 ? 'text-[#52D6A6]' : 'text-[#9BB0D6] hover:text-[#DEEBFF]'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${currentTab === 3 ? 'bg-[#173A2E]' : ''}`}>
              <Trophy className="w-5 h-5" />
            </div>
            <span className="text-[11px] font-bold">المتصدرون</span>
          </button>

          <button
            onClick={() => {
              setActiveQuiz(null);
              setCurrentTab(4);
            }}
            className={`flex flex-col items-center gap-1 transition px-3 py-1 rounded-xl ${
              currentTab === 4 ? 'text-[#52D6A6]' : 'text-[#9BB0D6] hover:text-[#DEEBFF]'
            }`}
          >
            <div className={`p-1 rounded-xl transition ${currentTab === 4 ? 'bg-[#173A2E]' : ''}`}>
              <User className="w-5 h-5" />
            </div>
            <span className="text-[11px] font-bold">ملفي</span>
          </button>
        </div>
      </nav>

      <NotificationsModal
        isOpen={isNotificationsOpen}
        onClose={() => setIsNotificationsOpen(false)}
      />
      <PreferencesModal
        isOpen={isPreferencesOpen}
        onClose={() => setIsPreferencesOpen(false)}
      />
    </div>
  );
};
