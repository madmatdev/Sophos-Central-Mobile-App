# Sophos Central Playwright Backend

Headless browser automation for Sophos Central features the API doesn't support:
Live Discover, threat graphs, policy management, screenshots.

## Quick Start

```bash
# Build and start
docker compose up -d

# First run: complete the login
# 1. Open http://localhost:6080 in your browser (noVNC)
# 2. You'll see a Chrome window with the Sophos Central login
# 3. Log in with your credentials + MS Authenticator 2FA
# 4. Once you see the Sophos Central dashboard, run:
docker attach sophos-playwright
# Press Enter to save the session, then Ctrl+P Ctrl+Q to detach
```

The session is saved to `./state/sophos-session.json` and persists across restarts.

## Re-Login (when session expires)

```bash
docker compose exec sophos-playwright node login.mjs
# Then use noVNC at http://localhost:6080 to complete 2FA
```

## API Endpoints

All endpoints require `X-Playwright-Secret` header (default: `sophos-pw-2026`).

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Server status + session state |
| GET | `/api/session/status` | Check if Sophos Central session is active |
| POST | `/api/screenshot` | Capture any Sophos Central page as PNG |
| POST | `/api/live-discover` | Run Live Discover SQL queries |
| POST | `/api/threat-graph` | Get threat graph data for a case/alert |
| GET | `/api/policies` | List policy health check scores |

## Configuration

Set via environment variables or `.env` file:

| Variable | Default | Description |
|----------|---------|-------------|
| `PLAYWRIGHT_SECRET` | `sophos-pw-2026` | Auth header value |
| `PORT` | `18870` | API port |

## Requirements

- Docker & Docker Compose
- Works on Mac, Windows (WSL2), and Linux
- No Chrome/Node/Playwright installation needed
