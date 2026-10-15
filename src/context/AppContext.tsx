import React, { createContext, useContext, useState, useEffect } from 'react';
import {
  User,
  AcademicYear,
  AcademicSubject,
  AcademicLecture,
  AcademicMaterial,
  QuizQuestion,
  QuizAttemptResult,
  QuizAttemptAnswer,
  DailyChallenge,
  ReviewItem,
  StudyPlan,
  StudyNotification,
  StudentPreferences,
} from '../types';
import {
  INITIAL_YEARS,
  INITIAL_SUBJECTS,
  generateInitialLectures,
  INITIAL_MATERIALS,
  INITIAL_USERS,
  INITIAL_NOTIFICATIONS,
  INITIAL_STUDY_PLANS,
  INITIAL_REVIEW_ITEMS,
  INITIAL_PREFERENCES,
  INITIAL_DAILY_CHALLENGE,
  QUESTION_BANK,
} from '../data/seedData';

interface AppContextType {
  currentUser: User | null;
  users: User[];
  years: AcademicYear[];
  subjects: AcademicSubject[];
  lectures: AcademicLecture[];
  materials: AcademicMaterial[];
  dailyChallenge: DailyChallenge;
  reviewItems: ReviewItem[];
  studyPlans: StudyPlan[];
  notifications: StudyNotification[];
  preferences: StudentPreferences;
  attemptHistory: QuizAttemptResult[];
  unreadNotificationsCount: number;

  // Auth
  login: (identifier: string, pass: string) => Promise<{ success: boolean; error?: string }>;
  register: (data: {
    username: string;
    email: string;
    universityId: string;
    academicYear: number;
    password?: string;
  }) => Promise<{ success: boolean; error?: string }>;
  logout: () => void;
  switchUser: (uid: string) => void;
  updateProfile: (data: Partial<User>) => void;
  updateProfileImage: (image: string) => void;

  // Quizzes & Challenges
  createQuiz: (
    subject: string,
    lecture: number,
    count: number,
    difficulty: 'easy' | 'medium' | 'hard',
    isDailyChallenge?: boolean
  ) => { quiz_id: string; questions: QuizQuestion[] } | null;
  submitQuiz: (
    quizId: string,
    subject: string,
    lecture: number,
    answers: { question_id: string; selected_index: number | null }[],
    isDailyChallenge?: boolean
  ) => QuizAttemptResult;

  // Review Items
  markReviewed: (id: number) => void;

  // Plans
  savePlan: (plan: Partial<StudyPlan>) => void;
  deletePlan: (id: number) => void;
  togglePlanActive: (id: number) => void;

  // Notifications
  markNotificationRead: (id: number) => void;
  markAllNotificationsRead: () => void;

  // Preferences
  updatePreferences: (prefs: Partial<StudentPreferences>) => void;

