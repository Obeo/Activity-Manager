#!/usr/bin/env bash
set -euo pipefail

DB_BASE="${DB_BASE:-/usr}"
DB_DATADIR="${DB_DATADIR:-/var/lib/mysql}"
DB_RUNDIR="${DB_RUNDIR:-/run/mysqld}"
DB_SOCKET="${DB_SOCKET:-${DB_RUNDIR}/mysqld.sock}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-taskmgr_db}"
DB_USER="${DB_USER:-taskmgr_user}"
DB_PASSWORD="${DB_PASSWORD:-secret}"
DB_INIT_MARKER="${DB_INIT_MARKER:-${DB_DATADIR}/.activitymgr_initialized}"

mkdir -p "${DB_DATADIR}" "${DB_RUNDIR}"
chown -R mysql:mysql "${DB_DATADIR}" "${DB_RUNDIR}"

MARIADB_INSTALL_DB="/usr/bin/mariadb-install-db"
MYSQLD_SAFE="/usr/bin/mysqld_safe"
MARIADB_ADMIN="/usr/bin/mariadb-admin"
MARIADB="/usr/bin/mariadb"

if [[ ! -d "${DB_DATADIR}/mysql" ]]; then
  echo "[mariadb12] Initializing MariaDB data directory"
  "${MARIADB_INSTALL_DB}" \
    --basedir="${DB_BASE}" \
    --datadir="${DB_DATADIR}" \
    --user=mysql
fi

if [[ ! -f "${DB_INIT_MARKER}" ]]; then
  echo "[mariadb12] Starting temporary MariaDB instance"
  "${MYSQLD_SAFE}" \
    --basedir="${DB_BASE}" \
    --datadir="${DB_DATADIR}" \
    --socket="${DB_SOCKET}" \
    --port="${DB_PORT}" \
    --user=mysql \
    --skip-networking=0 \
    --bind-address=127.0.0.1 \
    >/tmp/mariadb-init.log 2>&1 &

  for i in $(seq 1 120); do
    if "${MARIADB_ADMIN}" --socket="${DB_SOCKET}" --user=root ping --silent >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! "${MARIADB_ADMIN}" --socket="${DB_SOCKET}" --user=root ping --silent >/dev/null 2>&1; then
    cat /tmp/mariadb-init.log >&2 || true
    echo "[mariadb12] Temporary MariaDB instance did not become ready" >&2
    exit 1
  fi

  "${MARIADB}" --socket="${DB_SOCKET}" --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL

  "${MARIADB_ADMIN}" --socket="${DB_SOCKET}" --user=root shutdown
  touch "${DB_INIT_MARKER}"
  chown mysql:mysql "${DB_INIT_MARKER}"
fi

echo "[mariadb12] Starting Debian 12 MariaDB on port ${DB_PORT}"
exec "${MYSQLD_SAFE}" \
  --basedir="${DB_BASE}" \
  --datadir="${DB_DATADIR}" \
  --socket="${DB_SOCKET}" \
  --port="${DB_PORT}" \
  --user=mysql \
  --skip-networking=0 \
  --bind-address=0.0.0.0
