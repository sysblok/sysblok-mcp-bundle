# SETUP.md -- скрипт настройки sysblok-mcp-bundle для агента

> Ты -- AI-агент, который выполняет этот файл от имени коллеги-человека.
> Документ написан во втором лице, повелительном наклонении и обращён
> именно к ТЕБЕ. Человек только отвечает на вопросы и подтверждает
> действия по ходу дела -- не пересказывай ему этот файл и не проси
> выполнить шаги вручную самостоятельно.
>
> Если у тебя есть Bash/shell-инструмент: сам этот файл нужно было
> получить через `curl -fsSL <raw-url>`, а не через инструмент,
> суммаризирующий веб-страницы -- ты сейчас будешь записывать его
> содержимое на диск дословно, а суммаризация могла бы его перефразировать
> или обрезать. Если у тебя есть только суммаризирующий web-fetch
> инструмент, попроси его воспроизвести содержимое документа дословно, а
> не описать его.
>
> Всё нужное уже встроено ниже в виде блоков кода. Тебе не понадобятся
> `git clone`, `git`, Node.js, Python или `uv`. Единственное условие --
> Docker, проверяется на шаге 1.

---

## Шаг 1 -- Проверка предварительных условий

Выполни:

```bash
docker --version
docker compose version
```

Если хоть одна команда не сработала или не найдена: остановись здесь.
Скажи человеку установить Docker Desktop (macOS/Windows) или Docker Engine
+ плагин Compose (Linux) и дождись подтверждения, что всё установлено,
прежде чем продолжать. Не действуй на основе предположений -- убедись,
что обе команды реально отрабатывают успешно.

---

## Шаг 2 -- Выбор рабочей директории и создание файлов

Спроси у человека рабочую директорию, по умолчанию `~/sysblok-mcp-bundle/`,
если предпочтений нет. Создай её, затем запиши в неё три файла ниже
дословно, используя блоки кода из этого документа как их точное
содержимое (не перефразируй, не переформатируй и не "улучшай" их -- эти
блоки поддерживаются байт-в-байт идентичными отслеживаемым файлам этого
репозитория через CI, так что всё ниже уже корректно и протестировано):

`docker-compose.yml`:

<!-- BEGIN-SYNC: docker-compose.yml -->
```yaml
name: sysblok-mcp

services:
  planka-mcp:
    image: chmald/planka-mcp:${PLANKA_MCP_VERSION:-latest}
    container_name: sysblok-mcp-planka
    restart: unless-stopped
    environment:
      - MCP_TRANSPORT=sse
      - MCP_PORT=3001
      - PLANKA_BASE_URL=${PLANKA_BASE_URL}
      - PLANKA_API_KEY=${PLANKA_API_KEY}
    ports:
      # только localhost: PLANKA_API_KEY зашит на стороне сервера, а у
      # SSE-эндпоинта нет дополнительной авторизации на уровне запроса --
      # у всех, кто достучится до этого порта, будет полный доступ от
      # имени этого пользователя. Никогда не биндить на 0.0.0.0.
      - "127.0.0.1:3001:3001"

  google-workspace-mcp:
    image: ghcr.io/taylorwilsdon/google_workspace_mcp:${GOOGLE_WORKSPACE_MCP_VERSION:-latest}
    container_name: sysblok-mcp-google
    restart: unless-stopped
    # Не переопределяем command: у образа ENTRYPOINT ["/bin/sh","-c"] и
    # дефолтный CMD -- одна shell-строка вида
    # `uv run main.py --transport streamable-http ${TOOL_TIER:+--tool-tier "$TOOL_TIER"} ...`,
    # которая уже сама подставляет --transport и читает переменные TOOL_TIER
    # и TOOLS. Переопределение command списком ломает это: /bin/sh -c
    # получает наш список как command-string + позиционные параметры, а не
    # как единственный аргумент -c (проверено: контейнер падал в краш-луп с
    # `/bin/sh: 0: Illegal option --`).
    environment:
      - MCP_ENABLE_OAUTH21=true
      - WORKSPACE_MCP_TRANSPORT=streamable-http
      - WORKSPACE_MCP_HOST=0.0.0.0
      - WORKSPACE_MCP_PORT=8000
      - TOOL_TIER=${GOOGLE_WORKSPACE_TOOL_TIER:-core}
      # --tool-tier сам по себе -- горизонтальный срез уровня "core" по ВСЕМ
      # 12 сервисам образа (gmail, calendar, chat, contacts, forms, slides,
      # tasks, search, appscript, ...), а не фильтр по конкретным сервисам.
      # Без TOOLS ниже OAuth consent запросит доступ к Gmail/Calendar/etc.,
      # хотя бандл заявлен как Docs+Sheets+Drive-only.
      - TOOLS=${GOOGLE_WORKSPACE_TOOLS:-docs sheets drive}
      - GOOGLE_OAUTH_CLIENT_ID=${GOOGLE_OAUTH_CLIENT_ID}
      - GOOGLE_OAUTH_CLIENT_SECRET=${GOOGLE_OAUTH_CLIENT_SECRET}
      - GOOGLE_OAUTH_REDIRECT_URI=http://localhost:8000/oauth2callback
      - OAUTHLIB_INSECURE_TRANSPORT=1
      # Образ работает под непривилегированным uid=1000(app), HOME=/home/app --
      # /root закрыт для этого пользователя (0700 root:root), путь /root/...
      # для этого образа непригоден (Permission denied).
      - WORKSPACE_MCP_CREDENTIALS_DIR=/home/app/.google_workspace_mcp/credentials
    ports:
      # только localhost, и это обязательно: браузер стучится напрямую на
      # localhost:8000 для OAuth-редиректа, поэтому порт должен быть
      # опубликован на хосте, а не быть просто адресом во внутренней сети
      # compose.
      - "127.0.0.1:8000:8000"
    volumes:
      # bind mount, а не именованный volume, чтобы SETUP.md/человек могли
      # проверить успешность авторизации простым `ls ./google-credentials`.
      # Не кладём эту директорию под data/ -- если Docker успевает создать
      # bind-mount директорию до первого успешного запуска, она достаётся
      # root, и повторные попытки падают с Permission denied.
      - ./google-credentials:/home/app/.google_workspace_mcp/credentials
```
<!-- END-SYNC: docker-compose.yml -->

