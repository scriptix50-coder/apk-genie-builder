# GitHub Actions Build Worker

Ця директорія містить скрипти для реальної збірки Android APK/AAB на GitHub Actions.
Workflow: [`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml).

## Як це працює

1. Користувач у платформі натискає **Зібрати APK** або **Зібрати AAB** — у таблицю `builds`
   додається запис зі статусом `queued`.
2. GitHub Actions виконується за розкладом (кожні 5 хв) або вручну через
   **Actions → Build APK Worker → Run workflow**.
3. Воркер викликає `POST /api/public/builds/next` — платформа атомарно віддає
   наступну збірку з черги та переводить її у стан `running`.
4. Скрипт `worker/generate-android-project.sh` створює мінімальний Android-
   проєкт із назвою та `package_name` користувача.
5. `./gradlew assembleRelease` збирає `.apk`, а `./gradlew bundleRelease` збирає `.aab`.
6. Готовий APK/AAB завантажується в приватне сховище через
   `POST /api/public/builds/{id}/artifact`; статус оновлюється на `success` і
   генерується тимчасове посилання (7 днів).
7. У разі помилки — `POST /api/public/builds/{id}/status` з логами.

## Налаштування (одноразово)

У репозиторії GitHub → **Settings → Secrets and variables → Actions** додайте:

| Ім'я                  | Значення                                                              |
| --------------------- | --------------------------------------------------------------------- |
| `BUILD_WORKER_SECRET` | Секрет `BUILD_WORKER_SECRET` з бекенду (той самий, що в Lovable).     |
| `LOVABLE_API_BASE`    | Базовий URL опублікованого застосунку, напр. `https://project--<id>.lovable.app` |

Для миттєвого запуску worker після натискання **Зібрати APK/AAB** додайте runtime secrets у бекенді застосунку:

| Ім'я                   | Значення                                      |
| ---------------------- | --------------------------------------------- |
| `GITHUB_ACTIONS_TOKEN` | Fine-grained GitHub token з правом Actions write |
| `GITHUB_OWNER`         | Власник репозиторію                           |
| `GITHUB_REPO`          | Назва репозиторію                             |
| `GITHUB_REF`           | Гілка для запуску, наприклад `main`           |

> `BUILD_WORKER_SECRET` вже згенеровано на бекенді. Оскільки згенеровані значення
> не показуються, скиньте його через **update_secret** у чаті Lovable, збережіть
> нове значення та вставте той самий рядок у GitHub.

## Локальне тестування воркера

```bash
export APP_NAME="Демо застосунок"
export PACKAGE_NAME="app.demo.generated"
bash worker/generate-android-project.sh /tmp/android-app
cd /tmp/android-app && ./gradlew assembleRelease
cd /tmp/android-app && ./gradlew bundleRelease
```

## Розширення

- Замінити генератор на повноцінний Android-шаблон, що читає `projects.spec`
  (екрани, ресурси, іконки) і формує реальний UI.
- Додати підпис production-ключем: перенести keystore у GitHub Secret та
  налаштувати `signingConfigs.release` замість `debug`.
- Замість cron polling — тригер `workflow_dispatch` через `repository_dispatch`
  з бекенду одразу після `startBuild`.
