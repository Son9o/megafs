#!/bin/bash
MysqlUser=root
MysqlPassword=Kolega123
FileSize=$(du -b ${1} | awk '{print $1}')
MegaUsername=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT login FROM accounts WHERE free_space >= ${FileSize};" | awk 'NR == 1')
MegaPassword=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT password FROM accounts WHERE login = \"${MegaUsername}\";")
MegaAccFreeSpaceBefore=$(mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "SELECT free_space FROM accounts WHERE login = \"${MegaUsername}\";")
FileRealPath=$(realpath ${1})
DirPath=$(dirname ${FileRealPath})
BaseName=$(basename ${1})


if [[ -z ${MegaUsername+x}  ]] ;then
	echo "no Account Avaiable, creating new one ;)"
	exit 1
fi
if [ -d ${1} ] ;then
	echo "Cannot uplaod DIRs"
	exit 1
fi

PutResoult=$(megaput --username=${MegaUsername} --password=${MegaPassword} --no-progress ${1} 2>&1) 
echo ${PutResoult}|grep ERROR 2>&1 >/dev/null
if [[ $? = 0 ]] ;then
	echo "fy all"
	exit 1
fi
megadf --free --username=${MegaUsername} --password=${MegaPassword}
DownloadLink=$(megals --username=${MegaUsername} --password=${MegaPassword} -e | grep "${BaseName}" | awk '{print $1}' )
mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "INSERT INTO files (path,filename,link,account) VALUES (\"${DirPath}\",\"${BaseName}\",\"${DownloadLink}\",\"${MegaUsername}\")"


