<div align="center">

# MiokoApp

**Нативный клиент для [mioko.ai](https://mioko.ai) на Flutter**

Персонажи, истории и чаты с AI-компаньонами — в удобном приложении для Android и iOS

<br>

![Flutter](https://img.shields.io/badge/Flutter-3.50-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.14-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=apple&logoColor=white)

![Riverpod](https://img.shields.io/badge/state-Riverpod-28C1EA?style=flat-square)
![go_router](https://img.shields.io/badge/navigation-go__router-28C1EA?style=flat-square)
![Material 3](https://img.shields.io/badge/design-Material%203%20%2B%20Monet-28C1EA?style=flat-square)
![Status](https://img.shields.io/badge/status-в%20разработке-F090B4?style=flat-square)

</div>

> [!NOTE]
> Это **неофициальное** приложение. Оно не связано с командой Mioko и работает через тот же публичный API, что и сайт. Все персонажи, истории и платежи — на стороне mioko.ai.

<!--
## Скриншоты

Положи PNG в docs/screenshots/ и раскомментируй блок.

<div align="center">
  <img src="docs/screenshots/home.png"    width="200" alt="Главная">
  <img src="docs/screenshots/item.png"    width="200" alt="Персонаж">
  <img src="docs/screenshots/search.png"  width="200" alt="Поиск">
  <img src="docs/screenshots/pearls.png"  width="200" alt="Тарифы и жемчужины">
</div>
-->

## Содержание

- [Возможности](#возможности)
- [Дизайн](#дизайн)
- [Стек](#стек)
- [Структура проекта](#структура-проекта)
- [Запуск](#запуск)
- [Как устроено API](#как-устроено-api)

---

## Возможности

### Каталог и поиск
- **Главная** — популярные авторы, ленты «Популярное» и «Новинки»
- **Каталог** — секции по жанрам в том же порядке, что на сайте, с перемешиванием при обновлении
- **Поиск** — по персонажам и историям, с подгрузкой при прокрутке и счётчиком найденного
- **Страница персонажа или истории** — большая обложка, теги, характер, внешность, предыстория, автор и живые счётчики

### Аккаунт
- **Вход** по email и паролю, токен хранится в защищённом хранилище системы
- **Профиль** — аватар, статистика, баланс жемчужин и статус Wave
- **Редактирование профиля** — имя, ник, описание и загрузка фото с камеры или из галереи
- **Персоны** — создание с аватаром, удаление свайпом, лимит как на сайте
- **Лорбуки** — поиск опубликованных, страница лорбука с записями, подключение «для всех чатов» и к персоне

### Тарифы и жемчужины
- Тарифы Mioko Wave и пакеты жемчужин — цены приходят с сервера
- **Оплата прямо в приложении** через официальный виджет CloudPayments: карта, СБП, T‑Pay
- Баланс обновляется сам, когда покупка зачислена

### Настройки
- Светлая и тёмная тема в цветах сайта, отдельный переключатель **Monet**
- Ссылки на сообщество Mioko в Telegram и ВКонтакте

---

## Дизайн

Без Monet обе темы повторяют палитру сайта — цвета взяты прямо из его CSS.

| | Тёмная | Светлая |
|---|---|---|
| **Акцент** | ![](https://img.shields.io/badge/%2328C1EA-28C1EA?style=flat-square) | ![](https://img.shields.io/badge/%2328C1EA-28C1EA?style=flat-square) |
| **Фон** | ![](https://img.shields.io/badge/%23010D19-010D19?style=flat-square) | ![](https://img.shields.io/badge/%23F2F5FA-F2F5FA?style=flat-square) |
| **Карточки** | ![](https://img.shields.io/badge/%23061626-061626?style=flat-square) | ![](https://img.shields.io/badge/%23FFFFFF-FFFFFF?style=flat-square) |
| **Рамки** | ![](https://img.shields.io/badge/%23192738-192738?style=flat-square) | ![](https://img.shields.io/badge/%23E6EAED-E6EAED?style=flat-square) |
| **Основной текст** | ![](https://img.shields.io/badge/%23E8F0F8-E8F0F8?style=flat-square) | ![](https://img.shields.io/badge/%2321325A-21325A?style=flat-square) |
| **Вторичный текст** | ![](https://img.shields.io/badge/%239FB3C8-9FB3C8?style=flat-square) | ![](https://img.shields.io/badge/%236C86A3-6C86A3?style=flat-square) |

**Monet** на Android 12+ берёт цвета из обоев системы и работает с любой из двух тем.

### Из чего складывается ощущение
- **Плавающая нижняя панель** — капсула с размытием фона; у активного раздела иконка и подпись
- **Обложка перелетает** из карточки на страницу персонажа и сворачивается в шапку при прокрутке
- **Карточки отзываются** на нажатие лёгким «проседанием» и вибрацией
- **Ролевой текст** оформлен как на сайте: *действия* курсивом, `{{user}}` заменяется на твоё имя
- **Аватары** без картинки рисуются фирменным градиентом с буквой, а картинки плавно проявляются поверх
- Все цвета берутся из темы — ни одного «зашитого» белого текста на светлом фоне

---

## Стек

| Задача | Пакет |
|---|---|
| Состояние | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) |
| Навигация | [go_router](https://pub.dev/packages/go_router) |
| HTTP | [dio](https://pub.dev/packages/dio) |
| Токен | [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) |
| Настройки | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Monet | [dynamic_color](https://pub.dev/packages/dynamic_color) |
| Иконки и логотипы | [flutter_svg](https://pub.dev/packages/flutter_svg) |
| Фото | [image_picker](https://pub.dev/packages/image_picker) |
| Ссылки | [url_launcher](https://pub.dev/packages/url_launcher) |
| Оплата | [webview_flutter](https://pub.dev/packages/webview_flutter) + виджет CloudPayments |

---

## Структура проекта

```
lib/
├── core/                 # общее для всего приложения
│   ├── api/              #   Dio-клиент, токен, ошибки, загрузка картинок
│   ├── router/           #   маршруты и переходы
│   ├── theme/            #   палитра сайта, темы, Monet
│   └── utils/            #   форматирование, ссылки
├── features/             # экраны по разделам
│   ├── auth/             #   вход
│   ├── home/             #   главная
│   ├── explore/          #   каталог
│   ├── search/           #   поиск
│   ├── catalog/          #   модели каталога и страница персонажа
│   ├── chat/             #   список чатов
│   ├── profile/          #   профиль и редактирование
│   ├── personas/         #   персоны
│   ├── pearls/           #   тарифы, жемчужины, оплата
│   └── settings/         #   настройки
└── shared/               # общие виджеты: аватары, панель, иконки
```

Каждый раздел устроен одинаково: `models/` → `providers/` → `screens/`.

---

## Запуск

**Нужно:** Flutter 3.50+, Android SDK, JDK 17, для iOS — Xcode.

```bash
git clone https://github.com/MikeTheEngeneer/MiokoApp.git
cd MiokoApp
flutter pub get
flutter run
```

<details>
<summary><b>Сборка падает на загрузке зависимостей Gradle</b></summary>

<br>

Если провайдер обрывает соединения с Maven Central, перенаправь Gradle на зеркало Google. Создай `~/.gradle/init.d/maven-mirror.init.gradle.kts`:

```kotlin
val centralMirror = "https://maven-central.storage-download.googleapis.com/maven2/"

fun RepositoryHandler.redirectCentral() {
    all {
        if (this is MavenArtifactRepository) {
            val u = url.toString()
            if (u.startsWith("https://repo.maven.apache.org") || u.startsWith("https://repo1.maven.org")) {
                setUrl(centralMirror)
            }
        }
    }
}

beforeSettings {
    pluginManagement.repositories.google()
    pluginManagement.repositories.maven(centralMirror) { name = "CentralMirror" }
    pluginManagement.repositories.gradlePluginPortal()
    pluginManagement.repositories.redirectCentral()
    dependencyResolutionManagement.repositories.redirectCentral()
}

allprojects {
    buildscript.repositories.redirectCentral()
    repositories.redirectCentral()
}
```

</details>

<details>
<summary><b>Добавил пакет — а приложение его не видит</b></summary>

<br>

Новые плагины, картинки и маршруты горячая перезагрузка (`r`) не подхватывает. Нужен перезапуск (`R`) или пересборка.

</details>

---

## Как устроено API

Базовый адрес — `https://api.mioko.ai`, авторизация — заголовок `Authorization: Bearer <токен>`.

<details>
<summary><b>Используемые запросы</b></summary>

<br>

| Раздел | Запрос |
|---|---|
| Вход | `POST /api/auth/login` |
| Способы входа | `GET /api/auth/methods` · `POST /api/auth/unlink` (`{method}`) · привязка: `/api/auth/yandex?link=1&m=…` с cookie `mk_token` |
| Профиль | `GET /api/auth/me` · `PUT /api/auth/me` |
| Статистика | `GET /api/authors/<id>` |
| Загрузка фото | `POST /api/images/upload` |
| Главная | `GET /api/catalog?sort=hot\|new` · `GET /api/catalog/authors` |
| Каталог | `GET /api/catalog/sections?genres=…&seed=…` |
| Поиск | `GET /api/catalog?q=…&sort=random&seed=…&cursor=…` · `GET /api/catalog/facets?q=…` |
| Персонаж / история | `GET /api/characters/<id>` · `GET /api/stories/<id>` |
| Чаты | `GET /api/chats` · `POST /api/chats` (`{characterId}` \| `{storyId}`) · `DELETE /api/chats/<id>` · `GET /api/chats/tide-status` |
| Переписка | `GET /api/chats/<id>/messages?limit=&before=` · `POST …/messages` (`{content}`, ответ — SSE) · `POST …/regenerate` (SSE) · `GET …/stream` (SSE) · `POST …/messages/<mid>/variant?from=<mid>` (`{index}`) |
| Персоны | `GET` · `POST /api/personas` · `DELETE /api/personas/<id>` |
| Уведомления | `GET` · `PUT /api/notifications/prefs` (`{<ключ>: bool}`) |
| Баланс и тарифы | `GET /api/payments/me` · `GET /api/payments/config` |
| Лорбуки | `GET /api/lorebooks/mine` · `GET /api/lorebooks/public?q=…&before=…` · `GET /api/lorebooks/<id>` · `GET /api/lorebooks/<id>/targets` |
| Подключение лорбука | `GET` · `POST /api/lorebooks/places/<mine\|persona>/<me\|id персоны>` (`{lorebook}`) · `DELETE …/<id лорбука>` |

</details>

<details>
<summary><b>Как работает оплата</b></summary>

<br>

Приложение повторяет то, что делает сайт: генерирует номер заказа (`P-` или `W-`, 9 символов Crockford Base32 и контрольный символ) и открывает официальный виджет CloudPayments с тем же товаром и id аккаунта. Данные карты вводятся в форме CloudPayments — приложение их не видит. Покупку зачисляет сервер Mioko, когда CloudPayments сообщает ему об оплате.

</details>

---

<div align="center">
<sub>Сделано <a href="https://github.com/MikeTheEngeneer">MikeTheEngeneer</a> · платформа — <a href="https://t.me/mioko_ai">Mioko</a></sub>
</div>
