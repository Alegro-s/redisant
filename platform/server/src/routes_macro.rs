
macro_rules! po_common_routes {
    ($app:expr) => {
        $app
            .route("/health", web::get().to(health))
            .route("/health", web::head().to(health_head))
            .route("/ready", web::get().to(ready))
            .route("/metrics", web::get().to(observability::metrics_http))
    };
}

macro_rules! po_auth_routes {
    ($app:expr) => {
        $app
            .route("/api/docs/openapi.json", web::get().to(openapi_doc::openapi_json))
            .route("/api/docs", web::get().to(openapi_doc::swagger_ui))
            .route("/register", web::post().to(register))
            .route(
                "/auth/register/verify",
                web::post().to(email_verification::verify_email),
            )
            .route(
                "/auth/register/resend",
                web::post().to(email_verification::resend_verification),
            )
            .route("/login", web::post().to(login))
            .route("/logout", web::post().to(logout))
            .route(
                "/auth/login/challenge-preview",
                web::post().to(auth_challenge::challenge_preview),
            )
            .route("/auth/login/challenge", web::post().to(auth_challenge::challenge_start))
            .route("/auth/login/verify", web::post().to(auth_challenge::challenge_verify))
            .route("/auth/admin/activate", web::post().to(activate_admin_by_key))
            .route("/auth/lynx/activate", web::post().to(activate_nexus_by_key))
            .route("/auth/nexus/activate", web::post().to(activate_nexus_by_key))
            .route("/auth/realms/link", web::post().to(link_realm))
            .route(
                "/auth/challenge/lynx-code",
                web::get().to(auth_challenge::nexus_reveal),
            )
            .route(
                "/auth/challenge/nexus-code",
                web::get().to(auth_challenge::nexus_reveal),
            )
            .route("/auth/vk/start", web::get().to(vk_oauth::vk_start))
            .route("/auth/vk/callback", web::get().to(vk_oauth::vk_callback))
            .route("/auth/introspect", web::get().to(auth_introspect))
            .route("/profile", web::get().to(get_profile))
            .route("/profile", web::put().to(update_profile))
            .route("/profile/avatar", web::post().to(upload_profile_avatar))
            .route("/avatars/{user_id}/{filename}", web::get().to(serve_avatar))
            .route("/admin/registration-status", web::get().to(admin_registration_status))
            .route("/admin/register", web::post().to(admin_register))
            .route("/admin/keys", web::get().to(admin_keys_list))
            .route("/admin/keys", web::post().to(admin_keys_create))
            .route("/admin/login", web::post().to(admin_login))
            .route("/me/roza/quota", web::get().to(roza_cabinet::get_roza_quota))
            .route("/me/roza/consume", web::post().to(roza_cabinet::post_roza_consume))
            .route("/me/roza/billing", web::get().to(billing::get_my_billing))
            .route(
                "/me/roza/billing/checkout",
                web::post().to(billing::post_checkout),
            )
            .route("/auth/desktop/pair/start", web::post().to(desktop_devices::pair_start))
            .route("/auth/desktop/pair/confirm", web::post().to(desktop_devices::pair_confirm))
            .route("/auth/desktop/pair/claim", web::post().to(desktop_devices::pair_claim))
            .route("/auth/token/refresh", web::post().to(desktop_devices::token_refresh))
    };
}

