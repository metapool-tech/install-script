#!/usr/bin/env bash
# Made by opimon, svenhash
set -e

BZMINER_VERSION=7.1.5
SCRIPT_VERSION=1.3.0

DIR=$(pwd)
PKG_MANAGER=""
BZMINER_FOLDER=$DIR/bzminer${BZMINER_VERSION}

GREEN="\e[0;92m"
YELLOW="\e[0;93m"
RESET="\e[0m"

echo -e ""
echo -e "script version: ${SCRIPT_VERSION}"

if ! command -v curl &> /dev/null; then

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
     echo "OS cannot be detected. Install curl manually" 
  else
     ${PKG_MANAGER} update && ${PKG_MANAGER} -y install curl
  fi

fi

mkdir ${BZMINER_FOLDER}
curl -fsSL https://www.bzminer.com/downloads/bzminer_v${BZMINER_VERSION}_linux.tar.gz | tar -xz -C ${BZMINER_FOLDER}

echo -e ""

if [[ ! -f config.txt ]] || [[ "$1" == "-r" ]]; then

cat <<EOT > ${BZMINER_FOLDER}/config.txt
{
    "pool_configs": [{
            "algorithm": "alph",
            "wallet": [ "your-mining-address" ], 
            "url": ["stratum+tcp://eu.metapool.tech:20032"], 
            "username": "worker_name",
            "lhr_only": false
        }],
    "pool": [0], 
    "rig_name": "rig",
    "log_file": "",
    "nvidia_only": false,
    "amd_only": false,
    "auto_detect_lhr": true,
    "lock_config": false,
    "advanced_config": false,
    "advanced_display_config": false,
    "device_overrides": []
}

EOT
fi

cat << EOT > metapool-run.sh
#!/usr/bin/env bash
set -e

DIR=$(pwd)
RED="\e[0;91m"
GREEN="\e[0;92m"
RESET="\e[0m"

if [[ ! -f  \$DIR/bzminer${BZMINER_VERSION}/config.txt ]]
then
   echo -e "\${RED}Error: \$DIR/bzminer${BZMINER_VERSION}/config.txt not found\${RESET}"
   exit 1
fi

if [[ \$1 == "-a" ]] && [ ! -z \$2 ]; then
   ADDR="\$2"
   echo -e "\${GREEN}Address: \$2\${RESET}"
   sed -i 's/\"wallet\".*/\"wallet\": [\"'\${ADDR}'\"],/ig' \$DIR/bzminer${BZMINER_VERSION}/config.txt
else
   echo -e "\${RED}No address set. Run ./metapool-run.sh -a <your address>\${RESET}"
   exit 1
fi

if grep -q -wi ".*your-mining.*" \$DIR/bzminer${BZMINER_VERSION}/config.txt; then
   echo -e "\${RED}Error: Address is not set"
   echo -e "\${RED}Set your address with ./metapool-run.sh -a <your address> or in \$DIR/bzminer${BZMINER_VERSION}/config.txt\${RESET}"
   exit 1
fi

cd $DIR/bzminer${BZMINER_VERSION}
./bzminer -c config.txt

EOT

chmod +x metapool-run.sh

if grep -q -wi ".*your-mining.*" ${BZMINER_FOLDER}/config.txt; then
   echo -e "${YELLOW}Set your address with ./metapool-run.sh -a <your address>${RESET}"
   echo -e ""
fi

echo -e "${GREEN}Welcome to https://metapool.tech, join us on Telegram https://t.me/metapool1"
echo -e "${GREEN}Run $DIR/metapool-run.sh -a <your address> to mine${RESET}"


