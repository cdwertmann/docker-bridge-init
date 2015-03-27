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

if ! mysql -h mysql -e "use ESC4;"; then
  # create bridge user and add permissions
  mysql -h mysql -e "CREATE DATABASE ESC4;GRANT ALL PRIVILEGES ON ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  # import bridge initial DB
  wget --no-check-certificate -qO- $INITIAL_SQL_URL | mysql -h mysql ESC4
fi

# set up slave
until mysql -h mysql_backup -e ";" ; do
  echo "waiting for connection to database host 'mysql_backup'..."
  sleep 3
done

pos=`mysql -h mysql <<EOF | grep bin | awk '{print $2;}'
GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'mysql-backup.novalocal.node.dc1.consul' IDENTIFIED BY '$MYSQL_SLAVE_PW';
FLUSH TABLES WITH READ LOCK;SHOW MASTER STATUS;UNLOCK TABLES;
EOF`

mysql -h mysql_backup <<EOF
STOP SLAVE FOR CHANNEL '';
RESET SLAVE;
CHANGE MASTER TO MASTER_HOST='mysql.novalocal.node.dc1.consul', MASTER_USER='repl',MASTER_PASSWORD='$MYSQL_SLAVE_PW',MASTER_LOG_POS=$pos;
START SLAVE;
EOF
