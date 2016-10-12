#!/bin/bash
MysqlUser=root
MysqlPassword=Kolega123
FileSize=$(du -b ${1} | awk '{print $1}')
MegaUsername=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT login FROM accounts WHERE free_space >= ${FileSize};")
MegaPassword=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT password FROM accounts WHERE login = \"${MegaUsername}\";")
MegaAccFreeSpaceBefore=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT free_space FROM accounts WHERE login = ${MegaUsername};")


if [[ -z ${MegaUsername+x}  ]] ;then
	echo "no Account Avaiable, creating new one ;)"
	exit 1
fi

megaput --username=${MegaUsername} --password=${MegaPassword} --no-progress ${1}
megadf --free --username=${MegaUsername} --password=${MegaPassword}
