import { Link } from 'react-router-dom';
import { LYNX_CABINET_URL } from '../config/links';

export function RegisterPage() {
  const registerUrl = `${LYNX_CABINET_URL}/sign-in?mode=register`;

  return (
    <div className="lynx-register">
      <h1>Регистрация на платформе Lynx</h1>
      <p className="lynx-lead">
        Один аккаунт для Hub, Cloud и форума: следите за обновлениями движка, получайте уведомления о релизах и
        участвуйте в обсуждениях.
      </p>
      <ul className="lynx-register-list">
        <li>Личный профиль и история загрузок</li>
        <li>Уведомления о новых версиях ядра</li>
        <li>Форум разработчиков (по мере запуска)</li>
        <li>Единый вход в Lynx Cloud для авторов</li>
      </ul>
      <a href={registerUrl} className="lynx-app-cta" target="_blank" rel="noreferrer">
        Создать аккаунт Lynx Cloud
      </a>
      <p style={{ marginTop: '1.5rem' }}>
        <Link to="/" className="lynx-link-accent">
          ← На главную
        </Link>
      </p>
    </div>
  );
}
