# MiokoApp

Неофициальный Flutter-клиент для mioko.ai (Android, тест на Samsung Galaxy S23+). Пользователь учится Flutter и git на этом проекте — объясняй по-русски и простыми словами.

## Как работаем

- После правок запускай только `flutter analyze lib`. **Сборку и запуск пользователь делает сам** — `flutter build`/`run`/`install` не запускай без просьбы. В конце скажи, хватит ли `r` (hot reload) или нужен `R`/пересборка: новые пакеты, ассеты, маршруты (роутер живёт в провайдере) и нативные изменения требуют `R` или пересборки.
- Git-команды пользователь любит вводить сам — объясни шаги, а не делай за него, если не попросил. Сообщения коммитов на русском.
- `*.har` в `.gitignore`: в HAR лежат токены. Никогда не выводи заголовки `Authorization`/`cookie`, коды и токены из них.

## Окружение (Arch Linux)

- Flutter 3.50: импорт `package:material_ui/material_ui.dart`, **не** `flutter/material.dart`.
- Провайдер обрывает Maven Central → `~/.gradle/init.d/maven-mirror.init.gradle.kts` перенаправляет на зеркало Google (текст в README). Без него Gradle не собирается.
- `MainActivity` наследует `FlutterFragmentActivity` — иначе `image_picker` падает с channel-error.

## Архитектура и правила

- `lib/features/<раздел>/{models,providers,screens}`, общее — `lib/core` и `lib/shared`. Состояние — Riverpod 2 (`FutureProvider`, `StateNotifierProvider`), кодогенерация не используется.
- После любого `await` в `ConsumerStatefulWidget` — `if (!mounted) return;` до `ref`/`context`.
- **Цвета только из `Theme.of(context).colorScheme`.** Палитры сайта — `MiokoPalette` в `core/theme/app_theme.dart` (тёмная/светлая из CSS сайта, акцент `#28C1EA`); Monet — отдельный тумблер поверх любой из них. Никаких `Colors.white`/`Color(0x…)` для текста и фонов, кроме текста поверх картинок/градиентов.
- Навигация: в `ShellRoute` с плавающей нижней панелью (`shared/widgets/main_shell.dart`, `extendBody: true`) только 4 вкладки — home, explore, chats, profile. Остальные экраны — верхнеуровневые маршруты на весь экран. У вкладок снизу нужен отступ `MediaQuery.paddingOf(context).bottom`, иначе контент уходит под панель.
- Ошибки загрузки — `ErrorView` (`shared/widgets/error_view.dart`, котик; сам различает «нет интернета»). Текст ошибки сервера — `apiErrorMessage()` (сервер шлёт `{"error": "…"}` по-русски).
- Аватары персонажей/историй/чатов — `MediaAvatar` + `AvatarImage` (картинка в `avatar.image_url`, градиент `c1→c2`, `pos` = CSS object-position).
- Hero-теги должны быть уникальны на экране (`'<экран>-<лента>-<id>'`): один персонаж бывает в нескольких лентах.
- Новые провайдеры с данными аккаунта добавляй в `AuthNotifier._invalidateUserData()`, иначе после смены аккаунта останутся старые данные.

## API mioko.ai

Документации нет. База `https://api.mioko.ai`, `Authorization: Bearer <token>`. Список используемых запросов — в README («Как устроено API»).

Как узнавать новое:
1. Пользователь снимает HAR в `~/Загрузки` (`mioko.ai.har`, `mioko.ai_pay.har`) — разбирай `python3 -I`, скрывая секреты.
2. Логика сайта (порядок жанров, оплата, вход) лежит в его Next.js-бандлах `https://mioko.ai/_next/static/chunks/*.js` — качай в scratchpad и ищи python-скриптом (`ugrep` падает на длинных строках).
3. Многие GET работают без токена — можно проверять `curl`-ом.

Делай «как на сайте» (пользователь это ценит), но не показывай данные, которые сайт скрывает (`notes` — инструкции для нейросети).

## Оплата (CloudPayments)

`features/pearls/payment/cloudpayments_page.dart` повторяет сайт: официальный виджет в WebView (`baseUrl` = `https://mioko.ai/mioko-pearls`), `pay("charge", …)` с `publicId`/тарифами из `GET /api/payments/config`, `accountId` = id пользователя, `data = {kind: "wave"|"pearls", itemId, orderNumber}`. Номер заказа `W-`/`P-` + 9 символов Crockford Base32 + контрольный символ mod 37 — сервер его проверяет. Менять осторожно: ошибка = деньги списаны, покупка не начислена.

## Вход

- Почта: `POST /api/auth/login`.
- Яндекс: WebView `api.mioko.ai/api/auth/yandex?m=<secret 32 hex>` → перехват редиректа на `mioko.ai/auth/complete#code=…` → `POST /api/auth/session/exchange {code, secret}`. Сервер пускает только аккаунты, где Яндекс уже привязан.
- **Google не сделан.** Вход Google в WebView запрещён Google (403 disallowed_useragent) — **не подменять User-Agent**. Нативный `/api/auth/app/google` требует регистрации нашего пакета в проекте Mioko — недоступно. Остался план: Custom Tab на `/api/auth/google?m=<secret>&app=1` → сервер ведёт на `https://mioko.ai/auth/complete-app#code=…`; домен по `assetlinks.json` принадлежит `ai.mioko.app`, поэтому пользователь должен один раз вручную включить «Открывать по умолчанию → mioko.ai» для нашего приложения (не сработает, если стоит официальное приложение). Сейчас кнопка Google показывает окно «скоро появится».

## Что дальше

- Экран чата: открытие, сообщения, отправка (сайт стримит ответ через SSE — `sendMessageStream` в бандле).
- Кнопка «Начать чат» на странице персонажа — нужен запрос создания чата.
- Фильтры поиска — названия параметров неизвестны (угаданные `genres`/`settings`/`moods`/`traits` игнорируются), нужен URL с сайта.
- Редактирование персон — `PATCH /api/personas/<id>` (из бандла, тело не проверено).
- Лорбуки, этап 2: создание/редактирование (`POST /api/lorebooks`, `PUT /api/lorebooks/<id>`, формат тела — снять HAR). Сейчас есть просмотр, поиск и подключение к «все мои чаты»/персоне (`features/lorebooks`). Места подключения на сайте: `mine/me`, `persona/<pid>`, `chat/<id>` (1, «Лорбук чата» — когда будет экран чата), `character`/`story` (карточки автора).
- Вкладки «Персонажи»/«Истории» в профиле — данные есть в `GET /api/authors/<id>`.
- Скриншоты для README (блок закомментирован, ждёт `docs/screenshots/*.png`).
