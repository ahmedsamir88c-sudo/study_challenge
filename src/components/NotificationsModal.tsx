import React from 'react';
import { useApp } from '../context/AppContext';
import { X, CheckCheck, Bell, BellRing } from 'lucide-react';

interface NotificationsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const NotificationsModal: React.FC<NotificationsModalProps> = ({ isOpen, onClose }) => {
  const { notifications, unreadNotificationsCount, markNotificationRead, markAllNotificationsRead } = useApp();

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/70 backdrop-blur-sm">
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl w-full max-w-md max-h-[80vh] flex flex-col shadow-2xl overflow-hidden animate-in fade-in duration-200">
        {/* Header */}
        <div className="p-4 border-b border-[#2B3B5C] flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-[#FFC76A]/10 border border-[#FFC76A]/30 flex items-center justify-center text-[#FFC76A]">
              <Bell className="w-4 h-4" />
            </div>
            <div>
              <h3 className="font-bold text-white text-base">الإشعارات والتنبيهات</h3>
              <p className="text-xs text-[#9BB0D6]">غير المقروءة: {unreadNotificationsCount}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-[#9BB0D6] hover:text-white hover:bg-[#1B2640] transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Action bar */}
        {unreadNotificationsCount > 0 && (
          <div className="px-4 py-2 bg-[#1B2640]/50 border-b border-[#2B3B5C] flex justify-end">
            <button
              onClick={markAllNotificationsRead}
              className="text-xs font-semibold text-[#52D6A6] hover:underline flex items-center gap-1.5"
            >
              <CheckCheck className="w-3.5 h-3.5" />
              تحديد الكل كمقروء
            </button>
          </div>
        )}

        {/* Content list */}
        <div className="overflow-y-auto p-3 space-y-2 flex-1">
          {notifications.length === 0 ? (
            <div className="text-center py-12 text-[#9BB0D6] text-sm">
              لا توجد إشعارات حالياً
            </div>
          ) : (
            notifications.map((n) => (
              <div
                key={n.id}
                onClick={() => !n.is_read && markNotificationRead(n.id)}
                className={`p-3.5 rounded-xl border transition cursor-pointer flex gap-3 ${
                  n.is_read
                    ? 'bg-[#141C2E] border-[#2B3B5C]/60 opacity-75'
                    : 'bg-[#1B2640] border-[#52D6A6]/40 hover:border-[#52D6A6]'
                }`}
              >
                <div
                  className={`mt-0.5 w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 ${
                    n.is_read ? 'bg-[#23314F] text-[#9BB0D6]' : 'bg-[#FFC76A]/20 text-[#FFC76A]'
                  }`}
                >
                  <BellRing className="w-4 h-4" />
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between gap-2">
                    <h4 className="text-sm font-bold text-white">{n.title}</h4>
                    <span className="text-[11px] text-[#9BB0D6]">{n.created_at}</span>
                  </div>
                  <p className="text-xs text-[#DEEBFF] mt-1 leading-relaxed">{n.body}</p>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-[#2B3B5C] bg-[#141C2E] flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 bg-[#1B2640] hover:bg-[#23314F] text-white text-xs font-semibold rounded-xl transition"
          >
            إغلاق
          </button>
        </div>
      </div>
    </div>
  );
};
