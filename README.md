# sysblok-mcp-bundle

Локальные MCP-серверы (Model Context Protocol) для WordPress, Planka и
Google Docs/Sheets/Drive, чтобы любой человек в команде мог направить
Claude Code, Claude Desktop или другого MCP-совместимого агента на
инструменты sysblok. Единственное предварительное условие -- Docker, без
Node.js, Python или git.

**Не читайте это как руководство по ручной настройке.** Скажите любому
AI-агенту:

> Скачай `https://raw.githubusercontent.com/sysblok/sysblok-mcp-bundle/v0.2.1/SETUP.md`
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
| Planka | [`chmald/planka-mcp`](https://github.com/chmald/planka-mcp) | SSE | через `docker compose` (постоянно работающий) |
| Google Docs/Sheets/Drive | [`taylorwilsdon/google_workspace_mcp`](https://github.com/taylorwilsdon/google_workspace_mcp) | streamable-HTTP + OAuth 2.1 | через `docker compose` (постоянно работающий) |

## Предварительные условия

| Инструмент | Комментарий |
|---|---|
| Docker | Desktop (macOS/Windows) или Engine + плагин Compose (Linux). Больше ничего не нужно. |

## Структура репозитория

- `SETUP.md` -- собственно путь онбординга, рассчитанный на выполнение
  агентом от имени человека.
- `docker-compose.yml` / `.env.example` -- отслеживаемые, канонические
  файлы для сервисов Planka и Google. `SETUP.md` встраивает
  байт-в-байт идентичные копии этих файлов (проверяется через CI, см.
  `scripts/check-setup-sync.sh`), так что агенту не нужен второй запрос,
  чтобы их создать.
- `client-config.example.json` -- блок `mcpServers` для всех трёх
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
