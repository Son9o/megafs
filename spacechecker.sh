#!/bin/bash
source settings.sh


MegaUsernames=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT login FROM accounts;")

for acc in ${MegaUsernames}; do
	pass=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT password FROM accounts WHERE login = \"${acc}\";")
	echo "${acc}: $(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT free_space FROM accounts WHERE login = \"${acc}\";") actual: $(megadf --free --username=${acc} --password=${pass})"
done


