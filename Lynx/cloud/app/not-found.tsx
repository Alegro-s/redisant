import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="cloud-apple cloud-cabinet-page">
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>Страница не найдена</h1>
        <p className="cloud-intro-lead">Такого адреса нет. Витрина и кабинет — по ссылкам ниже.</p>
        <div className="cloud-intro-actions">
          <Link className="cloud-btn-primary" href="/">
            На главную
          </Link>
          <Link className="cloud-btn-secondary" href="/cabinet/sign-in">
            Войти в кабинет
          </Link>
        </div>
      </section>
    </main>
  );
}