`.env.example`:

<!-- BEGIN-SYNC: .env.example -->
```bash
# ==============================================================================
# sysblok-mcp-bundle -- переменные окружения
# Скопируйте этот файл в .env и заполните пропуски. .env добавлен в
# .gitignore и никогда не должен коммититься -- см. раздел "Секреты" в README.md.
# ==============================================================================

# ---- Planka MCP (chmald/planka-mcp) -----------------------------------------

# ОДНОКРАТНО, общая для всех константа: прод-инстанс Planka в sysblok.
PLANKA_BASE_URL=https://board.sysblok.team

# СВОЙ У КАЖДОГО, НО САМОСТОЯТЕЛЬНО НЕ СГЕНЕРИРОВАТЬ: у обычных
# пользователей Planka нет доступа к разделу API Keys в своих настройках --
# это может сделать только администратор через Administration -> Users ->
# (ваш аккаунт) -> Actions -> сгенерировать API Key. Попросите админа
# сгенерировать ключ для вашего аккаунта и прислать его вам -- ключ
# показывается только один раз в момент генерации, потом его не
# восстановить, только перевыпустить новый.
PLANKA_API_KEY=

# Опционально: закрепить конкретный тег образа planka-mcp вместо `latest`.
PLANKA_MCP_VERSION=latest


# ---- WordPress MCP (docdyhr/mcp-wordpress) ----------------------------------
# ПРИМЕЧАНИЕ: WordPress MCP НЕ управляется через docker-compose -- он работает
# только по stdio и запускается по требованию вашим MCP-клиентом (см.
# client-config.example.json). Эти значения всё равно хранятся в .env, чтобы
# SETUP.md мог прочитать их один раз и сразу прописать в конфиг клиента.

# ОДНОКРАТНО, общая для всех константа: адрес сайта WordPress sysblok.
WORDPRESS_SITE_URL=https://sysblok.ru

# СВОЙ У КАЖДОГО, генерируется самостоятельно: wp-admin -> ваш профиль ->
# Application Passwords -> "New Application Password Name" -> Add New.
# Нужна роль Editor или выше. Скопируйте сгенерированный пароль точно как
# показано, включая пробелы. ВАЖНО: пароль содержит пробелы (формат
# `xxxx xxxx xxxx xxxx xxxx xxxx`) -- обязательно берите значение в
# кавычки, иначе большинство инструментов (source, docker compose
# --env-file) обрежут его по первому пробелу или сломают команду.
WORDPRESS_USERNAME=
WORDPRESS_APP_PASSWORD=


# ---- Google Workspace MCP (taylorwilsdon/google_workspace_mcp) -------------

# ОДНОКРАТНО, ПРЕДОСТАВЛЯЕТСЯ АДМИНОМ: общий на всю организацию OAuth Client
# ID/Secret типа "Web application" (НЕ "Desktop app" -- у нас фиксированный
# redirect URI на постоянно работающем контейнере, а не динамический
# loopback-порт нативного приложения). Создаётся один раз в Google Cloud
# Console со scope'ами Docs+Sheets+Drive и зарегистрированным redirect URI
# http://localhost:8000/oauth2callback. ЭТО РЕАЛЬНЫЙ СЕКРЕТ: в отличие от
# Desktop-приложений, Google считает Client Secret Web-приложений
# конфиденциальным. Раздаётся админом отдельным каналом -- НЕ через этот
# репозиторий и НЕ в публичный канал, и никогда не должен попасть в git.
GOOGLE_OAUTH_CLIENT_ID=
GOOGLE_OAUTH_CLIENT_SECRET=

# Какой УРОВЕНЬ инструментов открывать -- но учтите: --tool-tier это
# горизонтальный срез "core"/"extended"/"complete" ПО ВСЕМ 12 сервисам
# образа (gmail, calendar, chat, contacts, forms, slides, tasks, search,
# appscript, docs, sheets, drive), а не переключатель "дай мне только
# Docs+Sheets+Drive". За выбор конкретных сервисов отвечает переменная
# GOOGLE_WORKSPACE_TOOLS ниже -- обе переменные работают вместе.
GOOGLE_WORKSPACE_TOOL_TIER=core

# Какие СЕРВИСЫ открывать -- вот это и есть Docs+Sheets+Drive-only,
# под что рассчитан бандл. Не меняйте, если не уверены, что нужны другие
# сервисы Google Workspace.
GOOGLE_WORKSPACE_TOOLS=docs sheets drive

# Опционально: закрепить конкретный тег образа google_workspace_mcp вместо
# `latest`.
GOOGLE_WORKSPACE_MCP_VERSION=latest
```
<!-- END-SYNC: .env.example -->

