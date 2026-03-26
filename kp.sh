#!/bin/bash
# Timing settings: * /10 * * * /bin/bash /root/kp.sh runs every 10 minutes
# If you have installed the Serv00 local SSH script, do not run this script deployment again, this will cause the process to be full, you must choose one of the two!
# serv00 variable add rule:
# If using keepalive web pages, do not enable cron to prevent the process from bursting due to repeated running of cron and keepalive web pages
# RES (required): n means not resetting the deployment every time, y means resetting the deployment every time. Rep (required): n means do not reset the random ports (leave the three ports blank), y means reset the ports (leave the three ports blank). SSH_user (required) is the serv00 account name. SSH_pass (required) indicates serv00 password. Reality stands for reality domain name (leave blank for serv00 official domain name: your serv00 account name .serv00.net). SUUID represents uuid (leave blank for random uuid). TCP1_port represents the tcp port of vless (leave blank for random tcp port). TCP2_port represents the tcp port of vmess (leave blank for random tcp port). UDP_port represents the udp port of hy2 (leave blank for random udp port). Host (required) indicates the domain name of the logged-in serv00 server. Argo_domain represents an argo fixed domain name (leave blank for a temporary domain name). Argo_auth means argo fixed domain name token (leave blank for temporary domain name).
# Required variables: RES, rep, SSH_user, SSH_pass, host
# Note [] "",: Do not delete these symbols randomly, align them regularly
# One {serv00 server} per line, one service can also be used at the end, interval, the last server does not need to be used at the end, interval
ACCOUNTS='[
{"RES":"n", "REP":"n", "SSH_USER":"Your serv00 account name", "SSH_PASS":"Your serv00 account password", "REALITY":"Your serv00 account name.serv00.net", "SUUID":"Custom UUID", "TCP1_PORT":"vless tcp port", "TCP2_PORT":"tcp port of vmess", "UDP_PORT":"udp port of hy2", "HOST":"s1.serv00.com", "ARGO_DOMAIN":"", "ARGO_AUTH":""},
{"RES":"y", "REP":"y", "SSH_USER":"123456", "SSH_PASS":"7890000", "REALITY":"time.is", "SUUID":"73203ee6-b3fa-4a3d-b5df-6bb2f55073ad", "TCP1_PORT":"", "TCP2_PORT":"", "UDP_PORT":"", "HOST":"s16.serv00.com", "ARGO_DOMAIN":"Your argo fixed domain", "ARGO_AUTH":"eyJhIjoiOTM3YzFjYWI88552NTFiYTM4ZTY0ZDQzRmlNelF0TkRBd1pUQTRNVEJqTUdVeCJ9"}
]'
run_remote_command() {
local RES=$1
local REP=$2
local SSH_USER=$3
local SSH_PASS=$4
local REALITY=${5}
local SUUID=$6
local TCP1_PORT=$7
local TCP2_PORT=$8
local UDP_PORT=$9
local HOST=${10}
local ARGO_DOMAIN=${11}
local ARGO_AUTH=${12}
  if [ -z "${ARGO_DOMAIN}" ]; then
    echo "No Argo domain was provided. Requesting a temporary Argo domain."
  else
    echo "Argo has set a fixed domain name: ${ARGO_DOMAIN}"
  fi
  remote_command="export reym=$REALITY UUID=$SUUID vless_port=$TCP1_PORT vmess_port=$TCP2_PORT hy2_port=$UDP_PORT reset=$RES resport=$REP ARGO_DOMAIN=${ARGO_DOMAIN} ARGO_AUTH=${ARGO_AUTH} && bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxmetrue/main/serv00keep.sh)"
  echo "Executing remote command on $HOST as $SSH_USER with command: $remote_command"
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$remote_command"
}
if  cat /etc/issue /proc/version /etc/os-release 2>/dev/null | grep -q -E -i "openwrt"; then
opkg update
opkg install sshpass curl jq
else
    if [ -f /etc/debian_version ]; then
        package_manager="apt-get install -y"
        apt-get update >/dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        package_manager="yum install -y"
    elif [ -f /etc/fedora-release ]; then
        package_manager="dnf install -y"
    elif [ -f /etc/alpine-release ]; then
        package_manager="apk add"
    fi
    $package_manager sshpass curl jq cron >/dev/null 2>&1 &
fi
echo "*****************************************************"
echo "*****************************************************"
echo "Yongge GitHub project: github.com/yonggekkk"
echo "Yongge blog: ygkkk.blogspot.com"
echo "Yongge YouTube channel: www.youtube.com/@ygkkk"
echo "Automatic remote deployment script for the Serv00 three-protocol setup [VPS + router]"
echo "Version: V25.3.26"
echo "*****************************************************"
echo "*****************************************************"
              count=0  
           for account in $(echo "${ACCOUNTS}" | jq -c '.[]'); do
              count=$((count+1))
              RES=$(echo $account | jq -r '.RES')
              REP=$(echo $account | jq -r '.REP')              
              SSH_USER=$(echo $account | jq -r '.SSH_USER')
              SSH_PASS=$(echo $account | jq -r '.SSH_PASS')
              REALITY=$(echo $account | jq -r '.REALITY')
              SUUID=$(echo $account | jq -r '.SUUID')
              TCP1_PORT=$(echo $account | jq -r '.TCP1_PORT')
              TCP2_PORT=$(echo $account | jq -r '.TCP2_PORT')
              UDP_PORT=$(echo $account | jq -r '.UDP_PORT')
              HOST=$(echo $account | jq -r '.HOST')
              ARGO_DOMAIN=$(echo $account | jq -r '.ARGO_DOMAIN')
              ARGO_AUTH=$(echo $account | jq -r '.ARGO_AUTH') 
          if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" -q exit; then
            echo "🎉[Server $count] Connected successfully. Server: $HOST, account: $SSH_USER"
          if [ -z "${ARGO_DOMAIN}" ]; then
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep [l]ocalhost:$TCP2_PORT > /dev/null"
            else
           check_process="ps aux | grep '[c]onfig' > /dev/null && ps aux | grep '[t]oken $ARGO_AUTH' > /dev/null"
           fi
          if ! sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "$check_process" || [[ "$RES" =~ ^[Yy]$ ]]; then
            echo "⚠️The main process or Argo process is missing, or a reset was requested."
             echo "Starting repair or redeployment. Please wait..."
             output=$(run_remote_command "$RES" "$REP" "$SSH_USER" "$SSH_PASS" "${REALITY}" "$SUUID" "$TCP1_PORT" "$TCP2_PORT" "$UDP_PORT" "$HOST" "${ARGO_DOMAIN}" "${ARGO_AUTH}")
            echo "Remote command execution result: $output"
          else
            echo "🎉All required processes are running normally."
            SSH_USER_LOWER=$(echo "$SSH_USER" | tr '[:upper:]' '[:lower:]')
            sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$HOST" "
echo \"Current configuration:\"
            cat domains/${SSH_USER_LOWER}.serv00.net/logs/list.txt
            echo \"====================================================\""
            fi
           else
            echo "===================================================="
            echo "❌[Server $count] Connection failed. Server: $HOST, account: $SSH_USER"
            echo "The account name, password, or server name may be incorrect, or the server may currently be under maintenance."
            echo "===================================================="
           fi
            done
