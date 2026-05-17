import { Link } from 'react-router-dom';

const rows = [
  { feature: 'Lynx Core (движок)', free: '✓', basic: '✓', pro: '✓' },
  { feature: 'Редактор и сборка', free: '✓', basic: '✓', pro: '✓' },
  { feature: 'Чат в Launcher', free: '✓', basic: '✓', pro: '✓' },
  { feature: 'Реклама Lynx в клиенте', free: 'да', basic: 'нет', pro: 'нет' },
  { feature: 'Расширения Launcher', free: '—', basic: 'базовые', pro: 'полный набор' },
  { feature: 'Приоритет Cloud', free: '—', basic: '—', pro: '✓' },
];

export function PricingPage() {
  return (
    <div className="lynx-price-page">
      <p className="lynx-pill">Подписки</p>
      <h1>Тарифы Launcher</h1>
      <p className="lynx-dl-lead">
        Движок бесплатен. Подписка отключает рекламу и открывает функции в клиенте — не путать с Lynx Cloud (отдельный
        вход).
      </p>

      <table className="lynx-price-table">
        <thead>
          <tr>
            <th>Возможность</th>
            <th>Бесплатно</th>
            <th>Базовый</th>
            <th>Полный</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.feature}>
              <td>{r.feature}</td>
              <td className="col-free">{r.free}</td>
              <td className="col-paid">{r.basic}</td>
              <td className="col-paid">{r.pro}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <p className="lynx-price-foot">
        Оформление подписки — <strong>скоро будет</strong>. Сейчас можно{' '}
        <Link to="/download">скачать Launcher</Link> с бесплатным ядром.
      </p>

      <p className="lynx-launch-foot" style={{ marginTop: '2rem' }}>
        <Link to="/">← Главная</Link>
      </p>
    </div>
  );
}