`client-config.example.json`:

<!-- BEGIN-SYNC: client-config.example.json -->
```json
{
  "mcpServers": {
    "wordpress": {
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "WORDPRESS_SITE_URL",
        "-e", "WORDPRESS_USERNAME",
        "-e", "WORDPRESS_APP_PASSWORD",
        "docdyhr/mcp-wordpress:latest"
      ],
      "env": {
        "WORDPRESS_SITE_URL": "<будет заполнено SETUP.md из .env>",
        "WORDPRESS_USERNAME": "<будет заполнено SETUP.md из .env>",
        "WORDPRESS_APP_PASSWORD": "<будет заполнено SETUP.md из .env>"
      }
    },
    "planka": {
      "type": "sse",
      "url": "http://127.0.0.1:3001/sse"
    },
    "google-workspace": {
      "type": "http",
      "url": "http://localhost:8000/mcp"
    }
  }
}
```
<!-- END-SYNC: client-config.example.json -->

Обрати внимание: `google-workspace` указывает на `localhost`, а не
`127.0.0.1`, хотя `planka` использует `127.0.0.1` -- это не опечатка. У
Google-сервиса `GOOGLE_OAUTH_REDIRECT_URI` зафиксирован на `localhost`, и
для OAuth 2.1 resource-indicator matching URL клиента должен совпадать по
origin с этим redirect URI буквально (`localhost` и `127.0.0.1` считаются
разными origin, хотя технически один и тот же loopback-адрес). У `planka`
это не имеет значения -- это SSE-сервер без resource-matching.

---

## Шаг 3 -- Создание `.env` из `.env.example`

Скопируй только что записанный `.env.example` в `.env` в той же
директории. `PLANKA_BASE_URL` (`https://board.sysblok.team`) и
`WORDPRESS_SITE_URL` (`https://sysblok.ru`) уже заполнены как
фиксированные константы, общие для всей организации -- спрашивать у
человека здесь нечего.

---

## Шаг 4 -- Application Password для WordPress

Проведи человека через шаги:
1. Зайти на `$WORDPRESS_SITE_URL/wp-admin/`.
2. Перейти в свой профиль (аватарка справа сверху, или `/wp-admin/profile.php`).
3. Прокрутить до раздела "Application Passwords".
4. Ввести имя (например, "sysblok-mcp-bundle"), нажать "Add New Application Password".
5. Скопировать сгенерированный пароль точно как показано, включая пробелы.