macro_rules! po_waypoint_routes {
    ($app:expr) => {
        $app
            .route("/api/docs/openapi.json", web::get().to(openapi_doc::openapi_json))
            .route("/api/docs", web::get().to(openapi_doc::swagger_ui))
            .route("/profile", web::get().to(get_profile))
            .route("/profile", web::put().to(update_profile))
            .route("/profile/avatar", web::post().to(upload_profile_avatar))
            .route("/avatars/{user_id}/{filename}", web::get().to(serve_avatar))
            .route("/me/workspace", web::get().to(platform::get_workspace))
            .route("/me/workspace", web::put().to(platform::put_workspace))
            .route("/me/ingest", web::post().to(platform::ingest_submit))
            .route("/me/ingest/self-test", web::post().to(platform::ingest_self_test))
            .route("/me/ingest/export", web::get().to(dev_tooling::ingest_export))
            .route("/me/ingest/replay", web::post().to(dev_tooling::ingest_replay))
            .route("/me/repro-bundle", web::get().to(dev_tooling::repro_bundle))
            .route("/me/vk-module", web::get().to(platform::list_vk_modules))
            .route("/me/vk-module", web::post().to(platform::create_vk_module))
            .route("/me/billing", web::get().to(billing::get_my_billing))
            .route("/me/billing/checkout", web::post().to(billing::post_checkout))
            .route(
                "/integrations/billing/webhook",
                web::post().to(billing::stripe_webhook),
            )
            .route(
                "/integrations/billing/yookassa-webhook",
                web::post().to(billing::yookassa_webhook),
            )
            .route("/admin/billing/summary", web::get().to(billing::admin_billing_summary))
            .route("/me/hosting/request", web::post().to(platform::request_hosting))
            .route("/me/hosting", web::get().to(platform::list_my_hosting_requests))
            .route("/admin/hosting-requests", web::get().to(platform::list_hosting_admin))
            .route(
                "/admin/hosting-requests/{id}",
                web::patch().to(platform::patch_hosting_admin),
            )
            .route("/admin/stats", web::get().to(admin_stats))
            .route("/admin/metrics", web::get().to(admin_metrics))
            .route("/admin/users", web::get().to(admin_users))
            .route("/admin/users/{id}", web::put().to(admin_update_user))
            .route("/admin/users/{id}/block", web::post().to(admin_block_user))
            .route("/admin/users/{id}", web::delete().to(admin_delete_user))
            .route("/admin/db/query", web::post().to(admin_db_query))
            .route("/admin/logs", web::get().to(admin_logs))
            .route(
                "/admin/registration-log",
                web::get().to(routes_extra::admin_registration_log),
            )
            .route("/me/db/query", web::post().to(user_db_query))
            .route("/me/baas/schema", web::get().to(baas::get_schema))
            .route("/me/baas/bootstrap", web::get().to(baas::bootstrap))
            .route("/me/baas/sql", web::post().to(baas::post_sql))
            .route("/me/baas/sql/param", web::post().to(baas::post_sql_param))
            .route("/me/baas/tables", web::get().to(baas::list_tables))
            .route("/me/baas/tables", web::post().to(baas::create_table))
            .route("/me/baas/rest/{table}", web::get().to(baas::rest_list))
            .route("/me/baas/rest/{table}", web::post().to(baas::rest_insert))
            .route("/me/baas/rest/{table}/{id}", web::put().to(baas::rest_update))
            .route("/me/baas/rest/{table}/{id}", web::delete().to(baas::rest_delete))
            .route("/me/baas/realtime/ws", web::get().to(wm_baas_realtime::baas_realtime_ws))
            .route("/me/baas/buckets", web::get().to(baas::buckets_list))
            .route("/me/baas/buckets", web::post().to(baas::buckets_create))
            .route(
                "/me/baas/buckets/{bucket}/objects",
                web::put().to(baas::object_put),
            )
            .route(
                "/me/baas/buckets/{bucket}/objects",
                web::get().to(baas::object_get),
            )
            .route("/me/ai/chat", web::post().to(waypoint_ai::deepseek_chat))
            .route("/me/ai/quota", web::get().to(waypoint_cabinet::get_ai_quota))
            .route("/me/vouchers", web::get().to(waypoint_cabinet::list_vouchers))
            .route("/me/vouchers", web::post().to(waypoint_cabinet::create_voucher))
            .route("/me/vouchers/{id}", web::patch().to(waypoint_cabinet::patch_voucher))
            .route("/me/vouchers/{id}", web::delete().to(waypoint_cabinet::delete_voucher))
            .route("/me/shipments", web::get().to(waypoint_cabinet::list_shipments))
            .route("/me/shipments", web::post().to(waypoint_cabinet::create_shipment))
            .route("/me/shipments/{id}", web::patch().to(waypoint_cabinet::patch_shipment))
            .route("/me/shipments/{id}", web::delete().to(waypoint_cabinet::delete_shipment))
            .service(
                web::scope("/waypointmetric/v1")
                    .route("/health", web::get().to(waypoint_metric::health))
                    .route("/baas/schema", web::get().to(baas::get_schema))
                    .route("/baas/bootstrap", web::get().to(baas::bootstrap))
                    .route("/baas/sql", web::post().to(baas::post_sql))
                    .route("/baas/sql/param", web::post().to(baas::post_sql_param))
                    .route("/baas/tables", web::get().to(baas::list_tables))
                    .route("/baas/tables", web::post().to(baas::create_table))
                    .route("/baas/rest/{table}", web::get().to(baas::rest_list))
                    .route("/baas/rest/{table}", web::post().to(baas::rest_insert))
                    .route("/baas/rest/{table}/{id}", web::put().to(baas::rest_update))
                    .route("/baas/rest/{table}/{id}", web::delete().to(baas::rest_delete))
                    .route("/baas/realtime/ws", web::get().to(wm_baas_realtime::baas_realtime_ws))
                    .route("/baas/buckets", web::get().to(baas::buckets_list))
                    .route("/baas/buckets", web::post().to(baas::buckets_create))
                    .route(
                        "/baas/buckets/{bucket}/objects",
                        web::put().to(baas::object_put),
                    )
                    .route(
                        "/baas/buckets/{bucket}/objects",
                        web::get().to(baas::object_get),
                    )
                    .route(
                        "/storage/public/{owner_id}/{bucket}/objects",
                        web::get().to(baas::object_get_public),
                    ),
            )
            .route("/me/metrics", web::get().to(routes_extra::my_metrics))
            .route("/me/metrics/summary", web::get().to(routes_extra::my_metrics_summary))
            .route("/me/waypoint/usage", web::get().to(routes_extra::my_waypoint_usage))
            .route("/me/system-metrics", web::get().to(routes_extra::my_system_metrics))
            .route("/me/logs", web::get().to(routes_extra::my_logs))
            .route("/me/ingest/simulate", web::post().to(routes_extra::ingest_simulate))
            .route("/me/desktop/devices", web::get().to(desktop_devices::list_devices))
            .route("/me/desktop/devices/{id}", web::patch().to(desktop_devices::patch_device))
            .route("/me/desktop/devices/{id}", web::delete().to(desktop_devices::revoke_device))
            .route("/me/desktop/hosts", web::get().to(desktop_devices::list_desktop_hosts))
            .route("/api/waypoint/desktop/heartbeat", web::post().to(desktop_devices::desktop_heartbeat))
            .route("/profile/vk-code", web::get().to(routes_extra::profile_vk_code))
            .route("/integrations/vk/bind", web::post().to(routes_extra::vk_bot_bind))
            .route(
                "/integrations/vk/health",
                web::get().to(routes_extra::vk_integration_health),
            )
            .service(
                web::scope("/api/waypoint")
                    .route("/instances", web::get().to(waypoint::instances::list))
                    .route("/instances", web::post().to(waypoint::instances::create))
                    .route("/instances/{id}", web::get().to(waypoint::instances::get))
                    .route("/instances/{id}", web::put().to(waypoint::instances::update))
                    .route("/instances/{id}", web::delete().to(waypoint::instances::delete))
                    .route("/versions", web::get().to(waypoint::versions::list))
                    .route("/versions", web::post().to(waypoint::versions::create))
                    .route("/jobs", web::get().to(waypoint::jobs::list))
                    .route("/jobs/{id}", web::get().to(waypoint::jobs::get))
                    .route("/jobs", web::post().to(waypoint::jobs::create))
                    .route("/ai/analyze", web::post().to(waypoint::ai::analyze))
                    .route("/api-keys", web::get().to(waypoint::api_keys::list))
                    .route("/api-keys", web::post().to(waypoint::api_keys::create))
                    .route("/api-keys/{id}", web::patch().to(waypoint::api_keys::patch))
                    .route("/api-keys/{id}", web::delete().to(waypoint::api_keys::delete))
                    .route("/ingest", web::post().to(waypoint::ingest::ingest_handler))
                    .route(
                        "/developer-events",
                        web::get().to(waypoint::developer_events::list),
                    )
                    .route("/network-drives", web::get().to(waypoint::network_drives::list))
                    .route("/network-drives", web::post().to(waypoint::network_drives::create))
                    .route(
                        "/network-drives/{id}",
                        web::get().to(waypoint::network_drives::get),
                    )
                    .route(
                        "/network-drives/{id}",
                        web::patch().to(waypoint::network_drives::patch),
                    )
                    .route(
                        "/network-drives/{id}",
                        web::delete().to(waypoint::network_drives::delete),
                    )
                    .route("/vk-bot/pull", web::post().to(waypoint::vk_bot_pull::pull)),
            )
    };
}

