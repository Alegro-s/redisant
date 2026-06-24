# AVITO Hackathon messenger

## Работает ли на том же VPS?

**По умолчанию — нет.** Проект хакатона AVITO **не входит** в репозиторий `Alegro-s/redisant` (monorepo PO/redik).

| Что | Статус |
|-----|--------|
| Lynx Hub / Cloud / API | В репозитории, деплой через `server-deploy-lynx-admin.sh` |
| Waypoint Club / Metric | В репозитории |
| TSPUT (tsput_profile) | В репозитории (`tsput_profile/`) |
| **AVITO messenger** | Отдельный проект (у вас: `Учёба/Хакатоны/AVITO`), **не задеплоен** автоматически |

Ранее была заглушка `avito-messenger/` в monorepo — она **удалена**. Деплой `WITH_AVITO` из `deploy-all-products.sh` тоже убран.

## Как подключить AVITO на тот же сервер

1. Скопируйте проект на VPS, например:
   ```bash
   # с вашего ПК
   scp -r "d:/Учёба/Хакатоны/AVITO" root@72.56.244.26:/opt/waypoint/avito-messenger
   ```

2. Добавьте nginx `location` и systemd/docker по README проекта AVITO.

3. Либо положите код в monorepo:
   ```bash
   PO/avito-messenger/   # и свой deploy/server-update.sh
   ```

## Проверка на VPS

```bash
# AVITO не в git — ищем только если вы сами положили:
ls -la /opt/waypoint/avito-messenger 2>/dev/null || echo "AVITO not deployed"
docker ps | grep -i avito || echo "no AVITO container"
```

**Итог:** вопрос «работает ли тот же AVITO» — **нет, пока вы отдельно не развернули мессенджер хакатона**. Lynx и AVITO — разные продукты на одном VPS только если вы настроите оба вручную.
