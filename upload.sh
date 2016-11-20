#!/bin/bash
source settings.sh
source newmegaacc.sh

if [[ $# < 1 ]] ;then # Check if argument passed
	echo "USAGE: $0 <filename>, to upload a directory specify a directory WITHOUT  an asterix(*)"
	exit 1
fi
if ! [[ -e ${1} ]] ;then ## check if file exists
    echo "USAGE: $0 <filename>, to upload a directory specify a directory WITHOUT  an asterix(*)"
	exit 1
fi
if [ -d ${1} ] ;then #Check if Directory
	IsDir=1
fi

function AccountSelector {
FileSize=$(du -b ${1} | awk '{print $1}' | tail -1)
MegaUsername=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT login FROM accounts WHERE free_space >= ${FileSize};" | awk 'NR == 1')
MegaPassword=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT password FROM accounts WHERE login = \"${MegaUsername}\";")
MegaAccFreeSpaceBefore=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT free_space FROM accounts WHERE login = \"${MegaUsername}\";")
MegaAccFreeSpaceAfter=$((${MegaAccFreeSpaceBefore}-${FileSize}))
}
function CheckIfPutExistsError {
	echo ${PutResoult}|grep exists &>/dev/null
	PutExistErr=$?
}
function CheckIfChecksumExists {
	FileHash=$(sha1sum ${1} | awk '{print $1}')
	Sha1Lookup=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT sha1sum FROM files WHERE sha1sum = \"${FileHash}\";" | awk 'NR == 1')
	if [[ ${Sha1Lookup} == ${FileHash} ]] ;then
	local Return=0
	fi
	return ${Return}
}	
function upload {
if CheckIfChecksumExists ${1} ;then
	local DownloadLinkExisting=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT link FROM files WHERE sha1sum = \"${MegaUsername}\";")
	local BaseNameExisting=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT filename FROM files WHERE sha1sum = \"${MegaUsername}\";")
	local DirPathExisting=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT path FROM files WHERE sha1sum = \"${MegaUsername}\";")
	echo "File already uploaded as ${DirPathExisting}/${BaseNameExisting} with link: ${DownloadLinkExisting}"
	return 1
fi
#Some Working Variables
FileHash=$(sha1sum ${1} | awk '{print $1}')
RFI=1 #RemoteFolderIncrementation
PutExistErr=0
FileRealPath=$(realpath ${1})
DirPath=$(dirname ${FileRealPath})
BaseName=$(basename ${1})
BaseRemotePath=/Root
RemotePath=${BaseRemotePath}/${RFI}
unset SetRemotePath
##End of Working varaibles
AccountSelector ${1}
if [[ -z ${MegaUsername+x}  ]] ;then #If no account found with enough free space; do
	echo "no Account Avaiable, creating new one ;)"
	CreateNewMegaAcc 
	AccountSelector	${1}
fi
PutResoult=$(megaput --username=${MegaUsername} --password=${MegaPassword} --no-progress ${1} 2>&1 ) 
echo ${PutResoult}|grep ERROR &>/dev/null  #act on error
if [[ $? == 0 ]] ;then
	echo ${PutResoult}|grep exists 2>&1 >/dev/null ## Puta file exists error insert into incremental dir
	if [[ $? != 0 ]] ;then ## If non-exists(unknown) error then break this shit 
		echo "Other(Unhandled) error, BREAKING"
		exit  1
	fi
	while [[ ${PutExistErr} -lt 1 ]]; do
		megamkdir --username=${MegaUsername} --password=${MegaPassword} ${BaseRemotePath}/${RFI} >/dev/null 2>&1 
		PutResoult=$(megaput --username=${MegaUsername} --password=${MegaPassword} --path=${BaseRemotePath}/${RFI} --no-progress ${1} 2>&1 )
		SetRemotePath=${BaseRemotePath}/${RFI}
		((RFI++))
		CheckIfPutExistsError
	done
fi

##Add Link to DB
DownloadLink=$(megals --username=${MegaUsername} --password=${MegaPassword} -e | grep -w ${SetRemotePath:-${BaseRemotePath}}/${BaseName} | awk '{print $1}' )
mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "INSERT INTO files (path,filename,link,account,sha1sum) VALUES (\"${DirPath}\",\"${BaseName}\",\"${DownloadLink}\",\"${MegaUsername}\",\"${FileHash}\")"

##Update Free space for account
mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "UPDATE accounts SET free_space=\"${MegaAccFreeSpaceAfter}\" WHERE login = \"${MegaUsername}\";"

}



if [[ $IsDir = 1 ]] ;then
	AllFiles+=$(find ${1} -type f) ##Pupulate ARRAY with files
	for file in ${AllFiles[*]} ;do
		upload ${file}
	done
exit
fi
for arg in ${BASH_ARGV[*]} ;do
	upload ${arg}
done
