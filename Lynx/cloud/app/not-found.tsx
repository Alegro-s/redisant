import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="cloud-apple cloud-cabinet-page" style={{ background: '#ffffff' }}>
      <section className="cloud-cabinet-hero">
        <p className="cloud-kicker">Lynx Cloud</p>
        <h1>Страница не найдена</h1>
        <p className="cloud-intro-lead">Такого адреса нет. Перейдите на витрину или войдите в кабинет.</p>
        <div className="cloud-intro-actions">
          <Link className="cloud-btn-primary" href="/">
            На главную
          </Link>
          <Link className="cloud-btn-secondary" href="/cabinet/sign-in">
            Войти
          </Link>
        </div>
      </section>
    </main>
  );
}
