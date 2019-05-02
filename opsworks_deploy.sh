#!/bin/bash
# This script uses the AWS CLI tools to initiate and monitor an OpsWorks application deployment
# See https://github.com/ggedde/opsworks-deploy

DIR="$(dirname "$0")"

_SPINNER_POS=0
_TASK_OUTPUT=""
CYAN=$(tput setaf 6)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

ERROR_COLOR=`tput setaf 1`
RUNNING_COLOR=`tput setaf 6`
SUCCESS_COLOR=`tput setaf 2`
NO_COLOR=`tput sgr0` # No Color

spinner() {
    _TASK_OUTPUT=""
    local delay=0.05
    local list=( $(echo -e '\xe2\xa0\x8b')
                 $(echo -e '\xe2\xa0\x99')
                 $(echo -e '\xe2\xa0\xb9')
                 $(echo -e '\xe2\xa0\xb8')
                 $(echo -e '\xe2\xa0\xbc')
                 $(echo -e '\xe2\xa0\xb4')
                 $(echo -e '\xe2\xa0\xa6')
                 $(echo -e '\xe2\xa0\xa7')
                 $(echo -e '\xe2\xa0\x87')
                 $(echo -e '\xe2\xa0\x8f'))
    local i=$_SPINNER_POS
    local tempfile
    tempfile=$(mktemp)

    eval $2 >> $tempfile 2>/dev/null &
    local pid=$!

    tput sc
    printf "%s %s" "${list[i]}" "$1"
	tput el
    tput rc

    i=$(($i+1))
    i=$(($i%10))

    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        printf "%s" "${CYAN}${list[i]}${NORMAL}"
        i=$(($i+1))
        i=$(($i%10))
        sleep $delay
        printf "\b\b\b"
    done
    _TASK_OUTPUT="$(cat $tempfile)"
    rm $tempfile
    _SPINNER_POS=$i

    if [ -z $3 ]; then :; else
      eval $3=\'"$_TASK_OUTPUT"\'
    fi
}

TEMP_FILE="/tmp/opsworks_deploy.tmp"

if [ -f $TEMP_FILE ]
then
	rm $TEMP_FILE
fi

DEPLOYMENTS=()
DEPLOYMENT_TITLES=()
DEPLOYMENT_STACK_IDS=()
DEPLOYMENT_APP_IDS=()
DEPLOYMENT_REGIONS=()
DEPLOYMENT_PROFILES=()
DEPLOYMENT_IDS=()

DEPLOYMENT_INDEX=0

for var in "$@"
do
	# Set Defaults
	TITLE=""
	STACK_ID=""
	API_ID=""
	REGION=""
	PROFILE=""

	if [ ! -f ${DIR}/$var ]
	then
		echo "${ERROR_COLOR}Variables File Not Found (${DIR}/${var})${NO_COLOR}"
		exit
	fi

	source ${DIR}/$var;

	if [ -z "$TITLE" ]
	then
		TITLE="App";
	fi

	DEPLOYMENT_TITLES+=("${TITLE}")
	DEPLOYMENT_STACK_IDS+=("${STACK_ID}")
	DEPLOYMENT_APP_IDS+=("${APP_ID}")
	DEPLOYMENT_REGIONS+=("${REGION}")
	DEPLOYMENT_PROFILES+=("${PROFILE}")

done

APPS_STRING="$(printf ", %s" "${DEPLOYMENT_TITLES[@]}")"
APPS_STRING="${APPS_STRING:2}"

RETRY_LIMIT=60;
WAIT_TIME=2s;
RETRY_COUNT=0;
HAS_RUNNING=1;
LAST_STATUS="";
status_re=".*\"Status\": \"([a-zA-Z0-9\-]+)\"";
deployid_re=".*\"DeploymentId\": \"([a-zA-Z0-9\-]+)\"";

trap ctrl_c INT

function ctrl_c() {
	tput cud1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput dl1
	tput cuu1
	tput el
        tput cnorm && stty echo
		exit
}

deploy_app() {

	DEPLOY_RESULT=$(aws --profile $2 opsworks --region $3 create-deployment --stack-id $4 --app-id $5 --command "{\"Name\":\"deploy\"}" --output json 2>&1 );

	# Remove New Lines
	DEPLOY_RESULT=$(echo $DEPLOY_RESULT|tr -d '\n')

    # check response for deployment-id
    if [[ $DEPLOY_RESULT =~ $deployid_re ]]
    then
    	DEPLOYMENT_ID=("${BASH_REMATCH[1]}")
		echo "${1}|${DEPLOYMENT_ID}|running|" >> $TEMP_FILE
    else
		echo "${1}||Failed|${DEPLOY_RESULT}" >> $TEMP_FILE
    fi

	exit 0
}

deploy_apps() {

	for index in "${!DEPLOYMENT_TITLES[@]}"
	do
		deploy_app $index "${DEPLOYMENT_PROFILES[$index]}" "${DEPLOYMENT_REGIONS[$index]}" "${DEPLOYMENT_STACK_IDS[$index]}" "${DEPLOYMENT_APP_IDS[$index]}" &
	done

	sleep 3

	echo "Done"
}




