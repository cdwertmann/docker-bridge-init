#!/bin/bash -x
set -e

# set up master
until mysql -e ";" ; do
  echo "waiting for connection to database host 'mysql'..."
  sleep 3
done

mysql -e "GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'%' IDENTIFIED BY '$MYSQL_SLAVE_PW';"

if ! mysql -e "use ESC4;"; then
  # create bridge user and add permissions
  mysql -e "CREATE DATABASE ESC4;GRANT ALL PRIVILEGES ON ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  # import bridge initial DB
  wget --no-check-certificate -qO import.sql $INITIAL_SQL_URL
  mysql -f ESC4 < import.sql
  # create tableau user and set permissions
  mysql -N -s -r -e "SELECT CONCAT(\"GRANT SELECT ON ESC4.\", table_name, \" TO tableau@'%' IDENTIFIED BY '$TABLEAUDB_PASSWORD';\") FROM information_schema.TABLES WHERE table_schema = \"ESC4\" AND table_name <> \"jobs\" AND table_name <> \"old_jobs\";" > /tmp/sql
  mysql < /tmp/sql
  # Reset Master replication
  mysql -e "RESET MASTER;"
fi

if ! mysql -e "use training_ESC4;"; then
  # create bridge user and add permissions
  mysql -e "CREATE DATABASE training_ESC4;GRANT ALL PRIVILEGES ON training_ESC4.* To 'training_rails'@'%' IDENTIFIED BY '$BRIDGEDB_TRAINING_PASSWORD';"
  mysql -e "GRANT ALL PRIVILEGES ON training_ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  # import bridge initial DB
  wget --no-check-certificate -qO import.sql $INITIAL_SQL_URL
  mysql -f training_ESC4 < import.sql
  # create tableau user and set permissions
  mysql -N -s -r -e "SELECT CONCAT(\"GRANT SELECT ON training_ESC4.\", table_name, \" TO tableau@'%' IDENTIFIED BY '$TABLEAUDB_PASSWORD';\") FROM information_schema.TABLES WHERE table_schema = \"training_ESC4\" AND table_name <> \"jobs\" AND table_name <> \"old_jobs\";" > /tmp/sql
  mysql < /tmp/sql
fi

# set up slave
until mysql -h mysql_backup -e ";" ; do
  echo "waiting for connection to database host 'mysql_backup'..."
  sleep 3
done

if ! mysql -h $MYSQL_SLAVE_HOST -e "use ESC4;"; then
  mysql -h $MYSQL_SLAVE_HOST -e "STOP SLAVE;RESET MASTER;RESET SLAVE;CHANGE MASTER TO MASTER_HOST='mysql', MASTER_USER='repl',MASTER_PASSWORD='$MYSQL_SLAVE_PW',MASTER_LOG_FILE='master-bin.000001',MASTER_LOG_POS=4;START SLAVE;"
fi
