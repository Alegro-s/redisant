-- ТОЛСТОВСКИЙ PROFILE — демо-данные (не трогает licenses, activations и др.)
-- Выполните в Supabase → SQL Editor

-- ========== ТАБЛИЦЫ ==========

CREATE TABLE IF NOT EXISTS public.tspu_schedule (
  id text PRIMARY KEY,
  subject text NOT NULL,
  teacher text NOT NULL DEFAULT '',
  classroom text NOT NULL DEFAULT '',
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  type text NOT NULL DEFAULT 'лекция',
  additional_info text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_grades (
  id text PRIMARY KEY,
  subject text NOT NULL,
  teacher text NOT NULL DEFAULT '',
  value integer NOT NULL DEFAULT 0,
  type text NOT NULL,
  date timestamptz NOT NULL,
  semester integer,
  zet integer,
  hours integer,
  grade_label text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_exams (
  id text PRIMARY KEY,
  subject text NOT NULL,
  teacher text NOT NULL DEFAULT '',
  exam_date text NOT NULL,
  exam_time text NOT NULL,
  classroom text NOT NULL DEFAULT '',
  is_completed boolean NOT NULL DEFAULT false,
  type text NOT NULL DEFAULT 'экзамен',
  grade integer,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_portfolio (
  id text PRIMARY KEY,
  title text NOT NULL,
  category text NOT NULL,
  status text NOT NULL,
  item_date timestamptz NOT NULL,
  source text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_moodle_labs (
  id text PRIMARY KEY,
  course text NOT NULL,
  title text NOT NULL,
  status text NOT NULL,
  teacher_comment text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  deadline timestamptz,
  work_type text,
  theme text,
  score integer
);

CREATE TABLE IF NOT EXISTS public.tspu_showcase_slides (
  id text PRIMARY KEY,
  tag text NOT NULL,
  title text NOT NULL,
  subtitle text NOT NULL,
  colors jsonb NOT NULL DEFAULT '[]'::jsonb,
  action_url text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_app_release (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  version text NOT NULL,
  build_number text NOT NULL,
  notes text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ========== RLS (демо: чтение всем, запись для админ-веба) ==========

ALTER TABLE public.tspu_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_portfolio ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_moodle_labs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_showcase_slides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_app_release ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY[
    'tspu_schedule','tspu_grades','tspu_exams','tspu_portfolio',
    'tspu_moodle_labs','tspu_showcase_slides','tspu_app_release'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tspu_%I_select ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS tspu_%I_all ON public.%I', t, t);
    EXECUTE format('CREATE POLICY tspu_%I_select ON public.%I FOR SELECT USING (true)', t, t);
    EXECUTE format('CREATE POLICY tspu_%I_all ON public.%I FOR ALL USING (true) WITH CHECK (true)', t, t);
  END LOOP;
END $$;

-- ========== SEED: расписание (текущая неделя, пн=0) ==========

DELETE FROM public.tspu_schedule;
INSERT INTO public.tspu_schedule (id, subject, teacher, classroom, start_time, end_time, type) VALUES
  ('S1', 'Большие данные и распределенные системы', 'Добровольский Николай Николаевич', '3-309-3',
    date_trunc('week', now()) + interval '0 days 8 hours 40 minutes',
    date_trunc('week', now()) + interval '0 days 10 hours 15 minutes', 'лекция'),
  ('S2', 'Большие данные и распределенные системы', 'Добровольский Николай Николаевич', '3-308а-3',
    date_trunc('week', now()) + interval '0 days 10 hours 25 minutes',
    date_trunc('week', now()) + interval '0 days 12 hours 0 minutes', 'лабораторная'),
  ('S3', 'Экономико-математические методы и модели', 'Рарова Елена Михайловна', '3-313-3',
    date_trunc('week', now()) + interval '1 days 8 hours 40 minutes',
    date_trunc('week', now()) + interval '1 days 10 hours 15 minutes', 'лекция'),
  ('S4', 'Методы оптимизации', 'Родионов Александр Валерьевич', '3-313-3',
    date_trunc('week', now()) + interval '3 days 8 hours 40 minutes',
    date_trunc('week', now()) + interval '3 days 10 hours 15 minutes', 'лекция');

DELETE FROM public.tspu_grades;
INSERT INTO public.tspu_grades (id, subject, teacher, value, type, date, semester, zet, hours, grade_label) VALUES
  ('G1', 'Безопасность жизнедеятельности', '—', 0, 'Зачёт', '2022-12-23T00:00:00Z', 1, 3, 108, 'Зачтено'),
  ('G2', 'Введение в программирование', '—', 4, 'Экзамен', '2023-01-17T00:00:00Z', 1, 5, 180, 'Хорошо'),
  ('G3', 'Дискретная математика', '—', 0, 'Зачёт', '2022-12-28T00:00:00Z', 1, 4, 144, 'Зачтено'),
  ('G4', 'Математический анализ', '—', 4, 'Экзамен', '2023-01-12T00:00:00Z', 1, 5, 180, 'Хорошо'),
  ('G5', 'Алгоритмы', 'Петров А.А.', 5, 'лабораторная', now() - interval '5 days', 7, 3, 36, NULL);

DELETE FROM public.tspu_exams;
INSERT INTO public.tspu_exams (id, subject, teacher, exam_date, exam_time, classroom, is_completed, type, grade) VALUES
  ('E1', 'Компьютерные сети', 'Иванова Н.В.', '20.04.2026', '10:00', 'ауд. 102', false, 'экзамен', NULL);

DELETE FROM public.tspu_portfolio;
INSERT INTO public.tspu_portfolio (id, title, category, status, item_date, source) VALUES
  ('P1', 'Методы оптимизации 2025 - 2026', 'Учебная дисциплина', 'Подтверждено', now() - interval '120 days', '1C/Учебный план'),
  ('P2', 'Большие данные и распределенные системы 2025 - 2026', 'Учебная дисциплина', 'Подтверждено', now() - interval '110 days', '1C/Учебный план'),
  ('P3', 'Производственная преддипломная практика 2025 - 2026', 'Практика', 'В процессе', now() - interval '90 days', '1C/Практика'),
  ('P4', 'Экономико-математические методы и модели 2025 - 2026', 'Учебная дисциплина', 'Подтверждено', now() - interval '80 days', '1C/Учебный план'),
  ('P5', 'Подготовка к процедуре защиты ВКР 2025 - 2026', 'ВКР', 'В процессе', now() - interval '60 days', '1C/ВКР'),
  ('P6', 'Компьютерное моделирование 2025 - 2026', 'Учебная дисциплина', 'Подтверждено', now() - interval '50 days', '1C/Учебный план'),
  ('P7', 'Рекурсивно-логическое программирование 2025 - 2026', 'Учебная дисциплина', 'Подтверждено', now() - interval '40 days', '1C/Учебный план');

DELETE FROM public.tspu_moodle_labs;
INSERT INTO public.tspu_moodle_labs (id, course, title, status, teacher_comment, updated_at, deadline, work_type, theme, score) VALUES
  ('L1', 'Программирование', 'ЛР №3', 'Принято', 'Хорошая реализация, добавьте тесты.', now() - interval '6 hours', now() + interval '5 days', 'ЛР', 'Структуры данных', 5),
  ('L2', 'Базы данных', 'ЛР №2', 'На проверке', NULL, now() - interval '1 day', now() + interval '2 days', 'ЛР', 'Нормализация', NULL),
  ('L3', 'Веб-программирование', 'КР — макет', 'Требуются правки', 'Проверьте адаптив и контраст.', now() - interval '20 hours', now() - interval '1 day', 'КР', 'Вёрстка landing', 2);

DELETE FROM public.tspu_showcase_slides;
INSERT INTO public.tspu_showcase_slides (id, tag, title, subtitle, colors, sort_order) VALUES
  ('slide1', 'Стипендии', 'Льготы и выплаты', 'Матпомощь, категории и сроки', '["#3A2520","#A34A35","#C45D45"]', 1),
  ('slide2', 'Университет', 'ТГПУ рядом с вами', 'Обучение, расписание, сервисы', '["#121212","#1E1E1E","#2C2C2C"]', 2),
  ('slide3', 'Карьера', 'Наука и проекты', 'Практики, ВКР, мероприятия', '["#1E2D28","#2A4038","#355A4F"]', 3);

INSERT INTO public.tspu_app_release (id, version, build_number, notes)
VALUES (1, '1.1.2', '3', 'Демо через Supabase + веб-админка')
ON CONFLICT (id) DO UPDATE SET
  version = EXCLUDED.version,
  build_number = EXCLUDED.build_number,
  notes = EXCLUDED.notes,
  updated_at = now();
