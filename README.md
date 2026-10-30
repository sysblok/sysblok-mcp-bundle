# sysblok-mcp-bundle

Локальные MCP-серверы (Model Context Protocol) для WordPress, Planka,
Google Docs/Sheets/Drive и GitHub, чтобы любой человек в команде мог
направить Claude Code, Claude Desktop или другого MCP-совместимого
агента на инструменты sysblok. Основное предварительное условие --
Docker, без Python или git. Node.js нужен дополнительно только
пользователям Claude Desktop (см. `SETUP.md`, шаг 7) -- его локальный
конфиг не поддерживает удалённые (HTTP) серверы напрямую.

GitHub здесь нужен точечно: чтобы агент сам заводил issue в репозитории
скиллов [`sysblok/sysblok-ai`](https://github.com/sysblok/sysblok-ai) --
на это рассчитаны скиллы вроде `report-skill-problem`. Секрета он не
требует: авторизация проходит через OAuth в браузере, см. `SETUP.md`,
шаг 9.

**Не читайте это как руководство по ручной настройке.** Скажите любому
AI-агенту:

> Скачай `https://raw.githubusercontent.com/sysblok/sysblok-mcp-bundle/v0.4.0/SETUP.md`
> и следуй инструкциям из этого файла.

и отвечайте на его вопросы по ходу настройки. Полный пошаговый процесс,
который выполняет агент, описан в [`SETUP.md`](./SETUP.md).

> Для мейнтейнеров: ссылка выше закреплена за релизным тегом, а не за
> `main`, чтобы инструкции не могли поменяться между "сказали запустить"
> и "реально запустили". Обновляйте её здесь после каждого релиза.

## Что входит в бандл

| Сервер | Апстрим | Транспорт | Как запускается |
|---|---|---|---|
| WordPress | [`docdyhr/mcp-wordpress`](https://github.com/docdyhr/mcp-wordpress) | только stdio | по требованию через `docker run`, запускается вашим MCP-клиентом |
| Planka | [`sysblok/planka-mcp`](https://github.com/sysblok/planka-mcp) (форк [`omnicoreos/planka-mcp`](https://github.com/omnicoreos/planka-mcp)), образ `ghcr.io/sysblok/planka-mcp` | только stdio | по требованию через `docker run`, запускается вашим MCP-клиентом |
| Google Docs/Sheets/Drive | [`taylorwilsdon/google_workspace_mcp`](https://github.com/taylorwilsdon/google_workspace_mcp) | streamable-HTTP + OAuth 2.1 | через `docker compose` (постоянно работающий) |
| GitHub | [`github/github-mcp-server`](https://github.com/github/github-mcp-server) | только stdio | по требованию через `docker run`, запускается вашим MCP-клиентом |

Planka работает через наш форк, а не через апстрим: старый
`chmald/planka-mcp` отдавал доску «СБъ. Редакция» (больше 1300 карточек)
целиком и падал, а список карточек молча обрезал на 50. Агент видит
только читающие инструменты (`PLANKA_READ_ONLY=true`): ни один скилл в
`sysblok/sysblok-ai` в Planka не пишет.

**Уже настроили бандл раньше, с `chmald/planka-mcp`?** Попросите агента
выполнить раздел "Обновление: переход с `chmald/planka-mcp` на
`sysblok/planka-mcp`" в конце `SETUP.md`. Коротко: `docker compose up -d
--remove-orphans`, заменить запись `planka` в конфиге клиента,
перезапустить клиента.

## Предварительные условия

| Инструмент | Комментарий |
|---|---|
| Docker | Desktop (macOS/Windows) или Engine + плагин Compose (Linux). |
| Node.js | Только для Claude Desktop: его конфиг понимает лишь stdio-серверы, `google-workspace` там нужно подключать через npx-мост `mcp-remote` -- см. `SETUP.md`, шаг 7. Остальные три сервера и так stdio, им мост не нужен. Claude Code и другим клиентам, понимающим HTTP напрямую, не нужен. |

## Структура репозитория

- `SETUP.md` -- собственно путь онбординга, рассчитанный на выполнение
  агентом от имени человека.
- `docker-compose.yml` / `.env.example` -- отслеживаемые, канонические
  файлы: compose-сервис Google и переменные окружения всех серверов. `SETUP.md` встраивает
  байт-в-байт идентичные копии этих файлов (проверяется через CI, см.
  `scripts/check-setup-sync.sh`), так что агенту не нужен второй запрос,
  чтобы их создать.
- `client-config.example.json` -- блок `mcpServers` для всех четырёх
  серверов, в том виде, в каком `SETUP.md` встраивает его в ваш реальный
  конфиг MCP-клиента.

## Секреты

Файл `.env` никогда не коммитится. `.gitignore` блокирует `.env` и
`data/` (там через bind mount оседают персональные OAuth-токены Google
каждого пользователя). Общий на всю организацию Google OAuth Client
ID/Secret хранится в локальном `.env` каждого участника команды и
раздаётся админом отдельным каналом -- подробности о том, что
заполняется каждым лично, а что предоставляется админом, см. в
`.env.example`.

GitHub -- единственный сервер в бандле, который не добавляет в `.env`
ни одного секрета: в официальный образ зашито зарегистрированное
OAuth-приложение, и авторизация проходит в браузере. Токен при этом
живёт только в памяти контейнера, поэтому после перезапуска
MCP-клиента авторизацию нужно пройти заново.

## Лицензия

MIT -- см. [`LICENSE`](./LICENSE).

## Для мейнтейнеров репозитория

Если правите `docker-compose.yml`, `.env.example` или
`client-config.example.json` -- обновите соответствующий блок в
`SETUP.md` в том же PR. CI (`scripts/check-setup-sync.sh`) завалит сборку
при расхождении -- прогоните его локально перед пушем:

```bash
./scripts/check-setup-sync.sh
```
