'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { lynxCabinetFetch } from '@/lib/adminClient';

type Overview = {
  projects: number;
  builds: number;
  downloads_30d: number;
  sessions_30d: number;
  revenue_rub: number;
};

type AnalyticsDay = { date: string; downloads: number; sessions: number };

type Build = {
  id: string;
  status: string;
  label?: string;
  created_at: string;
};

export default function LynxCabinetDashboardPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const denied = searchParams.get('denied') === 'ops';
  const [overview, setOverview] = useState<Overview | null>(null);
  const [days, setDays] = useState<AnalyticsDay[]>([]);
  const [builds, setBuilds] = useState<Build[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('lynx_auth_token');
    if (!token) {
      router.replace('/cabinet/sign-in');
      return;
    }
    void (async () => {
      try {
        const [ov, an, b] = await Promise.all([
          lynxCabinetFetch<Overview>('/me/lynx-cloud/overview'),
          lynxCabinetFetch<{ days?: AnalyticsDay[] }>('/me/lynx-cloud/analytics'),
          lynxCabinetFetch<{ builds?: Build[] } | Build[]>('/me/lynx-cloud/builds'),
        ]);
        setOverview(ov);
        setDays(an.days ?? []);
        const buildList = Array.isArray(b) ? b : (b.builds ?? []);
        setBuilds(buildList.slice(0, 8));
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Ошибка загрузки');
      }
    })();
  }, [router]);

  const maxBar = Math.max(1, ...days.map((d) => d.downloads + d.sessions));

  return (
    <div className="cloud-admin-page">
      <h1>Кабинет разработчика</h1>
      <p className="cloud-intro-lead">
        Проекты, сборки, скачивания и доход — аналитика Lynx Cloud за 30 дней.
      </p>
      {denied ? (
        <p className="cloud-auth-error">Нет доступа к панели операций. Требуется роль NEXUS.</p>
      ) : null}
      {error ? <p className="cloud-auth-error">{error}</p> : null}

      {overview ? (
        <div className="lynx-ops-kpi-row">
          <div className="lynx-ops-kpi">
            <strong>{overview.projects}</strong>
            <span>Проектов</span>
          </div>
          <div className="lynx-ops-kpi">
            <strong>{overview.builds}</strong>
            <span>Сборок</span>
          </div>
          <div className="lynx-ops-kpi">
            <strong>{overview.downloads_30d}</strong>
            <span>Скачиваний (30д)</span>
          </div>
          <div className="lynx-ops-kpi">
            <strong>{Math.round(overview.sessions_30d / 60)}</strong>
            <span>Минут игры (30д)</span>
          </div>
          <div className="lynx-ops-kpi">
            <strong>{overview.revenue_rub.toFixed(0)} ₽</strong>
            <span>Баланс / доход</span>
          </div>
        </div>
      ) : null}

      {days.length > 0 ? (
        <>
          <h2>Активность</h2>
          <div className="lynx-ops-bars" aria-hidden>
            {days.map((d) => (
              <div
                key={d.date}
                className="lynx-ops-bar"
                style={{ height: `${((d.downloads + d.sessions) / maxBar) * 100}%` }}
                title={d.date}
              />
            ))}
          </div>
        </>
      ) : (
        <p className="cloud-cabinet-note">Телеметрия появится после запусков игр из Launcher.</p>
      )}

      <h2>Последние сборки</h2>
      <ul className="lynx-data-table cloud-admin-list">
        {builds.length === 0 ? <li>Пока нет сборок.</li> : null}
        {builds.map((b) => (
          <li key={b.id}>
            <strong>{b.label ?? b.id.slice(0, 8)}</strong>
            <span>{b.status}</span>
            <span>{new Date(b.created_at).toLocaleString()}</span>
          </li>
        ))}
      </ul>
      <div className="cloud-intro-actions" style={{ marginTop: '1.5rem' }}>
        <Link className="cloud-btn-secondary" href="/cabinet/projects">
          Все проекты
        </Link>
        <Link className="cloud-btn-secondary" href="/cabinet/builds">
          Все сборки
        </Link>
      </div>
    </div>
  );
}
