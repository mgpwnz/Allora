#!/bin/bash
while true
do

# Menu

PS3='Select an action: '
options=("Pre Install" "Install wallet" "Install worker" "Re-run node" "Logs" "Uninstall" "Exit")
select opt in "${options[@]}"
               do
                   case $opt in                          

"Pre Install")
#docker + compose
touch $HOME/.bash_profile
	cd $HOME
	if ! docker --version; then
		sudo apt update
		sudo apt upgrade -y
		sudo apt install curl apt-transport-https ca-certificates gnupg lsb-release -y
		. /etc/*-release
		wget -qO- "https://download.docker.com/linux/${DISTRIB_ID,,}/gpg" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
		echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
		sudo apt update
		sudo apt install docker-ce docker-ce-cli containerd.io -y
		docker_version=`apt-cache madison docker-ce | grep -oPm1 "(?<=docker-ce \| )([^_]+)(?= \| https)"`
		sudo apt install docker-ce="$docker_version" docker-ce-cli="$docker_version" containerd.io -y
	fi
	if ! docker compose version; then
		sudo apt update
		sudo apt upgrade -y
		sudo apt install wget jq -y
		local docker_compose_version=`wget -qO- https://api.github.com/repos/docker/compose/releases/latest | jq -r ".tag_name"`
		sudo wget -O /usr/bin/docker-compose "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-`uname -s`-`uname -m`"
		sudo chmod +x /usr/bin/docker-compose
		. $HOME/.bash_profile
	fi
#python
sudo apt install python3
python3 --version
sudo apt install python3-pip
pip3 --version
#go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.4.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> $HOME/.bash_profile
source .bash_profile
go version

break
;;

"Install wallet")
# Clone repository
git clone https://github.com/allora-network/allora-chain.git
cd allora-chain && make all
allorad version
sleep 1
allorad keys add testkey --recover
break
;;
"Install worker")
cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node
cd basic-coin-prediction-node
#Copy the example configuration file and populate it with your variables:
cp config.example.json config.json
#create new conf
read -p "Enter wallet seed: " SEED

# Export seed as an environment variable
export SEED="${SEED}"
echo "Wallet seed exported."

# Create the data directory if it doesn't exist
mkdir -p $HOME/basic-coin-prediction-node/data

# Update config.json with the provided seed and other parameters
CONFIG_FILE="$HOME/basic-coin-prediction-node/config.json"
sed -i -e "s%\"addressRestoreMnemonic\": \"\"%\"addressRestoreMnemonic\": \"${SEED}\"%g" $CONFIG_FILE
sed -i -e "s%\"nodeRpc\": \"http://localhost:26657\"%\"nodeRpc\": \"https://allora-rpc.testnet-1.testnet.allora.network\"%g" $CONFIG_FILE
sed -i -e "s%\"alloraHomeDir\": \"\"%\"alloraHomeDir\": \"data\"%g" $CONFIG_FILE
chmod +x init.config
./init.config
sleep 2
docker compose up -d
break
;;
"Re-run node")
docker compose -f $HOME/basic-coin-prediction-node/docker-compose.yml up -d
break
;;
"Logs")
docker logs -f worker
break
;;

"Uninstall")
if [ ! -d "$HOME/basic-coin-prediction-node" ]; then
    break
fi
read -r -p "Wipe all DATA? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
cd $HOME/basic-coin-prediction-node && docker compose down -v
rm -rf $HOME/basic-coin-prediction-node $HOME/allora-chain
        ;;
    *)
	echo Canceled
	break
        ;;
esac
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
