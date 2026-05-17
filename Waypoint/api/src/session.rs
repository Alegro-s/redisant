use actix_web::cookie::{time::Duration as CookieDuration, Cookie, SameSite};

/// Единая сессия PO (Waypoint + Lynx + auth-api).
pub const SESSION_COOKIE: &str = "waypoint_session";
/// Совместимость со старыми деплоями.
pub const SESSION_COOKIE_LEGACY: &str = "nexus_session";

pub fn session_cookie(token: &str, max_age_secs: i64, secure: bool) -> Cookie<'static> {
    let mut b = Cookie::build(SESSION_COOKIE, token.to_string())
        .path("/")
        .http_only(true)
        .same_site(SameSite::Lax)
        .max_age(CookieDuration::seconds(max_age_secs.max(60)));
    if secure {
        b = b.secure(true);
    }
    b.finish()
}

pub fn clear_session_cookie(secure: bool) -> Cookie<'static> {
    let mut b = Cookie::build(SESSION_COOKIE, "")
        .path("/")
        .http_only(true)
        .same_site(SameSite::Lax)
        .max_age(CookieDuration::seconds(0));
    if secure {
        b = b.secure(true);
    }
    b.finish()
}
