#!/bin/bash
source settings.sh

##meagaccount creation
LastAcc=$(mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "SELECT login FROM accounts ;" | tail -1)
LastAccNumber=${LastAcc#*_}; LastAccNumber=${LastAccNumber%@*}
MegaAccNumber=$((${LastAccNumber} + 1))
NewMegaPassword=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1) # Courtesy of githab/earthgecko
ErrExistsCode=0
function CheckIfErrExists { ##Checks if "account exists" in reponse from server
	echo ${Response}|grep EEXIST &>/dev/null
	ErrExistsCode=$?
}
function RegisterAccount { ##Requests account registration and saves a confirmation key  to match with link from e-mail
	Response=$(megareg --name=${Prefix}$MegaAccNumber --email=${Prefix}$MegaAccNumber@${EmailDomain} --password=$NewMegaPassword --register --scripted 2>&1)
	MegaConfirmKey=$(echo ${Response} | awk '{print $3}')
}
function CreateNewMegaAcc { ##Create new Account and increment accoutn number if previous is not available
	RegisterAccount ${MegaAccNumber}
	echo ${Response}|grep ERROR &>/dev/null  #act on error
	if [[ $? == 0 ]] ;then
		echo ${Response}|grep EEXIST 2>&1 >/dev/null ## if EEXIST error, increment until avaialble
		if [[ $? != 0 ]] ;then ## If non-EEXIST error(unknown) then break this shit 
			echo "Unknown Error while creating account, BREAKING"
			exit  1
		fi
		##Finding available increment
		while [[ ${ErrExistsCode} == 0 ]]; do
			RegisterAccount ${MegaAccNumber}
			NewMegaUsername=${Prefix}$MegaAccNumber@${EmailDomain}
			((MegaAccNumber++))
			CheckIfErrExists
		done
	fi
	sleep 1m 
    MegaConfirmLink=`tac $EmailDrop | grep ^http | grep -m1 confirm`
    megareg --verify ${MegaConfirmKey} ${MegaConfirmLink}
	mysql -h ${MysqlHost} -u ${MysqlUser} -p${MysqlPassword} -N ${MysqlDb} <<< "INSERT INTO accounts (login,password,free_space) VALUES (\"${NewMegaUsername}\",\"${NewMegaPassword}\",\"53687091200\");"

}

