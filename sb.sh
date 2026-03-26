#!/bin/bash
export LANG=en_US.UTF-8
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;36m'
bblue='\033[0;34m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "Please run the script in root mode" && exit
#[[ -e /etc/hosts ]] && grep -qE '^ *172.65.251.78 gitlab.com' /etc/hosts || echo -e '\n172.65.251.78 gitlab.com' >> /etc/hosts
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "alpine"; then
release="alpine"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "script does not support the current system, please choose to use Ubuntu, Debian, Centos system." && exit
fi
export sbfiles="/etc/s-box/sb10.json /etc/s-box/sb11.json /etc/s-box/sb.json"
export sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
vsid=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
#if [[ $(echo "$op" | grep -i -E "arch|alpine") ]]; then
if [[ $(echo "$op" | grep -i -E "arch") ]]; then
red "script does not support the current $op system, please choose to use Ubuntu, Debian, Centos system. The" && exit
fi
version=$(uname -r | cut -d "-" -f1)
[[ -z $(systemd-detect-virt 2>/dev/null) ]] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
armv7l) cpu=armv7;;
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) red "The script currently does not support the $(uname -m) architecture" && exit;;
esac
if [[ -n $(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk -F ' ' '{print $3}') ]]; then
bbr=`sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}'`
elif [[ -n $(ping 10.0.0.2 -c 2 | grep ttl) ]]; then
bbr="Openvz version bbr-plus"
else
bbr="Openvz/Lxc"
fi
hostname=$(hostname)

if [ ! -f sbyg_update ]; then
green "The necessary dependencies for the first installation of the Sing-box-yg script..."
if command -v apk >/dev/null 2>&1; then
apk update
apk add bash libc6-compat jq openssl procps busybox-extras iproute2 iputils coreutils expect git socat iptables grep tar tzdata util-linux
apk add virt-what
else
if [[ $release = Centos && ${vsid} =~ 8 ]]; then
cd /etc/yum.repos.d/ && mkdir backup && mv *repo backup/ 
curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-8.repo
sed -i -e "s|mirrors.cloud.aliyuncs.com|mirrors.aliyun.com|g " /etc/yum.repos.d/CentOS-*
sed -i -e "s|releasever|releasever-stream|g" /etc/yum.repos.d/CentOS-*
yum clean all && yum makecache
cd
fi
if [ -x "$(command -v apt-get)" ]; then
apt update -y
apt install jq cron socat busybox iptables-persistent coreutils util-linux -y
elif [ -x "$(command -v yum)" ]; then
yum update -y && yum install epel-release -y
yum install jq socat busybox coreutils util-linux -y
elif [ -x "$(command -v dnf)" ]; then
dnf update -y
dnf install jq socat busybox coreutils util-linux -y
fi
if [ -x "$(command -v yum)" ] || [ -x "$(command -v dnf)" ]; then
if [ -x "$(command -v yum)" ]; then
yum install -y cronie iptables-services
elif [ -x "$(command -v dnf)" ]; then
dnf install -y cronie iptables-services
fi
systemctl enable iptables >/dev/null 2>&1
systemctl start iptables >/dev/null 2>&1
fi
if [[ -z $vi ]]; then
apt install iputils-ping iproute2 systemctl -y
fi

packages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
inspackages=("curl" "openssl" "iptables" "tar" "expect" "wget" "xxd" "python3" "qrencode" "git")
for i in "${!packages[@]}"; do
package="${packages[$i]}"
inspackage="${inspackages[$i]}"
if ! command -v "$package" &> /dev/null; then
if [ -x "$(command -v apt-get)" ]; then
apt-get install -y "$inspackage"
elif [ -x "$(command -v yum)" ]; then
yum install -y "$inspackage"
elif [ -x "$(command -v dnf)" ]; then
dnf install -y "$inspackage"
fi
fi
done
fi
touch sbyg_update
fi

