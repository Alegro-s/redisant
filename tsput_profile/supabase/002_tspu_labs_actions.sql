ALTER TABLE public.tspu_moodle_labs
  ADD COLUMN IF NOT EXISTS task_file_url text,
  ADD COLUMN IF NOT EXISTS task_file_name text;

CREATE TABLE IF NOT EXISTS public.tspu_lab_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id text NOT NULL,
  file_name text NOT NULL,
  file_url text,
  submitted_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.tspu_lab_comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lab_id text NOT NULL,
  text text NOT NULL,
  author_name text NOT NULL DEFAULT 'Студент',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.tspu_lab_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tspu_lab_comments ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['tspu_lab_submissions', 'tspu_lab_comments'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS tspu_%I_select ON public.%I', t, t);
    EXECUTE format('DROP POLICY IF EXISTS tspu_%I_all ON public.%I', t, t);
    EXECUTE format('CREATE POLICY tspu_%I_select ON public.%I FOR SELECT USING (true)', t, t);
    EXECUTE format('CREATE POLICY tspu_%I_all ON public.%I FOR ALL USING (true) WITH CHECK (true)', t, t);
  END LOOP;
END $$;

UPDATE public.tspu_moodle_labs SET
  task_file_name = 'LR3_assignment.pdf',
  task_file_url = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'
WHERE id = 'L1' AND task_file_url IS NULL;

UPDATE public.tspu_moodle_labs SET
  task_file_name = COALESCE(task_file_name, 'LR2_assignment.pdf'),
  task_file_url = COALESCE(task_file_url, 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf')
WHERE id = 'L2';

UPDATE public.tspu_moodle_labs SET
  task_file_name = COALESCE(task_file_name, 'KR_layout.pdf'),
  task_file_url = COALESCE(task_file_url, 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf')
WHERE id = 'L3';

DELETE FROM public.tspu_lab_comments;
INSERT INTO public.tspu_lab_comments (lab_id, text, author_name) VALUES
  ('L2', 'Работа получена, ожидайте оценку.', 'Преподаватель'),
  ('L3', 'Собеседование', 'Преподаватель');

DELETE FROM public.tspu_lab_submissions WHERE lab_id = 'L2';
INSERT INTO public.tspu_lab_submissions (lab_id, file_name, file_url) VALUES
  ('L2', 'Отчет лабы.pdf', NULL),
  ('L2', 'full.zip', NULL);
