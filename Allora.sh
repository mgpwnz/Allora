#!/bin/bash
while true
do

# Menu

PS3='Select an action: '
options=("Pre Install" "Install Wallet" "Install Worker" "Logs" "Uninstall Worker" "Uninstall Wallet" "Exit")
#options=("Pre Install" "Install Wallet" "Install Worker" "Re-run Worker" "Install Huggingface" "Re-run Huggingface" "Logs" "Uninstall Worker" "Uninstall Huggingface" "Uninstall Wallet" "Exit")
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
		sudo apt install curl jq apt-transport-https ca-certificates gnupg lsb-release -y
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
sudo apt install jq -y
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

"Install Wallet")
# Clone repository
git clone https://github.com/allora-network/allora-chain.git
cd allora-chain && make all
allorad version
sleep 1
allorad keys add testkey --recover
break
;;
"Install Worker")
if [  -d "$HOME/allora-huggingface-walkthrough" ]; then
docker compose -f $HOME/allora-huggingface-walkthrough/docker-compose.yaml down -v
fi
cd $HOME && git clone https://github.com/allora-network/basic-coin-prediction-node
cd basic-coin-prediction-node
#Copy the example configuration file and populate it with your variables:
cp config.example.json config.json
#create new conf
read -p "Enter wallet seed: " SEED
read -p "Enter API coingecko: " API
# Export seed as an environment variable
export SEED="${SEED}"
echo "Wallet seed exported."
export API="${API}"
echo "API exported."
# Update config.json with the provided seed and other parameters
CONFIG_FILE="$HOME/basic-coin-prediction-node/config.json"
sed -i -e "s%\"addressRestoreMnemonic\": \"\"%\"addressRestoreMnemonic\": \"${SEED}\"%g" $CONFIG_FILE
sed -i -e "s%\"nodeRpc\": \"http://localhost:26657\"%\"nodeRpc\": \"https://allora-rpc.testnet.allora.network/\"%g" $CONFIG_FILE
sed -i -e "s%\"alloraHomeDir\": \"\"%\"alloraHomeDir\": \"/root/.allorad\"%g" $CONFIG_FILE
sed -i -e "s%\"addressKeyName\": \"test\"%\"addressKeyName\": \"testkey\"%g" $CONFIG_FILE
# Update the worker block
sed -i '/"worker": \[/,/\]/c\
    "worker": [\
        {\
            "topicId": 1,\
            "inferenceEntrypointName": "api-worker-reputer",\
            "loopSeconds": 5,\
            "parameters": {\
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
                "Token": "ETH"\
            }\
        },\
        {\
            "topicId": 2,\
            "inferenceEntrypointName": "api-worker-reputer",\
            "loopSeconds": 5,\
            "parameters": {\
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
                "Token": "ETH"\
            }\
        },\
        {\
            "topicId": 7,\
            "inferenceEntrypointName": "api-worker-reputer",\
            "loopSeconds": 5,\
            "parameters": {\
                "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
                "Token": "ETH"\
            }\
        }\
    ]' $CONFIG_FILE
#change timeout
#TIMEOUT="$HOME/basic-coin-prediction-node/model.py"
#sed -i -e "s%intervals = \[\"1d\"\]%intervals = \[\"10m\", \"20m\", \"1h\", \"1d\"\]%g" $TIMEOUT
#create env
tee $HOME/basic-coin-prediction-node/.env > /dev/null <<EOF
TOKEN=ETH
TRAINING_DAYS=180
TIMEFRAME=4h
MODEL=BayesianRidge
REGION=EU
DATA_PROVIDER=coingecko
CG_API_KEY=$API
EOF

