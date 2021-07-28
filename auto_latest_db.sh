#!/bin/bash
#Check your OS version
OS=`uname -r|cut -d '-' -f1|cut -d '.' -f1`
if [ `whoami` != root ]
then
echo "Please login as root to continue :)"
exit 1
fi

#check version
if [ $OS -ne 3 ];then
echo "Sorry, Sir, Your System is not CentOS 7!"
exit 1
fi

systemctl stop firewalld.service
systemctl disable firewalld.service
sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
setenforce 0

yum update -y --exclude=kernel*
sleep 2
yum -y install openssl openssl-devel epel-release perl perl-DBI jemalloc jemalloc-devel lsof rsync libaio boost ncurses-compat-libs

#waiting 2 seconds
sleep 5

#setting my.cnf file
if [ $? -eq 0 ];then
rpm -qa|grep mariadb|xargs rpm -e --nodeps && rpm -qa|grep galera|xargs rpm -e --nodeps
sleep 2
cd $PWD && rpm -Uvh *.rpm
fi
mkdir -p /data/{mysql_data,mysql_log,mysql_slow,mysql_undo}
chown -R mysql.mysql /data/*

cat >/etc/my.cnf <<EOF
[client]
port=3306
socket=/tmp/mysql.sock
#default-character-set=utf8mb4
[mysql]
no-auto-rehash
[mysqld]
port=3306
character-set-server=utf8mb4
socket=/tmp/mysql.sock
datadir=/data/mysql_data
#explicit_defaults_for_timestamp=true
lower_case_table_names=0
skip-name-resolve
bind-address=0.0.0.0
sql_mode='STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'
log-bin-trust-function-creators=1
back_log=103
max_connections=3000
max_connect_errors=100000
table_open_cache=512
external-locking=FALSE
max_allowed_packet=512M
sort_buffer_size=16M
join_buffer_size=2M
thread_cache_size=51
query_cache_size=0
query_cache_type=0
transaction_isolation=READ-COMMITTED
tmp_table_size=96M
max_heap_table_size=96M
log-error=/data/mysql_log/error.log
###***slowqueryparameters
long_query_time=2
slow_query_log=1
slow_query_log_file=/data/mysql_slow/slow.log
###***binlogparameters
log-bin=/data/mysql_log/mysql-bin
binlog_cache_size=1M
max_binlog_cache_size=4096M
max_binlog_size=1024M
binlog_format=ROW
binlog_row_image=FULL
expire_logs_days=3
sync_binlog=0
###***undolog
innodb_undo_directory=/data/mysql_undo
innodb_undo_logs=128
innodb_undo_tablespaces=4
innodb_undo_log_truncate=1
innodb_max_undo_log_size=1G
innodb_purge_rseg_truncate_frequency
#***MyISAMparameters
key_buffer_size=16M
read_buffer_size=1M
read_rnd_buffer_size=16M
bulk_insert_buffer_size=100M
###***master-slavereplicationparameters
server-id=1
#read-only=1
#replicate-wild-ignore-table=mysql.%
#slave-parallel-workers=8
relay_log_recovery=ON
slave_skip_errors=1062,1008
#plugin-load = "rpl_semi_sync_master=semisync_master.so;rpl_semi_sync_slave=semisync_slave.so"
#rpl_semi_sync_master_enabled=1
#rpl_semi_sync_master_timeout=1000
#rpl_semi_sync_slave_enabled=1
#rpl_semi_sync_master_wait_point=AFTER_SYNC
#***Innodbstorageengineparameters
innodb_defragment=1
innodb_defragment_n_pages=16
innodb_buffer_pool_dump_at_shutdown=1
innodb_buffer_pool_load_at_startup=1
innodb_buffer_pool_size=4G
innodb_data_file_path=ibdata1:10M:autoextend
innodb_temp_data_file_path = ibtmp1:12M:autoextend:max:5G
innodb_thread_concurrency=0
innodb_flush_log_at_trx_commit=2
innodb_log_buffer_size=16M
innodb_log_file_size=2048M
innodb_log_files_in_group=2
innodb_max_dirty_pages_pct=75
innodb_buffer_pool_dump_pct=50
innodb_lock_wait_timeout=50
innodb_file_per_table=on
innodb_flush_neighbors=0
innodb_flush_method=O_DIRECT
innodb_io_capacity = 5000
wait_timeout = 14400
interactive_timeout = 14400

#thread pool
thread_handling = pool-of-threads
thread_pool_max_threads = 65536
thread_pool_size = 32

[mysqldump]
quick
max_allowed_packet=512M

[myisamchk]
key_buffer=16M
sort_buffer_size=16M
read_buffer=8M
write_buffer=8M

[mysqld_safe]
open-files-limit=28192
log-error=/data/mysql_log/error.log
pid-file=/data/mysql_data/mysqld.pid
EOF

#Initialize MySQL configuration
mysql_install_db --user=mysql --datadir=/data/mysql_data

#Start MySQL
service mysql start

#Setting password from MySQL
read -s -p "Enter password : " password
mysqladmin -uroot password "$password"

#Delete user
mysql -uroot -p"$password" -e "delete from mysql.user where user='' or password='';"
mysql -uroot -p"$password" -e "drop database test;"
mysql -uroot -p"$password" -e "flush privileges;"
echo Your password is "$password"

