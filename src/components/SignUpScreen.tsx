import React, { useState } from 'react';
import { useApp } from '../context/AppContext';
import { UserPlus, User, Mail, BadgeCheck, Lock, Eye, EyeOff, AlertCircle, ArrowRight } from 'lucide-react';

interface SignUpScreenProps {
  onGoToLogin: () => void;
}

export const SignUpScreen: React.FC<SignUpScreenProps> = ({ onGoToLogin }) => {
  const { register } = useApp();

  const [username, setUsername] = useState('');
  const [email, setEmail] = useState('');
  const [universityId, setUniversityId] = useState('');
  const [academicYear, setAcademicYear] = useState<number>(2);
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !email.trim() || !universityId.trim() || !password) {
      setErrorMessage('يرجى ملء جميع الحقول المطلوبة');
      return;
    }

    if (password.length < 6) {
      setErrorMessage('كلمة المرور يجب ألا تقل عن 6 أحرف');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    const res = await register({
      username: username.trim(),
      email: email.trim(),
      universityId: universityId.trim(),
      academicYear,
    });

    setIsLoading(false);

    if (!res.success) {
      setErrorMessage(res.error || 'فشل إنشاء الحساب');
    }
  };

  return (
    <div className="min-h-screen bg-[#0B1020] flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-[#141C2E] border border-[#2B3B5C] rounded-3xl p-6 sm:p-8 shadow-2xl animate-in fade-in duration-300 space-y-5">
        {/* Header */}
        <div className="text-center space-y-1.5">
          <div className="w-14 h-14 rounded-2xl bg-[#173A2E] border border-[#52D6A6]/40 flex items-center justify-center text-[#52D6A6] mx-auto shadow-md">
            <UserPlus className="w-7 h-7" />
          </div>
          <h2 className="text-2xl font-bold text-white tracking-tight">إنشاء حساب جديد</h2>
          <p className="text-xs text-[#9BB0D6]">انضم إلى مجتمع Study Challenge الآن</p>
        </div>

        {errorMessage && (
          <div className="p-3 bg-[#3C1F2B] border border-[#FF7E86]/50 rounded-xl flex items-center gap-2.5 text-xs text-[#FF7E86]">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-3.5 text-xs">
          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1">اسم المستخدم (Username) *</label>
            <div className="relative">
              <input
                type="text"
                dir="ltr"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="مثال: ahmed_samir"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-2.5 text-white outline-none text-left transition"
              />
              <User className="w-4 h-4 text-[#9BB0D6] absolute left-3.5 top-3 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1">البريد الإلكتروني *</label>
            <div className="relative">
              <input
                type="email"
                dir="ltr"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="name@example.com"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-2.5 text-white outline-none text-left transition"
              />
              <Mail className="w-4 h-4 text-[#9BB0D6] absolute left-3.5 top-3 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1">ID الجامعة (رقم الطالب) *</label>
            <div className="relative">
              <input
                type="text"
                dir="ltr"
                required
                value={universityId}
                onChange={(e) => setUniversityId(e.target.value)}
                placeholder="مثال: 2024001"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-2.5 text-white outline-none text-left transition"
              />
              <BadgeCheck className="w-4 h-4 text-[#9BB0D6] absolute left-3.5 top-3 pointer-events-none" />
            </div>
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1">السنة الدراسية (الفرقة) *</label>
            <select
              value={academicYear}
              onChange={(e) => setAcademicYear(Number(e.target.value))}
              className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] text-white rounded-xl px-3.5 py-2.5 text-xs outline-none transition"
            >
              <option value={1}>الفرقة الأولى (1)</option>
              <option value={2}>الفرقة الثانية (2) — الموصى به</option>
              <option value={3}>الفرقة الثالثة (3)</option>
              <option value={4}>الفرقة الرابعة (4)</option>
            </select>
          </div>

          <div>
            <label className="block text-[#DEEBFF] font-semibold mb-1">كلمة المرور *</label>
            <div className="relative">
              <input
                type={showPassword ? 'text' : 'password'}
                dir="ltr"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="6 أحرف على الأقل"
                className="w-full bg-[#0B1020] border border-[#2B3B5C] focus:border-[#52D6A6] rounded-xl pl-10 pr-3.5 py-2.5 text-white outline-none text-left transition"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute left-3.5 top-3 text-[#9BB0D6] hover:text-white"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading}
            className="w-full py-3 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-sm rounded-xl transition shadow-lg mt-3 cursor-pointer"
          >
            {isLoading ? 'جاري التسجيل...' : 'إنشاء الحساب والبدء'}
          </button>
        </form>

        <div className="text-center text-xs text-[#9BB0D6] pt-1">
          لديك حساب بالفعل؟{' '}
          <button
            onClick={onGoToLogin}
            className="text-[#FFC76A] font-bold hover:underline cursor-pointer"
          >
            تسجيل الدخول
          </button>
        </div>
      </div>
    </div>
  );
};
