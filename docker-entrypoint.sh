#!/bin/bash -x

set -e

cat > ~/.my.cnf <<EOF
[client]
user=root
password=$MYSQL_ROOT_PW
protocol=tcp
EOF

# set up master
until mysql -h mysql -e ";" ; do
  echo "waiting for connection to database host 'mysql'..."
  sleep 3
done

mysql -h mysql -e "GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'%' IDENTIFIED BY '$MYSQL_SLAVE_PW';"

if ! mysql -h mysql -e "use ESC4;"; then
  # create bridge user and add permissions
  mysql -h mysql -e "CREATE DATABASE ESC4;GRANT ALL PRIVILEGES ON ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  mysql -h mysql -e "GRANT SELECT ON ESC4.* To 'tableau'@'%' IDENTIFIED BY '$TABLEAUDB_PASSWORD';"  
  # import bridge initial DB
  wget --no-check-certificate -qO import.sql $INITIAL_SQL_URL
  mysql -h mysql ESC4 < import.sql
fi

if ! mysql -h mysql -e "use training_ESC4;"; then
  # create bridge user and add permissions
  mysql -h mysql -e "CREATE DATABASE training_ESC4;GRANT ALL PRIVILEGES ON training_ESC4.* To 'training_rails'@'%' IDENTIFIED BY '$BRIDGEDB_TRAINING_PASSWORD';"
  mysql -h mysql -e "GRANT ALL PRIVILEGES ON training_ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  mysql -h mysql -e "GRANT SELECT ON training_ESC4.* To 'tableau'@'%' IDENTIFIED BY '$TABLEAUDB_PASSWORD';"
  # import bridge initial DB
  wget --no-check-certificate -qO import.sql $INITIAL_SQL_URL
  mysql -h mysql training_ESC4 < import.sql
fi

# set up slave
until mysql -h mysql_backup -e ";" ; do
  echo "waiting for connection to database host 'mysql_backup'..."
  sleep 3
done

if ! mysql -h mysql_backup -e "use ESC4;"; then
  mysql -h mysql_backup -e "STOP SLAVE;CHANGE MASTER TO MASTER_HOST='mysql', MASTER_USER='repl',MASTER_PASSWORD='$MYSQL_SLAVE_PW',MASTER_LOG_POS=4;START SLAVE;"
fi
