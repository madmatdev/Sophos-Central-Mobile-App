FROM node:22-slim

# Install Chrome, VNC, noVNC for headed login
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget gnupg ca-certificates fonts-liberation \
    xvfb x11vnc fluxbox websockify \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.tar.gz -O /tmp/novnc.tar.gz \
    && tar xzf /tmp/novnc.tar.gz -C /opt \
    && mv /opt/noVNC-1.5.0 /opt/novnc \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html \
    && rm /tmp/novnc.tar.gz

WORKDIR /app

# Install dependencies
COPY package.json ./
RUN npm install --omit=dev && npx playwright install chromium

# Copy app
COPY server.mjs login.mjs entrypoint.sh ./
RUN chmod +x entrypoint.sh

# Session state persisted via volume
RUN mkdir -p /app/state

# Ports: 18870 = API, 6080 = noVNC for login
EXPOSE 18870 6080

VOLUME ["/app/state"]

ENTRYPOINT ["./entrypoint.sh"]
