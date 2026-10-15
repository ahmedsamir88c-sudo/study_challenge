import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { GraduationCap, Lock, BadgeCheck, Eye, EyeOff, AlertCircle, ArrowLeft, ShieldCheck } from 'lucide-react';

interface LoginScreenProps {
  onGoToSignUp: () => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({ onGoToSignUp }) => {
  const { login } = useApp();

  const [studentId, setStudentId] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!studentId.trim() || !password.trim()) {
      setErrorMessage('يرجى إدخال رقم الطالب وكلمة المرور');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    const res = await login(studentId.trim(), password);
    setIsLoading(false);

    if (!res.success) {
      setErrorMessage(res.error || 'فشل تسجيل الدخول');
    }
  };

  const handleQuickFill = (id: string, pass: string) => {
    setStudentId(id);
    setPassword(pass);
    setErrorMessage(null);
  };

  return (
    <div className="min-h-screen bg-[#0B1020] flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-[#141C2E] border border-[#2B3B5C] rounded-3xl p-6 sm:p-8 shadow-2xl animate-in fade-in duration-300 space-y-6">
        {/* Logo and App Title */}
        <div className="text-center space-y-2">
          <div className="w-16 h-16 rounded-2xl bg-[#173A2E] border border-[#52D6A6]/40 flex items-center justify-center text-[#52D6A6] mx-auto shadow-md">
            <GraduationCap className="w-9 h-9" />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">Study Challenge</h1>
          <p className="text-xs text-[#9BB0D6]">منصة التحديات الأكاديمية والذكاء الاصطناعي</p>
        </div>

        {/* Error notice */}
        {errorMessage && (
          <div className="p-3 bg-[#3C1F2B] border border-[#FF7E86]/50 rounded-xl flex items-center gap-2.5 text-xs text-[#FF7E86]">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1.5">
              رقم الطالب (ID) أو اسم المستخدم
            </label>
            <div className="relative">
              <input
                type="text"
                dir="ltr"
                required
                value={studentId}
                onChange={(e) => setStudentId(e.target.value)}
                placeholder="مثال: 2024001 أو ahmed_samir"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-3 text-white outline-none text-left transition text-sm"
              />
              <BadgeCheck className="w-4 h-4 text-[#9BB0D6] absolute left-3.5 top-3.5 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1.5">كلمة المرور</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                dir="ltr"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="أدخل كلمة المرور"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-3 text-white outline-none text-left transition text-sm"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute left-3.5 top-3.5 text-[#9BB0D6] hover:text-white"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full py-3.5 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-sm rounded-xl transition shadow-lg flex items-center justify-center gap-2 cursor-pointer mt-2"
          >
            {isLoading ? 'جاري التحقق...' : 'تسجيل الدخول'}
          </button>
        </form>

        {/* Quick Demo Accounts Helper */}
        <div className="pt-2 border-t border-[#2B3B5C]/60 space-y-2">
          <span className="text-[11px] text-[#9BB0D6] block text-center font-semibold">
            حسابات تجريبية سريعة للتجربة الفورية:
          </span>
          <div className="grid grid-cols-2 gap-2 text-[11px]">
            <button
              type="button"
              onClick={() => handleQuickFill('2024001', 'password123')}
              className="p-2 bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] rounded-xl text-white font-medium text-center transition"
            >
              <div className="font-bold text-[#52D6A6]">حساب طالب</div>
              <div className="text-[10px] text-[#9BB0D6]">2024001</div>
            </button>
            <button
              type="button"
              onClick={() => handleQuickFill('2024000', 'owner123')}
              className="p-2 bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] rounded-xl text-white font-medium text-center transition"
            >
              <div className="font-bold text-[#FFC76A] flex items-center justify-center gap-1">
                <ShieldCheck className="w-3 h-3" /> مالك المنصة
              </div>
              <div className="text-[10px] text-[#9BB0D6]">2024000</div>
            </button>
          </div>
        </div>

        {/* Link to Sign Up */}
        <div className="text-center text-xs text-[#9BB0D6] pt-1">
          ليس لديك حساب؟{' '}
          <button
            onClick={onGoToSignUp}
            className="text-[#FFC76A] font-bold hover:underline cursor-pointer"
          >
            إنشاء حساب جديد
          </button>
        </div>
      </div>
    </div>
  );
};
