
use sqlx::PgPool;
use uuid::Uuid;

pub async fn user_can_read_project(
    pool: &PgPool,
    user_id: Option<Uuid>,
    project_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let row: Option<(Uuid, String)> = sqlx::query_as(
        "SELECT owner_id, visibility FROM projects WHERE id = $1",
    )
    .bind(project_id)
    .fetch_optional(pool)
    .await?;

    let Some((owner_id, visibility)) = row else {
        return Ok(false);
    };

    if visibility == "public" {
        return Ok(true);
    }

    let Some(uid) = user_id else {
        return Ok(false);
    };

    if owner_id == uid {
        return Ok(true);
    }

    if visibility == "link" {
        let ok: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM project_link_members WHERE project_id = $1 AND user_id = $2)",
        )
        .bind(project_id)
        .bind(uid)
        .fetch_one(pool)
        .await?;
        return Ok(ok);
    }

    Ok(false)
}

pub async fn user_can_write_project(
    pool: &PgPool,
    user_id: Uuid,
    project_id: Uuid,
) -> Result<bool, sqlx::Error> {
    let row: Option<(Uuid,)> =
        sqlx::query_as("SELECT owner_id FROM projects WHERE id = $1")
            .bind(project_id)
            .fetch_optional(pool)
            .await?;
    if let Some((owner_id,)) = row {
        if owner_id == user_id {
            return Ok(true);
        }
    } else {
        return Ok(false);
    }
    let role: Option<String> = sqlx::query_scalar(
        "SELECT role FROM project_link_members WHERE project_id = $1 AND user_id = $2",
    )
    .bind(project_id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?;
    Ok(matches!(role.as_deref(), Some("editor")))
}