if [[ $vi = openvz ]]; then
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'is in an error state' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
red "has detected that TUN is not turned on, and now tries to add TUN support" && sleep 4
cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun
TUN=$(cat /dev/net/tun 2>&1)
if [[ ! $TUN =~ 'in bad state' ]] && [[ ! $TUN =~ 'is in an error state' ]] && [[ ! $TUN =~ 'Die Dateizugriffsnummer ist in schlechter Verfassung' ]]; then 
green "Failed to add TUN support. It is recommended to communicate with the VPS manufacturer or enable background settings" && exit
else
echo '#!/bin/bash' > /root/tun.sh && echo 'cd /dev && mkdir net && mknod net/tun c 10 200 && chmod 0666 net/tun' >> /root/tun.sh && chmod +x /root/tun.sh
grep -qE "^ *@reboot root bash /root/tun.sh >/dev/null 2>&1" /etc/crontab || echo "@reboot root bash /root/tun.sh >/dev/null 2>&1" >> /etc/crontab
green "The TUN guardian function has been started"
fi
fi
fi
v4v6(){
v4=$(curl -s4m5 icanhazip.com -k)
v6=$(curl -s6m5 icanhazip.com -k)
v4dq=$(curl -s4m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
v6dq=$(curl -s6m5 -k https://ip.fm | sed -n 's/.*Location: //p' 2>/dev/null)
}
warpcheck(){
wgcfv6=$(curl -s6m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
wgcfv4=$(curl -s4m5 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

v6(){
v4orv6(){
if [ -z "$(curl -s4m5 icanhazip.com -k)" ]; then
echo
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
yellow "Pure IPV6 VPS detected, add NAT64"
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
ipv=prefer_ipv6
else
ipv=prefer_ipv4
fi
if [ -n "$(curl -s6m5 icanhazip.com -k)" ]; then
endip="2606:4700:d0::a29f:c001"
else
endip="162.159.192.1"
fi
}
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
v4orv6
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
v4orv6
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

close(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
if [[ -n $(apachectl -v 2>/dev/null) ]]; then
systemctl stop httpd.service >/dev/null 2>&1
systemctl disable httpd.service >/dev/null 2>&1
service apache2 stop >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
fi
sleep 1
green "Execute the open port and close the firewall."
}

openyn(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
readp "Do you want to open the port and close the firewall? \n1. Yes, execute (return to default)\n2. No, skip! Handle it yourself\nPlease select [1-2]:" action
if [[ -z $action ]] || [[ "$action" = "1" ]]; then
close
elif [[ "$action" = "2" ]]; then
echo
else
red "Input error, please select again" && openyn
fi
}

inssb(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "use?"
yellow "1: Use the latest official version of the kernel (Enter to default)"
yellow "2: Use the previous 1.10.7 official version of the kernel"
readp "Please select [1-2]:" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
sbcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
else
sbcore='1.10.7'
fi
sbname="sing-box-$sbcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$sbcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
blue "Successfully installed Sing-box kernel version: $(/etc/s-box/sing-box version | awk '/version/{print $NF}')"
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
else
red "Download Sing-box The kernel is incomplete, the installation failed, please run the installation again" && exit
fi
else
red "Download Sing-box The kernel failed, please run the installation again, and check whether the VPS network can access Github" && exit
fi
}

inscertificate(){
ymzs(){
ym_vl_re=apple.com
echo
blue "The SNI domain name of Vless-reality defaults to apple.com."
tlsyn=true
ym_vm_ws=$(cat /root/ygkkkca/ca.log 2>/dev/null)
certificatec_vmess_ws='/root/ygkkkca/cert.crt'
certificatep_vmess_ws='/root/ygkkkca/private.key'
certificatec_hy2='/root/ygkkkca/cert.crt'
certificatep_hy2='/root/ygkkkca/private.key'
certificatec_tuic='/root/ygkkkca/cert.crt'
certificatep_tuic='/root/ygkkkca/private.key'
certificatec_an='/root/ygkkkca/cert.crt'
certificatep_an='/root/ygkkkca/private.key'
}

zqzs(){
ym_vl_re=apple.com
echo
blue "The SNI domain name of Vless-reality defaults to apple.com."
tlsyn=false
ym_vm_ws=www.bing.com
certificatec_vmess_ws='/etc/s-box/cert.pem'
certificatep_vmess_ws='/etc/s-box/private.key'
certificatec_hy2='/etc/s-box/cert.pem'
certificatep_hy2='/etc/s-box/private.key'
certificatec_tuic='/etc/s-box/cert.pem'
certificatep_tuic='/etc/s-box/private.key'
certificatec_an='/etc/s-box/cert.pem'
certificatep_an='/etc/s-box/private.key'
}

red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "2. Generate and set up relevant certificates"
echo
blue "automatically generates bing self-signed certificate..." && sleep 2
openssl ecparam -genkey -name prime256v1 -out /etc/s-box/private.key
openssl req -new -x509 -days 36500 -key /etc/s-box/private.key -out /etc/s-box/cert.pem -subj "/CN=www.bing.com"
echo
if [[ -f /etc/s-box/cert.pem ]]; then
blue "Successfully generated bing self-signed certificate"
else
red "Failed to generate bing self-signed certificate" && exit
fi
echo
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
yellow "After detection, the Acme-yg script has been used to apply for the Acme domain name certificate: $(cat /root/ygkkkca/ca.log)"
green "use the $(cat /root/ygkkkca/ca.log) domain name certificate?"
yellow "1: No! Use self-signed certificate (press Enter to default)"
yellow "2: Yes! Use $(cat /root/ygkkkca/ca.log) domain name certificate"
readp "Please select [1-2]:" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
ymzs
fi
else
green "If you have a domain name that has been resolved, do you want to apply for an Acme domain name certificate?"
yellow "1: No! Continue to use the self-signed certificate (press enter to default)"
yellow "2: Yes! Use the Acme-yg script to apply for an Acme certificate (supports regular 80 port mode and Dns API mode)"
readp "Please select [1-2]:" menu
if [ -z "$menu" ] || [ "$menu" = "1" ] ; then
zqzs
else
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
if [[ ! -f /root/ygkkkca/cert.crt && ! -f /root/ygkkkca/private.key && ! -s /root/ygkkkca/cert.crt && ! -s /root/ygkkkca/private.key ]]; then
red "Acme certificate application failed, continue to use self-signed certificate" 
zqzs
else
ymzs
fi
fi
fi
}

chooseport(){
if [[ -z $port ]]; then
port=$(shuf -i 10000-65535 -n 1)
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom port:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom port:" port
done
fi
blue "Confirmed ports: $port" && sleep 2
}

vlport(){
readp "\nSet Vless-reality port (Enter to skip to a random port between 10000-65535):" port
chooseport
port_vl_re=$port
}
vmport(){
readp "\nSet Vmess-ws port (Enter to skip to a random port between 10000-65535):" port
chooseport
port_vm_ws=$port
}
hy2port(){
readp "\nSet the Hysteria2 main port (Enter to skip to a random port between 10000-65535):" port
chooseport
port_hy2=$port
}
tu5port(){
readp "\nSet the Tuic5 main port (Enter to skip to a random port between 10000-65535):" port
chooseport
port_tu=$port
}
anport(){
readp "\nSet the Anytls main port, available in the latest kernel (Enter to skip to a random port between 10000-65535):" port
chooseport
port_an=$port
}

insport(){
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "3. Set each protocol port"
yellow "1: Automatically generate random ports for each protocol (Within the range of 10000-65535), press Enter to default. Please ensure that all ports have been opened in the VPS background"
yellow "2: Customize each protocol port. Please ensure that the specified port has been opened in the VPS background"
readp "Please enter [1-2]:" port
if [ -z "$port" ] || [ "$port" = "1" ] ; then
ports=()
for i in {1..5}; do
while true; do
port=$(shuf -i 10000-65535 -n 1)
if ! [[ " ${ports[@]} " =~ " $port " ]] && \
[[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && \
[[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]; then
ports+=($port)
break
fi
done
done
port_vm_ws=${ports[0]}
port_vl_re=${ports[1]}
port_hy2=${ports[2]}
port_tu=${ports[3]}
port_an=${ports[4]}
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
until [[ -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port_vm_ws") ]]
do
if [[ $tlsyn == "true" ]]; then
numbers=("2053" "2083" "2087" "2096" "8443")
else
numbers=("8080" "8880" "2052" "2082" "2086" "2095")
fi
port_vm_ws=${numbers[$RANDOM % ${#numbers[@]}]}
done
echo
blue "According to whether TLS is enabled in the Vmess-ws protocol, a standard port that supports CDN preferred IP is randomly specified: $port_vm_ws"
else
vlport && vmport && hy2port && tu5port
if [[ "$sbnh" != "1.10" ]]; then
anport
fi
fi
echo
blue "Each protocol port is confirmed as follows"
blue "Vless-reality port: $port_vl_re"
blue "Vmess-ws port: $port_vm_ws"
blue "Hysteria-2 port: $port_hy2"
blue "Tuic-v5 port: $port_tu"
if [[ "$sbnh" != "1.10" ]]; then
blue "Anytls port: $port_an"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "4. Automatically generate a unified uuid (password) for each protocol"
uuid=$(/etc/s-box/sing-box generate uuid)
blue "Confirmed uuid (password): ${uuid}"
blue "The path of Vmess has been confirmed: ${uuid}-vm"
}

inssbjsonser(){
cat > /etc/s-box/sb10.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "sniff": true,
      "sniff_override_destination": true,
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",
        "sniff": true,
        "sniff_override_destination": true,
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",
            "sniff": true,
            "sniff_override_destination": true,
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        }
],
"outbounds": [
{
"type":"direct",
"tag":"direct",
"domain_strategy": "$ipv"
},
{
"type":"direct",
"tag": "vps-outbound-v4", 
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag": "vps-outbound-v6",
"domain_strategy":"prefer_ipv6"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
},
{
"type":"direct",
"tag":"socks-IPv4-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"socks-IPv6-out",
"detour":"socks-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"direct",
"tag":"warp-IPv4-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv4"
},
{
"type":"direct",
"tag":"warp-IPv6-out",
"detour":"wireguard-out",
"domain_strategy":"prefer_ipv6"
},
{
"type":"wireguard",
"tag":"wireguard-out",
"server":"$endip",
"server_port":2408,
"local_address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peer_public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"reserved":$res
},
{
"type": "block",
"tag": "block"
}
],
"route":{
"rules":[
{
"protocol": [
"quic",
"stun"
],
"outbound": "block"
},
{
"outbound":"warp-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"warp-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv4-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"socks-IPv6-out",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v4",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound":"vps-outbound-v6",
"domain_suffix": [
"yg_kkk"
]
,"geosite": [
"yg_kkk"
]
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF

cat > /etc/s-box/sb11.json <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",

      
      "tag": "vless-sb",
      "listen": "::",
      "listen_port": ${port_vl_re},
      "users": [
        {
          "uuid": "${uuid}",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${ym_vl_re}",
          "reality": {
          "enabled": true,
          "handshake": {
            "server": "${ym_vl_re}",
            "server_port": 443
          },
          "private_key": "$private_key",
          "short_id": ["$short_id"]
        }
      }
    },
{
        "type": "vmess",

 
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${port_vm_ws},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"    
        },
        "tls":{
                "enabled": ${tlsyn},
                "server_name": "${ym_vm_ws}",
                "certificate_path": "$certificatec_vmess_ws",
                "key_path": "$certificatep_vmess_ws"
            }
    }, 
    {
        "type": "hysteria2",

 
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${port_hy2},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$certificatec_hy2",
            "key_path": "$certificatep_hy2"
        }
    },
        {
            "type":"tuic",

     
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${port_tu},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$certificatec_tuic",
                "key_path": "$certificatep_tuic"
            }
        },
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${port_an},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$certificatec_an",
                "key_path": "$certificatep_an"
            }
        }
],
"endpoints":[
{
"type":"wireguard",
"tag":"warp-out",
"address":[
"172.16.0.2/32",
"${v6}/128"
],
"private_key":"$pvk",
"peers": [
{
"address": "$endip",
"port":2408,
"public_key":"bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
"allowed_ips": [
"0.0.0.0/0",
"::/0"
],
"reserved":$res
}
]
}
],









"outbounds": [
{
"type":"direct",
"tag":"direct"
},
{
"type": "socks",
"tag": "socks-out",
"server": "127.0.0.1",
"server_port": 40000,
"version": "5"
}
],
"route":{
"rules":[
{
 "action": "sniff"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv4"
},
{
"action": "resolve",
"domain_suffix":[
"yg_kkk"
],
"strategy": "prefer_ipv6"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"socks-out"
},
{
"domain_suffix":[
"yg_kkk"
],
"outbound":"warp-out"
},
{
"outbound": "direct",
"network": "udp,tcp"
}
]
}
}
EOF
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
}

sbservice(){
if command -v apk >/dev/null 2>&1; then
echo '#!/sbin/openrc-run
description="sing-box service"
command="/etc/s-box/sing-box"
command_args="run -c /etc/s-box/sb.json"
command_background=true
pidfile="/var/run/sing-box.pid"' > /etc/init.d/sing-box
chmod +x /etc/init.d/sing-box
rc-update add sing-box default
rc-service sing-box start
else
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
After=network.target nss-lookup.target
[Service]
User=root
WorkingDirectory=/root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/s-box/sing-box run -c /etc/s-box/sb.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable sing-box >/dev/null 2>&1
systemctl start sing-box
systemctl restart sing-box
fi
}

ipuuid(){
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
v4v6
if [[ -n $v4 && -n $v6 ]]; then
green "Adjust the IPv4/IPV6 configuration output"
yellow "1: Refresh the local IP and use IPV4 configuration output (Enter to default)"
yellow "2: Refresh local IP, use IPV6 configuration output"
readp "Please select [1-2]:" menu
if [ -z "$menu" ] || [ "$menu" = "1" ]; then
server_ip="$v4"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v4"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="[$v6]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$v6"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
else
yellow "VPS is not a dual-stack VPS and does not support switching of IP configuration output"
serip=$(curl -s4m5 icanhazip.com -k || curl -s6m5 icanhazip.com -k)
if [[ "$serip" =~ : ]]; then
server_ip="[$serip]"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
else
server_ip="$serip"
echo "$server_ip" > /etc/s-box/server_ip.log
server_ipcl="$serip"
echo "$server_ipcl" > /etc/s-box/server_ipcl.log
fi
fi
else
red "Sing-box service is not running" && exit
fi
}

wgcfgo(){
warpcheck
if [[ ! $wgcfv4 =~ on|plus && ! $wgcfv6 =~ on|plus ]]; then
ipuuid
else
systemctl stop wg-quick@wgcf >/dev/null 2>&1
kill -15 $(pgrep warp-go) >/dev/null 2>&1 && sleep 2
ipuuid
systemctl start wg-quick@wgcf >/dev/null 2>&1
systemctl restart warp-go >/dev/null 2>&1
systemctl enable warp-go >/dev/null 2>&1
systemctl start warp-go >/dev/null 2>&1
fi
}

result_vl_vm_hy_tu(){
if [[ -f /root/ygkkkca/cert.crt && -f /root/ygkkkca/private.key && -s /root/ygkkkca/cert.crt && -s /root/ygkkkca/private.key ]]; then
ym=`bash ~/.acme.sh/acme.sh --list | tail -1 | awk '{print $1}'`
echo $ym > /root/ygkkkca/ca.log
fi
rm -rf /etc/s-box/vm_ws_argo.txt /etc/s-box/vm_ws.txt /etc/s-box/vm_ws_tls.txt
server_ip=$(cat /etc/s-box/server_ip.log)
server_ipcl=$(cat /etc/s-box/server_ipcl.log)
uuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vl_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
public_key=$(cat /etc/s-box/public.key)
short_id=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.short_id[0]')
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
ws_path=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
if [[ -f /etc/s-box/cfvmadd_local.txt ]]; then
vmadd_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
vmadd_are_local=$(cat /etc/s-box/cfvmadd_local.txt 2>/dev/null)
else
if [[ "$tls" = "false" ]]; then
if [[ -f /etc/s-box/cfymjx.txt ]]; then
vm_name=$(cat /etc/s-box/cfymjx.txt 2>/dev/null)
else
vm_name=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
fi
vmadd_local=$server_ipcl
vmadd_are_local=$server_ip
else
vmadd_local=$vm_name
vmadd_are_local=$vm_name
fi
fi
if [[ -f /etc/s-box/cfvmadd_argo.txt ]]; then
vmadd_argo=$(cat /etc/s-box/cfvmadd_argo.txt 2>/dev/null)
else
vmadd_argo=www.visa.com.sg
fi
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
if [[ -n $hy2_ports ]]; then
hy2ports=$(echo $hy2_ports | sed 's/:/-/g')
hyps=$hy2_port,$hy2ports
else
hyps=
fi
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [[ "$hy2_sniname" = '/etc/s-box/private.key' ]]; then
hy2_name=www.bing.com
sb_hy2_ip=$server_ip
cl_hy2_ip=$server_ipcl
ins_hy2=1
hy2_ins=true
else
hy2_name=$ym
sb_hy2_ip=$ym
cl_hy2_ip=$ym
ins_hy2=0
hy2_ins=false
fi
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [[ "$tu5_sniname" = '/etc/s-box/private.key' ]]; then
tu5_name=www.bing.com
sb_tu5_ip=$server_ip
cl_tu5_ip=$server_ipcl
ins=1
tu5_ins=true
else
tu5_name=$ym
sb_tu5_ip=$ym
cl_tu5_ip=$ym
ins=0
tu5_ins=false
fi
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
ym=$(cat /root/ygkkkca/ca.log 2>/dev/null)
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [[ "$an_sniname" = '/etc/s-box/private.key' ]]; then
an_name=www.bing.com
sb_an_ip=$server_ip
cl_an_ip=$server_ipcl
ins_an=1
an_ins=true
else
an_name=$ym
sb_an_ip=$ym
cl_an_ip=$ym
ins_an=0
an_ins=false
fi
}

resvless(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
vl_link="vless://$uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo "$vl_link" > /etc/s-box/vl_reality.txt
red "🚀[ vless-reality-vision ] Node information is as follows:" && sleep 2
echo
echo "Share link [v2ran (switch singbox kernel), nekobox, shadowrocket]"
echo -e "${yellow}$vl_link${plain}"
echo
echo "QR code [v2ran (switch singbox kernel), nekobox, shadowrocket]"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vl_reality.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resvmess(){
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo】The temporary node information is as follows (3-8-3 can be selected, customized CDN preferred address):" && sleep 2
echo
echo "Share link [v2rayn, v2rayng, nekobox, shadowrocket]"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code [v2rayn, v2rayng, nekobox, shadowrocket]"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argo'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argo'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argols.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argols.txt)"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
argogd=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀【 vmess-ws(tls)+Argo】The fixed node information is as follows (3-8-3 can be selected, customized CDN preferred address):" && sleep 2
echo
echo "Share link [v2rayn, v2rayng, nekobox, shadowrocket]"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code [v2rayn, v2rayng, nekobox, shadowrocket]"
echo 'vmess://'$(echo '{"add":"'$vmadd_argo'","aid":"0","host":"'$argogd'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"8443","ps":"'vm-argo-$hostname'","tls":"tls","sni":"'$argogd'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_argogd.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_argogd.txt)"
fi
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀[ vmess-ws ] Node information is as follows (it is recommended to choose 3-8-1, set as CDN preferred node):" && sleep 2
echo
echo "Share link [v2rayn, v2rayng, nekobox, shadowrocket]"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code [v2rayn, v2rayng, nekobox, shadowrocket]"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws.txt)"
else
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀[ vmess-ws-tls ] The node information is as follows (it is recommended to choose 3-8-1 and set as the CDN preferred node):" && sleep 2
echo
echo "Share link [v2rayn, v2rayng, nekobox, shadowrocket]"
echo -e "${yellow}vmess://$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0)${plain}"
echo
echo "QR code [v2rayn, v2rayng, nekobox, shadowrocket]"
echo 'vmess://'$(echo '{"add":"'$vmadd_are_local'","aid":"0","host":"'$vm_name'","id":"'$uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","fp":"chrome","type":"none","v":"2"}' | base64 -w 0) > /etc/s-box/vm_ws_tls.txt
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/vm_ws_tls.txt)"
fi
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

reshy2(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&mport=$hyps&sni=$hy2_name#hy2-$hostname"
#hy2_link="hysteria2://$uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&sni=$hy2_name#hy2-$hostname"
echo "$hy2_link" > /etc/s-box/hy2.txt
red "🚀[Hysteria-2]The node information is as follows:" && sleep 2
echo
echo "Share link [v2rayn, v2rayng, nekobox, shadowrocket]"
echo -e "${yellow}$hy2_link${plain}"
echo
echo "QR code [v2rayn, v2rayng, nekobox, shadowrocket]"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/hy2.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

restu5(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
tuic5_link="tuic://$uuid:$uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&allow_insecure=$ins&allowInsecure=$ins#tu5-$hostname"
echo "$tuic5_link" > /etc/s-box/tuic5.txt
red "🚀[Tuic-v5]The node information is as follows:" && sleep 2
echo
echo "Share link [v2rayn, nekobox, shadowrocket]"
echo -e "${yellow}$tuic5_link${plain}"
echo
echo "QR code [v2rayn, nekobox, shadowrocket]"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/tuic5.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

resan(){
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
an_link="anytls://$uuid@$sb_an_ip:$an_port?&sni=$an_name&allowInsecure=$ins_an#anytls-$hostname"
echo "$an_link" > /etc/s-box/an.txt
red "🚀[Anytls]The node information is as follows:" && sleep 2
echo
echo "Share link [v2rayn, shadowrocket]"
echo -e "${yellow}$an_link${plain}"
echo
echo "QR code [v2rayn, nekobox, shadowrocket]"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/an.txt)"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

sb_client(){
sbany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "\"anytls-$hostname\","
  fi
}
clany1(){
  if [[ "$sbnh" != "1.10" ]]; then
    echo "- anytls-$hostname"
  fi
}
sbany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
         {
            "type": "anytls",
            "tag": "anytls-$hostname",
            "server": "$sb_an_ip",
            "server_port": $an_port,
            "password": "$uuid",
            "idle_session_check_interval": "30s",
            "idle_session_timeout": "30s",
            "min_idle_session": 5,
            "tls": {
                "enabled": true,
                "insecure": $an_ins,
                "server_name": "$an_name"
            }
         },
EOF
  fi
}
clany2(){
  if [[ "$sbnh" != "1.10" ]]; then
    cat <<EOF
- name: anytls-$hostname
  type: anytls
  server: $cl_an_ip
  port: $an_port
  password: $uuid
  client-fingerprint: chrome
  udp: true
  idle-session-check-interval: 30
  idle-session-timeout: 30
  sni: $an_name
  skip-cert-verify: $an_ins
EOF
  fi
}

sball(){
cat <<EOF
{
    "log": {
        "disabled": false,
        "level": "info",
        "timestamp": true
    },
    "experimental": {
        "cache_file": {
            "enabled": true,
            "path": "./cache.db",
            "store_fakeip": true
        },
        "clash_api": {
            "external_controller": "127.0.0.1:9090",
            "external_ui": "ui",
            "default_mode": "Rule"
        }
    },
    "dns": {
        "servers": [
            {
                "tag": "aliDns",
                "type": "https",
                "server": "dns.alidns.com",
                "path": "/dns-query",
                "domain_resolver": "local"
            },
            {
                "tag": "local",
                "type": "udp",
                "server": "223.5.5.5"
            },
            {
                "tag": "proxyDns",
                "type": "https",
                "server": "dns.google",
                "path": "/dns-query",
	            "domain_resolver": "aliDns",
                "detour": "proxy"
            },
           {
        "type": "fakeip",
        "tag": "fakeip",
        "inet4_range": "198.18.0.0/15",
        "inet6_range": "fc00::/18"
      }
        ],
        "rules": [
            {
                "rule_set": "geosite-cn",
                "clash_mode": "Rule",
                "server": "aliDns"
            },
            {
                "clash_mode": "Direct",
                "server": "local"
            },
            {
                "clash_mode": "Global",
                "server": "proxyDns"
            },
            {
        "query_type": [
          "A",
          "AAAA"
        ],
        "server": "fakeip"
      }
        ],
        "final": "proxyDns",
        "strategy": "prefer_ipv4",
        "independent_cache": true
    },
    "inbounds": [
        {
            "type": "tun",
            "tag": "tun-in",
            "address": [
                "172.19.0.1/30",
                "fd00::1/126"
            ],
            "auto_route": true,
            "strict_route": true
        }
    ],
    "route": {
        "rules": [
            {
	           "inbound": "tun-in",
                "action": "sniff"
            },
            {
                "type": "logical",
                "mode": "or",
                "rules": [
                    {
                        "port": 53
                    },
                    {
                        "protocol": "dns"
                    }
                ],
                "action": "hijack-dns"
            },
         {
          "clash_mode": "Global",
          "outbound": "proxy"
         },
        {
        "rule_set": "geosite-cn",
        "clash_mode": "Rule",
        "outbound": "direct"
       },
     {
    "rule_set": "geoip-cn",
    "clash_mode": "Rule",
    "outbound": "direct"
      },
     {
    "ip_is_private": true,
    "clash_mode": "Rule",
    "outbound": "direct"
    },
     {
      "clash_mode": "Direct",
      "outbound": "direct"
     }		
        ],
        "rule_set": [
            {
                "tag": "geosite-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geosite/geolocation-cn.srs",
                "download_detour": "direct"
            },
            {
                "tag": "geoip-cn",
                "type": "remote",
                "format": "binary",
                "url": "https://cdn.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@sing/geo/geoip/cn.srs",
                "download_detour": "direct"
            }
        ],
        "final": "proxy",
        "auto_detect_interface": true,
        "default_domain_resolver": {
            "server": "aliDns"
        }
    },
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-$hostname",
      "server": "$server_ipcl",
      "server_port": $vl_port,
      "uuid": "$uuid",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "$vl_name",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
      "reality": {
          "enabled": true,
          "public_key": "$public_key",
          "short_id": "$short_id"
        }
      }
    },
{
            "server": "$vmadd_local",
            "server_port": $vm_port,
            "tag": "vmess-$hostname",
            "tls": {
                "enabled": $tls,
                "server_name": "$vm_name",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$vm_name"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },

    {
        "type": "hysteria2",
        "tag": "hy2-$hostname",
        "server": "$cl_hy2_ip",
        "server_port": $hy2_port,
        "password": "$uuid",
        "tls": {
            "enabled": true,
            "server_name": "$hy2_name",
            "insecure": $hy2_ins,
            "alpn": [
                "h3"
            ]
        }
    },
        {
            "type":"tuic",
            "tag": "tuic5-$hostname",
            "server": "$cl_tu5_ip",
            "server_port": $tu5_port,
            "uuid": "$uuid",
            "password": "$uuid",
            "congestion_control": "bbr",
            "udp_relay_mode": "native",
            "udp_over_stream": false,
            "zero_rtt_handshake": false,
            "heartbeat": "10s",
            "tls":{
                "enabled": true,
                "server_name": "$tu5_name",
                "insecure": $tu5_ins,
                "alpn": [
                    "h3"
                ]
            }
        },
EOF
}

clall(){
cat <<EOF
port: 7890
allow-lan: true
mode: rule
log-level: info
unified-delay: true
dns:
  enable: true 
  listen: "0.0.0.0:1053"
  ipv6: true
  prefer-h3: false
  respect-rules: true
  use-system-hosts: false
  cache-algorithm: "arc"
  enhanced-mode: "fake-ip"
  fake-ip-range: "198.18.0.1/16"
  fake-ip-filter:
    - "+.lan"
    - "+.local"
    - "+.msftconnecttest.com"
    - "+.msftncsi.com"
    - "localhost.ptlogin2.qq.com"
    - "localhost.sec.qq.com"
    - "+.in-addr.arpa"
    - "+.ip6.arpa"
    - "time.*.com"
    - "time.*.gov"
    - "pool.ntp.org"
    - "localhost.work.weixin.qq.com"
  default-nameserver: ["223.5.5.5", "1.2.4.8"]
  nameserver:
    - "https://208.67.222.222/dns-query"
    - "https://1.1.1.1/dns-query"
    - "https://8.8.4.4/dns-query"
  proxy-server-nameserver:
    - "https://223.5.5.5/dns-query"
    - "https://doh.pub/dns-query"
  nameserver-policy:
    "geosite:private,cn":
      - "https://223.5.5.5/dns-query"
      - "https://doh.pub/dns-query"

proxies:
- name: vless-reality-vision-$hostname               
  type: vless
  server: $server_ipcl                           
  port: $vl_port                                
  uuid: $uuid   
  network: tcp
  udp: true
  tls: true
  flow: xtls-rprx-vision
  servername: $vl_name                 
  reality-opts: 
    public-key: $public_key    
    short-id: $short_id                      
  client-fingerprint: chrome                  

- name: vmess-ws-$hostname                         
  type: vmess
  server: $vmadd_local                        
  port: $vm_port                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: $tls
  network: ws
  servername: $vm_name                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $vm_name                     

- name: hysteria2-$hostname                            
  type: hysteria2                                      
  server: $cl_hy2_ip                               
  port: $hy2_port                                
  password: $uuid                          
  alpn:
    - h3
  sni: $hy2_name                               
  skip-cert-verify: $hy2_ins
  fast-open: true

- name: tuic5-$hostname                            
  server: $cl_tu5_ip                      
  port: $tu5_port                                    
  type: tuic
  uuid: $uuid       
  password: $uuid   
  alpn: [h3]
  disable-sni: true
  reduce-rtt: true
  udp-relay-mode: native
  congestion-controller: bbr
  sni: $tu5_name                                
  skip-cert-verify: $tu5_ins
EOF
}

tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo fixed-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo fixed-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo temporary-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo temporary-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo fixed-$hostname",
        "vmess-argo fixed-$hostname",
        "vmess-tls-argo temporary-$hostname",
        "vmess-argo temporary-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo fixed-$hostname",
        "vmess-argo fixed-$hostname",
        "vmess-tls-argo temporary-$hostname",
        "vmess-argo temporary-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

- name: vmess-tls-argo fixed-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd


- name: vmess-argo fixed-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-tls-argo temporary-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo temporary-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: load balancing
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname

- name: automatic selection
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname
    
- name: 🌍Select agent node
  type: select
  proxies:
    - load balancing
    - automatic selection
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
- MATCH,🌍Select agent node
EOF

elif ! ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo temporary-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo temporary-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argo",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argo"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo temporary-$hostname",
        "vmess-argo temporary-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo temporary-$hostname",
        "vmess-argo temporary-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)








$(clany2)

- name: vmess-tls-argo temporary-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo

- name: vmess-argo temporary-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argo                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argo 

proxy-groups:
- name: load balancing
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname

- name: automatic selection
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname
    
- name: 🌍Select agent node
  type: select
  proxies:
    - load balancing
    - automatic selection
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo temporary-$hostname
- vmess-argo temporary-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
- MATCH,🌍Select agent node
EOF

elif ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' && ! ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1 && [ "$tls" = "false" ]; then
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
{
            "server": "$vmadd_argo",
            "server_port": 8443,
            "tag": "vmess-tls-argo fixed-$hostname",
            "tls": {
                "enabled": true,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
{
            "server": "$vmadd_argo",
            "server_port": 8880,
            "tag": "vmess-argo fixed-$hostname",
            "tls": {
                "enabled": false,
                "server_name": "$argogd",
                "insecure": false,
                "utls": {
                    "enabled": true,
                    "fingerprint": "chrome"
                }
            },
            "packet_encoding": "packetaddr",
            "transport": {
                "headers": {
                    "Host": [
                        "$argogd"
                    ]
                },
                "path": "$ws_path",
                "type": "ws"
            },
            "type": "vmess",
            "security": "auto",
            "uuid": "$uuid"
        },
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo fixed-$hostname",
        "vmess-argo fixed-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname",
        $(sbany1)
        "vmess-tls-argo fixed-$hostname",
        "vmess-argo fixed-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)






$(clany2)

- name: vmess-tls-argo fixed-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8443                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

- name: vmess-argo fixed-$hostname
  type: vmess
  server: $vmadd_argo                        
  port: 8880                                     
  uuid: $uuid       
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  network: ws
  servername: $argogd                    
  ws-opts:
    path: "$ws_path"                             
    headers:
      Host: $argogd

proxy-groups:
- name: load balancing
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname

- name: automatic selection
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname
    
- name: 🌍Select agent node
  type: select
  proxies:
    - load balancing
    - automatic selection
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
- vmess-tls-argo fixed-$hostname
- vmess-argo fixed-$hostname
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
- MATCH,🌍Select agent node
EOF

else
cat > /etc/s-box/sbox.json <<EOF
$(sball)
$(sbany2)
        {
            "tag": "proxy",
            "type": "selector",
			"default": "auto",
            "outbounds": [
        "auto",
        "vless-$hostname",
		$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ]
        },
        {
            "tag": "auto",
            "type": "urltest",
            "outbounds": [
        "vless-$hostname",
		$(sbany1)
        "vmess-$hostname",
        "hy2-$hostname",
        "tuic5-$hostname"
            ],
            "url": "http://www.gstatic.com/generate_204",
            "interval": "10m",
            "tolerance": 50
        },
        {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

cat > /etc/s-box/clmi.yaml <<EOF
$(clall)

$(clany2)

proxy-groups:
- name: load balancing
  type: load-balance
  url: https://www.gstatic.com/generate_204
  interval: 300
  strategy: round-robin
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)

- name: automatic selection
  type: url-test
  url: https://www.gstatic.com/generate_204
  interval: 300
  tolerance: 50
  proxies:
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
    
- name: 🌍Select agent node
  type: select
  proxies:
    - load balancing
    - automatic selection
    - DIRECT
    - vless-reality-vision-$hostname                              
    - vmess-ws-$hostname
    - hysteria2-$hostname
    - tuic5-$hostname
    $(clany1)
rules:
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
- MATCH,🌍Select agent node
EOF
fi
}

cfargo_ym(){
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
echo
yellow "1: Add or delete Argo temporary tunnel"
yellow "2: Add or delete Argo fixed tunnel"
yellow "0: Return to the upper layer"
readp "Please select [0-2]:" menu
if [ "$menu" = "1" ]; then
cfargo
elif [ "$menu" = "2" ]; then
cfargoym
else
changeserv
fi
else
yellow "Because vmess has enabled tls, the Argo tunnel function is unavailable" && sleep 2
fi
}

cloudflaredargo(){
if [ ! -e /etc/s-box/cloudflared ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/cloudflared -# --retry 2 https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu
#curl -L -o /etc/s-box/cloudflared -# --retry 2 https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/$cpu
chmod +x /etc/s-box/cloudflared
fi
}

cfargoym(){
echo
if [[ -f /etc/s-box/sbargotoken.log && -f /etc/s-box/sbargoym.log ]]; then
green "Current Argo fixed tunnel domain name: $(cat /etc/s-box/sbargoym.log 2>/dev/null)"
green "Current Argo fixed tunnel Token: $(cat /etc/s-box/sbargotoken.log 2>/dev/null)"
fi
echo
green "Please enter the Cloudflare official website --- Zero Trust --- Network --- Connector, create a fixed tunnel"
yellow "1: Reset/set Argo fixed tunnel domain name"
yellow "2: Stop Argo fixed tunnel"
yellow "0: Return to the upper layer"
readp "Please select [0-2]:" menu
if [ "$menu" = "1" ]; then
cloudflaredargo
readp "Enter the Argo fixed tunnel Token:" argotoken
readp "Enter the Argo fixed tunnel domain name:" argoym
pid=$(ps -ef 2>/dev/null | awk '/[c]loudflared.*run/ {print $2}')
[ -n "$pid" ] && kill -9 "$pid" >/dev/null 2>&1
echo
if [[ -n "${argotoken}" && -n "${argoym}" ]]; then
if pidof systemd >/dev/null 2>&1; then
cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
TimeoutStartSec=0
ExecStart=/etc/s-box/cloudflared tunnel --no-autoupdate --edge-ip-version auto --protocol http2 run --token "${argotoken}"
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1
systemctl enable argo >/dev/null 2>&1
systemctl start argo >/dev/null 2>&1
elif command -v rc-service >/dev/null 2>&1; then
cat > /etc/init.d/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="/etc/s-box/cloudflared tunnel"
command_args="--no-autoupdate --edge-ip-version auto --protocol http2 run --token ${argotoken}"
pidfile="/run/argo.pid"
command_background="yes"
depend() {
need net
}
EOF
chmod +x /etc/init.d/argo >/dev/null 2>&1
rc-update add argo default >/dev/null 2>&1
rc-service argo start >/dev/null 2>&1
fi
fi
echo ${argoym} > /etc/s-box/sbargoym.log
echo ${argotoken} > /etc/s-box/sbargotoken.log
argo=$(cat /etc/s-box/sbargoym.log 2>/dev/null)
sbshare > /dev/null 2>&1
blue "Argo fixed tunnel setting is completed, fixed domain name: $argo"
elif [ "$menu" = "2" ]; then
if pidof systemd >/dev/null 2>&1; then
systemctl stop argo >/dev/null 2>&1
systemctl disable argo >/dev/null 2>&1
rm -rf /etc/systemd/system/argo.service
elif command -v rc-service >/dev/null 2>&1; then
rc-service argo stop >/dev/null 2>&1
rc-update del argo default >/dev/null 2>&1
rm -rf /etc/init.d/argo
fi
rm -rf /etc/s-box/vm_ws_argogd.txt
sbshare > /dev/null 2>&1
green "Argo fixed tunnel has stopped"
else
cfargo_ym
fi
}

cfargo(){
echo
yellow "1: Reset the Argo temporary tunnel domain name"
yellow "2: Stop Argo temporary tunnel"
yellow "0: Return to the upper layer"
readp "Please select [0-2]:" menu
if [ "$menu" = "1" ]; then
green "Please wait..."
cloudflaredargo
ps -ef | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 20
if [[ -n $(curl -sL https://$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')/ -I | awk 'NR==1 && /404|400|503/') ]]; then
argo=$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
sbshare > /dev/null 2>&1
blue "Argo temporary tunnel application is successful, domain name verification is valid: $argo" && sleep 2
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpineargo.start <<'EOF'
#!/bin/bash
sleep 10
nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 &
sleep 10
printf "9\n1\n" | bash /usr/bin/sb > /dev/null 2>&1
EOF
chmod +x /etc/local.d/alpineargo.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup /etc/s-box/cloudflared tunnel --url http://localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port') --edge-ip-version auto --no-autoupdate --protocol http2 > /etc/s-box/argo.log 2>&1 & sleep 10 && printf \"9\n1\n\" | bash /usr/bin/sb > /dev/null 2>&1"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
else
yellow "Argo temporary domain name verification is temporarily unavailable, please try again later"
fi
elif [ "$menu" = "2" ]; then
ps -ef | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/s-box/vm_ws_argols.txt
rm -rf /etc/local.d/alpineargo.start
sbshare > /dev/null 2>&1
green "Argo temporary tunnel has stopped"
else
cfargo_ym
fi
}

instsllsingbox(){
if [[ -f '/etc/systemd/system/sing-box.service' ]]; then
red "The Sing-box service has been installed and cannot be installed again" && exit
fi
mkdir -p /etc/s-box
v6
openyn
inssb
inscertificate
insport
sleep 2
echo
blue "Vless-reality related keys and ids will be automatically generated..."
key_pair=$(/etc/s-box/sing-box generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
echo "$public_key" > /etc/s-box/public.key
short_id=$(/etc/s-box/sing-box generate rand --hex 4)
wget -q -O /root/geoip.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.db
wget -q -O /root/geosite.db https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.db
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "5. Automatically generate warp-wireguard outbound account" && sleep 2
warpwg
inssbjsonser
sbservice
sbactive
#curl -sL https://gitlab.com/rwkgyg/sing-box-yg/-/raw/main/version/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
curl -sL https://raw.githubusercontent.com/anyagixx/proxmetrue/main/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
lnsb && blue "The Sing-box-yg script is installed successfully, and the script shortcut is: sb" && cronsb
echo
wgcfgo
sbshare
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
blue "You can select 9 to refresh and display all protocol configurations and sharing links"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
}

changeym(){
[ -f /root/ygkkkca/ca.log ] && ymzs="$yellow switched to domain name certificate: $(cat /root/ygkkkca/ca.log 2>/dev/null)$plain" || ymzs="$yellow has not applied for a domain name certificate and cannot switch to $plain"
vl_na="Domain name in use: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name'). Change the domain name that meets the reality requirements. The certificate domain name $plain"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[[ "$tls" = "false" ]] && vm_na="TLS is currently turned off. $ymzs ${yellow} will enable TLS, and Argo tunnel will not support opening ${plain}" || vm_na="The domain name certificate in use: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow switches to turn off TLS, and the Argo tunnel will be available. $plain"
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_na="is not supported. Using self-signed bing certificate $ymzs." || hy2_na="Domain name certificate in use: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow switches to self-signed bing certificate $plain"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_na="is not supported. Using self-signed bing certificate $ymzs." || tu5_na="Domain name certificate in use: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow switches to self-signed bing certificate $plain"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_na="is not supported. Using self-signed bing certificate $ymzs." || an_na="Domain name certificate in use: $(cat /root/ygkkkca/ca.log 2>/dev/null). $yellow switches to self-signed bing certificate $plain"
echo
green "Please select the protocol to switch the certificate mode"
green "1: vless-reality protocol, $vl_na"
if [[ -f /root/ygkkkca/ca.log ]]; then
green "2: vmess-ws protocol, $vm_na"
green "3: Hysteria2 protocol, $hy2_na"
green "4: Tuic5 protocol, $tu5_na"
if [[ "$sbnh" != "1.10" ]]; then
green "5: Anytls protocol, $an_na"
fi
else
red "only supports option 1 (vless-reality). Because the domain name certificate has not been applied for, the certificate switching options for vmess-ws, Hysteria-2, Tuic-v5, and Anytls are temporarily not displayed."
fi
green "0: Return to the upper layer"
readp "Please select:" menu
if [ "$menu" = "1" ]; then
readp "Please enter the vless-reality domain name (enter to use apple.com):" menu
ym_vl_re=${menu:-apple.com}
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.reality.handshake.server')
c=$(cat /etc/s-box/vl_reality.txt | cut -d'=' -f5 | cut -d'&' -f1)
echo $sbfiles | xargs -n1 sed -i "23s/$a/$ym_vl_re/"
echo $sbfiles | xargs -n1 sed -i "27s/$b/$ym_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "The Vless-reality domain name certificate has been replaced."
elif [ "$menu" = "2" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
a=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
[ "$a" = "true" ] && a_a=false || a_a=true
b=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.server_name')
[ "$b" = "www.bing.com" ] && b_b=$(cat /root/ygkkkca/ca.log) || b_b=$(cat /root/ygkkkca/ca.log)
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "55s#$a#$a_a#"
echo $sbfiles | xargs -n1 sed -i "56s#$b#$b_b#"
echo $sbfiles | xargs -n1 sed -i "57s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "58s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "vmess-ws protocol domain name certificate replacement completed"
echo
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
blue "The current port of Vmess-ws (tls): $vm_port"
[[ "$tls" = "false" ]] && blue "Remember: You can enter the main menu option 4-2 and change the Vmess-ws port to any 7 80-series ports (80, 8080, 8880, 2052, 2082, 2086, 2095) to achieve CDN preferred IP" || blue "Remember: You can enter the main menu option 4-2 and change the Vmess-ws-tls port to any 6 443 series ports (443, 8443, 2053, 2083, 2087, 2096) to achieve CDN preferred IP"
echo
else
red "The domain name certificate has not been applied for and cannot be switched. Select 12 from the main menu and execute Acme certificate application" && sleep 2 && sb
fi
elif [ "$menu" = "3" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "79s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "80s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "The domain name certificate of the Hysteria2 protocol has been replaced."
else
red "The domain name certificate has not been applied for and cannot be switched. Select 12 from the main menu and execute Acme certificate application" && sleep 2 && sb
fi
elif [ "$menu" = "4" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "102s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "103s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Tuic5 protocol domain name certificate has been replaced"
else
red "The domain name certificate has not been applied for and cannot be switched. Select 12 from the main menu and execute Acme certificate application" && sleep 2 && sb
fi
elif [ "$menu" = "5" ]; then
if [ -f /root/ygkkkca/ca.log ]; then
c=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.certificate_path')
d=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
if [ "$d" = '/etc/s-box/private.key' ]; then
c_c='/root/ygkkkca/cert.crt'
d_d='/root/ygkkkca/private.key'
else
c_c='/etc/s-box/cert.pem'
d_d='/etc/s-box/private.key'
fi
echo $sbfiles | xargs -n1 sed -i "119s#$c#$c_c#"
echo $sbfiles | xargs -n1 sed -i "120s#$d#$d_d#"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls protocol domain name certificate replacement completed"
else
red "The domain name certificate has not been applied for and cannot be switched. Select 12 from the main menu and execute Acme certificate application" && sleep 2 && sb
fi
else
sb
fi
}

allports(){
vl_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].listen_port')
vm_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')
hy2_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
tu5_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
an_port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].listen_port')
hy2_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$hy2_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
tu5_ports=$(iptables -t nat -nL --line 2>/dev/null | grep -w "$tu5_port" | awk '{print $8}' | sed 's/dpts://; s/dpt://' | tr '\n' ',' | sed 's/,$//')
[[ -n $hy2_ports ]] && hy2zfport="$hy2_ports" || hy2zfport="Not added"
[[ -n $tu5_ports ]] && tu5zfport="$tu5_ports" || tu5zfport="Not added"
}

changeport(){
sbactive
allports
fports(){
readp "\nPlease enter a forwarded port range (in the range of 1000-65535, the format is small number:large number):" rangeport
if [[ $rangeport =~ ^([1-9][0-9]{3,4}:[1-9][0-9]{3,4})$ ]]; then
b=${rangeport%%:*}
c=${rangeport##*:}
if [[ $b -ge 1000 && $b -le 65535 && $c -ge 1000 && $c -le 65535 && $b -lt $c ]]; then
iptables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $rangeport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "Confirmed forwarding port range: $rangeport"
else
red "The entered port range is not within the valid range" && fports
fi
else
red "The input format is incorrect. The format is small number: large number" && fports
fi
echo
}
fport(){
readp "\nPlease enter a forwarded port (in the range of 1000-65535):" onlyport
if [[ $onlyport -ge 1000 && $onlyport -le 65535 ]]; then
iptables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
ip6tables -t nat -A PREROUTING -p udp --dport $onlyport -j DNAT --to-destination :$port
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
blue "Confirmed forwarding port: $onlyport"
else
blue "The entered port is not within the valid range" && fport
fi
echo
}

hy2deports(){
allports
hy2_ports=$(echo "$hy2_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$hy2_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$hy2_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}
tu5deports(){
allports
tu5_ports=$(echo "$tu5_ports" | sed 's/,/,/g')
IFS=',' read -ra ports <<< "$tu5_ports"
for port in "${ports[@]}"; do
iptables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
ip6tables -t nat -D PREROUTING -p udp --dport $port -j DNAT --to-destination :$tu5_port
done
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
}

allports
green "Vless-reality, Vmess-ws, and Anytls can only change the only port. Note the Argo port reset for vmess-ws."
green "Hysteria2 and Tuic5 support changing the main port, and also support adding and deleting multiple forwarding ports."
green "Hysteria2 supports port hopping, and supports multi-port multiplexing with Tuic5."
echo
green "1: Vless-reality protocol ${yellow} port: $vl_port${plain}"
green "2: Vmess-ws protocol ${yellow} port: $vm_port${plain}"
green "3: Hysteria2 protocol ${yellow} port: $hy2_port Forwarding multi-port: $hy2zfport${plain}"
green "4: Tuic5 protocol ${yellow} port: $tu5_port Forward multi-port: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
green "5: Anytls protocol ${yellow} port: $an_port${plain}"
fi
green "0: Return to the upper layer"
readp "Please select the protocol to change the port:" menu
if [ "$menu" = "1" ]; then
vlport
echo $sbfiles | xargs -n1 sed -i "14s/$vl_port/$port_vl_re/"
restartsb && sbshare > /dev/null 2>&1
blue "Vless-reality port change completed"
echo
elif [ "$menu" = "5" ]; then
anport
echo $sbfiles | xargs -n1 sed -i "110s/$an_port/$port_an/"
restartsb && sbshare > /dev/null 2>&1
blue "Anytls port change completed"
echo
elif [ "$menu" = "2" ]; then
vmport
echo $sbfiles | xargs -n1 sed -i "41s/$vm_port/$port_vm_ws/"
restartsb && sbshare > /dev/null 2>&1
blue "Vmess-ws port change completed"
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
blue ". Remember: if Argo is in use, the temporary tunnel must be reset, and the CF setting interface port of the fixed tunnel must be modified to $port_vm_ws"
else
blue "Because TLS is enabled, the current Argo tunnel does not support opening"
fi
echo
elif [ "$menu" = "3" ]; then
green "1: Replace the main port of Hysteria2 (the original multi-port is automatically reset and deleted)"
green "2: Add Hysteria2 multi-port"
green "3: Reset and delete the Hysteria2 multi-port"
green "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
if [ -n $hy2_ports ]; then
hy2deports
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
else
hy2port
echo $sbfiles | xargs -n1 sed -i "67s/$hy2_port/$port_hy2/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Hysteria2 port change is completed."
elif [ "$menu" = "2" ]; then
green "1: Add Hysteria2 range port"
green "2: Add Hysteria2 single port"
green "0: Return to the upper layer"
readp "Please select [0-2]:" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $hy2_ports ]; then
hy2deports && sbshare > /dev/null 2>&1 && changeport
else
yellow "Hysteria2 has not set up multiple ports." && changeport
fi
else
changeport
fi

elif [ "$menu" = "4" ]; then
green "1: Replace Tuic5 main port (original multi-port automatic reset and delete)"
green "2: Add Tuic5 multi-port"
green "3: Reset and delete Tuic5 multi-port"
green "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
if [ -n $tu5_ports ]; then
tu5deports
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
else
tu5port
echo $sbfiles | xargs -n1 sed -i "89s/$tu5_port/$port_tu/"
restartsb && sbshare > /dev/null 2>&1
fi
blue "Tuic5 port change completed"
elif [ "$menu" = "2" ]; then
green "1: Add Tuic5 range port"
green "2: Add Tuic5 single port"
green "0: Return to the upper layer"
readp "Please select [0-2]:" menu
port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].listen_port')
if [ "$menu" = "1" ]; then
fports && sbshare > /dev/null 2>&1 && changeport
elif [ "$menu" = "2" ]; then
fport && sbshare > /dev/null 2>&1 && changeport
else
changeport
fi
elif [ "$menu" = "3" ]; then
if [ -n $tu5_ports ]; then
tu5deports && sbshare > /dev/null 2>&1 && changeport
else
yellow "Tuic5 has not set up multiple ports" && changeport
fi
else
changeport
fi
else
sb
fi
}

changeuuid(){
echo
olduuid=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')
oldvmpath=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')
green "Full protocol uuid (password): $olduuid"
green "Vmess path: $oldvmpath"
echo
yellow "1: Customize the uuid (password) of the full protocol"
yellow "2: Customize the path of Vmess"
yellow "0: Return to the upper layer"
readp "Please select [0-2]:" menu
if [ "$menu" = "1" ]; then
readp "Enter uuid, which must be in uuid format. If you do not understand, press Enter (reset and randomly generate uuid):" menu
if [ -z "$menu" ]; then
uuid=$(/etc/s-box/sing-box generate uuid)
else
uuid=$menu
fi
echo $sbfiles | xargs -n1 sed -i "s/$olduuid/$uuid/g"
restartsb && sbshare > /dev/null 2>&1
blue "Confirmed uuid (password): ${uuid}" 
blue "The path of Vmess has been confirmed: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
elif [ "$menu" = "2" ]; then
readp "Enter the path of Vmess, and press Enter to indicate unchanged:" menu
if [ -z "$menu" ]; then
echo
else
vmpath=$menu
echo $sbfiles | xargs -n1 sed -i "50s#$oldvmpath#$vmpath#g"
restartsb && sbshare > /dev/null 2>&1
fi
blue "The path of Vmess has been confirmed: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')"
else
changeserv
fi
}

listusers(){
echo
green "Current user list:"
echo
local i=1
while read -r user_uuid; do
if [[ -n "$user_uuid" ]]; then
echo -e "  ${yellow}$i${plain}. UUID: ${blue}$user_uuid${plain}"
((i++))
fi
done < <(jq -r '.inbounds[0].users[].uuid' /etc/s-box/sb.json 2>/dev/null)
echo
local total
total=$(jq '.inbounds[0].users | length' /etc/s-box/sb.json 2>/dev/null)
blue "Total users: $total"
echo
}

genuserlinks(){
local user_uuid=$1
if [[ -z "$user_uuid" ]]; then
red "UUID not provided"
return 1
fi

local exists
exists=$(jq -r --arg uuid "$user_uuid" '.inbounds[0].users[] | select(.uuid == $uuid) | .uuid' /etc/s-box/sb.json 2>/dev/null)
if [[ -z "$exists" ]]; then
red "UUID not found"
return 1
fi

local server_ip
server_ip=$(curl -s4m5 ip.sb 2>/dev/null || curl -s6m5 ip.sb 2>/dev/null)
local hostname
hostname=$(hostname)
local vl_port vm_port hy2_port tu5_port an_port
local vl_name vm_name hy2_name tu5_name an_name
local public_key short_id ws_path tls
local hy2_key_path tu5_key_path an_key_path
local ins_hy2=1 ins_tu5=1 ins_an=1
local sb_hy2_ip sb_tu5_ip sb_an_ip
local v6test vm_link vl_link hy2_link tu5_link an_link aggr_links aggr_base64

vl_port=$(jq -r '.inbounds[0].listen_port' /etc/s-box/sb.json)
vm_port=$(jq -r '.inbounds[1].listen_port' /etc/s-box/sb.json)
hy2_port=$(jq -r '.inbounds[2].listen_port' /etc/s-box/sb.json)
tu5_port=$(jq -r '.inbounds[3].listen_port' /etc/s-box/sb.json)
an_port=$(jq -r '.inbounds[4].listen_port // empty' /etc/s-box/sb.json)
vl_name=$(jq -r '.inbounds[0].tls.server_name' /etc/s-box/sb.json)
vm_name=$(jq -r '.inbounds[1].tls.server_name' /etc/s-box/sb.json)
hy2_name=$(jq -r '.inbounds[2].tls.server_name' /etc/s-box/sb.json)
tu5_name=$(jq -r '.inbounds[3].tls.server_name' /etc/s-box/sb.json)
an_name=$(jq -r '.inbounds[4].tls.server_name // empty' /etc/s-box/sb.json)
public_key=$(cat /etc/s-box/public.key 2>/dev/null)
short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' /etc/s-box/sb.json)
ws_path=$(jq -r '.inbounds[1].transport.path' /etc/s-box/sb.json)
tls=$(jq -r '.inbounds[1].tls.enabled' /etc/s-box/sb.json)
hy2_key_path=$(jq -r '.inbounds[2].tls.key_path' /etc/s-box/sb.json)
tu5_key_path=$(jq -r '.inbounds[3].tls.key_path' /etc/s-box/sb.json)
an_key_path=$(jq -r '.inbounds[4].tls.key_path // empty' /etc/s-box/sb.json)

[[ "$hy2_key_path" = '/etc/s-box/private.key' ]] && ins_hy2=0
[[ "$tu5_key_path" = '/etc/s-box/private.key' ]] && ins_tu5=0
[[ "$an_key_path" = '/etc/s-box/private.key' ]] && ins_an=0

v6test=$(curl -s6m5 ip.sb 2>/dev/null)
if [[ -n "$v6test" ]]; then
sb_hy2_ip="[$server_ip]"
sb_tu5_ip="[$server_ip]"
sb_an_ip="[$server_ip]"
else
sb_hy2_ip="$server_ip"
sb_tu5_ip="$server_ip"
sb_an_ip="$server_ip"
fi

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "Share links for user: $user_uuid"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo
red "🚀[ Vless-reality-vision ]"
vl_link="vless://$user_uuid@$server_ip:$vl_port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$vl_name&fp=chrome&pbk=$public_key&sid=$short_id&type=tcp&headerType=none#vl-reality-$hostname"
echo -e "${yellow}$vl_link${plain}"
echo

red "🚀[ Vmess-ws ]"
if [[ "$tls" = "true" ]]; then
vm_link="vmess://$(echo '{"add":"'$server_ip'","aid":"0","host":"'$vm_name'","id":"'$user_uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-tls-$hostname'","tls":"tls","sni":"'$vm_name'","type":"none","v":"2"}' | base64 -w 0)"
else
vm_link="vmess://$(echo '{"add":"'$server_ip'","aid":"0","host":"'$vm_name'","id":"'$user_uuid'","net":"ws","path":"'$ws_path'","port":"'$vm_port'","ps":"'vm-ws-$hostname'","tls":"","type":"none","v":"2"}' | base64 -w 0)"
fi
echo -e "${yellow}$vm_link${plain}"
echo

red "🚀[ Hysteria-2 ]"
hy2_link="hysteria2://$user_uuid@$sb_hy2_ip:$hy2_port?security=tls&alpn=h3&insecure=$ins_hy2&sni=$hy2_name#hy2-$hostname"
echo -e "${yellow}$hy2_link${plain}"
echo

red "🚀[ Tuic-v5 ]"
tu5_link="tuic://$user_uuid:$user_uuid@$sb_tu5_ip:$tu5_port?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=$tu5_name&allow_insecure=$ins_tu5&allowInsecure=$ins_tu5#tu5-$hostname"
echo -e "${yellow}$tu5_link${plain}"
echo

aggr_links="$vl_link
$vm_link
$hy2_link
$tu5_link"

if jq -e '.inbounds[4].type == "anytls"' /etc/s-box/sb.json >/dev/null 2>&1; then
red "🚀[ AnyTLS ]"
an_link="anytls://$user_uuid@$sb_an_ip:$an_port?&sni=$an_name&allowInsecure=$ins_an#anytls-$hostname"
echo -e "${yellow}$an_link${plain}"
echo
aggr_links="$aggr_links
$an_link"
fi

white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "QR codes:"
echo
green "Vless-reality QR code:"
qrencode -o - -t ANSIUTF8 "$vl_link"
echo
green "Vmess-ws QR code:"
qrencode -o - -t ANSIUTF8 "$vm_link"
echo
green "Hysteria2 QR code:"
qrencode -o - -t ANSIUTF8 "$hy2_link"
echo
green "Tuic5 QR code:"
qrencode -o - -t ANSIUTF8 "$tu5_link"
if [[ -n "$an_link" ]]; then
echo
green "AnyTLS QR code:"
qrencode -o - -t ANSIUTF8 "$an_link"
fi
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀[ Aggregated subscription ] for user: $user_uuid"
echo
aggr_base64=$(echo -e "$aggr_links" | base64 -w 0)
echo "Aggregated share link (base64):"
echo -e "${yellow}$aggr_base64${plain}"
echo
green "Aggregated subscription QR code:"
qrencode -o - -t ANSIUTF8 "$aggr_base64"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
}

adduser(){
sbactive
echo
green "Add a new user for all configured protocols"
echo
readp "Enter UUID (press Enter to auto-generate): " new_uuid
if [[ -z "$new_uuid" ]]; then
new_uuid=$(/etc/s-box/sing-box generate uuid)
blue "Generated UUID: $new_uuid"
fi

if [[ ! "$new_uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
red "Invalid UUID format. Expected: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
return 1
fi

local exists
exists=$(jq -r --arg uuid "$new_uuid" '.inbounds[0].users[] | select(.uuid == $uuid) | .uuid' /etc/s-box/sb.json 2>/dev/null)
if [[ -n "$exists" ]]; then
red "UUID already exists"
return 1
fi

local num tmp_file
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
tmp_file=$(mktemp)

jq --arg uuid "$new_uuid" '.inbounds[0].users += [{"uuid": $uuid, "flow": "xtls-rprx-vision"}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[1].users += [{"uuid": $uuid, "alterId": 0}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[2].users += [{"password": $uuid}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$new_uuid" '.inbounds[3].users += [{"uuid": $uuid, "password": $uuid}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
if jq -e '.inbounds[4].type == "anytls"' /etc/s-box/sb.json >/dev/null 2>&1; then
jq --arg uuid "$new_uuid" '.inbounds[4].users += [{"password": $uuid}]' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
fi

cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

green "User added successfully"
restartsb
genuserlinks "$new_uuid"
}

deluser(){
sbactive
listusers

local total
total=$(jq '.inbounds[0].users | length' /etc/s-box/sb.json 2>/dev/null)
if [[ "$total" -le 1 ]]; then
red "Cannot delete the last remaining user"
return 1
fi

readp "Enter UUID to delete: " del_uuid
if [[ -z "$del_uuid" ]]; then
red "UUID not provided"
return 1
fi

local exists
exists=$(jq -r --arg uuid "$del_uuid" '.inbounds[0].users[] | select(.uuid == $uuid) | .uuid' /etc/s-box/sb.json 2>/dev/null)
if [[ -z "$exists" ]]; then
red "UUID not found"
return 1
fi

local num tmp_file
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
tmp_file=$(mktemp)

jq --arg uuid "$del_uuid" 'del(.inbounds[0].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[1].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[2].users[] | select(.password == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
jq --arg uuid "$del_uuid" 'del(.inbounds[3].users[] | select(.uuid == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
if jq -e '.inbounds[4].type == "anytls"' /etc/s-box/sb.json >/dev/null 2>&1; then
jq --arg uuid "$del_uuid" 'del(.inbounds[4].users[] | select(.password == $uuid))' /etc/s-box/sb.json > "$tmp_file" && mv "$tmp_file" /etc/s-box/sb.json
fi

cp /etc/s-box/sb.json /etc/s-box/sb${num}.json

green "User deleted successfully"
restartsb
}

manageusers(){
sbactive
echo
green "User management"
yellow "1: Add new user"
yellow "2: Delete user"
yellow "3: List all users"
yellow "4: Generate share links for a specific user"
yellow "0: Return to the main menu"
readp "Please select [0-4]: " menu

case "$menu" in
1 ) adduser ;;
2 ) deluser ;;
3 ) listusers ;;
4 )
listusers
readp "Enter UUID: " show_uuid
if [[ -n "$show_uuid" ]]; then
genuserlinks "$show_uuid"
fi
;;
0 ) sb ;;
* ) manageusers ;;
esac
}

changeip(){
if [[ "$sbnh" == "1.10" ]]; then
v4v6
chip(){
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy')
sed -i "111s/$rpip/$rrpip/g" /etc/s-box/sb10.json
cp /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
}
readp "1. IPV4 priority\n2. IPV6 priority\n3. IPV4 only\n4. IPV6 only\nPlease select:" choose
if [[ $choose == "1" && -n $v4 ]]; then
rrpip="prefer_ipv4" && chip && v4_6="IPV4 priority ($v4)"
elif [[ $choose == "2" && -n $v6 ]]; then
rrpip="prefer_ipv6" && chip && v4_6="IPV6 priority ($v6)"
elif [[ $choose == "3" && -n $v4 ]]; then
rrpip="ipv4_only" && chip && v4_6="IPV4 only ($v4)"
elif [[ $choose == "4" && -n $v6 ]]; then
rrpip="ipv6_only" && chip && v4_6="IPV6 outbound only ($v6)"
else 
red "The IPV4/IPV6 address you selected does not currently exist, or the input is incorrect." && changeip
fi
blue "The current IP priority has been changed: ${v4_6}" && sb
else
red "only supports 1.10.7 kernel available" && exit
fi
}

tgsbshow(){
echo
yellow "1: Reset/set the Token and user ID of the Telegram robot"
yellow "0: Return to the upper layer"
readp "Please select [0-1]:" menu
if [ "$menu" = "1" ]; then
rm -rf /etc/s-box/sbtg.sh
readp "Enter the Telegram robot Token:" token
telegram_token=$token
readp "Enter the Telegram robot user ID:" userid
telegram_id=$userid
echo '#!/bin/bash
export LANG=en_US.UTF-8
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
total_lines=$(wc -l < /etc/s-box/clmi.yaml)
half=$((total_lines / 2))
head -n $half /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client1.txt
tail -n +$((half + 1)) /etc/s-box/clmi.yaml > /etc/s-box/clash_meta_client2.txt

total_lines=$(wc -l < /etc/s-box/sbox.json)
quarter=$((total_lines / 4))
head -n $quarter /etc/s-box/sbox.json > /etc/s-box/sing_box_client1.txt
tail -n +$((quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client2.txt
tail -n +$((2 * quarter + 1)) /etc/s-box/sbox.json | head -n $quarter > /etc/s-box/sing_box_client3.txt
tail -n +$((3 * quarter + 1)) /etc/s-box/sbox.json > /etc/s-box/sing_box_client4.txt

m1=$(cat /etc/s-box/vl_reality.txt 2>/dev/null)
m2=$(cat /etc/s-box/vm_ws.txt 2>/dev/null)
m3=$(cat /etc/s-box/vm_ws_argols.txt 2>/dev/null)
m3_5=$(cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null)
m4=$(cat /etc/s-box/vm_ws_tls.txt 2>/dev/null)
m5=$(cat /etc/s-box/hy2.txt 2>/dev/null)
m6=$(cat /etc/s-box/tuic5.txt 2>/dev/null)
m7=$(cat /etc/s-box/sing_box_client1.txt 2>/dev/null)
m7_5=$(cat /etc/s-box/sing_box_client2.txt 2>/dev/null)
m7_5_5=$(cat /etc/s-box/sing_box_client3.txt 2>/dev/null)
m7_5_5_5=$(cat /etc/s-box/sing_box_client4.txt 2>/dev/null)
m8=$(cat /etc/s-box/clash_meta_client1.txt 2>/dev/null)
m8_5=$(cat /etc/s-box/clash_meta_client2.txt 2>/dev/null)
m9=$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)
m10=$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)
m11=$(cat /etc/s-box/jhsub.txt 2>/dev/null)
m12=$(cat /etc/s-box/an.txt 2>/dev/null)
message_text_m1=$(echo "$m1")
message_text_m2=$(echo "$m2")
message_text_m3=$(echo "$m3")
message_text_m3_5=$(echo "$m3_5")
message_text_m4=$(echo "$m4")
message_text_m5=$(echo "$m5")
message_text_m6=$(echo "$m6")
message_text_m7=$(echo "$m7")
message_text_m7_5=$(echo "$m7_5")
message_text_m7_5_5=$(echo "$m7_5_5")
message_text_m7_5_5_5=$(echo "$m7_5_5_5")
message_text_m8=$(echo "$m8")
message_text_m8_5=$(echo "$m8_5")
message_text_m9=$(echo "$m9")
message_text_m10=$(echo "$m10")
message_text_m11=$(echo "$m11")
message_text_m12=$(echo "$m12")
MODE=HTML
URL="https://api.telegram.org/bottelegram_token/sendMessage"
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vless-reality-vision share link 】: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m1}")
if [[ -f /etc/s-box/vm_ws.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws sharing link 】: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m2}")
fi
if [[ -f /etc/s-box/vm_ws_argols.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo temporary domain name sharing link】: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m3}")
fi
if [[ -f /etc/s-box/vm_ws_argogd.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws(tls)+Argo fixed domain name sharing link】: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m3_5}")
fi
if [[ -f /etc/s-box/vm_ws_tls.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Vmess-ws-tls sharing link 】: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m4}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀[Hysteria-2 Share link ]: Support v2rayng, nekobox"$'"'"'\n\n'"'"'"${message_text_m5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Tuic-v5 share link 】: Support nekobox"$'"'"'\n\n'"'"'"${message_text_m6}")
if [[ "$sbnh" != "1.10" ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀[Anytls sharing link]: only the latest kernel is available"$'"'"'\n\n'"'"'"${message_text_m12}")
fi
if [[ -f /etc/s-box/sing_box_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀[ Sing-box subscription link 】: Support SFA, SFW, SFI"$'"'"'\n\n'"'"'"${message_text_m9}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Sing-box configuration file (4 paragraphs) 】: Support SFA, SFW, SFI"$'"'"'\n\n'"'"'"${message_text_m7}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m7_5_5_5}")
fi

if [[ -f /etc/s-box/clash_meta_gitlab.txt ]]; then
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀[ Mihomo subscription link ]: Support Mihomo related client"$'"'"'\n\n'"'"'"${message_text_m10}")
else
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀[ Mihomo configuration file (2 paragraphs) ]: Support Mihomo related client"$'"'"'\n\n'"'"'"${message_text_m8}")
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=${message_text_m8_5}")
fi
res=$(timeout 20s curl -s -X POST $URL -d chat_id=telegram_id  -d parse_mode=${MODE} --data-urlencode "text=🚀【 Aggregation node 】: Support nekobox"$'"'"'\n\n'"'"'"${message_text_m11}")

if [ $? == 124 ];then
echo TG_api request timed out, please check whether the network restart is complete and whether you can access TG
fi
resSuccess=$(echo "$res" | jq -r ".ok")
if [[ $resSuccess = "true" ]]; then
echo "TG push is successful";
else
echo "TG push failed, please check TG robot Token and ID";
fi
' > /etc/s-box/sbtg.sh
sed -i "s/telegram_token/$telegram_token/g" /etc/s-box/sbtg.sh
sed -i "s/telegram_id/$telegram_id/g" /etc/s-box/sbtg.sh
green "Setup completed! Please make sure the TG robot is activated!"
tgnotice
else
changeserv
fi
}

tgnotice(){
if [[ -f /etc/s-box/sbtg.sh ]]; then
green "Please wait for 5 seconds, the TG robot is ready to push..."
sbshare > /dev/null 2>&1
bash /etc/s-box/sbtg.sh
else
yellow "TG notification function is not set up"
fi
exit
}

changeserv(){
sbactive
echo
green "The Sing-box configuration change options are as follows:"
readp "1: Change the Reality domain name camouflage address, switch between self-signed certificate and Acme domain name certificate, switch TLS\n2: Change the full protocol UUID (password), Vmess-Path path\n3: Set up Argo temporary tunnel, fixed tunnel\n4: Switch the proxy priority of IPV4 or IPV6 (only 1.10.7 Kernel available)\n5: Set up Telegram push node notification\n6: Change Warp-wireguard outbound account\n7: Set up Gitlab subscription sharing link\n8: Set up local IP subscription sharing link\n9: Set CDN preferred address of all Vmess nodes\n0: Return to the upper layer\nPlease select [0-9]:" menu
if [ "$menu" = "1" ];then
changeym
elif [ "$menu" = "2" ];then
changeuuid
elif [ "$menu" = "3" ];then
cfargo_ym
elif [ "$menu" = "4" ];then
changeip
elif [ "$menu" = "5" ];then
tgsbshow
elif [ "$menu" = "6" ];then
changewg
elif [ "$menu" = "7" ];then
gitlabsub
elif [ "$menu" = "8" ];then
ipsub
elif [ "$menu" = "9" ];then
vmesscfadd
else 
sb
fi
}

ipsub(){
subtokenipsub(){
echo
readp "Enter the subscription link path password (Press Enter means use the current UUID):" menu
if [ -z "$menu" ]; then
subtoken="$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')"
else
subtoken="$menu"
fi
rm -rf /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
echo $subtoken > /etc/s-box/subtoken.log
green "Subscription link path password: $(cat /etc/s-box/subtoken.log 2>/dev/null)"
}
subportipsub(){
echo
readp "Enter an unoccupied and available subscription link port (Enter indicates a random port):" menu
if [ -z "$menu" ]; then
subport=$(shuf -i 10000-65535 -n 1)
else
subport="$menu"
fi
echo $subport > /etc/s-box/subport.log
green "Subscription link port: $(cat /etc/s-box/subport.log 2>/dev/null)"
}
echo
yellow "1: Reset the installation local IP subscription link"
yellow "2: Change the subscription link path password"
yellow "3: Change the subscription link port"
yellow "4: Uninstall local IP subscription link"
yellow "0: Return to the upper layer"
readp "Please select [0-4]:" menu
if [ "$menu" = "1" ]; then
subtokenipsub && subportipsub
elif [ "$menu" = "2" ];then
subtokenipsub
elif [ "$menu" = "3" ];then
subportipsub
elif [ "$menu" = "4" ];then
ps -ef | grep "$(cat /etc/s-box/subport.log 2>/dev/null)" | grep -v grep | awk 'NR==1 {print $2}' | xargs kill 2>/dev/null
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/httpd -f -p/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /root/websbox
rm -rf /etc/local.d/alpinesub.start
green "The local IP subscription link has been uninstalled" && sleep 3 && exit
else
changeserv
fi
echo
green "Please wait..."
ps -ef | grep "$(cat /etc/s-box/subport.log 2>/dev/null)" | grep -v grep | awk 'NR==1 {print $2}' | xargs kill 2>/dev/null
mkdir -p /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"
ln -sf /etc/s-box/clmi.yaml /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/clmi.yaml
ln -sf /etc/s-box/sbox.json /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/sbox.json
ln -sf /etc/s-box/jhsub.txt /root/websbox/"$(cat /etc/s-box/subtoken.log 2>/dev/null)"/jhsub.txt
if command -v apk >/dev/null 2>&1; then
busybox-extras httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
else
busybox httpd -f -p "$(cat /etc/s-box/subport.log 2>/dev/null)" -h /root/websbox > /dev/null 2>&1 &
fi
sleep 5
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinesub.start <<'EOF'
#!/bin/bash
sleep 10
busybox-extras httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &
EOF
chmod +x /etc/local.d/alpinesub.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/httpd -f -p/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "busybox httpd -f -p $(cat /etc/s-box/subport.log 2>/dev/null) -h /root/websbox > /dev/null 2>&1 &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
sbshare > /dev/null 2>&1
sleep 1 && green "The local IP subscription link has been updated" && sleep 3 && sb
}

vmesscfadd(){
echo
green "recommends using the stable official CDN domain name of a major world manufacturer or organization as the preferred CDN address:"
blue "www.visa.com.sg"
blue "www.wto.org"
blue "www.web.com"
blue "yg1.ygkkk.dpdns.org (1 in yg1 can be replaced by any number from 1-11, maintained by Brother Yong)"
echo
yellow "1: Customize the CDN preferred address of the Vmess-ws (tls) main protocol node"
yellow "2: For option 1, reset the client host/sni domain name (IP resolves to the domain name on CF)"
yellow "3: Customize the CDN preferred address of Vmess-ws(tls)-Argo node"
yellow "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
echo
green "Please ensure that the IP of the VPS has been resolved to the Cloudflare domain name"
if [[ ! -f /etc/s-box/cfymjx.txt ]] 2>/dev/null; then
readp "Enter the client host/sni domain name (IP is resolved to the domain name on CF):" menu
echo "$menu" > /etc/s-box/cfymjx.txt
fi
echo
readp "Enter the custom preferred IP/domain name:" menu
echo "$menu" > /etc/s-box/cfvmadd_local.txt
green "The setting is successful, select main menu 9 to update the node configuration" && sleep 2 && vmesscfadd
elif  [ "$menu" = "2" ]; then
rm -rf /etc/s-box/cfymjx.txt
green "Reset successfully, you can choose 1 to reset" && sleep 2 && vmesscfadd
elif  [ "$menu" = "3" ]; then
readp "Enter the custom preferred IP/domain name:" menu
echo "$menu" > /etc/s-box/cfvmadd_argo.txt
green "The setting is successful, select main menu 9 to update the node configuration" && sleep 2 && vmesscfadd
else
changeserv
fi
}

gitlabsub(){
echo
green "Please ensure that the project has been established on the Gitlab official website, the push function has been enabled, and the access token has been obtained"
yellow "1: Reset/set the Gitlab subscription link"
yellow "0: Return to the upper layer"
readp "Please select [0-1]:" menu
if [ "$menu" = "1" ]; then
cd /etc/s-box
readp "Enter the login email:" email
readp "Enter the access token:" token
readp "Enter the user name:" userid
readp "Enter the project name:" project
echo
green "Multiple VPSs share one token and project name, and multiple branch subscription links can be created"
green "Press Enter to skip to mean no new creation, only use the main branch main subscription link (it is recommended to press Enter to skip for the first VPS)"
readp "New branch name:" gitlabml
echo
if [[ -z "$gitlabml" ]]; then
gitlab_ml=''
git_sk=main
rm -rf /etc/s-box/gitlab_ml_ml
else
gitlab_ml=":${gitlabml}"
git_sk="${gitlabml}"
echo "${gitlab_ml}" > /etc/s-box/gitlab_ml_ml
fi
echo "$token" > /etc/s-box/gitlabtoken.txt
rm -rf /etc/s-box/.git
git init >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git config --global user.email "${email}" >/dev/null 2>&1
git config --global user.name "${userid}" >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
branches=$(git branch)
if [[ $branches == *master* ]]; then
git branch -m master main >/dev/null 2>&1
fi
git remote add origin https://${token}@gitlab.com/${userid}/${project}.git >/dev/null 2>&1
if [[ $(ls -a | grep '^\.git$') ]]; then
cat > /etc/s-box/gitpush.sh <<EOF
#!/usr/bin/expect
spawn bash -c "git push -f origin main${gitlab_ml}"
expect "Password for 'https://$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)@gitlab.com':"
send "$(cat /etc/s-box/gitlabtoken.txt 2>/dev/null)\r"
interact
EOF
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/sbox.json/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/sing_box_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/clmi.yaml/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/clash_meta_gitlab.txt
echo "https://gitlab.com/api/v4/projects/${userid}%2F${project}/repository/files/jhsub.txt/raw?ref=${git_sk}&private_token=${token}" > /etc/s-box/jh_sub_gitlab.txt
clsbshow
else
yellow "Failed to set up the Gitlab subscription link, please give feedback"
fi
cd
else
changeserv
fi
}

gitlabsubgo(){
cd /etc/s-box
if [[ $(ls -a | grep '^\.git$') ]]; then
if [ -f /etc/s-box/gitlab_ml_ml ]; then
gitlab_ml=$(cat /etc/s-box/gitlab_ml_ml)
fi
git rm --cached sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_rm_$(date +"%F %T")" >/dev/null 2>&1
git add sbox.json clmi.yaml jhsub.txt >/dev/null 2>&1
git commit -m "commit_add_$(date +"%F %T")" >/dev/null 2>&1
chmod +x gitpush.sh
./gitpush.sh "git push -f origin main${gitlab_ml}" cat /etc/s-box/gitlabtoken.txt >/dev/null 2>&1
clsbshow
else
yellow "Gitlab subscription link is not set up"
fi
cd
}

clsbshow(){
green "The current Sing-box node has been updated and pushed"
green "The Sing-box subscription link is as follows:"
blue "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
green "The Sing-box subscription link QR code is as follows:"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/sing_box_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "Current Mihomo node configuration has been updated and pushed"
green "Mihomo subscription link is as follows:"
blue "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
green "Mihomo subscription link QR code is as follows:"
qrencode -o - -t ANSIUTF8 "$(cat /etc/s-box/clash_meta_gitlab.txt 2>/dev/null)"
echo
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
green "The current aggregation node configuration has been updated and pushed"
green "The subscription link is as follows:"
blue "$(cat /etc/s-box/jh_sub_gitlab.txt 2>/dev/null)"
echo
yellow "You can enter the subscription link on the web page to view the configuration content. If there is no configuration content, please self-check Gitlab related settings and reset"
echo
}

warpwg(){
warpcode(){
reg(){
keypair=$(openssl genpkey -algorithm X25519 | openssl pkey -text -noout)
private_key=$(echo "$keypair" | awk '/priv:/{flag=1; next} /pub:/{flag=0} flag' | tr -d '[:space:]' | xxd -r -p | base64)
public_key=$(echo "$keypair" | awk '/pub:/{flag=1} flag' | tr -d '[:space:]' | xxd -r -p | base64)
response=$(curl -sL --tlsv1.3 --connect-timeout 3 --max-time 5 \
-X POST 'https://api.cloudflareclient.com/v0a2158/reg' \
-H 'CF-Client-Version: a-7.21-0721' \
-H 'Content-Type: application/json' \
-d '{
"key": "'"$public_key"'",
"tos": "'"$(date -u +'%Y-%m-%dT%H:%M:%S.000Z')"'"
}')
if [ -z "$response" ]; then
return 1
fi
echo "$response" | python3 -m json.tool 2>/dev/null | sed "/\"account_type\"/i\         \"private_key\": \"$private_key\","
}
reserved(){
reserved_str=$(echo "$warp_info" | grep 'client_id' | cut -d\" -f4)
reserved_hex=$(echo "$reserved_str" | base64 -d | xxd -p)
reserved_dec=$(echo "$reserved_hex" | fold -w2 | while read HEX; do printf '%d ' "0x${HEX}"; done | awk '{print "["$1", "$2", "$3"]"}')
echo -e "{\n    \"reserved_dec\": $reserved_dec,"
echo -e "    \"reserved_hex\": \"0x$reserved_hex\","
echo -e "    \"reserved_str\": \"$reserved_str\"\n}"
}
result() {
echo "$warp_reserved" | grep -P "reserved" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/:\[/: \[/g' | sed 's/\([0-9]\+\),\([0-9]\+\),\([0-9]\+\)/\1, \2, \3/' | sed 's/^"/    "/g' | sed 's/"$/",/g'
echo "$warp_info" | grep -P "(private_key|public_key|\"v4\": \"172.16.0.2\"|\"v6\": \"2)" | sed "s/ //g" | sed 's/:"/: "/g' | sed 's/^"/    "/g'
echo "}"
}
warp_info=$(reg) 
warp_reserved=$(reserved) 
result
}
output=$(warpcode)
if ! echo "$output" 2>/dev/null | grep -w "private_key" > /dev/null; then
v6=2606:4700:110:860e:738f:b37:f15:d38d
pvk=g9I2sgUH6OCbIBTehkEfVEnuvInHYZvPOFhWchMLSc4=
res=[33,217,129]
else
pvk=$(echo "$output" | sed -n 4p | awk '{print $2}' | tr -d ' "' | sed 's/.$//')
v6=$(echo "$output" | sed -n 7p | awk '{print $2}' | tr -d ' "')
res=$(echo "$output" | sed -n 1p | awk -F":" '{print $NF}' | tr -d ' ' | sed 's/.$//')
fi
blue "Private_key private key: $pvk"
blue "IPV6 address: $v6"
blue "reserved value: $res"
}

changewg(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
if [[ "$sbnh" == "1.10" ]]; then
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .local_address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .private_key')
wgres=$(sed -n '165s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "wireguard") | .server_port')
else
wgipv6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .address[1] | split("/")[0]')
wgprkey=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .private_key')
wgres=$(sed -n '142s/.*\[\(.*\)\].*/\1/p' /etc/s-box/sb.json)
wgip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].address')
wgpo=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.endpoints[] | .peers[].port')
fi
echo
green "The current parameters that can be replaced by warp-wireguard are as follows:"
green "Private_key private key: $wgprkey"
green "IPV6 address: $wgipv6"
green "Reserved value: $wgres"
green "Peer IP: $wgip:$wgpo"
echo
yellow "1: Replace warp-wireguard account"
yellow "0: Return to the upper layer"
readp "Please select [0-1]:" menu
if [ "$menu" = "1" ]; then
green "The latest randomly generated ordinary warp-wireguard account is as follows"
warpwg
echo
readp "Enter the custom Private_key:" menu
sed -i "163s#$wgprkey#$menu#g" /etc/s-box/sb10.json
sed -i "132s#$wgprkey#$menu#g" /etc/s-box/sb11.json
readp "Enter the custom IPV6 address:" menu
sed -i "161s/$wgipv6/$menu/g" /etc/s-box/sb10.json
sed -i "130s/$wgipv6/$menu/g" /etc/s-box/sb11.json
readp "Enter the custom Reserved value (format: number, number, number). If there is no value, press Enter to skip:" menu
if [ -z "$menu" ]; then
menu=0,0,0
fi
sed -i "165s/$wgres/$menu/g" /etc/s-box/sb10.json
sed -i "142s/$wgres/$menu/g" /etc/s-box/sb11.json
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
green "The setting is completed"
else
changeserv
fi
}

sbymfl(){
sbport=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}' | awk -F":" '{print $NF}') 
sbport=${sbport:-'40000'}
resv1=$(curl -sm3 --socks5 localhost:$sbport icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$sbport icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
warp_s4_ip='Socks5-IPV4 is not started, blacklist mode'
warp_s6_ip='Socks5-IPV6 is not started, blacklist mode'
else
warp_s4_ip='Socks5-IPV4 is available'
warp_s6_ip='Socks5-IPV6 self-test'
fi
v4v6
if [[ -z $v4 ]]; then
vps_ipv4='No local IPV4, blacklist mode'      
vps_ipv6="Current IP: $v6"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="Current IP: $v4"    
vps_ipv6="Current IP: $v6"
else
vps_ipv4="Current IP: $v4"    
vps_ipv6='No local IPV6, blacklist mode'
fi
unset swg4 swd4 swd6 swg6 ssd4 ssg4 ssd6 ssg6 sad4 sag4 sad6 sag6
wd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].domain_suffix | join(" ")')
wg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[1].geosite | join(" ")' 2>/dev/null)
if [[ "$wd4" == "yg_kkk" && ("$wg4" == "yg_kkk" || -z "$wg4") ]]; then
wfl4="${yellow} [warp outbound IPV4 available] Not diverted ${plain}"
else
if [[ "$wd4" != "yg_kkk" ]]; then
swd4="$wd4 "
fi
if [[ "$wg4" != "yg_kkk" ]]; then
swg4=$wg4
fi
wfl4="${yellow} [warp outbound IPV4 available] Offloaded: $swd4$swg4${plain}"
fi

wd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].domain_suffix | join(" ")')
wg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[2].geosite | join(" ")' 2>/dev/null)
if [[ "$wd6" == "yg_kkk" && ("$wg6" == "yg_kkk"|| -z "$wg6") ]]; then
wfl6="${yellow} [warp outbound IPV6 self-test] Not diverted ${plain}"
else
if [[ "$wd6" != "yg_kkk" ]]; then
swd6="$wd6 "
fi
if [[ "$wg6" != "yg_kkk" ]]; then
swg6=$wg6
fi
wfl6="${yellow} [warp outbound IPV6 self-test] Offloaded: $swd6$swg6${plain}"
fi

sd4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].domain_suffix | join(" ")')
sg4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[3].geosite | join(" ")' 2>/dev/null)
if [[ "$sd4" == "yg_kkk" && ("$sg4" == "yg_kkk" || -z "$sg4") ]]; then
sfl4="${yellow}【$warp_s4_ip】Not routed${plain}"
else
if [[ "$sd4" != "yg_kkk" ]]; then
ssd4="$sd4 "
fi
if [[ "$sg4" != "yg_kkk" ]]; then
ssg4=$sg4
fi
sfl4="${yellow}【$warp_s4_ip】Shunted: $ssd4$ssg4${plain}"
fi

sd6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].domain_suffix | join(" ")')
sg6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[4].geosite | join(" ")' 2>/dev/null)
if [[ "$sd6" == "yg_kkk" && ("$sg6" == "yg_kkk" || -z "$sg6") ]]; then
sfl6="${yellow} [$warp_s6_ip] Not diverted ${plain}"
else
if [[ "$sd6" != "yg_kkk" ]]; then
ssd6="$sd6 "
fi
if [[ "$sg6" != "yg_kkk" ]]; then
ssg6=$sg6
fi
sfl6="${yellow}【$warp_s6_ip】Shunted: $ssd6$ssg6${plain}"
fi

ad4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].domain_suffix | join(" ")' 2>/dev/null)
ag4=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[5].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad4" == "yg_kkk" || -z "$ad4") && ("$ag4" == "yg_kkk" || -z "$ag4") ]]; then
adfl4="${yellow}[$vps_ipv4] has not been diverted ${plain}" 
else
if [[ "$ad4" != "yg_kkk" ]]; then
sad4="$ad4 "
fi
if [[ "$ag4" != "yg_kkk" ]]; then
sag4=$ag4
fi
adfl4="${yellow}[$vps_ipv4] has been diverted: $sad4$sag4${plain}"
fi

ad6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].domain_suffix | join(" ")' 2>/dev/null)
ag6=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.route.rules[6].geosite | join(" ")' 2>/dev/null)
if [[ ("$ad6" == "yg_kkk" || -z "$ad6") && ("$ag6" == "yg_kkk" || -z "$ag6") ]]; then
adfl6="${yellow}【$vps_ipv6】Not routed${plain}" 
else
if [[ "$ad6" != "yg_kkk" ]]; then
sad6="$ad6 "
fi
if [[ "$ag6" != "yg_kkk" ]]; then
sag6=$ag6
fi
adfl6="${yellow}【$vps_ipv6】has been diverted: $sad6$sag6${plain}"
fi
}

changefl(){
sbactive
blue "Configure unified domain-based routing for all protocols."
blue "For reliability, dual-stack IPv4/IPv6 routing uses priority mode."
blue "warp-wireguard is enabled by default (options 1 and 2)"
blue "socks5 needs to install warp official client or WARP-plus-Socks5-Psiphon VPN (options 3 and 4) on VPS"
blue "VPS local outbound routing is available in options 5 and 6."
echo
[[ "$sbnh" == "1.10" ]] && blue "The current Sing-box kernel supports geosite-based routing." || blue "The current Sing-box kernel does not support geosite-based routing and only supports options 2, 3, 5, and 6."
echo
yellow "Note:"
yellow "1. Only the complete domain name can be filled in with the complete domain name (for example: Google website fills in: www.google.com)"
yellow "2. The geosite method must fill in the geosite rule name (for example: Netflix, fill in: netflix; Disney, fill in: disney; Fill in ChatGPT: openai; fill in globally and bypass China: geolocation-!cn)"
yellow "3. Do not duplicate the same complete domain name or geosite"
yellow "4. If there are individual channels in the distribution channel without network, the filled-in distribution is in blacklist mode, that is, access to the website is blocked"
changef
}

changef(){
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sbymfl
echo
[[ "$sbnh" != "1.10" ]] && wfl4='Not supported yet' sfl6='Not supported yet' adfl4='Not supported yet' adfl6='Not supported yet'
green "1: Reset Warp WireGuard IPv4 priority routing domains $wfl4"
green "2: Reset Warp WireGuard IPv6 priority routing domains $wfl6"
green "3: Reset Warp Socks5 IPv4 priority routing domains $sfl4"
green "4: Reset Warp Socks5 IPv6 priority routing domains $sfl6"
green "5: Reset VPS local IPv4 priority routing domains $adfl4"
green "6: Reset VPS local IPv6 priority routing domains $adfl6"
green "0: Return to the upper layer"
echo
readp "Please select:" menu

if [ "$menu" = "1" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name and press Enter to skip the distribution channel of the complete domain name of warp-wireguard-ipv4):" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "184s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "Leave a space between each domain name and press Enter to skip to reset and clear the geosite distribution channel of warp-wireguard-ipv4):" w4flym
if [ -z "$w4flym" ]; then
w4flym='"yg_kkk"'
else
w4flym="$(echo "$w4flym" | sed 's/ /","/g')"
w4flym="\"$w4flym\""
fi
sed -i "187s/.*/$w4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "Sorry! Currently, only warp-wireguard-ipv6 is supported. If you need warp-wireguard-ipv4, please switch to the 1.10 series kernel" && exit
fi

elif [ "$menu" = "2" ]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the distribution channel of the full domain name of warp-wireguard-ipv6:" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "193s/.*/$w6flym/" /etc/s-box/sb10.json
sed -i "184s/.*/$w6flym/" /etc/s-box/sb11.json
sed -i "196s/.*/$w6flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the geosite distribution channel of warp-wireguard-ipv6:" w6flym
if [ -z "$w6flym" ]; then
w6flym='"yg_kkk"'
else
w6flym="$(echo "$w6flym" | sed 's/ /","/g')"
w6flym="\"$w6flym\""
fi
sed -i "196s/.*/$w6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "The current Sing-box kernel does not support geosite-based routing. Switch to the 1.10 series kernel if you need it." && exit
fi
else
changef
fi

elif [ "$menu" = "3" ]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the distribution channel of the full domain name of warp-socks5-ipv4:" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "202s/.*/$s4flym/" /etc/s-box/sb10.json
sed -i "177s/.*/$s4flym/" /etc/s-box/sb11.json
sed -i "190s/.*/$s4flym/" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the geosite distribution channel of warp-socks5-ipv4:" s4flym
if [ -z "$s4flym" ]; then
s4flym='"yg_kkk"'
else
s4flym="$(echo "$s4flym" | sed 's/ /","/g')"
s4flym="\"$s4flym\""
fi
sed -i "205s/.*/$s4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "The current Sing-box kernel does not support geosite-based routing. Switch to the 1.10 series kernel if you need it." && exit
fi
else
changef
fi

elif [ "$menu" = "4" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the distribution channel of the full domain name of warp-socks5-ipv6:" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "211s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
elif [ "$menu" = "2" ]; then
readp "Leave a space between each domain name, and press Enter to skip to reset and clear the geosite distribution channel of warp-socks5-ipv6:" s6flym
if [ -z "$s6flym" ]; then
s6flym='"yg_kkk"'
else
s6flym="$(echo "$s6flym" | sed 's/ /","/g')"
s6flym="\"$s6flym\""
fi
sed -i "214s/.*/$s6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
changef
fi
else
yellow "Sorry! Currently, only warp-socks5-ipv4 is supported. If you need warp-socks5-ipv6, please switch to the 1.10 series kernel" && exit
fi

elif [ "$menu" = "5" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name, and press Enter to skip to indicate reset and clear the VPS local ipv4. The full domain name distribution channel:" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "220s/.*/$ad4flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Separate domains with spaces. Press Enter to clear the VPS local IPv4 geosite routing list:" ad4flym
if [ -z "$ad4flym" ]; then
ad4flym='"yg_kkk"'
else
ad4flym="$(echo "$ad4flym" | sed 's/ /","/g')"
ad4flym="\"$ad4flym\""
fi
sed -i "223s/.*/$ad4flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "The current Sing-box kernel does not support geosite-based routing. Switch to the 1.10 series kernel if you need it." && exit
fi
else
changef
fi
else
yellow "If you need VPS local IPv4 routing, switch to the 1.10 series kernel." && exit
fi

elif [ "$menu" = "6" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "1: Use the complete domain name method\n2: Use the geosite method\n3: Return to the upper layer\nPlease select:" menu
if [ "$menu" = "1" ]; then
readp "Leave a space between each domain name, and press Enter to skip to indicate a reset and clear the VPS local IPv6." ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "229s/.*/$ad6flym/" /etc/s-box/sb10.json /etc/s-box/sb.json
restartsb
changef
elif [ "$menu" = "2" ]; then
if [[ "$sbnh" == "1.10" ]]; then
readp "Leave a space between each domain name, and press Enter to skip the geosite method to reset and clear the VPS local IPv6." ad6flym
if [ -z "$ad6flym" ]; then
ad6flym='"yg_kkk"'
else
ad6flym="$(echo "$ad6flym" | sed 's/ /","/g')"
ad6flym="\"$ad6flym\""
fi
sed -i "232s/.*/$ad6flym/" /etc/s-box/sb.json /etc/s-box/sb10.json
restartsb
changef
else
yellow "The current Sing-box kernel does not support geosite-based routing. Switch to the 1.10 series kernel if you need it." && exit
fi
else
changef
fi
else
yellow "If you need VPS local IPv6 routing, switch to the 1.10 series kernel." && exit
fi
else
sb
fi
}

restartsb(){
if command -v apk >/dev/null 2>&1; then
rc-service sing-box restart
else
systemctl enable sing-box
systemctl start sing-box
systemctl restart sing-box
fi
}

stclre(){
if [[ ! -f '/etc/s-box/sb.json' ]]; then
red "Sing-box is not installed normally" && exit
fi
readp "1: Restart\n2: Close\nPlease select:" menu
if [ "$menu" = "1" ]; then
restartsb
sbactive
green "Sing-box service has been restarted\n" && sleep 3 && sb
elif [ "$menu" = "2" ]; then
if command -v apk >/dev/null 2>&1; then
rc-service sing-box stop
else
systemctl stop sing-box
systemctl disable sing-box
fi
green "Sing-box service has been shut down\n" && sleep 3 && sb
else
stclre
fi
}

cronsb(){
uncronsb
crontab -l 2>/dev/null > /tmp/crontab.tmp
echo "0 1 * * * systemctl restart sing-box;rc-service sing-box restart" >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}
uncronsb(){
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sing-box/d' /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
sed -i '/url http/d' /tmp/crontab.tmp
sed -i '/httpd -f -p/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
}

lnsb(){
rm -rf /usr/bin/sb
curl -L -o /usr/bin/sb -# --retry 2 --insecure https://raw.githubusercontent.com/anyagixx/proxmetrue/main/sb.sh
chmod +x /usr/bin/sb
}

upsbyg(){
if [[ ! -f '/usr/bin/sb' ]]; then
red "Sing-box-yg is not installed normally" && exit
fi
lnsb
curl -sL https://raw.githubusercontent.com/anyagixx/proxmetrue/main/version | awk -F "Update content" '{print $1}' | head -n 1 > /etc/s-box/v
green "Sing-box-yg installation script upgraded successfully" && sleep 5 && sb
}

lapre(){
latcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
precore=$(curl -Ls https://github.com/SagerNet/sing-box/releases | grep -oP '/tag/v\K[0-9.]+-[^"]+' | head -n 1)
inscore=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}')
}

upsbcroe(){
sbactive
lapre
[[ $inscore =~ ^[0-9.]+$ ]] && lat="[v$inscore has been installed]" || pre="[v$inscore has been installed]"
green "1: Upgrade/switch to the latest official version of Sing-box v$latcore ${bblue}${lat}${plain}"
green "2: Upgrade/switch Sing-box latest beta version v$precore ${bblue}${pre}${plain}"
green "3: Switch to an official version or test version of Sing-box, you need to specify the version number (version 1.10.0 or above is recommended)"
green "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases/latest | grep -oP 'tag/v\K[0-9.]+' | head -n 1)
elif [ "$menu" = "2" ]; then
upcore=$(curl -Ls https://github.com/SagerNet/sing-box/releases | grep -oP '/tag/v\K[0-9.]+-[^"]+' | head -n 1)
elif [ "$menu" = "3" ]; then
echo
red "Note: The version number can be checked at https://github.com/SagerNet/sing-box/tags, and there is the word Downloads (must be 1.10 series or 1.30 series or above)"
green "Stable version format: number.number.number (example: 1.10.7). Note: the 1.10 series supports geosite-based routing, while later kernel lines do not."
green "beta version number format: number.number.number-alpha or rc or beta.number (Example: 1.13.0-alpha or rc or beta.1)"
readp "Please enter the Sing-box version number:" upcore
else
sb
fi
if [[ -n $upcore ]]; then
green "Start downloading and updating Sing-box kernel... Please wait"
sbname="sing-box-$upcore-linux-$cpu"
curl -L -o /etc/s-box/sing-box.tar.gz  -# --retry 2 https://github.com/SagerNet/sing-box/releases/download/v$upcore/$sbname.tar.gz
if [[ -f '/etc/s-box/sing-box.tar.gz' ]]; then
tar xzf /etc/s-box/sing-box.tar.gz -C /etc/s-box
mv /etc/s-box/$sbname/sing-box /etc/s-box
rm -rf /etc/s-box/{sing-box.tar.gz,$sbname}
if [[ -f '/etc/s-box/sing-box' ]]; then
chown root:root /etc/s-box/sing-box
chmod +x /etc/s-box/sing-box
sbnh=$(/etc/s-box/sing-box version 2>/dev/null | awk '/version/{print $NF}' | cut -d '.' -f 1,2)
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
rm -rf /etc/s-box/sb.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb && sbshare > /dev/null 2>&1
blue "Successfully upgraded/switched Sing-box kernel version: $(/etc/s-box/sing-box version | awk '/version/{print $NF}')" && sleep 3 && sb
else
red "Download Sing-box The kernel is incomplete, the installation failed, please try again" && upsbcroe
fi
else
red "Download Sing-box The kernel failed or does not exist, please try again" && upsbcroe
fi
else
red "An error occurred in version number detection, please try again" && upsbcroe
fi
}

unins(){
if command -v apk >/dev/null 2>&1; then
for svc in sing-box argo; do
rc-service "$svc" stop >/dev/null 2>&1
rc-update del "$svc" default >/dev/null 2>&1
done
rm -rf /etc/init.d/{sing-box,argo}
else
for svc in sing-box argo; do
systemctl stop "$svc" >/dev/null 2>&1
systemctl disable "$svc" >/dev/null 2>&1
done
rm -rf /etc/systemd/system/{sing-box.service,argo.service}
fi
ps -ef | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json 2>/dev/null | jq -r '.inbounds[1].listen_port')" | awk '{print $2}' | xargs kill 2>/dev/null
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
ps -ef | grep "$(cat /etc/s-box/subport.log 2>/dev/null)" | grep -v grep | awk 'NR==1 {print $2}' | xargs kill 2>/dev/null
rm -rf /etc/s-box sbyg_update /usr/bin/sb /root/geoip.db /root/geosite.db /root/warpapi /root/warpip /root/websbox
rm -f /etc/local.d/alpineargo.start /etc/local.d/alpinesub.start /etc/local.d/alpinews5.start
uncronsb
iptables -t nat -F PREROUTING >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
service iptables save >/dev/null 2>&1
green "Sing-box uninstallation is completed!"
blue "Run again with: bash <(curl -Ls https://raw.githubusercontent.com/anyagixx/proxmetrue/main/sb.sh)"
echo
}

sblog(){
red "Exit log Ctrl+c"
if command -v apk >/dev/null 2>&1; then
yellow "Not supported yet alpine view log"
else
#systemctl status sing-box
journalctl -u sing-box.service -o cat -f
fi
}

sbactive(){
if [[ ! -f /etc/s-box/sb.json ]]; then
red "Sing-box is not started normally, please uninstall and reinstall or select 10 to view the running log feedback" && exit
fi
}

sbshare(){
rm -rf /etc/s-box/{jhdy,vl_reality,vm_ws_argols,vm_ws_argogd,vm_ws,vm_ws_tls,hy2,tuic5,an}.txt
result_vl_vm_hy_tu && resvless && resvmess && reshy2 && restu5
if [[ "$sbnh" != "1.10" ]]; then
resan
fi
cat /etc/s-box/vl_reality.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argols.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_argogd.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/vm_ws_tls.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/hy2.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/tuic5.txt 2>/dev/null >> /etc/s-box/jhdy.txt
cat /etc/s-box/an.txt 2>/dev/null >> /etc/s-box/jhdy.txt
v2sub=$(cat /etc/s-box/jhdy.txt 2>/dev/null)
echo "$v2sub" > /etc/s-box/jhsub.txt
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀[ Aggregation node ] The node information is as follows:" && sleep 2
echo
echo "Share link"
echo -e "${yellow}$v2sub${plain}"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
sb_client
}

clash_sb_share(){
sbactive
echo
yellow "1: Refresh and view the shared links, QR codes, and aggregation nodes of each protocol"
yellow "2: Refresh and view Mihomo and Sing-box client configs (SFA/SFI/SFW), plus the private GitLab subscription link"
yellow "3: Push the latest node configuration information (option 1 + option 2) to Telegram notification"
yellow "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
sbshare
elif  [ "$menu" = "2" ]; then
green "Please wait..."
sbshare > /dev/null 2>&1
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "Gitlab subscription link is as follows:"
gitlabsubgo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀Mihomo configuration file is shown as follows:"
red "File directory /etc/s-box/clmi.yaml, copy and self-build shall be subject to yaml file format" && sleep 2
echo
cat /etc/s-box/clmi.yaml
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
red "🚀The SFA/SFI/SFW configuration file is displayed as follows:"
red "For Android SFA, Apple SFI, and win computer official file package SFW, please go to the Yongge Github project to download it yourself."
red "File directory /etc/s-box/sbox.json, copy and self-build shall be subject to json file format" && sleep 2
echo
cat /etc/s-box/sbox.json
echo
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
elif [ "$menu" = "3" ]; then
tgnotice
else
sb
fi
}

acme(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/acme-script/raw/main/acme.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/acme-yg/main/acme.sh)
}
cfwarp(){
#bash <(curl -Ls https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh)
bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/warp-yg/main/CFwarp.sh)
}
bbr(){
if [[ $vi =~ lxc|openvz ]]; then
yellow "The current VPS architecture is $vi, and does not support turning on the original BBR acceleration" && sleep 2 && exit 
else
green "Click any key to turn on BBR acceleration, ctrl+c to exit"
bash <(curl -Ls https://raw.githubusercontent.com/teddysun/across/master/bbr.sh)
fi
}

showprotocol(){
allports
sbymfl
tls=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].tls.enabled')
if [[ "$tls" = "false" ]]; then
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run' || ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
vm_zs="TLS is turned off"
argoym="has been turned on"
else
vm_zs="TLS is turned off"
argoym="is not started"
fi
else
vm_zs="TLS is turned on"
argoym="It is not supported to open"
fi
hy2_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[2].tls.key_path')
[[ "$hy2_sniname" = '/etc/s-box/private.key' ]] && hy2_zs="self-signed certificate" || hy2_zs="Domain name certificate"
tu5_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[3].tls.key_path')
[[ "$tu5_sniname" = '/etc/s-box/private.key' ]] && tu5_zs="self-signed certificate" || tu5_zs="Domain name certificate"
an_sniname=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[4].tls.key_path')
[[ "$an_sniname" = '/etc/s-box/private.key' ]] && an_zs="self-signed certificate" || an_zs="Domain name certificate"
echo -e "The key information of the Sing-box node and the diverted domain name are as follows:"
echo -e "🚀[ Vless-reality ] ${yellow} port: $vl_port Reality domain name certificate disguised address: $(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].tls.server_name')${plain}"
if [[ "$tls" = "false" ]]; then
echo -e "🚀【 Vmess-ws 】${yellow} port: $vm_port Certificate format: $vm_zs Argo status: $argoym${plain}"
else
echo -e "🚀[ Vmess-ws-tls ] ${yellow} port: $vm_port Certificate format: $vm_zs Argo status: $argoym${plain}"
fi
echo -e "🚀【 Hysteria-2 】${yellow} port: $hy2_port Certificate format: $hy2_zs Forwarding multi-port: $hy2zfport${plain}"
echo -e "🚀[ Tuic-v5 】${yellow} port: $tu5_port Certificate format: $tu5_zs Forwarding multi-port: $tu5zfport${plain}"
if [[ "$sbnh" != "1.10" ]]; then
echo -e "🚀[ Anytls ] ${yellow} port: $an_port Certificate form: $an_zs${plain}"
fi
if [ -s /etc/s-box/subport.log ]; then
showsubport=$(cat /etc/s-box/subport.log)
if ps -ef 2>/dev/null | grep "$showsubport" | grep -v grep >/dev/null; then
showsubtoken=$(cat /etc/s-box/subtoken.log 2>/dev/null)
subip=$(cat /etc/s-box/server_ip.log 2>/dev/null)
suburl="$subip:$showsubport/$showsubtoken"
echo "Clash/Mihomo Local IP subscription address: http://$suburl/clmi.yaml"
echo "Sing-box local IP subscription address: http://$suburl/sbox.json"
echo "Aggregation protocol local IP subscription address: http://$suburl/jhsub.txt"
fi
fi
if [ "$argoym" = "has been turned on" ]; then
#echo -e "Vmess-UUID：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[0].users[0].uuid')${plain}"
#echo -e "Vmess-Path：${yellow}$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].transport.path')${plain}"
if ps -ef 2>/dev/null | grep "localhost:$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.inbounds[1].listen_port')" >/dev/null 2>&1; then
echo -e "Argo temporary domain name: ${yellow}$(cat /etc/s-box/argo.log 2>/dev/null | grep -a trycloudflare.com | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')${plain}"
fi
if ps -ef 2>/dev/null | grep -q '[c]loudflared.*run'; then
echo -e "Argo fixed domain name: ${yellow}$(cat /etc/s-box/sbargoym.log 2>/dev/null)${plain}"
fi
fi
echo "------------------------------------------------------------------------------------"
if [[ -n $(ps -e | grep sbwpph) ]]; then
s5port=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
s5gj=$(cat /etc/s-box/sbwpph.log 2>/dev/null | awk '{print $6}')
case "$s5gj" in
AT) showgj="Austria" ;;
AU) showgj="Australia" ;;
BE) showgj="Belgium" ;;
BG) showgj="Bulgaria" ;;
CA) showgj="Canada" ;;
CH) showgj="Switzerland" ;;
CZ) showgj="Czech Republic" ;;
DE) showgj="Germany" ;;
DK) showgj="Denmark" ;;
EE) showgj="Estonia" ;;
ES) showgj="Spain" ;;
FI) showgj="Finland" ;;
FR) showgj="France" ;;
GB) showgj="United Kingdom" ;;
HR) showgj="Croatia" ;;
HU) showgj="Hungary" ;;
IE) showgj="Ireland" ;;
IN) showgj="India" ;;
IT) showgj="Italy" ;;
JP) showgj="Japan" ;;
LT) showgj="Lithuania" ;;
LV) showgj="Latvia" ;;
NL) showgj="Netherlands" ;;
NO) showgj="Norway" ;;
PL) showgj="Poland" ;;
PT) showgj="Portugal" ;;
RO) showgj="Romania" ;;
RS) showgj="Serbia" ;;
SE) showgj="Sweden" ;;
SG) showgj="Singapore" ;;
SK) showgj="Slovakia" ;;
US) showgj="United States" ;;
esac
grep -q "country" /etc/s-box/sbwpph.log 2>/dev/null && s5ms="Multi-regional Psiphon proxy mode (Port: $s5port Country: $showgj)" || s5ms="Local Warp proxy mode (port: $s5port)"
echo -e "WARP-plus-Socks5 status: $yellow is started $s5ms$plain"
else
echo -e "WARP-plus-Socks5 status: $yellow is not started$plain"
fi
echo "------------------------------------------------------------------------------------"
ww4="Warp WireGuard IPv4 priority routing domains: $wfl4"
ww6="Warp WireGuard IPv6 priority routing domains: $wfl6"
ws4="Warp Socks5 IPv4 priority routing domains: $sfl4"
ws6="Warp Socks5 IPv6 priority routing domains: $sfl6"
l4="VPS local IPv4 priority routing domains: $adfl4"
l6="VPS local IPv6 priority routing domains: $adfl6"
[[ "$sbnh" == "1.10" ]] && ymflzu=("ww4" "ww6" "ws4" "ws6" "l4" "l6") || ymflzu=("ww6" "ws4" "l4" "l6")
for ymfl in "${ymflzu[@]}"; do
if [[ ${!ymfl} != *"Not yet"* ]]; then
echo -e "${!ymfl}"
fi
done
if [[ $ww4 = *"Not yet"* && $ww6 = *"Not yet"* && $ws4 = *"Not yet"* && $ws6 = *"Not yet"* && $l4 = *"Not yet"* && $l6 = *"Not yet"* ]] ; then
echo -e "No domain-based routing rules are configured."
fi
}