Нужна роль Editor или выше. Запиши `WORDPRESS_USERNAME` и
`WORDPRESS_APP_PASSWORD` в `.env`. **Пароль содержит пробелы** (формат
`xxxx xxxx xxxx xxxx xxxx xxxx`) -- обязательно возьми значение в
кавычки: `WORDPRESS_APP_PASSWORD="xxxx xxxx xxxx xxxx xxxx xxxx"`. Без
кавычек значение обрежется по первому пробелу или сломает команду при
чтении файла. Прежде чем идти дальше, проверь, что всё реально работает:

```bash
curl -u "$WORDPRESS_USERNAME:$WORDPRESS_APP_PASSWORD" \
  "$WORDPRESS_SITE_URL/wp-json/wp/v2/users/me"
```

Должен вернуться HTTP 200 с JSON ожидаемого пользователя, а не 401. Если
не сработало -- не гадай, в чём дело, покажи человеку реальную ошибку и
попроси перепроверить, что пароль скопирован верно и взят в кавычки.
Если ошибка стабильно `incorrect_password` даже после аккуратной
перегенерации пароля -- это может быть серверная проблема (nginx не
прокидывает заголовок `Authorization` в PHP-FPM), а не ошибка
пользователя; в этом случае скажи человеку обратиться к администратору
сайта, а не пытаться и дальше перегенерировать пароль.

---

## Шаг 5 -- API-ключ Planka

В отличие от WordPress, здесь нет самостоятельной генерации: у обычных
пользователей Planka нет раздела API Keys в своих настройках -- это
может сделать только администратор, и только через панель
Administration -> Users, выбрав нужного пользователя (даже свой
собственный ключ администратор не может сгенерировать из своего же
профиля -- ему тоже нужно зайти туда через список пользователей).

Спроси у человека, есть ли у него уже ключ, полученный от админа. Если
нет -- скажи ему написать админу с просьбой сгенерировать API-ключ для
его аккаунта в Planka и прислать его. Дождись, пока ключ не будет
получен, прежде чем продолжать -- у тебя нет способа сгенерировать его
самостоятельно.

Запиши `PLANKA_API_KEY` в `.env`. Проверь:

```bash
curl -H "X-Api-Key: $PLANKA_API_KEY" "$PLANKA_BASE_URL/api/users/me"
```

Должен вернуться HTTP 200 с JSON ожидаемого пользователя.

---

## Шаг 6 -- Запуск постоянных сервисов

Спроси у человека `GOOGLE_OAUTH_CLIENT_ID` и `GOOGLE_OAUTH_CLIENT_SECRET`
(предоставляются админом, это общие для всей организации значения --
никогда не придумывай и не угадывай их, спроси человека или скажи ему
спросить админа). Запиши их в `.env`.

Из рабочей директории выполни:

```bash
docker compose up -d
```

**Если `docker compose up` падает с `denied: denied` при попытке
скачать `ghcr.io/taylorwilsdon/google_workspace_mcp`**, хотя образ
публичный: скорее всего на машине человека когда-то раньше был сделан
`docker login ghcr.io` с токеном, который с тех пор протух. Docker в
этом случае не откатывается на анонимный pull -- просто падает.
Почини: `docker logout ghcr.io`, затем повтори `docker compose up -d`.

Убедись, что оба сервиса реально доступны -- не доверяй только статусу
`docker compose ps`, проверь порты напрямую:

```bash
curl -sf -o /dev/null -w "planka-mcp: %{http_code}\n" http://127.0.0.1:3001/sse || echo "planka-mcp: недоступен"
curl -sf -o /dev/null -w "google-workspace-mcp: %{http_code}\n" http://127.0.0.1:8000/mcp || echo "google-workspace-mcp: недоступен"
```

Любой ответ, кроме отказа в соединении (даже 4xx), означает, что сервис
поднят и слушает порт. Не переходи к шагу 7, пока не ответят оба.

Если `google-workspace-mcp` падает с `Permission denied` на путь
`.../google_workspace_mcp/credentials` -- вероятно, директория
`./google-credentials` на хосте уже существует и принадлежит `root`
(Docker создаёт bind-mount директории от root, если их не было до
первого запуска, а первый запуск упал по другой причине раньше, чем
успел туда что-то записать). Почини: `sudo rm -rf ./google-credentials`
(или `sudo chown -R $(whoami) ./google-credentials`), затем `mkdir
./google-credentials` и повтори `docker compose up -d`.

---

## Шаг 7 -- OAuth-авторизация Google

**Авторизация проходит не через ссылку в логах контейнера, а через сам
MCP-клиент** -- это единственный поддерживаемый в текущей версии образа
способ (старый механизм со статичной auth-ссылкой в логах в этой версии
отключён при OAuth 2.1). Порядок действий зависит от клиента; для
Claude Code:

