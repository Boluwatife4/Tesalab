#!/usr/bin/env bash
set -eux

APP_DIR=/opt/app
VENVDIR=/opt/app/venv

# Ensure dirs and ownership
sudo mkdir -p $APP_DIR
sudo rsync -av --delete . $APP_DIR/
sudo chown -R appuser:appuser $APP_DIR

# Ensure venv exists (create if missing)
if [ ! -d "$VENVDIR" ]; then
  sudo -u appuser python3 -m venv "$VENVDIR"
fi

# Install/upgrade deps into the venv on every deploy
sudo $VENVDIR/bin/pip install --upgrade pip
sudo $VENVDIR/bin/pip install -r $APP_DIR/requirements.txt

# Restart the app
sudo systemctl daemon-reload
sudo systemctl restart app
sudo systemctl status app --no-pager