macro_rules! po_lynx_routes {
    ($app:expr) => {
        $app
            .route("/api/docs/openapi.json", web::get().to(openapi_doc::openapi_json))
            .route("/api/docs", web::get().to(openapi_doc::swagger_ui))
            .route("/engine/manifest", web::get().to(engine_releases::public_manifest))
            .route("/artifacts/manifest/{slug}", web::get().to(artifact_channels::manifest_by_slug))
            .route("/admin/engine/policy", web::get().to(engine_releases::admin_get_policy))
            .route("/admin/engine/policy", web::put().to(engine_releases::admin_put_policy))
            .route("/profile", web::get().to(get_profile))
            .route("/profile", web::put().to(update_profile))
            .route("/profile/avatar", web::post().to(upload_profile_avatar))
            .route("/projects", web::post().to(create_project))
            .route("/projects", web::get().to(get_projects))
            .route("/projects/{id}/assets", web::post().to(upload_asset))
            .route("/projects/{id}/assets", web::get().to(get_assets))
            .route(
                "/projects/{id}/assets/{asset_id}/content",
                web::put().to(put_project_asset_content),
            )
            .route("/projects/{id}/scenes", web::get().to(project_scenes::list_project_scenes))
            .route(
                "/projects/{id}/scenes/{scene_id}",
                web::get().to(project_scenes::get_project_scene),
            )
            .route(
                "/projects/{id}/scenes/{scene_id}",
                web::put().to(project_scenes::put_project_scene),
            )
            .route("/projects/{id}/share", web::post().to(social::project_enable_share))
            .route("/assets/{id}", web::get().to(download_asset))
            .route("/projects/preview/{slug}", web::get().to(social::project_preview))
            .route("/projects/join-link", web::post().to(social::project_join_link))
            .route("/avatars/{user_id}/{filename}", web::get().to(serve_avatar))
            .route("/users/search", web::get().to(social::users_search))
            .route("/friends", web::get().to(social::friends_list))
            .route("/friends/requests", web::get().to(social::friends_requests_incoming))
            .route("/friends/request", web::post().to(social::friends_request))
            .route("/friends/accept", web::post().to(social::friends_accept))
            .route("/friends/reject", web::post().to(social::friends_reject))
            .route("/me/module-tests", web::get().to(platform::list_module_tests))
            .route("/me/module-tests", web::post().to(platform::create_module_test))
            .route("/me/module-tests/python/upload", web::post().to(python_tests::upload_python_zip_test))
            .route("/me/module-tests/compare", web::get().to(python_tests::compare_module_test_runs))
            .route("/me/module-tests/{id}", web::get().to(python_tests::get_module_test_run))
            .route("/me/module-tests/{id}/logs", web::get().to(python_tests::get_module_test_logs))
            .route(
                "/me/module-tests/{id}/artifact/{name}",
                web::get().to(python_tests::get_module_test_artifact),
            )
            .route(
                "/integrations/agent/heartbeat",
                web::post().to(agent_integration::agent_heartbeat),
            )
            .route("/me/agent/schema", web::get().to(agent_integration::get_agent_schema))
            .route("/me/engine/session", web::post().to(engine_download::create_engine_session))
            .route(
                "/engine/blob/{version}",
                web::get().to(engine_download::download_engine_blob),
            )
            .route(
                "/ws/projects/{project_id}/scenes/{scene_id}",
                web::get().to(scene_ws::scene_ws_handler),
            )
            .route(
                "/ws/projects/{project_id}/studio",
                web::get().to(studio_ws::studio_ws_handler),
            )
            .route(
                "/integrations/lynx-cloud/build-report",
                web::post().to(nexus_cloud_builds::worker_build_report),
            )
            .route(
                "/integrations/nexus-cloud/build-report",
                web::post().to(nexus_cloud_builds::worker_build_report),
            )
            .route(
                "/me/lynx-cloud/projects",
                web::get().to(nexus_cloud::list_projects),
            )
            .route(
                "/me/lynx-cloud/projects",
                web::post().to(nexus_cloud::create_project),
            )
            .route(
                "/me/lynx-cloud/projects/{id}",
                web::get().to(nexus_cloud::get_project),
            )
            .route(
                "/me/lynx-cloud/projects/{id}",
                web::patch().to(nexus_cloud::patch_project),
            )
            .route(
                "/me/lynx-cloud/projects/{id}",
                web::delete().to(nexus_cloud::delete_project),
            )
            .route(
                "/me/lynx-cloud/projects/{id}/builds",
                web::post().to(nexus_cloud_builds::create_build),
            )
            .route(
                "/me/lynx-cloud/projects/{id}/builds",
                web::get().to(nexus_cloud_builds::list_project_builds),
            )
            .route("/me/lynx-cloud/builds", web::get().to(nexus_cloud_builds::list_my_builds))
            .route(
                "/me/nexus-cloud/projects",
                web::get().to(nexus_cloud::list_projects),
            )
            .route(
                "/me/nexus-cloud/projects",
                web::post().to(nexus_cloud::create_project),
            )
            .route(
                "/me/nexus-cloud/projects/{id}",
                web::get().to(nexus_cloud::get_project),
            )
            .route(
                "/me/nexus-cloud/projects/{id}",
                web::patch().to(nexus_cloud::patch_project),
            )
            .route(
                "/me/nexus-cloud/projects/{id}",
                web::delete().to(nexus_cloud::delete_project),
            )
            .route(
                "/me/nexus-cloud/projects/{id}/builds",
                web::post().to(nexus_cloud_builds::create_build),
            )
            .route(
                "/me/nexus-cloud/projects/{id}/builds",
                web::get().to(nexus_cloud_builds::list_project_builds),
            )
            .route("/me/nexus-cloud/builds", web::get().to(nexus_cloud_builds::list_my_builds))
            .route("/admin/projects", web::get().to(admin_projects))
            .route("/admin/projects/{id}", web::delete().to(admin_delete_project))
            .route("/admin/assets", web::get().to(admin_assets))
            .route("/admin/assets/{id}", web::delete().to(admin_delete_asset))
            .route("/chat/users", web::get().to(routes_extra::chat_users))
            .route("/chat/e2ee/key", web::put().to(routes_extra::e2ee_set_public_key))
            .route(
                "/chat/e2ee/key/{user_id}",
                web::get().to(routes_extra::e2ee_get_public_key),
            )
            .route("/chat/send", web::post().to(routes_extra::chat_send))
            .route("/chat/block", web::post().to(routes_extra::chat_block_user))
            .route(
                "/chat/block/{user_id}",
                web::delete().to(routes_extra::chat_unblock_user),
            )
            .route("/chat/recent", web::get().to(routes_extra::chat_recent_preview))
            .route("/chat/messages/{user_id}", web::get().to(routes_extra::chat_history))
    };
}

macro_rules! po_configure_routes {
    ($app:expr, $svc:expr) => {{
        let app = po_common_routes!($app);
        match $svc {
            service::PoService::Auth => po_auth_routes!(app),
            service::PoService::Waypoint => po_waypoint_routes!(app),
            service::PoService::Lynx => po_lynx_routes!(app),
        }
    }};
}