1. Скажи человеку открыть `/mcp` в Claude Code.
2. Выбрать в списке `google-workspace`.
3. Выбрать пункт "Authenticate" (или аналогичный, инициирующий вход).
4. Клиент откроет браузер с экраном согласия Google -- человек проходит
   его под своим личным аккаунтом.

Если клиент -- не Claude Code, скажи человеку поискать в клиенте
аналогичное действие "Authenticate"/"Connect"/"Sign in" рядом с
сервером `google-workspace` -- сам сервер инициативно ссылку не покажет,
инициатива со стороны клиента.

Убедись в успехе, дожидаясь появления файла с креденшелами на хосте, а
не спрашивая "получилось?":

```bash
ls ./google-credentials/
```

Появление файла там -- конкретный, проверяемый признак того, что
авторизация прошла успешно. Если через минуту-две ничего не появилось,
проверь логи контейнера на ошибки (`docker compose logs
google-workspace-mcp`) и убедись, что шаг с "Authenticate" в клиенте
был пройден до конца, а не просто открыт.

**Если ранее уже проходили эту авторизацию с более широким набором
разрешений** (до того, как GOOGLE_WORKSPACE_TOOLS сузил доступ до
Docs+Sheets+Drive) -- сам грант на аккаунте Google останется широким,
пока его не отозвать вручную на
`https://myaccount.google.com/permissions` и не пройти consent заново.

---

## Шаг 8 -- Настройка конфига MCP-клиента

Спроси у человека, каким MCP-клиентом он пользуется (Claude Code, Claude
Desktop или другим). Найди его реальный конфиг-файл для его ОС:

| Клиент | macOS | Windows | Linux |
|---|---|---|---|
| Claude Desktop | `~/Library/Application Support/Claude/claude_desktop_config.json` | `%APPDATA%\Claude\claude_desktop_config.json` | `~/.config/Claude/claude_desktop_config.json` |
| Claude Code | `.mcp.json` в текущей директории проекта, либо `claude mcp add` | так же | так же |

**Прежде чем что-либо записывать**: прочитай файл, если он уже существует.
Покажи человеку точное изменение, которое собираешься сделать -- слияние
трёх записей `mcpServers` из `client-config.example.json` (с
подстановкой значений WordPress из `.env` в блок `env`) в его
существующий конфиг, *не удаляя и не перезаписывая* остальные записи,
которые там уже есть. Обязательно получи явное подтверждение перед
записью -- это реальное изменение файлов самого человека.

Для Claude Code предпочти `claude mcp add-json` (если CLI доступен)
ручному редактированию `.mcp.json` -- это избавляет от ручных ошибок
слияния JSON. Учти также: конфиг, добавленный с `-s local`, привязан к
той рабочей директории проекта, в которой была вызвана команда -- если
интерактивная сессия потом запускается из другой директории, `/mcp` не
увидит добавленный сервер без явной ошибки. Убедись, что команда
выполняется из той же директории, откуда человек обычно запускает
клиента. Также стоит свериться с `claude mcp list` на предмет других
локальных MCP-серверов, уже занимающих порты 3001/8000 -- конфликт порта
тоже проявляется не как явная ошибка, а как молчаливая недоступность.

**Запасной вариант для старых клиентов**: если клиент отвергает записи
`"type": "sse"` или `"type": "http"` (некоторые старые сборки Claude
Desktop понимают только локальные stdio-серверы через `command`/`args`),
скажи человеку, что понадобится установленный Node.js и npx-мост
`mcp-remote` -- например,
`"command": "npx", "args": ["-y", "mcp-remote", "http://127.0.0.1:3001/sse"]`.
Это запасной путь только для устаревших клиентов, а не путь по умолчанию.

---

## Шаг 9 -- Итог

Выведи чек-лист того, что сделано и что ещё осталось:

- [ ] Docker установлен и работает
- [ ] Application Password для WordPress проверен
- [ ] API-ключ Planka проверен
- [ ] Сервисы после `docker compose up -d` доступны
- [ ] Google OAuth пройден через клиент, креденшелы появились в `./google-credentials/`
- [ ] Конфиг MCP-клиента записан (подтверждено человеком)

Напомни человеку про две команды, которые понадобятся позже:

```bash
docker compose up -d    # снова запустить planka-mcp + google-workspace-mcp
docker compose down     # остановить их
```

WordPress-серверу запуск/остановка не нужны -- он работает только на
протяжении каждой MCP-сессии, запускаясь напрямую клиентом.
