#!/usr/bin/env bash
set -eux
APP_DIR=/opt/app
sudo systemctl stop app || true
sudo mkdir -p $APP_DIR
sudo rsync -av --delete . $APP_DIR/
sudo chown -R appuser:appuser $APP_DIR
sudo -u appuser /opt/app/venv/bin/pip install -r $APP_DIR/requirements.txt
sudo systemctl daemon-reload
sudo systemctl start app
sudo systemctl status app --no-pager