  // Academic Management
  createYear: (yearNumber: number, name: string, order: number) => void;
  updateYear: (id: number, data: Partial<AcademicYear>) => void;
  deleteYear: (id: number) => void;
  createSubject: (academicYearId: number, name: string, code?: string, description?: string) => void;
  updateSubject: (id: number, data: Partial<AcademicSubject>) => void;
  deleteSubject: (id: number) => void;
  createLecture: (subjectId: number, lectureNumber: number, title: string, description?: string) => void;
  updateLecture: (id: number, data: Partial<AcademicLecture>) => void;
  deleteLecture: (id: number) => void;
  uploadMaterial: (data: {
    academicYearId: number;
    subjectId: number;
    lectureId: number;
    title: string;
    materialType: 'lecture' | 'section';
    sectionTitle?: string;
    filename: string;
    sizeBytes?: number;
  }) => void;
  replaceMaterial: (id: number, filename: string) => void;
  retryMaterial: (id: number) => void;
  deleteMaterial: (id: number) => void;
  toggleStudentStatus: (uid: string) => void;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

const STORAGE_KEYS = {
  CURRENT_USER_ID: 'study_challenge_user_id',
  USERS: 'study_challenge_users',
  YEARS: 'study_challenge_years',
  SUBJECTS: 'study_challenge_subjects',
  LECTURES: 'study_challenge_lectures',
  MATERIALS: 'study_challenge_materials',
  DAILY_CHALLENGE: 'study_challenge_daily',
  REVIEW_ITEMS: 'study_challenge_reviews',
  PLANS: 'study_challenge_plans',
  NOTIFICATIONS: 'study_challenge_notifications',
  PREFERENCES: 'study_challenge_prefs',
  ATTEMPTS: 'study_challenge_attempts',
};

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Load initial state from localStorage or seed
  const [users, setUsers] = useState<User[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.USERS);
    return saved ? JSON.parse(saved) : INITIAL_USERS;
  });

  const [currentUserId, setCurrentUserId] = useState<string | null>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.CURRENT_USER_ID);
    return saved || 'std-101'; // Default logged in as student Ahmed Samir
  });

  const [years, setYears] = useState<AcademicYear[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.YEARS);
    return saved ? JSON.parse(saved) : INITIAL_YEARS;
  });

  const [subjects, setSubjects] = useState<AcademicSubject[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.SUBJECTS);
    return saved ? JSON.parse(saved) : INITIAL_SUBJECTS;
  });

  const [lectures, setLectures] = useState<AcademicLecture[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.LECTURES);
    return saved ? JSON.parse(saved) : generateInitialLectures(INITIAL_SUBJECTS);
  });

  const [materials, setMaterials] = useState<AcademicMaterial[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.MATERIALS);
    return saved ? JSON.parse(saved) : INITIAL_MATERIALS;
  });

  const [dailyChallenge, setDailyChallenge] = useState<DailyChallenge>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.DAILY_CHALLENGE);
    return saved ? JSON.parse(saved) : INITIAL_DAILY_CHALLENGE;
  });

  const [reviewItems, setReviewItems] = useState<ReviewItem[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.REVIEW_ITEMS);
    return saved ? JSON.parse(saved) : INITIAL_REVIEW_ITEMS;
  });

  const [studyPlans, setStudyPlans] = useState<StudyPlan[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.PLANS);
    return saved ? JSON.parse(saved) : INITIAL_STUDY_PLANS;
  });

  const [notifications, setNotifications] = useState<StudyNotification[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.NOTIFICATIONS);
    return saved ? JSON.parse(saved) : INITIAL_NOTIFICATIONS;
  });

  const [preferences, setPreferences] = useState<StudentPreferences>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.PREFERENCES);
    return saved ? JSON.parse(saved) : INITIAL_PREFERENCES;
  });

  const [attemptHistory, setAttemptHistory] = useState<QuizAttemptResult[]>(() => {
    const saved = localStorage.getItem(STORAGE_KEYS.ATTEMPTS);
    return saved ? JSON.parse(saved) : [];
  });

  // Sync to localStorage
  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.USERS, JSON.stringify(users));
  }, [users]);

  useEffect(() => {
    if (currentUserId) {
      localStorage.setItem(STORAGE_KEYS.CURRENT_USER_ID, currentUserId);
    } else {
      localStorage.removeItem(STORAGE_KEYS.CURRENT_USER_ID);
    }
  }, [currentUserId]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.YEARS, JSON.stringify(years));
  }, [years]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.SUBJECTS, JSON.stringify(subjects));
  }, [subjects]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.LECTURES, JSON.stringify(lectures));
  }, [lectures]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.MATERIALS, JSON.stringify(materials));
  }, [materials]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.DAILY_CHALLENGE, JSON.stringify(dailyChallenge));
  }, [dailyChallenge]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.REVIEW_ITEMS, JSON.stringify(reviewItems));
  }, [reviewItems]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.PLANS, JSON.stringify(studyPlans));
  }, [studyPlans]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.NOTIFICATIONS, JSON.stringify(notifications));
  }, [notifications]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.PREFERENCES, JSON.stringify(preferences));
  }, [preferences]);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEYS.ATTEMPTS, JSON.stringify(attemptHistory));
  }, [attemptHistory]);

  const currentUser = users.find((u) => u.uid === currentUserId) || null;
  const unreadNotificationsCount = notifications.filter((n) => !n.is_read).length;

  // Auth Methods
  const login = async (identifier: string, _pass: string) => {
    const cleanId = identifier.trim().toLowerCase();
    const found = users.find(
      (u) =>
        u.university_id.toLowerCase() === cleanId ||
        u.username.toLowerCase() === cleanId ||
        u.email.toLowerCase() === cleanId
    );

    if (!found) {
      return { success: false, error: 'رقم الطالب أو اسم المستخدم غير موجود' };
    }

    if (!found.is_active) {
      return { success: false, error: 'هذا الحساب محظور حالياً. يرجى مراجعة إدارة المنصة.' };
    }

    setCurrentUserId(found.uid);
    return { success: true };
  };

  const register = async (data: {
    username: string;
    email: string;
    universityId: string;
    academicYear: number;
  }) => {
    const cleanUser = data.username.trim().toLowerCase();
    const cleanId = data.universityId.trim();

    if (users.some((u) => u.username.toLowerCase() === cleanUser)) {
      return { success: false, error: 'اسم المستخدم مسجل مسبقاً، اختر اسماً آخر' };
    }

    if (users.some((u) => u.university_id === cleanId)) {
      return { success: false, error: 'رقم الطالب (ID) مسجل مسبقاً' };
    }

    const newUser: User = {
      uid: 'std-' + Date.now().toString(36),
      username: data.username.trim(),
      email: data.email.trim(),
      university_id: cleanId,
      full_name: data.username.trim(),
      role: 'student',
      academic_year: data.academicYear,
      xp: 0,
      streak: 1,
      is_active: true,
      created_at: new Date().toISOString(),
    };

    setUsers((prev) => [newUser, ...prev]);
    setCurrentUserId(newUser.uid);
    return { success: true };
  };

  const logout = () => {
    setCurrentUserId(null);
  };

  const switchUser = (uid: string) => {
    setCurrentUserId(uid);
  };

  const updateProfile = (data: Partial<User>) => {
    if (!currentUserId) return;
    setUsers((prev) =>
      prev.map((u) => (u.uid === currentUserId ? { ...u, ...data } : u))
    );
  };

  const updateProfileImage = (image: string) => {
    if (!currentUserId) return;
    setUsers((prev) =>
      prev.map((u) => (u.uid === currentUserId ? { ...u, profile_image: image } : u))
    );
  };

  // Quizzes & Challenges
  const createQuiz = (
    subject: string,
    lecture: number,
    count: number,
    _difficulty: 'easy' | 'medium' | 'hard',
    isDailyChallenge = false
  ) => {
    const available = QUESTION_BANK[subject] || QUESTION_BANK['Computer Architecture'] || [];
    if (available.length === 0) return null;

    // Pick or cycle questions
    const picked: QuizQuestion[] = [];
    for (let i = 0; i < count; i++) {
      const baseQ = available[i % available.length];
      picked.push({
        ...baseQ,
        id: `${subject}-${lecture}-${i}-${Date.now()}`,
        lecture: lecture,
        subject: subject,
      });
    }

    return {
      quiz_id: 'quiz-' + Date.now(),
      questions: picked,
    };
  };

  const submitQuiz = (
    quizId: string,
    subject: string,
    lecture: number,
    answers: { question_id: string; selected_index: number | null }[],
    isDailyChallenge = false
  ): QuizAttemptResult => {
    const available = QUESTION_BANK[subject] || QUESTION_BANK['Computer Architecture'] || [];
    let score = 0;
    const answeredDetails: QuizAttemptAnswer[] = [];

    answers.forEach((ans, index) => {
      const q = available[index % available.length];
      const isCorrect = ans.selected_index === q.correct_index;
      if (isCorrect) score++;

      answeredDetails.push({
        question_id: ans.question_id,
        question: q.question,
        options: q.options,
        selected_index: ans.selected_index,
        correct_index: q.correct_index,
        is_correct: isCorrect,
        explanation: q.explanation,
      });

      // If incorrect, add to spaced review items if not already there
      if (!isCorrect && !reviewItems.some((r) => r.question === q.question)) {
        setReviewItems((prev) => [
          {
            id: Date.now() + index,
            subject,
            lecture,
            question: q.question,
            options: q.options,
            correct_index: q.correct_index,
            explanation: q.explanation,
            reviewed_at: null,
            review_count: 0,
          },
          ...prev,
        ]);
      }
    });

    const bonus = isDailyChallenge && score === answers.length ? 25 : 0;
    const earnedXp = score * 1 + bonus;

    const result: QuizAttemptResult = {
      id: 'attempt-' + Date.now(),
      quiz_id: quizId,
      score,
      total_questions: answers.length,
      earned_xp: earnedXp,
      created_at: new Date().toISOString(),
      subject,
      lecture,
      answers: answeredDetails,
    };

    setAttemptHistory((prev) => [result, ...prev]);

    // Update current user XP & streak
    if (currentUserId) {
      setUsers((prev) =>
        prev.map((u) => {
          if (u.uid === currentUserId) {
            return {
              ...u,
              xp: u.xp + earnedXp,
              streak: Math.max(u.streak, 1),
            };
          }
          return u;
        })
      );
    }

    if (isDailyChallenge) {
      setDailyChallenge((prev) => ({
        ...prev,
        completed: true,
        started: true,
        score,
        total_questions: answers.length,
      }));
    }

    return result;
  };

  const markReviewed = (id: number) => {
    setReviewItems((prev) =>
      prev.map((item) =>
        item.id === id
          ? {
              ...item,
              reviewed_at: new Date().toISOString(),
              review_count: item.review_count + 1,
            }
          : item
      )
    );
  };

  const savePlan = (plan: Partial<StudyPlan>) => {
    if (plan.id) {
      setStudyPlans((prev) =>
        prev.map((p) => (p.id === plan.id ? ({ ...p, ...plan } as StudyPlan) : p))
      );
    } else {
      const newPlan: StudyPlan = {
        id: Date.now(),
        title: plan.title || 'خطة مذاكرة جديدة',
        subject_id: plan.subject_id ?? null,
        subject_name: plan.subject_name,
        target_minutes_per_day: plan.target_minutes_per_day || 30,
        sessions_per_week: plan.sessions_per_week || 5,
        start_date: plan.start_date || new Date().toISOString().slice(0, 10),
        end_date: plan.end_date ?? null,
        notes: plan.notes || '',
        is_active: true,
      };
      setStudyPlans((prev) => [newPlan, ...prev]);
    }
  };

  const deletePlan = (id: number) => {
    setStudyPlans((prev) => prev.filter((p) => p.id !== id));
  };

  const togglePlanActive = (id: number) => {
    setStudyPlans((prev) =>
      prev.map((p) => (p.id === id ? { ...p, is_active: !p.is_active } : p))
    );
  };

  const markNotificationRead = (id: number) => {
    setNotifications((prev) =>
      prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
    );
  };

  const markAllNotificationsRead = () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
  };

  const updatePreferences = (prefs: Partial<StudentPreferences>) => {
    setPreferences((prev) => ({ ...prev, ...prefs }));
  };

  // Academic Management
  const createYear = (yearNumber: number, name: string, order: number) => {
    const newYear: AcademicYear = {
      id: Date.now(),
      year_number: yearNumber,
      name,
      order,
    };
    setYears((prev) => [...prev, newYear]);
  };

  const updateYear = (id: number, data: Partial<AcademicYear>) => {
    setYears((prev) => prev.map((y) => (y.id === id ? { ...y, ...data } : y)));
  };

  const deleteYear = (id: number) => {
    setYears((prev) => prev.filter((y) => y.id !== id));
  };

  const createSubject = (
    academicYearId: number,
    name: string,
    code?: string,
    description?: string
  ) => {
    const newSubj: AcademicSubject = {
      id: Date.now(),
      academic_year: academicYearId,
      name,
      code,
      description,
      order: subjects.length + 1,
      lecture_count: 16,
    };
    setSubjects((prev) => [...prev, newSubj]);

    // Create 16 lectures for this new subject
    const newLecs: AcademicLecture[] = [];
    for (let i = 1; i <= 16; i++) {
      newLecs.push({
        id: Date.now() + i,
        subject_id: newSubj.id,
        lecture_number: i,
        title: `المحاضرة ${i}: ${name} - الجزء ${i}`,
        description: `محتوى المحاضرة ${i}`,
        order: i,
        has_content: true,
      });
    }
    setLectures((prev) => [...prev, ...newLecs]);
  };

  const updateSubject = (id: number, data: Partial<AcademicSubject>) => {
    setSubjects((prev) => prev.map((s) => (s.id === id ? { ...s, ...data } : s)));
  };

  const deleteSubject = (id: number) => {
    setSubjects((prev) => prev.filter((s) => s.id !== id));
    setLectures((prev) => prev.filter((l) => l.subject_id !== id));
    setMaterials((prev) => prev.filter((m) => m.subject_id !== id));
  };

  const createLecture = (
    subjectId: number,
    lectureNumber: number,
    title: string,
    description?: string
  ) => {
    const newLec: AcademicLecture = {
      id: Date.now(),
      subject_id: subjectId,
      lecture_number: lectureNumber,
      title,
      description,
      order: lectureNumber,
      has_content: true,
    };
    setLectures((prev) => [...prev, newLec]);
  };

  const updateLecture = (id: number, data: Partial<AcademicLecture>) => {
    setLectures((prev) => prev.map((l) => (l.id === id ? { ...l, ...data } : l)));
  };

  const deleteLecture = (id: number) => {
    setLectures((prev) => prev.filter((l) => l.id !== id));
  };

  const uploadMaterial = (data: {
    academicYearId: number;
    subjectId: number;
    lectureId: number;
    title: string;
    materialType: 'lecture' | 'section';
    sectionTitle?: string;
    filename: string;
    sizeBytes?: number;
  }) => {
    const newMat: AcademicMaterial = {
      id: Date.now(),
      academic_year_id: data.academicYearId,
      subject_id: data.subjectId,
      lecture_id: data.lectureId,
      title: data.title || data.filename,
      material_type: data.materialType,
      section_title: data.sectionTitle,
      original_filename: data.filename,
      processing_status: 'READY',
      uploaded_at: new Date().toISOString().slice(0, 16).replace('T', ' '),
      size_bytes: data.sizeBytes || 2400000,
    };
    setMaterials((prev) => [newMat, ...prev]);
  };

  const replaceMaterial = (id: number, filename: string) => {
    setMaterials((prev) =>
      prev.map((m) =>
        m.id === id
          ? {
              ...m,
              original_filename: filename,
              title: filename,
              processing_status: 'READY',
              uploaded_at: new Date().toISOString().slice(0, 16).replace('T', ' '),
            }
          : m
      )
    );
  };

  const retryMaterial = (id: number) => {
    setMaterials((prev) =>
      prev.map((m) =>
        m.id === id
          ? {
              ...m,
              processing_status: 'READY',
              processing_error: undefined,
            }
          : m
      )
    );
  };

  const deleteMaterial = (id: number) => {
    setMaterials((prev) => prev.filter((m) => m.id !== id));
  };

  const toggleStudentStatus = (uid: string) => {
    setUsers((prev) =>
      prev.map((u) => (u.uid === uid ? { ...u, is_active: !u.is_active } : u))
    );
  };

  return (
    <AppContext.Provider
      value={{
        currentUser,
        users,
        years,
        subjects,
        lectures,
        materials,
        dailyChallenge,
        reviewItems,
        studyPlans,
        notifications,
        preferences,
        attemptHistory,
        unreadNotificationsCount,

        login,
        register,
        logout,
        switchUser,
        updateProfile,
        updateProfileImage,

        createQuiz,
        submitQuiz,
        markReviewed,

        savePlan,
        deletePlan,
        togglePlanActive,

        markNotificationRead,
        markAllNotificationsRead,
        updatePreferences,

        createYear,
        updateYear,
        deleteYear,
        createSubject,
        updateSubject,
        deleteSubject,
        createLecture,
        updateLecture,
        deleteLecture,
        uploadMaterial,
        replaceMaterial,
        retryMaterial,
        deleteMaterial,
        toggleStudentStatus,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
};