check_apps() {

	sleep 2

	RETURN_STATUS="Complete"
	DEPLOYMENT_IDS=()

	CONTENTS=$(cat ${TEMP_FILE})
	IFS=$'\n' DEPLOYMENTS=($CONTENTS)

	for d in "${!DEPLOYMENTS[@]}"
	do
		if [ "${DEPLOYMENTS[$d]}" != "" ]
		then

			IFS=$'|' DEPLOYMENT_DETAILS=(${DEPLOYMENTS[$d]})

			DEPLOYMENT_INDEX=${DEPLOYMENT_DETAILS[0]}
			DEPLOYMENT_ID=${DEPLOYMENT_DETAILS[1]}
			DEPLOYMENT_STATUS=${DEPLOYMENT_DETAILS[2]}
			DEPLOYMENT_ERROR=${DEPLOYMENT_DETAILS[3]}

			if [ "$DEPLOYMENT_STATUS" == "running" ]
			then

				COMMAND=`aws --profile ${DEPLOYMENT_PROFILES[$DEPLOYMENT_INDEX]} opsworks --region ${DEPLOYMENT_REGIONS[$DEPLOYMENT_INDEX]} describe-deployments --deployment-ids ${DEPLOYMENT_ID} --output json`

				if [[ $COMMAND =~ $status_re ]]
				then
					STATUS=${BASH_REMATCH[1]}

					if [ "$STATUS" == "running" ]
					then
						RETURN_STATUS="running"
					else
						sed -i '.bak' "s/${DEPLOYMENT_ID}|running/${DEPLOYMENT_ID}|${STATUS}/g" $TEMP_FILE
					fi
				else
					RETURN_STATUS="Error"
				fi

			fi
		fi
	done

	echo $RETURN_STATUS
	exit 0
}

DEPLOYING_STATUS_MESSAGE="${RUNNING_COLOR}Deploying Apps (${NO_COLOR}${APPS_STRING}${RUNNING_COLOR})${NO_COLOR}"

stty -echo && tput civis

spinner "${DEPLOYING_STATUS_MESSAGE}" deploy_apps DEPLOYMENT_DEPLOY_RESULTS

while [ $HAS_RUNNING ] && [ $RETRY_COUNT -lt $RETRY_LIMIT ]
do
	CHECKING_STATUS_MESSAGE="${RUNNING_COLOR}Checking Apps  (${NO_COLOR}${APPS_STRING}${RUNNING_COLOR})${NO_COLOR}"

	HAS_RUNNING=0
	CONTENTS=$(cat ${TEMP_FILE})
	IFS=$'\n' DEPLOYMENTS=($CONTENTS)

	for d in "${!DEPLOYMENTS[@]}"
	do
		IFS=$'|' DEPLOYMENT_DETAILS=(${DEPLOYMENTS[$d]})

		DEPLOYMENT_INDEX=${DEPLOYMENT_DETAILS[0]}
		DEPLOYMENT_ID=${DEPLOYMENT_DETAILS[1]}
		DEPLOYMENT_STATUS=${DEPLOYMENT_DETAILS[2]}
		DEPLOYMENT_ERROR=${DEPLOYMENT_DETAILS[3]}
		DEPLOYMENT_TITLE=${DEPLOYMENT_TITLES[$DEPLOYMENT_INDEX]}

		DEPLOYMENT_STATUS_MESSAGE="${RUNNING_COLOR} ${DEPLOYMENT_STATUS}${NO_COLOR}"


		if [ "$DEPLOYMENT_STATUS" == "running" ]
		then
			HAS_RUNNING=1
		elif [ "$DEPLOYMENT_STATUS" == "successful" ]
		then
			DEPLOYMENT_STATUS_MESSAGE="${SUCCESS_COLOR} ${DEPLOYMENT_STATUS}${NO_COLOR}"
		else
			DEPLOYMENT_STATUS_MESSAGE="${ERROR_COLOR} ${DEPLOYMENT_STATUS} - ${DEPLOYMENT_ERROR}${NO_COLOR}"
		fi

		CHECKING_STATUS_MESSAGE+="
    ${DEPLOYMENT_TITLE} ${RUNNING_COLOR}Deployment ID: ${NO_COLOR}${DEPLOYMENT_ID}${DEPLOYMENT_STATUS_MESSAGE}"

	done

	((RETRY_COUNT++))

	if [ $HAS_RUNNING -gt 0 ]
	then
		spinner "${CHECKING_STATUS_MESSAGE}" check_apps DEPLOYMENT_CHECK_RESULTS
	fi

done

tput el
tput dl1
for d in "${!DEPLOYMENTS[@]}"
do
	tput dl1
done

echo $CHECKING_STATUS_MESSAGE

echo "${SUCCESS_COLOR}Deployments Finished!${NO_COLOR}"
tput cud1

tput cnorm && stty echo

if [ -f $TEMP_FILE ]
then
	rm $TEMP_FILE
fi

exit
