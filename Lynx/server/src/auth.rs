use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{header::AUTHORIZATION, request::Parts, StatusCode},
};
use std::env;

#[derive(Clone, Debug)]
pub struct UserId(pub String);

/// Bearer-токен: для dev — любой непустой токен; опционально LYNX_DEV_USER_ID.
#[async_trait]
impl<S> FromRequestParts<S> for UserId
where
    S: Send + Sync,
{
    type Rejection = StatusCode;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let auth = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("");
        let token = auth.strip_prefix("Bearer ").unwrap_or(auth).trim();
        if token.is_empty() {
            return Err(StatusCode::UNAUTHORIZED);
        }
        let uid = env::var("LYNX_DEV_USER_ID").unwrap_or_else(|_| {
            if token.len() >= 8 {
                format!("user_{}", &token[..8])
            } else {
                "user_dev".into()
            }
        });
        Ok(UserId(uid))
    }
}
