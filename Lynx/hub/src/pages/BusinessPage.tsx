import { Link } from 'react-router-dom';

export function BusinessPage() {
  return (
    <div className="space-y-12 max-w-3xl">
      <h1 className="text-4xl md:text-5xl font-bold text-white tracking-tight">Enterprise и партнёры</h1>
      <p className="text-mist/85 text-xl leading-relaxed">
        Выделенные инстансы API, приоритет очередей Lynx Cloud, расширенные квоты WaypointMetric, SSO и отдельный канал
        поддержки. Опишите нагрузку (RPS ingest, объём BaaS, число проектов) — подготовим коммерческое предложение.
      </p>
      <div className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-10 space-y-6">
        <p className="text-mist/80 text-lg leading-relaxed">
          Для первого контакта напишите на корпоративную почту.
        </p>
        <a
          href="mailto:enterprise@lynx-hub.ru?subject=Lynx%20Enterprise"
          className="inline-flex items-center justify-center px-8 py-4 rounded-2xl bg-white text-ink font-semibold text-lg hover:bg-violet-50 transition-colors"
        >
          enterprise@lynx-hub.ru
        </a>
      </div>
      <p className="text-mist/55 text-lg">
        <Link to="/pricing" className="text-violet-400 hover:text-violet-300">
          ← К тарифам
        </Link>
      </p>
    </div>
  );
}
