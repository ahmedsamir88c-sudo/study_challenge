import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import {
  GraduationCap,
  Flame,
  Zap,
  Bell,
  Settings,
  LogOut,
  Users,
  ShieldCheck,
  Check,
} from 'lucide-react';

interface NavbarProps {
  onOpenNotifications: () => void;
  onOpenPreferences: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({ onOpenNotifications, onOpenPreferences }) => {
  const { currentUser, users, switchUser, logout, unreadNotificationsCount } = useApp();
  const [showUserMenu, setShowUserMenu] = useState(false);

  if (!currentUser) return null;

  return (
    <header className="sticky top-0 z-40 bg-[#141C2E]/95 backdrop-blur-md border-b border-[#2B3B5C] px-4 py-3">
      <div className="max-w-6xl mx-auto flex items-center justify-between gap-3">
        {/* Brand / Logo */}
        <div className="flex items-center gap-2.5">
          <div className="w-9 h-9 rounded-xl bg-[#173A2E] border border-[#2B3B5C] flex items-center justify-center text-[#52D6A6] shadow-sm">
            <GraduationCap className="w-5 h-5" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-bold text-white text-base tracking-tight">Study Challenge</span>
              {currentUser.role === 'owner' ? (
                <span className="bg-[#52D6A6]/15 border border-[#52D6A6]/40 text-[#52D6A6] text-[10px] font-bold px-2 py-0.5 rounded-full flex items-center gap-1">
                  <ShieldCheck className="w-3 h-3" /> مالك المنصة
                </span>
              ) : (
                <span className="bg-[#7DB8FF]/15 border border-[#7DB8FF]/40 text-[#7DB8FF] text-[10px] font-bold px-2 py-0.5 rounded-full">
                  الفرقة {currentUser.academic_year}
                </span>
              )}
            </div>
            <p className="text-xs text-[#9BB0D6] hidden sm:block">
              {currentUser.full_name || currentUser.username} (ID: {currentUser.university_id})
            </p>
          </div>
        </div>

        {/* User Stats & Actions */}
        <div className="flex items-center gap-2 sm:gap-3">
          {/* Streak indicator */}
          <div className="flex items-center gap-1.5 bg-[#1B2640] border border-[#2B3B5C] px-2.5 py-1.5 rounded-xl text-xs font-semibold text-[#FFC76A]" title="سلسلة المذاكرة اليومية">
            <Flame className="w-4 h-4 fill-[#FFC76A] text-[#FFC76A] animate-pulse" />
            <span>{currentUser.streak} يوم</span>
          </div>

          {/* XP Badge */}
          <div className="flex items-center gap-1 bg-[#7DB8FF]/10 border border-[#7DB8FF]/30 px-2.5 py-1.5 rounded-xl text-xs font-bold text-[#7DB8FF]" title="نقاط الخبرة XP">
            <Zap className="w-4 h-4 fill-[#7DB8FF] text-[#7DB8FF]" />
            <span>{currentUser.xp} XP</span>
          </div>

          {/* Notification button */}
          <button
            onClick={onOpenNotifications}
            className="relative p-2 rounded-xl bg-[#1B2640] border border-[#2B3B5C] text-[#DEEBFF] hover:text-[#52D6A6] hover:border-[#52D6A6]/40 transition"
            title="الإشعارات"
          >
            <Bell className="w-4 h-4" />
            {unreadNotificationsCount > 0 && (
              <span className="absolute -top-1 -right-1 bg-[#FF7E86] text-white text-[10px] font-bold w-4 h-4 rounded-full flex items-center justify-center">
                {unreadNotificationsCount}
              </span>
            )}
          </button>

          {/* Settings button */}
          <button
            onClick={onOpenPreferences}
            className="p-2 rounded-xl bg-[#1B2640] border border-[#2B3B5C] text-[#DEEBFF] hover:text-[#52D6A6] hover:border-[#52D6A6]/40 transition"
            title="إعدادات الدراسة"
          >
            <Settings className="w-4 h-4" />
          </button>

          {/* Quick Demo Switcher Dropdown */}
          <div className="relative">
            <button
              onClick={() => setShowUserMenu(!showUserMenu)}
              className="flex items-center gap-1.5 bg-[#23314F] hover:bg-[#1B2640] border border-[#2B3B5C] px-2.5 py-1.5 rounded-xl text-xs text-white transition font-medium"
              title="تبديل الحساب التجريبي"
            >
              <Users className="w-3.5 h-3.5 text-[#52D6A6]" />
              <span className="hidden md:inline">تبديل الحساب</span>
            </button>

            {showUserMenu && (
              <div
                className="absolute left-0 mt-2 w-64 bg-[#141C2E] border border-[#2B3B5C] rounded-2xl shadow-2xl py-2 z-50 text-right"
                onClick={() => setShowUserMenu(false)}
              >
                <div className="px-3 py-1.5 border-b border-[#2B3B5C] text-[11px] font-semibold text-[#9BB0D6]">
                  اختر حساباً للتجربة السريعة:
                </div>
                <div className="max-h-60 overflow-y-auto py-1">
                  {users.map((u) => {
                    const isSelected = u.uid === currentUser.uid;
                    return (
                      <button
                        key={u.uid}
                        onClick={() => switchUser(u.uid)}
                        className={`w-full px-3 py-2 text-right flex items-center justify-between hover:bg-[#1B2640] transition ${
                          isSelected ? 'bg-[#173A2E] text-[#52D6A6]' : 'text-[#DEEBFF]'
                        }`}
                      >
                        <div className="flex items-center gap-2">
                          <span
                            className={`w-2 h-2 rounded-full ${
                              u.role === 'owner' ? 'bg-[#52D6A6]' : 'bg-[#7DB8FF]'
                            }`}
                          />
                          <div>
                            <div className="text-xs font-bold leading-snug">
                              {u.username} {u.role === 'owner' && '(مالك)'}
                            </div>
                            <div className="text-[10px] text-[#9BB0D6]">
                              ID: {u.university_id} • {u.xp} XP
                            </div>
                          </div>
                        </div>
                        {isSelected && <Check className="w-4 h-4 text-[#52D6A6]" />}
                      </button>
                    );
                  })}
                </div>
                <div className="border-t border-[#2B3B5C] pt-1">
                  <button
                    onClick={logout}
                    className="w-full px-3 py-2 text-right text-xs text-[#FF7E86] hover:bg-[#3C1F2B] flex items-center gap-2"
                  >
                    <LogOut className="w-3.5 h-3.5" />
                    تسجيل الخروج
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
};