inssbwpph(){
sbactive
ins(){
if [ ! -e /etc/s-box/sbwpph ]; then
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
esac
curl -L -o /etc/s-box/sbwpph -# --retry 2 --insecure https://raw.githubusercontent.com/anyagixx/proxmetrue/main/sbwpph_$cpu
chmod +x /etc/s-box/sbwpph
fi
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
v4v6
if [[ -n $v4 ]]; then
sw46=4
else
red "IPV4 does not exist. Make sure the WARP-IPV4 mode is installed."
sw46=6
fi
echo
readp "Set up the WARP-plus-Socks5 port (press Enter to skip the port default of 40000):" port
if [[ -z $port ]]; then
port=40000
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] 
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom port:" port
done
else
until [[ -z $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") && -z $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]]
do
[[ -n $(ss -tunlp | grep -w udp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") || -n $(ss -tunlp | grep -w tcp | awk '{print $5}' | sed 's/.*://g' | grep -w "$port") ]] && yellow "\nThe port is occupied, please re-enter the port" && readp "Custom port:" port
done
fi
s5port=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[] | select(.type == "socks") | .server_port')
[[ "$sbnh" == "1.10" ]] && num=10 || num=11
sed -i "127s/$s5port/$port/g" /etc/s-box/sb10.json
sed -i "165s/$s5port/$port/g" /etc/s-box/sb11.json
cp /etc/s-box/sb${num}.json /etc/s-box/sb.json
restartsb
}
unins(){
ps -ef | grep '[s]bwpph' | awk '{print $2}' | xargs kill 2>/dev/null
rm -rf /etc/s-box/sbwpph.log
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
rm -rf /etc/local.d/alpinews5.start
}
aplws5(){
if command -v apk >/dev/null 2>&1; then
cat > /etc/local.d/alpinews5.start <<'EOF'
#!/bin/bash
sleep 10
nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null)
EOF
chmod +x /etc/local.d/alpinews5.start
rc-update add local default >/dev/null 2>&1
else
crontab -l 2>/dev/null > /tmp/crontab.tmp
sed -i '/sbwpph/d' /tmp/crontab.tmp
echo '@reboot sleep 10 && /bin/bash -c "nohup $(cat /etc/s-box/sbwpph.log 2>/dev/null) &"' >> /tmp/crontab.tmp
crontab /tmp/crontab.tmp >/dev/null 2>&1
rm /tmp/crontab.tmp
fi
}
echo
yellow "1: Reset and enable WARP-plus-Socks5 local Warp proxy mode"
yellow "2: Reset and enable WARP-plus-Socks5 multi-region Psiphon proxy mode"
yellow "3: Stop WARP-plus-Socks5 proxy mode"
yellow "0: Return to the upper layer"
readp "Please select [0-3]:" menu
if [ "$menu" = "1" ]; then
ins
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "Applying for IP... Please wait..." && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "Failed to obtain the IP of WARP-plus-Socks5" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --gool -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5 IP acquired successfully. Socks5-based routing is now available."
fi
elif [ "$menu" = "2" ]; then
ins
echo '
Austria (AT)
Australia (AU)
Belgium (BE)
Bulgaria (BG)
Canada (CA)
Switzerland (CH)
Czech Republic (CZ)
Germany (DE)
Denmark (DK)
Estonia (EE)
Spain (ES)
Finland (FI)
France (FR)
United Kingdom (GB)
Croatia (HR)
Hungary (HU)
Ireland (IE)
India (IN)
Italy (IT)
Japan (JP) Does
Lithuania (LT)
Latvia (LV)
Netherlands (NL)
Norway (NO)
Poland (PL)
Portugal (PT)
Romania (RO)
Serbia (RS)
Sweden (SE)
Singapore (SG)
Slovakia (SK)
United States (US)
'
readp "You can select the country and region (enter the last two capital letters, such as the United States, enter US):" guojia
nohup /etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1 &
green "Applying for IP... Please wait..." && sleep 20
resv1=$(curl -sm3 --socks5 localhost:$port icanhazip.com)
resv2=$(curl -sm3 -x socks5h://localhost:$port icanhazip.com)
if [[ -z $resv1 && -z $resv2 ]]; then
red "Failed to obtain the IP of WARP-plus-Socks5, try changing the country and region" && unins && exit
else
echo "/etc/s-box/sbwpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 --endpoint 162.159.192.1:2408 >/dev/null 2>&1" > /etc/s-box/sbwpph.log
aplws5
green "WARP-plus-Socks5 IP acquired successfully. Socks5-based routing is now available."
fi
elif [ "$menu" = "3" ]; then
unins && green "The WARP-plus-Socks5 proxy function has been stopped"
else
sb
fi
}

sbsm(){
echo
green "Follow Yongge YouTube channel: https://youtube.com/@ygkkk?sub_confirmation=1 to learn about the latest agent agreement and circumvention trends"
echo
blue "sing-box-yg script video tutorial: https://www.youtube.com/playlist?list=PLMgly2AulGG_Affv6skQXWnVqw7XWiPwJ"
echo
blue "sing-box-yg script blog description: http://ygkkk.blogspot.com/2023/10/sing-box-yg.html"
echo
blue "Project page: https://github.com/anyagixx/proxmetrue"
echo
blue "Recommended alternative from Yongge: the ArgoSBX one-click non-interactive script"
blue "ArgoSBX project address: https://github.com/yonggekkk/argosbx"
echo
}

clear
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Yongge Github Project: github.com/yonggekkk"
white "Yongge Blogger Blog: ygkkk.blogspot.com"
white "Yongge YouTube Channel: www.youtube.com/@ygkkk"
white "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "Five-protocol script: Vless-reality-vision, Vmess-ws(tls)+Argo, Hy2, Tuic, and AnyTLS"
white "Script shortcut: sb"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green "1. Install Sing-box" 
green "2. Remove Sing-box"
white "----------------------------------------------------------------------------------"
green "3. Change settings [TLS certificates / UUID path / Argo / IP priority / Telegram notifications / Warp / subscriptions / CDN preferences]" 
green "4. Change the main port or add multi-port hopping" 
green "5. Configure three-channel domain routing"
green "6. Shut down/restart Sing-box"   
green "7. Update Sing-box-yg script"
green "8. Update/switch/specify Sing-box kernel version"
white "----------------------------------------------------------------------------------"
green "9. Refresh and view nodes [Mihomo / SFA+SFI+SFW configs / subscription links / Telegram push]"
green "10. View Sing-box running log"
green "11. Enable original BBR + network acceleration"
green "12. Manage Acme and apply for domain name certificate"
green "13. Manage Warp and check Netflix / ChatGPT availability"
green "14. Add WARP-plus-Socks5 proxy mode [Local Warp/Multi-region Psiphon-VPN]"
green "15. Refresh local IP, adjust IPV4/IPV6 configuration output"
white "----------------------------------------------------------------------------------"
green "16. Sing-box-yg usage guide"
green "17. User management (add/delete users)"
white "----------------------------------------------------------------------------------"
green "0. Exit the script"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
insV=$(cat /etc/s-box/v 2>/dev/null)
latestV=$(curl -sL https://raw.githubusercontent.com/anyagixx/proxmetrue/main/version | awk -F "Update content" '{print $1}' | head -n 1)
if [ -f /etc/s-box/v ]; then
if [ "$insV" = "$latestV" ]; then
echo -e "Current Sing-box-yg script version: ${bblue}${insV}${plain} (latest installed)"
else
echo -e "Current Sing-box-yg script version: ${bblue}${insV}${plain}"
echo -e "Latest available Sing-box-yg script version: ${yellow}${latestV}${plain} (select 7 to update)"
echo -e "${yellow}$(curl -sL https://raw.githubusercontent.com/anyagixx/proxmetrue/main/version)${plain}"
fi
else
echo -e "Current Sing-box-yg script version: ${bblue}${latestV}${plain}"
yellow "Sing-box-yg script is not installed! Please select 1 to install first"
fi

lapre
if [ -f '/etc/s-box/sb.json' ]; then
if [[ $inscore =~ ^[0-9.]+$ ]]; then
if [ "${inscore}" = "${latcore}" ]; then
echo
echo -e "Current Sing-box stable kernel: ${bblue}${inscore}${plain} (installed)"
echo
echo -e "Latest Sing-box preview kernel: ${bblue}${precore}${plain} (available to switch)"
else
echo
echo -e "Installed Sing-box stable kernel: ${bblue}${inscore}${plain}"
echo -e "Latest available Sing-box stable kernel: ${yellow}${latcore}${plain} (select 8 to update)"
echo
echo -e "Latest Sing-box preview kernel: ${bblue}${precore}${plain} (available to switch)"
fi
else
if [ "${inscore}" = "${precore}" ]; then
echo
echo -e "Current Sing-box preview kernel: ${bblue}${inscore}${plain} (installed)"
echo
echo -e "Latest Sing-box stable kernel: ${bblue}${latcore}${plain} (available to switch)"
else
echo
echo -e "Installed Sing-box preview kernel: ${bblue}${inscore}${plain}"
echo -e "Latest available Sing-box preview kernel: ${yellow}${precore}${plain} (select 8 to update)"
echo
echo -e "Latest Sing-box stable kernel: ${bblue}${latcore}${plain} (available to switch)"
fi
fi
else
echo
echo -e "Latest Sing-box stable kernel: ${bblue}${latcore}${plain}"
echo -e "Latest Sing-box preview kernel: ${bblue}${precore}${plain}"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "VPS status:"
echo -e "System: $blue$op$plain \c";echo -e "Kernel: $blue$version$plain \c";echo -e "Processor: $blue$cpu$plain \c";echo -e "Virtualization: $blue$vi$plain \c";echo -e "BBR algorithm: $blue$bbr$plain"
v4v6
if [[ "$v6" == "2a09"* ]]; then
w6="【WARP】"
fi
if [[ "$v4" == "104.28"* ]]; then
w4="【WARP】"
fi
[[ -z $v4 ]] && showv4='IPV4 address is lost, please switch to IPV6 or reinstall Sing-box' || showv4=$v4$w4
[[ -z $v6 ]] && showv6='IPV6 address is lost, please switch to IPV4 or reinstall Sing-box' || showv6=$v6$w6
if [[ -z $v4 ]]; then
vps_ipv4='No IPV4'      
vps_ipv6="$v6"
location="$v6dq"
elif [[ -n $v4 &&  -n $v6 ]]; then
vps_ipv4="$v4"    
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"    
vps_ipv6='No IPV6'
location="$v4dq"
fi
echo -e "Local IPV4 address: $blue$vps_ipv4$w4$plain Local IPV6 address: $blue$vps_ipv6$w6$plain"
echo -e "Server region: $blue$location$plain"
if [[ "$sbnh" == "1.10" ]]; then
rpip=$(sed 's://.*::g' /etc/s-box/sb.json | jq -r '.outbounds[0].domain_strategy') 2>/dev/null
if [[ $rpip = 'prefer_ipv6' ]]; then
v4_6="IPV6 priority outbound ($showv6)"
elif [[ $rpip = 'prefer_ipv4' ]]; then
v4_6="IPV4 outbound priority ($showv4)"
elif [[ $rpip = 'ipv4_only' ]]; then
v4_6="IPV4 outbound only ($showv4)"
elif [[ $rpip = 'ipv6_only' ]]; then
v4_6="IPV6 outbound only ($showv6)"
fi
echo -e "Proxy IP priority: $blue$v4_6$plain"
fi
if command -v apk >/dev/null 2>&1; then
status_cmd="rc-service sing-box status"
status_pattern="started"
else
status_cmd="systemctl is-active sing-box"
status_pattern="active"
fi
if [[ -n $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box status: $blue Running $plain"
elif [[ -z $($status_cmd 2>/dev/null | grep -w "$status_pattern") && -f '/etc/s-box/sb.json' ]]; then
echo -e "Sing-box status: $yellow Not running. Select 10 to view logs. Switching to the stable kernel or reinstalling the script is recommended.$plain"
else
echo -e "Sing-box status: $red Not installed $plain"
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
if [ -f '/etc/s-box/sb.json' ]; then
showprotocol
fi
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "Please enter the number [0-17]:" Input
case "$Input" in  
 1 ) instsllsingbox;;
 2 ) unins;;
 3 ) changeserv;;
 4 ) changeport;;
 5 ) changefl;;
 6 ) stclre;;
 7 ) upsbyg;; 
 8 ) upsbcroe;;
 9 ) clash_sb_share;;
10 ) sblog;;
11 ) bbr;;
12 ) acme;;
13 ) cfwarp;;
14 ) inssbwpph;;
15 ) wgcfgo && sbshare;;
16 ) sbsm;;
17 ) manageusers;;
 * ) exit 
esac
