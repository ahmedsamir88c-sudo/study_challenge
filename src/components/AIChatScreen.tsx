import React, { useState, useRef, useEffect } from 'react';
import { useApp } from '../context/AppContext';
import { ChatMessage } from '../types';
import {
  Bot,
  Send,
  BookOpen,
  Sparkles,
  ChevronDown,
  ChevronUp,
  FileText,
  User,
  Loader2,
} from 'lucide-react';

export const AIChatScreen: React.FC = () => {
  const { subjects } = useApp();

  const [selectedSubject, setSelectedSubject] = useState<string>('Computer Architecture');
  const [selectedLecture, setSelectedLecture] = useState<number>(1);
  const [selectedSummaryType, setSelectedSummaryType] = useState<string>('quick');
  const [isSummarizerOpen, setIsSummarizerOpen] = useState<boolean>(false);
  const [isTyping, setIsTyping] = useState<boolean>(false);
  const [inputMessage, setInputMessage] = useState<string>('');

  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: 'welcome',
      text: 'أهلاً بك! أنا المساعد الذكي لمقرراتك الدراسية. يمكنك اختياري لمادة ومحاضرة وسؤالي عن أي مفهوم، أو طلب تلخيص مخصص للامتحانات وسلايدات المحاضرات.',
      is_user: false,
      time: 'الآن',
    },
  ]);

  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  const summaryTypes: Record<string, string> = {
    quick: 'سريع',
    detailed: 'تفصيلي',
    exam: 'للامتحان',
    key_points: 'نقاط مهمة',
    definitions: 'تعريفات',
  };

  const quickPrompts = [
    'اشرح مفهومًا من المحاضرة',
    'لخص أهم أفكار المادة',
    'راجع تعريفًا من المحتوى',
    'ما هي الأسئلة المتوقعة في الامتحان؟',
  ];

  const handleSendMessage = (customText?: string) => {
    const text = (customText || inputMessage).trim();
    if (!text || isTyping) return;

    if (!customText) setInputMessage('');

    const userMsg: ChatMessage = {
      id: 'user-' + Date.now(),
      text,
      is_user: true,
      time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    setIsTyping(true);

    setTimeout(() => {
      const botResponse = generateAIResponse(text, selectedSubject, selectedLecture);
      setMessages((prev) => [...prev, botResponse]);
      setIsTyping(false);
    }, 900);
  };

  const handleGenerateSummary = () => {
    if (isTyping) return;

    const summaryTypeName = summaryTypes[selectedSummaryType] || 'سريع';
    const requestText = `لخص المحاضرة رقم ${selectedLecture} لمقرر ${selectedSubject} بنوع (${summaryTypeName})`;

    const userMsg: ChatMessage = {
      id: 'user-' + Date.now(),
      text: requestText,
      is_user: true,
      time: new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' }),
    };

    setMessages((prev) => [...prev, userMsg]);
    setIsTyping(true);

    setTimeout(() => {
      const summaryReply = generateSummaryResponse(selectedSubject, selectedLecture, selectedSummaryType);
      setMessages((prev) => [...prev, summaryReply]);
      setIsTyping(false);
    }, 1200);
  };

  // Helper intelligent response generator grounded in subject curriculum
  const generateAIResponse = (query: string, subject: string, lecture: number): ChatMessage => {
    let reply = '';
    const nowTime = new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });

    if (subject === 'Computer Architecture') {
      reply = `بخصوص استفسارك حول **معمارية الحاسوب (المحاضرة ${lecture})**:
1. تعتمد البنية على تجريد النظام (Computer Abstractions) ومجموعة تعليمات MIPS 32-bit.
2. المسجلات الأساسية تنقسم إلى مسجلات حفظ مؤقت ($t0-$t9)، ومسجلات حفظ طويلة الأمد ($s0-$s7)، ومسجل الصفر ($zero)، ومسجل العودة ($ra).
3. عند تنفيذ التعليمة تمر بخمس مراحل متسلسلة في خطوط الأنابيب: IF (الجلب), ID (فك التشفير وقراءة المسجلات), EX (التنفيذ الحسابي عبر ALU), MEM (الوصول للذاكرة), WB (كتابة النتيجة في المسجل).
4. لتفادي مخاطر البيانات (Data Hazards) تُستخدم تقنيات التقديم السريع (Forwarding / Bypassing).`;
    } else if (subject === 'Digital Logic Design') {
      reply = `بناءً على محتوى **مقرر المنطق الرقمي (المحاضرة ${lecture})**:
1. الدوائر الرقمية تنقسم إلى دوائر توافقية (Combinational) تعتمد مخرجاتها على المدخلات الحالية فقط، ودوائر تتابعية (Sequential) تحتوي على عناصر ذاكرة كالنطاطات (Flip-Flops) وتعتمد على إشارة الساعة (Clock).
2. لتبسيط المعادلات يُستخدم الجبر البولياني وخرائط كارنو (K-Maps) لتجميع الواحدات في مجموعات 1، 2، 4، 8، أو 16 لتقليل عدد البوابات وتكلفة التصنيع.
3. المكونات التوافقية الشهيرة تشمل المجمعات (Adders)، النواخب (Multiplexers)، ومفكات التشفير (Decoders).`;
    } else if (subject === 'Data Structure and Algorithms') {
      reply = `وفقاً لمحتوى **هياكل البيانات والخوارزميات (المحاضرة ${lecture})**:
1. قياس كفاءة الخوارزميات يعتمد على مقياس Big-O للزمن والمساحة.
2. القوائم المتصلة (Linked Lists) تتيح إضافة وحذف ديناميكي في O(1) عند معرفة المؤشر ولكن الوصول لعنصر يستغرق O(n).
3. في أشجار البحث الثنائية (BST) المتوازنة كالـ AVL Trees يستغرق البحث والإضافة والحذف O(log n)، بينما ينحدر للأسوأ O(n) إذا كانت الشجرة مائلة.
4. خوارزميات الترتيب الفعالة مثل MergeSort و HeapSort تضمن تعقيد O(n log n) في كافة الحالات.`;
    } else {
      reply = `شكراً لسؤالك في مادة **${subject} (المحاضرة ${lecture})**. 
وفقاً للسلايدات والملفات المعتمدة للمقرر، هذه النقطة تعد من الركائز الأساسية التي يتم التركيز عليها في الامتحانات العملية والنظرية. تأكد من مراجعة المفاهيم النظرية وحل المسائل التطبيقية المرفقة في السكشن الخاص بالمحاضرة.`;
    }

    return {
      id: 'bot-' + Date.now(),
      text: reply,
      is_user: false,
      time: nowTime,
      sources: [
        {
          file_name: `Lecture_${lecture}_${subject.replace(/\s+/g, '_')}.pdf`,
          lecture_number: lecture,
          section_title: 'المفاهيم الأساسية',
          page_number: Math.floor(Math.random() * 15) + 2,
        },
      ],
    };
  };

  const generateSummaryResponse = (subject: string, lecture: number, type: string): ChatMessage => {
    const nowTime = new Date().toLocaleTimeString('ar-EG', { hour: '2-digit', minute: '2-digit' });

    let summaryText = `### ملخص ${summaryTypes[type] || ''} للمحاضرة (${lecture}) في مادة ${subject}:\n\n`;

    if (type === 'definitions') {
      summaryText += `📌 **أهم التعريفات والمصطلحات الأساسية:**\n` +
        `• **Datapath (مسار البيانات):** العتاد الذي يقوم بالعمليات الحسابية ومعالجة البيانات كالمسجلات ووحدة ALU.\n` +
        `• **Control Unit (وحدة التحكم):** الدائرة التي ترسل إشارات التوجيه لباقي المكونات لتنفيذ التعليمة.\n` +
        `• **Clock Cycle Time:** الزمن المستغرق لإكمال نبضة ساعة كاملة، ويحكم سرعة المعالج.\n` +
        `• **Pipelining (خطوط الأنابيب):** تقنية تنفيذ متزامنة لعدة تعليمات في مراحل مختلفة لتحسين معدل الإنتاجية (Throughput).`;
    } else if (type === 'exam') {
      summaryText += `🎯 **نقاط الامتحان المتكررة والأسئلة الحرجة:**\n` +
        `1. احفظ بدقة صيغ تعليمات MIPS الثلاث (R-type, I-type, J-type) وتقسيمات البتات لكل منها.\n` +
        `2. مسائل حساب CPI (Cycles Per Instruction) وزمن تنفيذ البرنامج: CPU Time = Instructions × CPI × Clock Cycle Time.\n` +
        `3. ركز على رسم مخطط التوقيت لمراحل الـ Pipeline وتحديد أماكن حدوث الـ Hazards وطرق حلها (Forwarding vs Stall).\n` +
        `4. المقارنة المشهورة بين ذاكرة الكاش المباشرة (Direct-Mapped) والمترابطة (Set-Associative).`;
    } else {
      summaryText += `✨ **أبرز محاور المحاضرة:**\n` +
        `• **المحور الأول:** البنية المعمارية للنظام وطريقة اتصال المعالج بالذاكرة الرئيسية.\n` +
        `• **المحور الثاني:** تمثيل البيانات والعمليات الحسابية المنطقية في العتاد.\n` +
        `• **المحور الثالث:** قواعد التصميم الأربعة (Simplicity favors regularity, Smaller is faster, Make the common case fast, Good design demands good compromises).\n\n` +
        `💡 *نصيحة:* راجع التمارين المحلولة في سكشن المادة واستعد للاختبار التدريبي من تبويب الاختبارات.`;
    }

    return {
      id: 'bot-' + Date.now(),
      text: summaryText,
      is_user: false,
      time: nowTime,
      sources: [
        {
          file_name: `Lecture_${lecture}_${subject.replace(/\s+/g, '_')}_Summary.pdf`,
          lecture_number: lecture,
          section_title: 'ملخص شامل',
          page_number: 1,
        },
      ],
    };
  };

  const subjectNames = Array.from(new Set(subjects.map((s) => s.name)));

  return (
    <div className="max-w-4xl mx-auto p-4 sm:p-6 flex flex-col h-[calc(100vh-140px)] animate-in fade-in duration-300">
      {/* Top Header & Subject Bar */}
      <div className="bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-4 shadow-sm mb-4 space-y-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-[#52D6A6]/15 border border-[#52D6A6]/40 flex items-center justify-center text-[#52D6A6]">
              <Bot className="w-5 h-5" />
            </div>
            <div>
              <h2 className="text-base font-bold text-white flex items-center gap-2">
                المساعد الذكي للدراسة
                <span className="w-2 h-2 rounded-full bg-[#52D6A6] animate-ping" />
              </h2>
              <p className="text-xs text-[#9BB0D6]">مساعد أكاديمي مخصص حسب مقرراتك وسلايدات المواد</p>
            </div>
          </div>

          <button
            onClick={() => setIsSummarizerOpen(!isSummarizerOpen)}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-[#1B2640] border border-[#2B3B5C] text-xs font-bold text-[#DEEBFF] hover:border-[#52D6A6]/40 transition"
          >
            <Sparkles className="w-3.5 h-3.5 text-[#FFC76A]" />
            <span>تلخيص محاضرة</span>
            {isSummarizerOpen ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
        </div>

        {/* Subject dropdown */}
        <div className="flex items-center gap-2 pt-1 border-t border-[#2B3B5C]/60 text-xs">
          <BookOpen className="w-4 h-4 text-[#FFC76A] flex-shrink-0" />
          <span className="text-[#9BB0D6] flex-shrink-0">المادة المختارة:</span>
          <select
            value={selectedSubject}
            onChange={(e) => setSelectedSubject(e.target.value)}
            className="bg-[#0B1020] border border-[#2B3B5C] text-white rounded-lg px-2.5 py-1 text-xs outline-none focus:border-[#52D6A6] flex-1 max-w-xs"
          >
            {subjectNames.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </div>

        {/* Collapsible Summarizer Panel */}
        {isSummarizerOpen && (
          <div className="bg-[#1B2640] border border-[#52D6A6]/30 rounded-xl p-3.5 mt-2 space-y-3 animate-in fade-in">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
              <div>
                <label className="block text-[#9BB0D6] mb-1 font-semibold">رقم المحاضرة:</label>
                <select
                  value={selectedLecture}
                  onChange={(e) => setSelectedLecture(Number(e.target.value))}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-lg px-3 py-1.5 outline-none"
                >
                  {Array.from({ length: 16 }, (_, i) => i + 1).map((n) => (
                    <option key={n} value={n}>
                      المحاضرة رقم {n}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-[#9BB0D6] mb-1 font-semibold">نوع التلخيص:</label>
                <select
                  value={selectedSummaryType}
                  onChange={(e) => setSelectedSummaryType(e.target.value)}
                  className="w-full bg-[#0B1020] border border-[#2B3B5C] text-white rounded-lg px-3 py-1.5 outline-none"
                >
                  {Object.entries(summaryTypes).map(([key, label]) => (
                    <option key={key} value={key}>
                      {label}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            <button
              onClick={handleGenerateSummary}
              disabled={isTyping}
              className="w-full py-2 bg-[#52D6A6] hover:bg-[#23B780] text-[#0B1020] font-bold text-xs rounded-lg transition flex items-center justify-center gap-2"
            >
              <Sparkles className="w-3.5 h-3.5" />
              توليد ملخص المحاضرة الآن
            </button>
          </div>
        )}
      </div>

      {/* Messages Feed */}
      <div className="flex-1 bg-[#141C2E]/60 border border-[#2B3B5C] rounded-2xl p-4 overflow-y-auto space-y-4">
        {messages.map((msg) => {
          const isUser = msg.is_user;
          return (
            <div
              key={msg.id}
              className={`flex gap-3 max-w-[85%] ${isUser ? 'mr-auto flex-row-reverse' : 'ml-auto'}`}
            >
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 text-xs font-bold ${
                  isUser ? 'bg-[#52D6A6] text-[#0B1020]' : 'bg-[#173A2E] text-[#52D6A6] border border-[#52D6A6]/30'
                }`}
              >
                {isUser ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
              </div>

              <div
                className={`p-4 rounded-2xl text-xs sm:text-sm leading-relaxed whitespace-pre-line shadow-md ${
                  isUser
                    ? 'bg-[#52D6A6] text-[#0B1020] font-medium rounded-tr-none'
                    : 'bg-[#1B2640] text-[#F3F7FF] border border-[#2B3B5C] rounded-tl-none'
                }`}
              >
                <div>{msg.text}</div>

                {/* Sources list */}
                {msg.sources && msg.sources.length > 0 && (
                  <div className="mt-3 pt-2.5 border-t border-[#2B3B5C] text-[11px] text-[#FFC76A] space-y-1">
                    <span className="font-bold flex items-center gap-1">
                      <FileText className="w-3 h-3" />
                      المصادر المستند إليها:
                    </span>
                    {msg.sources.map((s, idx) => (
                      <div key={idx} className="text-[#DEEBFF] flex items-center gap-1.5 opacity-90">
                        • {s.file_name} {s.section_title ? `— ${s.section_title}` : ''} {s.page_number ? `(ص ${s.page_number})` : ''}
                      </div>
                    ))}
                  </div>
                )}

                <div className={`text-[10px] mt-1.5 text-right ${isUser ? 'text-[#0B1020]/70' : 'text-[#9BB0D6]'}`}>
                  {msg.time}
                </div>
              </div>
            </div>
          );
        })}

        {isTyping && (
          <div className="flex items-center gap-2 text-xs text-[#9BB0D6] bg-[#1B2640] border border-[#2B3B5C] px-3 py-2 rounded-xl w-fit">
            <Loader2 className="w-4 h-4 animate-spin text-[#52D6A6]" />
            <span>جاري تحليل محتوى المحاضرة وصياغة الإجابة...</span>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Quick Prompts Bar */}
      {messages.length <= 3 && (
        <div className="flex items-center gap-2 overflow-x-auto py-2.5">
          {quickPrompts.map((prompt, idx) => (
            <button
              key={idx}
              onClick={() => handleSendMessage(prompt)}
              className="text-xs bg-[#1B2640] hover:bg-[#23314F] border border-[#2B3B5C] hover:border-[#52D6A6]/40 text-[#DEEBFF] px-3 py-1.5 rounded-full whitespace-nowrap transition cursor-pointer"
            >
              {prompt}
            </button>
          ))}
        </div>
      )}

      {/* Input Bar */}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          handleSendMessage();
        }}
        className="mt-3 flex items-center gap-2 bg-[#141C2E] border border-[#2B3B5C] rounded-2xl p-2 shadow-lg"
      >
        <input
          type="text"
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          placeholder={`اسأل عن محاضرات مادة ${selectedSubject}...`}
          className="flex-1 bg-transparent text-white px-3 py-2 text-xs sm:text-sm outline-none placeholder:text-[#9BB0D6]"
        />
        <button
          type="submit"
          disabled={!inputMessage.trim() || isTyping}
          className={`p-2.5 rounded-xl transition ${
            inputMessage.trim() && !isTyping
              ? 'bg-[#52D6A6] text-[#0B1020] hover:bg-[#23B780] cursor-pointer'
              : 'bg-[#1B2640] text-[#7286B1] cursor-not-allowed'
          }`}
          title="إرسال"
        >
          <Send className="w-4 h-4 rtl:rotate-180" />
        </button>
      </form>
    </div>
  );
};
