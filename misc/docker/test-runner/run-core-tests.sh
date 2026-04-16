#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace}"
M2_DIR="${M2_DIR:-/m2/repository}"
TP_MODE="${TP_MODE:-build}"
TEST_MODULE="${TEST_MODULE:-core/tests/org.activitymgr.core.tests}"
DB_HOST="${DB_HOST:-}"
DB_PORT="${DB_PORT:-}"
DB_WAIT_SECONDS="${DB_WAIT_SECONDS:-120}"

cd "${WORKSPACE_DIR}"

if [[ -n "${DB_HOST}" && -n "${DB_PORT}" ]]; then
  echo "[0/3] Waiting for database ${DB_HOST}:${DB_PORT}"
  for ((i=0; i<DB_WAIT_SECONDS; i++)); do
    if bash -c "</dev/tcp/${DB_HOST}/${DB_PORT}" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  if ! bash -c "</dev/tcp/${DB_HOST}/${DB_PORT}" >/dev/null 2>&1; then
    echo "Database ${DB_HOST}:${DB_PORT} did not become reachable within ${DB_WAIT_SECONDS}s" >&2
    exit 1
  fi
fi

echo "[1/3] Building target platform artifact (${TP_MODE})"
mvn -B \
  -Dmaven.repo.local="${M2_DIR}" \
  -Dgit.dirty=ignore \
  -Dtp.mode="${TP_MODE}" \
  -f parent/tpd/pom.xml \
  install

echo "[2/3] Installing application bundles in local Maven repository"
mvn -B \
  -Dmaven.repo.local="${M2_DIR}" \
  -Dgit.dirty=ignore \
  -Dtycho.releng.skip=true \
  -Dmaven.test.skip=true \
  -f pom.xml \
  install

echo "[3/3] Running Tycho tests (${TEST_MODULE})"
mvn -B \
  -Dmaven.repo.local="${M2_DIR}" \
  -Dgit.dirty=ignore \
  -Dtycho.releng.skip=true \
  -DfailIfNoTests=false \
  -pl "${TEST_MODULE}" \
  -am \
  -f pom.xml \
  verify \
  "${@}"
