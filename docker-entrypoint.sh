#!/bin/bash

set -e

my="mysql --protocol=tcp"

# set up master
until $my -u root -p$MYSQL_ROOT_PW -h mysql -e ";" ; do
  echo "waiting for connection to database..."
  sleep 3
done

pos=`$my -u root -p$MYSQL_ROOT_PW -h mysql << EOF | grep mysql-bin | awk '{print $2;}'
GRANT REPLICATION SLAVE ON *.*  TO 'repl'@'mysql-backup.novalocal.node.dc1.consul' IDENTIFIED BY '$MYSQL_SLAVE_PW';
FLUSH TABLES WITH READ LOCK;SHOW MASTER STATUS;UNLOCK TABLES;
EOF`

# set up slave
until $my -u root -p$MYSQL_ROOT_PW -h mysql_backup -e ";" ; do
  echo "waiting for connection to database..."
  sleep 3
done

$my -u root -p$MYSQL_ROOT_PW -h mysql_backup << EOF
CHANGE MASTER TO MASTER_HOST='mysql.novalocal.node.dc1.consul', MASTER_USER='repl',MASTER_PASSWORD='$MYSQL_SLAVE_PW',MASTER_LOG_POS=$pos;
START SLAVE;
EOF

# create bridge user and add permissions
$my -u root -p$MYSQL_ROOT_PW -h mysql << EOF
CREATE DATABASE ESC4;
GRANT ALL PRIVILEGES ON ESC4.* To 'esc4_rails'@'%' IDENTIFIED BY '$BRIDGEDB_PASSWORD';
EOF

# import bridge initial DB
wget --no-check-certificate -qO- $INITIAL_SQL_URL | $my -u esc4_rails -p$BRIDGEDB_PASSWORD -h mysql ESC4