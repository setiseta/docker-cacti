#!/bin/bash

if [ ! -d /data/config ]; then
	mkdir /data/config
	chown nobody:users /data/config
fi
if [ ! -d /data/rra ]; then
	mkdir /data/rra
	chown nobody:users /data/rra
fi
if [ ! -d /data/logs ]; then
	mkdir /data/logs
fi
if [ -d /var/log/cacti ]; then
	rm -rf /var/log/cacti
	ln -s /data/logs /var/log/cacti
fi
if [ ! -f /var/log/cacti/cacti.log ]; then
	touch /var/log/cacti/cacti.log
fi

chown nobody:users /data/logs -R

DB_TYPE=${DB_TYPE:-}
DB_HOST=${DB_HOST:-}
DB_PORT=${DB_PORT:-}
DB_NAME=${DB_NAME:-}
DB_USER=${DB_USER:-}
DB_PASS=${DB_PASS:-}

if [ -n "${MYSQL_PORT_3306_TCP_ADDR}" ]; then
	DB_TYPE=${DB_TYPE:-mysql}
	DB_HOST=${DB_HOST:-${MYSQL_PORT_3306_TCP_ADDR}}
	DB_PORT=${DB_PORT:-${MYSQL_PORT_3306_TCP_PORT}}
	# support for linked sameersbn/mysql image
	DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
	DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
	DB_NAME=${DB_NAME:-${MYSQL_ENV_DB_NAME}}
	# support for linked orchardup/mysql and enturylink/mysql image
	# also supports official mysql image
	DB_USER=${DB_USER:-${MYSQL_ENV_MYSQL_USER}}
	DB_PASS=${DB_PASS:-${MYSQL_ENV_MYSQL_PASSWORD}}
	DB_NAME=${DB_NAME:-${MYSQL_ENV_MYSQL_DATABASE}}
fi

if [ -z "${DB_HOST}" ]; then
  echo "ERROR: "
  echo "  Please configure the database connection."
  echo "  Cannot continue without a database. Aborting..."
  exit 1
fi

# use default port number if it is still not set
case "${DB_TYPE}" in
  mysql) DB_PORT=${DB_PORT:-3306} ;;
  *)
    echo "ERROR: "
    echo "  Please specify the database type in use via the DB_TYPE configuration option."
    echo "  Accepted value \"mysql\". Aborting..."
    exit 1
    ;;
esac

# set default user and database
DB_USER=${DB_USER:-root}
DB_NAME=${DB_NAME:-cacti}

sed -i -e 's/\$database_default = ".*";/\$database_default = "'$DB_NAME'";/g' /etc/cacti/debian.php
sed -i -e 's/DB_Database.*/DB_Database\t'$DB_NAME'/g' /etc/cacti/spine.conf
sed -i -e 's/\$database_hostname = ".*";/\$database_hostname = "'$DB_HOST'";/g' /etc/cacti/debian.php
sed -i -e 's/DB_Host.*/DB_Host\t\t'$DB_HOST'/g' /etc/cacti/spine.conf
sed -i -e 's/\$database_username = ".*";/\$database_username = "'$DB_USER'";/g' /etc/cacti/debian.php
sed -i -e 's/DB_User.*/DB_User\t\t'$DB_USER'/g' /etc/cacti/spine.conf
sed -i -e 's/\$database_password = ".*";/\$database_password = "'$DB_PASS'";/g' /etc/cacti/debian.php
sed -i -e 's/DB_Pass.*/DB_Pass\t\t'$DB_PASS'/g' /etc/cacti/spine.conf

sed -i -e 's/\/\/$url_path = "\/cacti\/";/$url_path = "\/";/g' /etc/cacti/debian.php
sed -i -e "s/\$config\[\"rra_path\"\] = '.*';/\$config\[\"rra_path\"\] = '\/data\/rra';/g" /usr/share/cacti/site/include/global.php

sed -i 's/memory_limit = 128/memory_limit = 512/g' /etc/php5/*/php.ini

prog="mysqladmin -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_PASS:+-p$DB_PASS} status"
timeout=60
printf "Waiting for database server to accept connections"
while ! ${prog} >/dev/null 2>&1
do
	timeout=$(expr $timeout - 1)
	if [ $timeout -eq 0 ]; then
		printf "\nCould not connect to database server. Aborting...\n"
		exit 1
	fi
	printf "."
	sleep 1
done

QUERY="SELECT count(*) FROM information_schema.tables WHERE table_schema = '${DB_NAME}';"
COUNT=$(mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_PASS:+-p$DB_PASS} -ss -e "${QUERY}")
if [ -z "${COUNT}" -o ${COUNT} -eq 0 ]; then
	echo "Setting up cacti for firstrun."
	mysql -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER} ${DB_PASS:+-p$DB_PASS} ${DB_NAME} < /usr/share/cacti/conf_templates/cacti.sql
fi