chmod +x init.config
./init.config
sleep 2
docker compose up --build -d
break
;;
"Re-run Worker")
docker compose -f $HOME/basic-coin-prediction-node/docker-compose.yml up -d
break
;;
"Update RPC")
cd basic-coin-prediction-node
docker compose down -v
CONFIG_FILE="$HOME/basic-coin-prediction-node/config.json"
sed -i -e "s%\"nodeRpc\": \"https://allora-rpc.testnet-1.testnet.allora.network\"%\"nodeRpc\": \"https://allora-rpc.testnet.allora.network/\"%g" $CONFIG_FILE
chmod +x init.config
./init.config
sleep 2
docker compose up -d
cd $HOME
break
;;
"Logs")
docker logs -f worker
break
;;
"Install Huggingface")
read -r -p "Install ver 2? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
#rem old config
if [  -d "$HOME/basic-coin-prediction-node" ]; then
docker compose -f $HOME/basic-coin-prediction-node/docker-compose.yml down -v
docker container prune
fi
#new config
cd $HOME
git clone https://github.com/allora-network/allora-huggingface-walkthrough
cd $HOME/allora-huggingface-walkthrough
mkdir -p worker-data
chmod -R 777 worker-data
#Copy the example configuration file and populate it with your variables:
cp config.example.json config.json
#create new conf
read -p "Enter wallet seed: " SEED
# Export seed as an environment variable
export SEED="${SEED}"
echo "Wallet seed exported."

# Update config.json with the provided seed and other parameters
CONFIG_FILE="$HOME/allora-huggingface-walkthrough/config.json"
sed -i -e "s%\"addressRestoreMnemonic\": \"\"%\"addressRestoreMnemonic\": \"${SEED}\"%g" $CONFIG_FILE
sed -i -e "s%\"alloraHomeDir\": \"\"%\"alloraHomeDir\": \"/root/.allorad\"%g" $CONFIG_FILE
sed -i -e "s%\"nodeRpc\": \"http://localhost:26657\"%\"nodeRpc\": \"https://allora-testnet-rpc.polkachu.com\"%g" $CONFIG_FILE
sed -i -e "s%\"addressKeyName\": \"test\"%\"addressKeyName\": \"testkey\"%g" $CONFIG_FILE
# # Update the worker block
#     sed -i '/"worker": \[/,/\]/c\
#         "worker": [\
#             {\
#                 "topicId": 1,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 1,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "ETH"\
#                 }\
#             },\
#             {\
#                 "topicId": 2,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 3,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "ETH"\
#                 }\
#             },\
#             {\
#                 "topicId": 3,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 5,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "BTC"\
#                 }\
#             },\
#             {\
#                 "topicId": 4,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 2,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "BTC"\
#                 }\
#             },\
#             {\
#                 "topicId": 5,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 4,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "SOL"\
#                 }\
#             },\
#             {\
#                 "topicId": 6,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 5,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "SOL"\
#                 }\
#             },\
#             {\
#                 "topicId": 7,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 2,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "ETH"\
#                 }\
#             },\
#             {\
#                 "topicId": 8,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 3,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "BNB"\
#                 }\
#             },\
#             {\
#                 "topicId": 9,\
#                 "inferenceEntrypointName": "api-worker-reputer",\
#                 "loopSeconds": 5,\
#                 "parameters": {\
#                     "InferenceEndpoint": "http://inference:8000/inference/{Token}",\
#                     "Token": "ARB"\
#                 }\
#             }\
#         ]' $CONFIG_FILE
#New app
read -p "Enter api key: " key
# Export seed as an environment variable
export key="${key}"
sed -i -e "s%<Your Coingecko API key>%${key}%g" $HOME/allora-huggingface-walkthrough/app.py
#init
chmod +x init.config
./init.config
docker compose up --build -d
cd $HOME
        ;;
    *)
	echo Canceled
	break
        ;;
esac
break
;;
"Re-run Huggingface")
docker compose -f $HOME/allora-huggingface-walkthrough/docker-compose.yaml up -d
break
;;
"Uninstall Worker")
if [ ! -d "$HOME/basic-coin-prediction-node" ]; then
    break
fi
read -r -p "Uninstall Worker? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
cd $HOME/basic-coin-prediction-node && docker compose down -v
rm -rf $HOME/basic-coin-prediction-node
        ;;
    *)
	echo Canceled
	break
        ;;
esac
break
;;
"Uninstall Huggingface")
if [ ! -d "$HOME/allora-huggingface-walkthrough" ]; then
    break
fi
read -r -p "Uninstall Huggingface? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
cd $HOME/allora-huggingface-walkthrough && docker compose down -v
rm -rf $HOME/allora-huggingface-walkthrough
        ;;
    *)
	echo Canceled
	break
        ;;
esac
break
;;
"Uninstall Wallet")
if [ ! -d "$HOME/wallet" ]; then
    break
fi
read -r -p "Remove Wallet? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY]) 
rm -rf $HOME/allora-chain $HOME/.allorad
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
