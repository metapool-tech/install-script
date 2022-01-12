#!/usr/bin/env bash
# Made by opimon, svenhash
set -e

PROXY_VERSION=0.2.2
MINER_VERSION=0.5.4
MINER_VERSION_AMD=0.2.0
SCRIPT_VERSION=1.0.1

DIR=$(pwd)
PKG_MANAGER=""

GREEN="\e[0;92m"
YELLOW="\e[0;93m"
RESET="\e[0m"

echo -e "script version: ${SCRIPT_VERSION}"

if [[ ! -f config.json ]] || [[ "$1" == "-r" ]]; then

if ! command -v wget &> /dev/null; then

   declare -A OS_INFO;
   OS_INFO[/etc/redhat-release]=yum
   OS_INFO[/etc/arch-release]=pacman
   OS_INFO[/etc/gentoo-release]=emerge
   OS_INFO[/etc/SuSE-release]=zypp
   OS_INFO[/etc/debian_version]=apt-get

   for f in ${!OS_INFO[@]}
   do
       if [[ -f $f ]];then
           echo Package manager: ${OS_INFO[$f]}
           PKG_MANAGER=${OS_INFO[$f]}
       fi
   done

   if [ -z $PKG_MANAGER ]; then
     echo "OS cannot be detected. Install wget manually" 
  else
     ${PKG_MANAGER} update && ${PKG_MANAGER} -y install wget
  fi

fi


if [[ $( cut -f1,2,18 /proc/bus/pci/devices | grep -c nvidia ) -gt 0 ]]; then
   echo -e "Downloading nvidia miner v${MINER_VERSION}" 
   wget -q https://github.com/alephium/gpu-miner/releases/download/v${MINER_VERSION}/alephium-${MINER_VERSION}-cuda-miner-linux -O alephium-miner-linux 
   wget -q https://github.com/alephium/gpu-miner/releases/download/v0.4.4/alephium-0.4.4-cuda-miner-linux -O alephium-cuda-miner-linux-workaround
else
   echo -e "Downloading amd miner v${MINER_VERSION_AMD}" 
   wget -q  https://github.com/alephium/amd-miner/releases/download/v0.2.0/alephium-0.2.0-amd-miner-linux -O alephium-miner-linux
fi

echo -e "Downloading mining-proxy v${PROXY_VERSION}"
wget -q https://github.com/alephium/mining-proxy/releases/download/v${PROXY_VERSION}/alephium-mining-proxy-${PROXY_VERSION}-linux -O alephium-mining-proxy-linux

echo -e ""

cat <<EOT > config.json
{
    "logPath": "./logs/",
    "diff1TargetNumZero": 30,
    "serverHost": "eu.metapool.tech",
    "serverPort": 20032,
    "proxyPort": 30032,
    "addresses": [
    "your-mining-address-1",
    "your-mining-address-2",
    "your-mining-address-3",
    "your-mining-address-4"
  ]
}
EOT

cat << EOT > metapool-run.sh
#!/usr/bin/env bash
set -e

DIR=\$(pwd)
RED="\e[0;91m"
RESET="\e[0m"

if [[ ! -f config.json ]]
then
   echo -e "\${RED}Error: \$DIR/config.json not found\${RESET}"
   exit 1
fi


if grep -q -wi ".*your-mining.*" \$DIR/config.json; then
   echo -e "\${RED}Error: Miner addresses are not set"
   echo -e "\${RED}Set your mining addresses in \$DIR/config.json \${RESET}"
   exit 1
fi


trap "trap - SIGTERM && kill -- -\$$" SIGINT SIGTERM EXIT
./alephium-mining-proxy-linux config.json &

./alephium-miner-linux  -p 30032 || ./alephium-cuda-miner-linux-workaround -p 30032 

wait

EOT

chmod +x alephium* metapool-run.sh

fi

if grep -q -wi ".*your-mining.*" $DIR/config.json; then
   echo -e "${YELLOW}Set your mining addresses in $DIR/config.json${RESET}"
   echo -e ""
fi

echo -e "${GREEN}Welcome to https://metapool.tech, join us on Telegram https://t.me/metapool1"
echo -e "${GREEN}Run $DIR/metapool-run.sh to mine${RESET}"

