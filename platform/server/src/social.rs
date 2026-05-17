
use actix_web::{web, HttpRequest, HttpResponse, Responder};
use serde::Deserialize;
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::{get_user_id_from_token, AppState, ErrorResponse};

fn norm_nick(q: &str) -> String {
    q.trim().trim_start_matches('@').to_lowercase()
}

pub async fn users_search(state: web::Data<AppState>, req: HttpRequest, q: web::Query<SearchQ>) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let needle = norm_nick(&q.q);
    if needle.len() < 2 {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Query too short (min 2 chars)".into(),
        });
    }

    let pattern = format!("%{}%", needle);
    let rows = sqlx::query_as::<_, (Uuid, String, String)>(
        r#"SELECT u.id, u.nickname, u.full_name FROM users u
           WHERE u.id != $1
             AND COALESCE(u.blocked, false) = false
             AND LOWER(u.nickname) LIKE $2
             AND NOT EXISTS (
               SELECT 1 FROM chat_blocks b
               WHERE (b.blocker_id = $1 AND b.blocked_id = u.id)
                  OR (b.blocker_id = u.id AND b.blocked_id = $1)
             )
           ORDER BY u.nickname
           LIMIT 30"#,
    )
    .bind(me)
    .bind(&pattern)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => {
            let out: Vec<_> = r
                .into_iter()
                .map(|(id, nickname, full_name)| {
                    json!({
                        "id": id.to_string(),
                        "nickname": nickname,
                        "full_name": full_name,
                        "at": format!("@{}", nickname),
                    })
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("users_search: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct SearchQ {
    pub q: String,
}

#[derive(Deserialize)]
pub struct FriendUserId {
    pub user_id: Uuid,
}

pub async fn friends_list(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, (Uuid, String, String)>(
        r#"SELECT u.id, u.nickname, u.full_name FROM users u
           INNER JOIN friendships f ON f.status = 'accepted'
             AND ((f.requester_id = $1 AND f.addressee_id = u.id)
               OR (f.addressee_id = $1 AND f.requester_id = u.id))
           WHERE COALESCE(u.blocked, false) = false
           ORDER BY u.nickname"#,
    )
    .bind(me)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => {
            let out: Vec<_> = r
                .into_iter()
                .map(|(id, nickname, full_name)| {
                    json!({
                        "id": id.to_string(),
                        "nickname": nickname,
                        "full_name": full_name,
                        "at": format!("@{}", nickname),
                    })
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("friends_list: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn friends_requests_incoming(state: web::Data<AppState>, req: HttpRequest) -> impl Responder {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            })
        }
    };
    let me = match get_user_id_from_token(&req, &jwt_secret) {
        Some(id) => id,
        None => {
            return HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            })
        }
    };

    let rows = sqlx::query_as::<_, (Uuid, String, String)>(
        r#"SELECT u.id, u.nickname, u.full_name FROM users u
           INNER JOIN friendships f ON f.addressee_id = $1 AND f.requester_id = u.id AND f.status = 'pending'
           WHERE COALESCE(u.blocked, false) = false
           ORDER BY f.created_at DESC"#,
    )
    .bind(me)
    .fetch_all(&state.pool)
    .await;

    match rows {
        Ok(r) => {
            let out: Vec<_> = r
                .into_iter()
                .map(|(id, nickname, full_name)| {
                    json!({
                        "id": id.to_string(),
                        "nickname": nickname,
                        "full_name": full_name,
                        "at": format!("@{}", nickname),
                    })
                })
                .collect();
            HttpResponse::Ok().json(out)
        }
        Err(e) => {
            log::error!("friends_requests_incoming: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn friends_request(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<FriendUserId>,
) -> impl Responder {
    let (me, pool) = match auth_me_pool(&state, &req).await {
        Ok(x) => x,
        Err(r) => return r,
    };
    if me == body.user_id {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Invalid user".into(),
        });
    }
    let exists: bool = sqlx::query_scalar("SELECT EXISTS(SELECT 1 FROM users WHERE id = $1)")
        .bind(body.user_id)
        .fetch_one(&pool)
        .await
        .unwrap_or(false);
    if !exists {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "User not found".into(),
        });
    }

    let ins = sqlx::query(
        r#"INSERT INTO friendships (requester_id, addressee_id, status)
           VALUES ($1, $2, 'pending')
           ON CONFLICT (requester_id, addressee_id) DO NOTHING"#,
    )
    .bind(me)
    .bind(body.user_id)
    .execute(&pool)
    .await;

    match ins {
        Ok(_) => HttpResponse::Ok().json(json!({"ok": true})),
        Err(e) => {
            log::error!("friends_request: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn friends_accept(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<FriendUserId>,
) -> impl Responder {
    let (me, pool) = match auth_me_pool(&state, &req).await {
        Ok(x) => x,
        Err(r) => return r,
    };

    let res = sqlx::query(
        r#"UPDATE friendships SET status = 'accepted', updated_at = now()
           WHERE addressee_id = $1 AND requester_id = $2 AND status = 'pending'"#,
    )
    .bind(me)
    .bind(body.user_id)
    .execute(&pool)
    .await;

    match res {
        Ok(r) if r.rows_affected() > 0 => HttpResponse::Ok().json(json!({"ok": true})),
        Ok(_) => HttpResponse::NotFound().json(ErrorResponse {
            error: "No pending request".into(),
        }),
        Err(e) => {
            log::error!("friends_accept: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn friends_reject(
    state: web::Data<AppState>,
    req: HttpRequest,
    body: web::Json<FriendUserId>,
) -> impl Responder {
    let (me, pool) = match auth_me_pool(&state, &req).await {
        Ok(x) => x,
        Err(r) => return r,
    };

    let _ = sqlx::query(
        r#"DELETE FROM friendships
           WHERE addressee_id = $1 AND requester_id = $2 AND status = 'pending'"#,
    )
    .bind(me)
    .bind(body.user_id)
    .execute(&pool)
    .await;

    HttpResponse::Ok().json(json!({"ok": true}))
}

async fn auth_me_pool(
    state: &web::Data<AppState>,
    req: &HttpRequest,
) -> Result<(Uuid, PgPool), HttpResponse> {
    let jwt_secret = match std::env::var("JWT_SECRET") {
        Ok(s) => s,
        Err(_) => {
            return Err(HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Server configuration error".into(),
            }))
        }
    };
    let me = match get_user_id_from_token(req, &jwt_secret) {
        Some(id) => id,
        None => {
            return Err(HttpResponse::Unauthorized().json(ErrorResponse {
                error: "Invalid token".into(),
            }))
        }
    };
    Ok((me, state.pool.clone()))
}

pub async fn project_preview(state: web::Data<AppState>, path: web::Path<String>) -> impl Responder {
    let slug = path.into_inner();
    let row = sqlx::query_as::<_, (Uuid, String, String, Uuid)>(
        r#"SELECT p.id, p.name, u.nickname, p.owner_id FROM projects p
           JOIN users u ON u.id = p.owner_id
           WHERE p.share_slug = $1 AND p.visibility = 'link'"#,
    )
    .bind(&slug)
    .fetch_optional(&state.pool)
    .await;

    match row {
        Ok(Some((pid, name, owner_nick, owner_id))) => HttpResponse::Ok().json(json!({
            "project_id": pid.to_string(),
            "name": name,
            "owner_nickname": owner_nick,
            "owner_id": owner_id.to_string(),
            "share_slug": slug,
        })),
        Ok(None) => HttpResponse::NotFound().json(ErrorResponse {
            error: "Invalid or private link".into(),
        }),
        Err(e) => {
            log::error!("project_preview: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

#[derive(Deserialize)]
pub struct JoinSlugBody {
    pub slug: String,
}

pub async fn project_join_link(state: web::Data<AppState>, req: HttpRequest, body: web::Json<JoinSlugBody>) -> impl Responder {
    let (me, pool) = match auth_me_pool(&state, &req).await {
        Ok(x) => x,
        Err(r) => return r,
    };

    let slug = body.slug.trim();
    if slug.is_empty() {
        return HttpResponse::BadRequest().json(ErrorResponse {
            error: "Empty slug".into(),
        });
    }

    let pid: Option<(Uuid, Uuid)> = sqlx::query_as(
        "SELECT id, owner_id FROM projects WHERE share_slug = $1 AND visibility = 'link'",
    )
    .bind(slug)
    .fetch_optional(&pool)
    .await
    .unwrap_or(None);

    let Some((project_id, owner_id)) = pid else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "Invalid link".into(),
        });
    };

    if owner_id == me {
        return HttpResponse::Ok().json(json!({"ok": true, "project_id": project_id.to_string(), "note": "owner"}));
    }

    let ins = sqlx::query(
        r#"INSERT INTO project_link_members (project_id, user_id, role) VALUES ($1, $2, 'viewer')
           ON CONFLICT DO NOTHING"#,
    )
    .bind(project_id)
    .bind(me)
    .execute(&pool)
    .await;

    match ins {
        Ok(_) => HttpResponse::Ok().json(json!({"ok": true, "project_id": project_id.to_string()})),
        Err(e) => {
            log::error!("project_join_link: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}

pub async fn project_enable_share(state: web::Data<AppState>, req: HttpRequest, path: web::Path<Uuid>) -> impl Responder {
    let (me, pool) = match auth_me_pool(&state, &req).await {
        Ok(x) => x,
        Err(r) => return r,
    };
    let project_id = path.into_inner();

    let row: Option<(Uuid,)> = sqlx::query_as("SELECT owner_id FROM projects WHERE id = $1")
        .bind(project_id)
        .fetch_optional(&pool)
        .await
        .unwrap_or(None);
    let Some((owner_id,)) = row else {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: "Project not found".into(),
        });
    };
    if owner_id != me {
        return HttpResponse::Forbidden().json(ErrorResponse {
            error: "Only owner can share".into(),
        });
    }

    let slug = format!("nx{}", Uuid::new_v4().as_simple());
    let res = sqlx::query(
        "UPDATE projects SET visibility = 'link', share_slug = $1, updated_at = now() WHERE id = $2",
    )
    .bind(&slug)
    .bind(project_id)
    .execute(&pool)
    .await;

    match res {
        Ok(_) => HttpResponse::Ok().json(json!({
            "share_slug": slug,
            "visibility": "link",
            "project_id": project_id.to_string(),
        })),
        Err(e) => {
            log::error!("project_enable_share: {}", e);
            HttpResponse::InternalServerError().json(ErrorResponse {
                error: "Database error".into(),
            })
        }
    }
}
