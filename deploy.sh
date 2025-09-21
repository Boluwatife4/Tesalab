#!/usr/bin/env bash
set -eux

APP_DIR=/opt/app
VENVDIR=/opt/app/venv
WEB_ROOT=/opt/app/website_files

# Make sure required packages are present (safe to re-run)
sudo apt-get update -y
sudo apt-get install -y python3-venv python3-pip nginx rsync

# Ensure app user exists
id appuser >/dev/null 2>&1 || sudo useradd -m -s /bin/bash appuser

# Sync repository to APP_DIR
sudo mkdir -p "$APP_DIR"
sudo rsync -av --delete . "$APP_DIR/"
sudo chown -R appuser:appuser "$APP_DIR"

# --- Python app kept for /api endpoints (optional) ---
if [ ! -d "$VENVDIR" ]; then
  sudo -u appuser python3 -m venv "$VENVDIR"
fi
if [ -f "$APP_DIR/requirements.txt" ]; then
  sudo "$VENVDIR/bin/pip" install --upgrade pip
  sudo "$VENVDIR/bin/pip" install -r "$APP_DIR/requirements.txt"
fi

# systemd unit (create once)
if [ ! -f /etc/systemd/system/app.service ]; then
  sudo tee /etc/systemd/system/app.service >/dev/null <<'UNIT'
[Unit]
Description=Gunicorn App (/api)
After=network.target

[Service]
User=appuser
Group=appuser
WorkingDirectory=/opt/app
Environment=PATH=/opt/app/venv/bin
ExecStart=/opt/app/venv/bin/gunicorn -w 2 -b 127.0.0.1:8000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
UNIT
  sudo systemctl daemon-reload
  sudo systemctl enable app
fi

# --- Nginx serves static site at / ---
# Uses website_files as the document root and proxies /api to Flask (optional)
sudo tee /etc/nginx/sites-available/app >/dev/null <<'NGX'
server {
    listen 80 default_server;
    server_name _;

    root /opt/app/website_files;
    index index.html;

    # Static site
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Optional: backend API proxied to Gunicorn
    location /api/ {
        proxy_pass         http://127.0.0.1:8000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
    }
}
NGX
sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/default

# Restart services
sudo systemctl restart app || true     # won't fail if app isn't used yet
sudo systemctl restart nginx

# Quick local checks (non-fatal)
curl -I http://127.0.0.1/        || true
curl -I http://127.0.0.1/api/    || true
