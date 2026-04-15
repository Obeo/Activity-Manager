#!/usr/bin/env bash
set -euo pipefail

MYSQL_BASE="${MYSQL_BASE:-/usr}"
MYSQL_DATADIR="${MYSQL_DATADIR:-/var/lib/mysql}"
MYSQL_RUNDIR="${MYSQL_RUNDIR:-/var/run/mysqld}"
MYSQL_SOCKET="${MYSQL_SOCKET:-${MYSQL_RUNDIR}/mysqld.sock}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_DATABASE="${MYSQL_DATABASE:-taskmgr_db}"
MYSQL_USER="${MYSQL_USER:-taskmgr_user}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_INIT_MARKER="${MYSQL_INIT_MARKER:-${MYSQL_DATADIR}/.activitymgr_initialized}"

mkdir -p "${MYSQL_DATADIR}" "${MYSQL_RUNDIR}"
chown -R mysql:mysql "${MYSQL_DATADIR}" "${MYSQL_RUNDIR}"

MYSQL_INSTALL_DB="/usr/bin/mysql_install_db"
MYSQLD_SAFE="/usr/bin/mysqld_safe"
MYSQLADMIN="/usr/bin/mysqladmin"
MYSQL="/usr/bin/mysql"

if [[ ! -d "${MYSQL_DATADIR}/mysql" ]]; then
  echo "[mysql-jessie] Initializing MySQL data directory"
  "${MYSQL_INSTALL_DB}" \
    --basedir="${MYSQL_BASE}" \
    --datadir="${MYSQL_DATADIR}" \
    --user=mysql
fi

if [[ ! -f "${MYSQL_INIT_MARKER}" ]]; then
  echo "[mysql-jessie] Starting temporary MySQL instance"
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
    echo "[mysql-jessie] Temporary MySQL instance did not become ready" >&2
    exit 1
  fi

  "${MYSQL}" --socket="${MYSQL_SOCKET}" --user=root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
FLUSH PRIVILEGES;
SQL

  "${MYSQLADMIN}" --socket="${MYSQL_SOCKET}" --user=root shutdown
  touch "${MYSQL_INIT_MARKER}"
  chown mysql:mysql "${MYSQL_INIT_MARKER}"
fi

echo "[mysql-jessie] Starting repository MySQL on port ${MYSQL_PORT}"
exec "${MYSQLD_SAFE}" \
  --basedir="${MYSQL_BASE}" \
  --datadir="${MYSQL_DATADIR}" \
  --socket="${MYSQL_SOCKET}" \
  --port="${MYSQL_PORT}" \
  --user=mysql \
  --skip-networking=0 \
  --bind-address=0.0.0.0
