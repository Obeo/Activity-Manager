#!/usr/bin/env bash
set -euo pipefail

MYSQL_BASE="${MYSQL_BASE:-/opt/mysql}"
MYSQL_DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
MYSQL_RUNDIR="${MYSQL_RUNDIR:-/var/run/mysqld}"
MYSQL_SOCKET="${MYSQL_SOCKET:-${MYSQL_RUNDIR}/mysqld.sock}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-taskmgr_db}"
MYSQL_USER="${MYSQL_USER:-taskmgr_user}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"

mkdir -p "${MYSQL_DATADIR}" "${MYSQL_RUNDIR}"
chown -R mysql:mysql "${MYSQL_DATADIR}" "${MYSQL_RUNDIR}"

MYSQL_INSTALL_DB="${MYSQL_BASE}/scripts/mysql_install_db"
MYSQLD_SAFE="${MYSQL_BASE}/bin/mysqld_safe"
MYSQLADMIN="${MYSQL_BASE}/bin/mysqladmin"
MYSQL="${MYSQL_BASE}/bin/mysql"

if [[ ! -d "${MYSQL_DATADIR}/mysql" ]]; then
  echo "[mysql55] Initializing MySQL data directory"
  "${MYSQL_INSTALL_DB}" \
    --basedir="${MYSQL_BASE}" \
    --datadir="${MYSQL_DATADIR}" \
    --user=mysql

  echo "[mysql55] Starting temporary MySQL instance"
  "${MYSQLD_SAFE}" \
    --basedir="${MYSQL_BASE}" \
    --datadir="${MYSQL_DATADIR}" \
    --socket="${MYSQL_SOCKET}" \
    --port="${MYSQL_PORT}" \
    --user=mysql \
    --skip-networking=0 \
    --bind-address=127.0.0.1 \
    >/tmp/mysql-init.log 2>&1 &

  for i in $(seq 1 120); do
    if "${MYSQLADMIN}" --socket="${MYSQL_SOCKET}" --user=root ping --silent >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if ! "${MYSQLADMIN}" --socket="${MYSQL_SOCKET}" --user=root ping --silent >/dev/null 2>&1; then
    cat /tmp/mysql-init.log >&2 || true
    echo "[mysql55] Temporary MySQL instance did not become ready" >&2
    exit 1
  fi

  "${MYSQL}" --socket="${MYSQL_SOCKET}" --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
SQL

  "${MYSQLADMIN}" --socket="${MYSQL_SOCKET}" --user=root shutdown
fi

echo "[mysql55] Starting MySQL 5.5.47 on port ${MYSQL_PORT}"
exec "${MYSQLD_SAFE}" \
  --basedir="${MYSQL_BASE}" \
  --datadir="${MYSQL_DATADIR}" \
  --socket="${MYSQL_SOCKET}" \
  --port="${MYSQL_PORT}" \
  --user=mysql \
  --skip-networking=0 \
  --bind-address=0.0.0.0
