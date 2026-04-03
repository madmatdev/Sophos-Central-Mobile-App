#!/bin/bash
set -e

STATE_FILE="/app/state/sophos-session.json"
MODE="${1:-auto}"

# ── Functions ─────────────────────────────────────────────────────────
start_vnc() {
    echo "🖥️  Starting virtual display + VNC..."
    export DISPLAY=:99
    Xvfb :99 -screen 0 1440x900x24 -ac &
    sleep 1
    fluxbox &
    x11vnc -display :99 -forever -nopw -shared -rfbport 5900 &
    sleep 1
    # noVNC web proxy (browser-accessible VNC)
    websockify --web /opt/novnc 6080 localhost:5900 &
    sleep 1
    echo "✅ noVNC ready at http://localhost:6080"
}

stop_vnc() {
    pkill -f "Xvfb :99" 2>/dev/null || true
    pkill -f fluxbox 2>/dev/null || true
    pkill -f x11vnc 2>/dev/null || true
    pkill -f websockify 2>/dev/null || true
}

run_login() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  🔐 Sophos Central Login Required                       ║"
    echo "║                                                          ║"
    echo "║  Open your browser to:                                   ║"
    echo "║    http://localhost:6080                                  ║"
    echo "║                                                          ║"
    echo "║  A Chrome window will open with the Sophos login page.   ║"
    echo "║  Complete login + 2FA, then come back here and           ║"
    echo "║  press Enter.                                            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    
    start_vnc
    
    # Launch Chrome via Playwright for login
    export DISPLAY=:99
    node login.mjs
    
    echo "🔒 Session saved. Stopping VNC..."
    stop_vnc
}

run_server() {
    echo ""
    echo "🎭 Starting Sophos Playwright Backend..."
    echo "   API: http://localhost:18870"
    echo "   Health: http://localhost:18870/health"
    echo ""
    exec node server.mjs
}

# ── Main ──────────────────────────────────────────────────────────────

case "$MODE" in
    login)
        # Force login mode
        run_login
        ;;
    server)
        # Force server mode (headless, no VNC)
        run_server
        ;;
    auto|*)
        # Auto: login if no session, then start server
        if [ ! -f "$STATE_FILE" ]; then
            echo "⚠️  No saved session found. Starting login flow..."
            run_login
        else
            echo "✅ Saved session found."
        fi
        
        # Start server with VNC available for re-login
        start_vnc
        echo ""
        echo "╔══════════════════════════════════════════════════════════╗"
        echo "║  🎭 Sophos Playwright Backend Running                   ║"
        echo "║                                                          ║"
        echo "║  API:    http://localhost:18870                          ║"
        echo "║  noVNC:  http://localhost:6080  (for re-login if needed) ║"
        echo "╚══════════════════════════════════════════════════════════╝"
        echo ""
        exec node server.mjs
        ;;
esac
