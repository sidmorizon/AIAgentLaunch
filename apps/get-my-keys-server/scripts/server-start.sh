#!/usr/bin/env bash
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_FILE="${LOCK_FILE:-/tmp/get-my-keys-start.lock}"
GIT_REMOTE="${GIT_REMOTE:-origin}"
GIT_BRANCH="${GIT_BRANCH:-main}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-3721}"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

if command -v flock >/dev/null 2>&1; then
  exec 9>"${LOCK_FILE}"
  if ! flock -n 9; then
    log "another startup process is running, aborting"
    exit 1
  fi
fi

cd "${APP_DIR}"

if ! git diff --quiet --ignore-submodules --; then
  log "working tree has local changes; refuse to pull to avoid merge conflicts"
  exit 1
fi

log "pulling latest code from ${GIT_REMOTE}/${GIT_BRANCH}"
git fetch --prune "${GIT_REMOTE}"
git checkout "${GIT_BRANCH}"
git pull --ff-only "${GIT_REMOTE}" "${GIT_BRANCH}"

log "installing dependencies"
npm ci --include=dev --no-audit --no-fund

log "building project"
npm run build

log "starting service on ${HOST}:${PORT}"
export NODE_ENV=production
exec npm run start -- --hostname "${HOST}" --port "${PORT}"
