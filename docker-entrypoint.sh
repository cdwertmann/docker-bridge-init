#!/bin/bash -x

set -e

cat > ~/.my.cnf <<EOF
[client]
user=root
password=$MYSQL_ROOT_PW
protocol=tcp
EOF

# set up master
until mysql -h mysql.service.consul -e ";" ; do
  echo "waiting for connection to database host 'mysql'..."
  sleep 3
done

if ! mysql -h mysql.service.consul -e "use ESC4;"; then
  # create bridge user and add permissions
  mysql -h mysql.service.consul -e "CREATE DATABASE ESC4;GRANT ALL PRIVILEGES ON ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';"
  # import bridge initial DB
  curl $INITIAL_SQL_URL | mysql -h mysql.service.consul ESC4
fi

# set up slave
until mysql -h mysql_backup.service.consul -e ";" ; do
  echo "waiting for connection to database host 'mysql_backup'..."
  sleep 3
done

pos=`mysql -h mysql.service.consul <<EOF | grep bin | awk '{print $2;}'
GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'mysql-backup.novalocal.node.dc1.consul' IDENTIFIED BY '$MYSQL_SLAVE_PW';
FLUSH TABLES WITH READ LOCK;SHOW MASTER STATUS;UNLOCK TABLES;
EOF`

mysql -h mysql_backup.service.consul <<EOF
STOP SLAVE FOR CHANNEL '';
RESET SLAVE;
CHANGE MASTER TO MASTER_HOST='mysql.novalocal.node.dc1.consul', MASTER_USER='repl',MASTER_PASSWORD='$MYSQL_SLAVE_PW',MASTER_LOG_POS=$pos;
START SLAVE;
EOF
