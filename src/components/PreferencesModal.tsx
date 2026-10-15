import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { X, Settings, Clock, Save, Check } from 'lucide-react';

interface PreferencesModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const PreferencesModal: React.FC<PreferencesModalProps> = ({ isOpen, onClose }) => {
  const { preferences, updatePreferences } = useApp();

  const [notificationsEnabled, setNotificationsEnabled] = useState(preferences.notifications_enabled);
  const [dailyReminders, setDailyReminders] = useState(preferences.daily_challenge_reminders);
  const [weeklyReports, setWeeklyReports] = useState(preferences.weekly_progress_reports);
  const [goalMinutes, setGoalMinutes] = useState(preferences.study_goal_minutes);
  const [savedMessage, setSavedMessage] = useState(false);

  if (!isOpen) return null;

  const handleSave = () => {
    updatePreferences({
      notifications_enabled: notificationsEnabled,
      daily_challenge_reminders: dailyReminders,
      weekly_progress_reports: weeklyReports,
      study_goal_minutes: Math.max(5, Math.min(600, Number(goalMinutes) || 60)),
    });
    setSavedMessage(true);
    setTimeout(() => {
      setSavedMessage(false);
      onClose();
    }, 800);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl w-full max-w-md shadow-2xl overflow-hidden animate-in fade-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-[#2B3B5C] flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#52D6A6]/10 border border-[#52D6A6]/30 flex items-center justify-center text-[#52D6A6]">
              <Settings className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-white text-base">إعدادات الدراسة والتنبيهات</h3>
              <p className="text-xs text-[#9BB0D6]">خصص أهدافك اليومية وطريقة التنبيه</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-[#9BB0D6] hover:text-white hover:bg-[#1B2640] transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Form Body */}
        <div className="p-5 space-y-4">
          {/* Daily Goal Input */}
          <div className="bg-[#1B2640] border border-[#2B3B5C] p-3.5 rounded-xl">
            <label className="block text-xs font-semibold text-[#DEEBFF] mb-1.5 flex items-center gap-2">
              <Clock className="w-4 h-4 text-[#52D6A6]" />
              هدف المذاكرة اليومي (بالدقائق)
            </label>
            <input
              type="number"
              min={5}
              max={600}
              value={goalMinutes}
              onChange={(e) => setGoalMinutes(Number(e.target.value))}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] rounded-lg px-3 py-2 text-sm text-white focus:outline-none focus:border-[#52D6A6]"
            />
            <p className="text-[11px] text-[#9BB0D6] mt-1">الموصى به: 45 - 90 دقيقة يومياً</p>
          </div>

          {/* Toggle Switches */}
          <div className="space-y-3">
            <label className="flex items-center justify-between p-3 rounded-xl bg-[#1B2640] border border-[#2B3B5C] cursor-pointer hover:border-[#52D6A6]/40 transition">
              <span className="text-xs font-semibold text-[#DEEBFF]">تفعيل الإشعارات العامة</span>
              <input
                type="checkbox"
                checked={notificationsEnabled}
                onChange={(e) => setNotificationsEnabled(e.target.checked)}
                className="w-4 h-4 accent-[#52D6A6] rounded"
              />
            </label>

            <label className="flex items-center justify-between p-3 rounded-xl bg-[#1B2640] border border-[#2B3B5C] cursor-pointer hover:border-[#52D6A6]/40 transition">
              <span className="text-xs font-semibold text-[#DEEBFF]">تذكير التحدي اليومي</span>
              <input
                type="checkbox"
                checked={dailyReminders}
                onChange={(e) => setDailyReminders(e.target.checked)}
                className="w-4 h-4 accent-[#52D6A6] rounded"
              />
            </label>

            <label className="flex items-center justify-between p-3 rounded-xl bg-[#1B2640] border border-[#2B3B5C] cursor-pointer hover:border-[#52D6A6]/40 transition">
              <span className="text-xs font-semibold text-[#DEEBFF]">تقارير التقدم الأسبوعية</span>
              <input
                type="checkbox"
                checked={weeklyReports}
                onChange={(e) => setWeeklyReports(e.target.checked)}
                className="w-4 h-4 accent-[#52D6A6] rounded"
              />
            </label>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-[#2B3B5C] bg-[#141C2E] flex items-center justify-between">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-[#1B2640] hover:bg-[#23314F] text-white text-xs font-semibold rounded-xl transition"
          >
            إلغاء
          </button>
          <button
            onClick={handleSave}
            className="px-5 py-2 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] text-xs font-bold rounded-xl transition flex items-center gap-2"
          >
            {savedMessage ? (
              <>
                <Check className="w-4 h-4" />
                تم الحفظ
              </>
            ) : (
              <>
                <Save className="w-4 h-4" />
                حفظ التفضيلات
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
};
