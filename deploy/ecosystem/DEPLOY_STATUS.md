# Статус автоматизации (2026-05-17)

## Сделано локально

- [x] Исправлен порядок миграции `nexus_cloud_build_jobs` (переименована в `20260420140000_...`).
- [x] `RUN_MIGRATIONS=1` только на auth-api; waypoint/lynx не гоняют миграции повторно.
- [x] Docker: Postgres + auth-api — **все миграции применены**, сервер слушает `:8090`.
- [x] Экспорт в `D:\PO\_github_export\` (8 репозиториев).
- [x] Скрипты: `prepare-github-repos.ps1`, `push-github-repos.ps1`, `db-migrate.ps1`.

## Нужны данные от вас (агент не может без них)

| Шаг | Блокер |
|-----|--------|
| Push на GitHub | Нет `gh` CLI и нет `GITHUB_TOKEN` в среде |
| VPS deploy | SSH `root@72.56.244.26` — Permission denied (publickey) |
| certbot / SMTP prod | Нужны пароли SMTP и доступ на сервер |

### Push на GitHub (вы или дайте токен)

```powershell
cd d:\PO\deploy\ecosystem\scripts
.\push-github-repos.ps1 -GitHubUser YOUR_GITHUB_LOGIN -Token ghp_xxxxxxxx
```

### VPS (после push)

1. Скопируйте на сервер: `repos.env`, `smtp.env`, `nginx/waypoint-ecosystem.conf`
2. Добавьте SSH-ключ: `ssh-copy-id root@72.56.244.26`
3. `bash server-wipe-legacy.sh && bash server-reset-and-deploy.sh`
