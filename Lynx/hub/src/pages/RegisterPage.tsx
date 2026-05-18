import { Link } from 'react-router-dom';

export function RegisterPage() {
  return (
    <div className="lynx-register">
      <h1>Регистрация Lynx</h1>
      <p className="lynx-lead">
        Новый аккаунт Lynx создаётся только в <strong>Lynx Launcher</strong> (Windows). Hub и Cloud — вход для уже
        зарегистрированных пользователей; один аккаунт на всю серию Lynx.
      </p>
      <ul className="lynx-register-list">
        <li>Скачайте и установите Lynx Launcher</li>
        <li>Вкладка «Нет аккаунта» → регистрация и подтверждение email</li>
        <li>После этого — вход на lynx-hub.ru и lynx-cloud.ru</li>
      </ul>
      <Link to="/download" className="lynx-app-cta">
        Скачать Lynx Launcher
      </Link>
      <p style={{ marginTop: '1rem' }}>
        <Link to="/sign-in" className="lynx-link-accent">
          Уже есть аккаунт — войти
        </Link>
      </p>
      <p style={{ marginTop: '1.5rem' }}>
        <Link to="/" className="lynx-link-accent">
          ← На главную
        </Link>
      </p>
    </div>
  );
}
