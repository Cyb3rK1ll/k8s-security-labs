#!/bin/bash
set -euo pipefail

DB_DIR=/var/lib/mysql
SOCKET=/var/run/mysqld/mysqld.sock
DEFAULT_PASSWORD="ChanEsgeThisDefaultPassworda9564ebc3289b7a14551baf8ad5ec60a"
DB_PASSWORD="${MISP_DB_PASSWORD:-$DEFAULT_PASSWORD}"
ADMIN_EMAIL="${MISP_ADMIN_EMAIL:-${MISP_admin_email:-admin@admin.test}}"
ADMIN_PASSWORD="${MISP_ADMIN_PASSWORD:-${MISP_admin_pw:-admin}}"
ADMIN_AUTHKEY="${MISP_ADMIN_AUTHKEY:-${MISP_authkey:-$(openssl rand -hex 20)}}"
MYSQLD_PID=0

start_mysql() {
  mysqld_safe --datadir="${DB_DIR}" --socket="${SOCKET}" >/var/log/mysqld_bootstrap.log 2>&1 &
  MYSQLD_PID=$!
  until mysqladmin --socket="${SOCKET}" ping --silent; do
    sleep 2
  done
}

stop_mysql() {
  mysqladmin --socket="${SOCKET}" -uroot shutdown
  wait "${MYSQLD_PID}" || true
  MYSQLD_PID=0
}

run_user_init() {
  echo "[misp] Running Cake user_init to ensure base admin exists..."
  runuser -u www-data -- bash -lc "cd /var/www/MISP/app && ./Console/cake user_init" \
    >/var/log/misp_admin_init.log 2>&1 || true
}

apply_admin_overrides() {
  echo "[misp] Applying admin email/auth key overrides..."
  local password_hash
  # shellcheck disable=SC2016
  password_hash=$(php -r '
    define("DS", DIRECTORY_SEPARATOR);
    define("ROOT", "/var/www/MISP");
    define("APP_DIR", "app");
    define("APP", ROOT . DS . APP_DIR . DS);
    define("WWW_ROOT", APP . "webroot" . DS);
    define("CAKE_CORE_INCLUDE_PATH", APP . "Lib" . DS . "cakephp" . DS . "lib");
    require APP . "Lib/cakephp/lib/Cake/bootstrap.php";
    App::uses("BlowfishPasswordHasher", "Controller/Component/Auth");
    $hasher = new BlowfishPasswordHasher();
    echo $hasher->hash($argv[1]);
  ' -- "${ADMIN_PASSWORD}")

  mysql --socket="${SOCKET}" -uroot misp -e "UPDATE users SET email='${ADMIN_EMAIL}', authkey='${ADMIN_AUTHKEY}', password='${password_hash}', change_pw=0 WHERE id=1;"
}

apply_baseurl() {
  if [ -n "${MISP_baseurl:-}" ]; then
    echo "[misp] Setting MISP.baseurl to ${MISP_baseurl}..."
    runuser -u www-data -- bash -lc "cd /var/www/MISP/app && ./Console/cake Baseurl \"${MISP_baseurl}\"" \
      >>/var/log/misp_admin_init.log 2>&1 || true
  fi
}

apply_admin_configuration() {
  run_user_init
  echo "[misp] Enforcing password policy to allow automation..."
  runuser -u www-data -- bash -lc "cd /var/www/MISP/app && ./Console/cake Admin setSetting \"Security.password_policy_length\" 12" \
    >>/var/log/misp_admin_init.log 2>&1 || true
  apply_admin_overrides
  apply_baseurl
}

initialize_db() {
  echo "[misp] Initializing MariaDB data directory..."
  chown -R mysql:mysql "${DB_DIR}"
  mysql_install_db --user=mysql --datadir="${DB_DIR}" >/dev/null

  start_mysql

  mysql --socket="${SOCKET}" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS misp DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS 'misp'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON misp.* TO 'misp'@'localhost';
FLUSH PRIVILEGES;
SQL

  mysql --socket="${SOCKET}" -uroot misp < /var/www/MISP/INSTALL/MYSQL.sql

  apply_admin_configuration
  stop_mysql
}

if [ ! -d "${DB_DIR}/mysql" ] || [ -z "$(ls -A "${DB_DIR}/mysql" 2>/dev/null)" ]; then
  initialize_db
else
  echo "[misp] Existing database detected, updating admin credentials..."
  start_mysql
  apply_admin_configuration
  stop_mysql
fi

exec /usr/bin/supervisord "$@"
