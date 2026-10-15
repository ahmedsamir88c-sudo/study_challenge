# Study Challenge (تحدي الدراسة)

A comprehensive academic quiz, spaced repetition review, daily challenges, and AI study assistant web application tailored for computer engineering and computer science university students. Rewritten as a modern React SPA using Vite, TypeScript, and Tailwind CSS.

## Features

- **Authentication & Profiles**:
  - Student and Owner/Administrator roles
  - Login by Student ID (e.g. `2024001`) or username
  - Academic year assignment (Year 1 to Year 4, focused on Year 2 / الفرقة الثانية)
  - Daily study streak counter, XP points, profile photo uploads, and role badges
  - Quick demo account switcher to easily preview both Student and Owner views

- **Interactive Timed Quiz Engine**:
  - Select Subject (Computer Architecture, Digital Logic Design, Data Structures & Algorithms, Computer Networks, Machine Learning, Modeling & Simulation)
  - Select Lecture (1 to 16)
  - Choose Question Count (5, 10, 20, 25, 30, 40, 50 questions)
  - Choose Difficulty level (Easy, Medium, Hard)
  - 30-second countdown timer per question with visual alerts
  - Real-time score grading, XP point awards, and comprehensive question-by-question review with explanations

- **Daily Challenge (التحدي اليومي)**:
  - 5 curated questions from current academic courses
  - Bonus +25 XP upon completion
  - Keeps study streaks active

- **Smart Review (المراجعة الذكية)**:
  - Spaced repetition mechanism for missed quiz questions
  - Reveal answer and explanation toggles
  - Mark questions as mastered (`review_count` tracking)

- **Study Plans & Goals (خطة الدراسة)**:
  - Create, edit, toggle, and delete personalized study plans
  - Set target study minutes per day and sessions per week
  - Associated academic subjects and date tracking

- **Analytics & Study Reports (التقارير والإحصائيات)**:
  - 7-day, 30-day, and 90-day progress metrics
  - Total quizzes, questions solved, accuracy rate, XP points earned, and active study days
  - Performance breakdown by subject and lecture

- **AI Academic Study Assistant & Summarizer (المساعد الذكي)**:
  - Grounded in university curriculum and lecture slides
  - Instant academic explanations with source citations (lecture number, section, slide page)
  - Lecture Summarizer tool with 5 modes: Quick, Detailed, Exam Focus, Key Points, Definitions

- **Olympic Leaderboard (لوحة المتصدرين)**:
  - 3-tier podium (Gold, Silver, Bronze) with medals, avatars, and points
  - Live ranked list of students for Year 2

- **Owner Dashboard & Academic Content Management (لوحة المالك)**:
  - High-level platform KPIs (Total students, active students, subjects, lectures, files, questions)
  - Full CRUD management of Academic Years, Subjects, and 16 Lectures per subject
  - Material and slide upload manager (Lecture Slides vs Section Labs)
  - Student account directory with search, filter (active/blocked), and ban/unban capabilities

## Tech Stack

- **Framework**: React 19, TypeScript
- **Bundler & Dev Server**: Vite
- **Styling**: Tailwind CSS (dark mode matching the original palette: `#0B1020`, `#141C2E`, `#52D6A6`, `#FFC76A`, `#7DB8FF`)
- **Icons**: Lucide React
- **Typography**: Google Fonts Cairo (Arabic RTL support)

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the development server on port 3000:
   ```bash
   npm run dev
   ```

3. Build for production:
   ```bash
   npm run build
   ```
