import React from 'react';
import { useApp } from '../context/AppContext';
import { Trophy, Medal, Award, Zap, Play } from 'lucide-react';

interface LeaderboardScreenProps {
  onStartQuizTab: () => void;
}

export const LeaderboardScreen: React.FC<LeaderboardScreenProps> = ({ onStartQuizTab }) => {
  const { users, currentUser } = useApp();

  // Filter students for Year 2 (or all students ranked by XP)
  const rankedStudents = [...users]
    .filter((u) => u.role === 'student' && u.is_active)
    .sort((a, b) => b.xp - a.xp);

  const first = rankedStudents[0];
  const second = rankedStudents[1];
  const third = rankedStudents[2];

  return (
    <div className="max-w-3xl mx-auto p-4 sm:p-6 space-y-6 animate-in fade-in duration-300">
      {/* Header */}
      <div className="flex items-center justify-between pb-3 border-b border-[#2B3B5C]">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-[#7DB8FF]/15 border border-[#7DB8FF]/40 text-[#7DB8FF] flex items-center justify-center">
            <Trophy className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-lg font-bold text-white tracking-tight">لوحة المتصدرين</h2>
            <span className="text-xs text-[#FFC76A] font-semibold">الفرقة الثانية (حاسبات ونظم)</span>
          </div>
        </div>
        <span className="text-xs bg-[#1B2640] border border-[#2B3B5C] text-[#9BB0D6] px-3 py-1 rounded-full font-semibold">
          {rankedStudents.length} متسابق
        </span>
      </div>

      {/* Podium Card */}
      <div className="bg-[#1B2640] border border-[#52D6A6]/30 rounded-2xl p-6 shadow-xl text-center">
        <div className="flex items-center justify-center gap-2 text-xs font-bold text-[#DEEBFF] mb-6">
          <Medal className="w-4 h-4 text-[#FFC76A]" />
          <span>منصة الصدارة — أفضل طلاب الفرقة</span>
        </div>

        {/* The 3 Podium Blocks */}
        <div className="flex items-end justify-center gap-3 sm:gap-6 pt-4">
          {/* Rank 2 (Silver) */}
          <div className="flex-1 max-w-[130px] flex flex-col items-center">
            <div className="relative mb-2">
              <div className="w-14 h-14 rounded-full bg-[#7DB8FF]/20 border-2 border-[#7DB8FF] flex items-center justify-center text-white font-bold text-lg shadow-md">
                {second ? (second.full_name || second.username)[0].toUpperCase() : '-'}
              </div>
              <div className="absolute -bottom-1.5 -right-1 bg-[#7DB8FF] text-[#0B1020] text-[10px] font-black px-1.5 py-0.5 rounded-full">
                #2
              </div>
            </div>
            <div className="text-xs font-bold text-white truncate max-w-[110px]">
              {second ? second.full_name || second.username : 'شاغر'}
            </div>
            <div className="text-[11px] font-bold text-[#7DB8FF] mt-0.5">
              {second ? `${second.xp} XP` : '0 XP'}
            </div>
            <div className="w-full h-24 bg-[#7DB8FF]/15 border-t-2 border-[#7DB8FF] rounded-t-xl mt-3 flex flex-col items-center justify-center shadow-inner">
              <span className="text-lg font-black text-white">#2</span>
              <span className="text-[10px] text-[#7DB8FF] font-semibold">وصيف</span>
            </div>
          </div>

          {/* Rank 1 (Gold Winner) */}
          <div className="flex-1 max-w-[150px] flex flex-col items-center">
            <Trophy className="w-6 h-6 text-[#FFC76A] mb-1 animate-bounce" />
            <div className="relative mb-2">
              <div className="w-16 h-16 rounded-full bg-[#FFC76A]/20 border-2 border-[#FFC76A] flex items-center justify-center text-white font-bold text-xl shadow-lg ring-4 ring-[#FFC76A]/10">
                {first ? (first.full_name || first.username)[0].toUpperCase() : '-'}
              </div>
              <div className="absolute -bottom-1.5 -right-1 bg-[#FFC76A] text-[#0B1020] text-[10px] font-black px-1.5 py-0.5 rounded-full">
                #1
              </div>
            </div>
            <div className="text-sm font-extrabold text-white truncate max-w-[130px]">
              {first ? first.full_name || first.username : 'شاغر'}
            </div>
            <div className="text-xs font-bold text-[#FFC76A] mt-0.5">
              {first ? `${first.xp} XP` : '0 XP'}
            </div>
            <div className="w-full h-32 bg-[#FFC76A]/20 border-t-2 border-[#FFC76A] rounded-t-xl mt-3 flex flex-col items-center justify-center shadow-inner">
              <span className="text-2xl font-black text-white">#1</span>
              <span className="text-[10px] text-[#FFC76A] font-bold">المتصدر الأول</span>
            </div>
          </div>

          {/* Rank 3 (Bronze) */}
          <div className="flex-1 max-w-[130px] flex flex-col items-center">
            <div className="relative mb-2">
              <div className="w-14 h-14 rounded-full bg-[#FF8A7A]/20 border-2 border-[#FF8A7A] flex items-center justify-center text-white font-bold text-lg shadow-md">
                {third ? (third.full_name || third.username)[0].toUpperCase() : '-'}
              </div>
              <div className="absolute -bottom-1.5 -right-1 bg-[#FF8A7A] text-[#0B1020] text-[10px] font-black px-1.5 py-0.5 rounded-full">
                #3
              </div>
            </div>
            <div className="text-xs font-bold text-white truncate max-w-[110px]">
              {third ? third.full_name || third.username : 'شاغر'}
            </div>
            <div className="text-[11px] font-bold text-[#FF8A7A] mt-0.5">
              {third ? `${third.xp} XP` : '0 XP'}
            </div>
            <div className="w-full h-20 bg-[#FF8A7A]/15 border-t-2 border-[#FF8A7A] rounded-t-xl mt-3 flex flex-col items-center justify-center shadow-inner">
              <span className="text-lg font-black text-white">#3</span>
              <span className="text-[10px] text-[#FF8A7A] font-semibold">المركز الثالث</span>
            </div>
          </div>
        </div>
      </div>

      {/* Rankings List */}
      <div className="space-y-3">
        <h3 className="text-sm font-bold text-white flex items-center gap-2">
          <Award className="w-4 h-4 text-[#52D6A6]" />
          ترتيب جميع طلاب الفرقة الثانية
        </h3>

        {rankedStudents.length === 0 ? (
          <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-8 text-center space-y-3">
            <Trophy className="w-10 h-10 text-[#9BB0D6] mx-auto" />
            <h4 className="font-bold text-white text-base">لا يوجد متصدرون الآن</h4>
            <p className="text-xs text-[#9BB0D6] max-w-sm mx-auto">
              المراكز الثلاثة الأولى متاحة! ابدأ الاختبار وحل الأسئلة لتكون الأول على دفعتك.
            </p>
            <button
              onClick={onStartQuizTab}
              className="py-2.5 px-5 bg-[#52D6A6] text-[#0B1020] font-bold text-xs rounded-xl shadow-md inline-flex items-center gap-2"
            >
              <Play className="w-4 h-4 fill-current" />
              ابدأ واكسب نقاط
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            {rankedStudents.map((std, index) => {
              const rank = index + 1;
              const isCurrentUser = currentUser?.uid === std.uid;

              return (
                <div
                  key={std.uid}
                  className={`p-3.5 rounded-xl border flex items-center justify-between transition ${
                    isCurrentUser
                      ? 'bg-[#1B2640] border-[#52D6A6] ring-1 ring-[#52D6A6]'
                      : 'bg-[#141C2E] border-[#2B3B5C] hover:border-[#52D6A6]/40'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    {/* Rank Circle */}
                    <div
                      className={`w-7 h-7 rounded-full flex items-center justify-center text-xs font-black ${
                        rank === 1
                          ? 'bg-[#FFC76A] text-[#0B1020]'
                          : rank === 2
                          ? 'bg-[#7DB8FF] text-[#0B1020]'
                          : rank === 3
                          ? 'bg-[#FF8A7A] text-[#0B1020]'
                          : 'bg-[#23314F] text-[#9BB0D6]'
                      }`}
                    >
                      {rank}
                    </div>

                    {/* Avatar */}
                    <div className="w-9 h-9 rounded-full bg-[#173A2E] text-[#52D6A6] border border-[#52D6A6]/30 flex items-center justify-center font-bold text-xs">
                      {(std.full_name || std.username)[0].toUpperCase()}
                    </div>

                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-bold text-white text-xs sm:text-sm">
                          {std.full_name || std.username}
                        </span>
                        {isCurrentUser && (
                          <span className="bg-[#52D6A6] text-[#0B1020] text-[9px] font-black px-1.5 py-0.2 rounded">
                            أنت
                          </span>
                        )}
                      </div>
                      <span className="text-[11px] text-[#9BB0D6]">ID: {std.university_id}</span>
                    </div>
                  </div>

                  {/* Points */}
                  <div className="flex items-center gap-1.5 bg-[#7DB8FF]/10 border border-[#7DB8FF]/30 px-3 py-1.5 rounded-xl text-xs font-bold text-[#7DB8FF]">
                    <Zap className="w-3.5 h-3.5 fill-[#7DB8FF]" />
                    <span>{std.xp} XP</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};
