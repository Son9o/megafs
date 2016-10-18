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
BaseRemotePath=/Root
RFI=1 #RemoteFolderIncrementation
RemotePath=${BaseRemotePath}/${RFI}

if [[ -z ${MegaUsername+x}  ]] ;then #If no account found with enough free space; do
	echo "no Account Avaiable, creating new one ;)"
	exit 1
fi
if [ -d ${1} ] ;then #Check if Directory
	echo "Cannot uplaod DIRs"
	exit 1
fi
function upload {
PutResoult=$(megaput --username=${MegaUsername} --password=${MegaPassword} ${2} --no-progress ${1} 2>&1 ) 
}
upload ${1}
PutExistErr=0
function CheckIfPutExistsError {
	echo ${PutResoult}|grep exists &>/dev/null
	PutExistErr=$?
}

echo ${PutResoult}|grep ERROR &>/dev/null  #act on error
if [[ $? == 0 ]] ;then
	echo ${PutResoult}|grep exists 2>&1 >/dev/null ## Puta file exists error insert into incremental dir
	if [[ $? != 0 ]] ;then ## If non-exists error then break this shit 
		echo "Other ERROR"
		exit  1
	fi
	echo "Error putaifile exists"
	while [[ ${PutExistErr} != 1 ]]; do
		megamkdir ${BaseRemotePath}/${RFI} >/dev/null 2>&1 
		upload ${1} --path=${BaseRemotePath}/${RFI}
		((RFI++))
		SetRemotePath=${BaseRemotePath}/${RFI}
		CheckIfPutExistsError
	done
fi
SetRemotePath=${BaseRemotePath}
#echo ${PutResoult}|grep -i ERROR | grep -i exists 2>&1 >/dev/null
#if [[ $? != 0 ]] ;then
#	echo "koniec swiata puta"
#	
#fi
megadf --free --username=${MegaUsername} --password=${MegaPassword}
DownloadLink=$(megals --username=${MegaUsername} --password=${MegaPassword} -e | grep -w ${SetRemotePath}/${BaseName} | awk '{print $1}' )
mysql -u ${MysqlUser} -p${MysqlPassword} -N megafs <<< "INSERT INTO files (path,filename,link,account) VALUES (\"${DirPath}\",\"${BaseName}\",\"${DownloadLink}\",\"${MegaUsername}\")"


