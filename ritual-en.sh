#!/bin/bash

# logo
show_logotip() {
    # Check if figlet is installed and install if not
    if ! command -v figlet &> /dev/null; then
        sudo apt install figlet -y  # Install figlet if not present
    fi

    # ASCII art text
    text=$(figlet -f slant "RITUAL NODE")

    # Fire gradient (red -> orange -> yellow)
    echo -e "\e[91m${text//█/\e[93m█\e[91m}\e[0m"

    bash <(curl -s https://raw.githubusercontent.com/tpatop/logo/refs/heads/main/logotype.sh)
}

# Variables for paths
CONFIG_PATH="/root/infernet-container-starter/deploy/config.json"
HELLO_CONFIG_PATH="/root/infernet-container-starter/projects/hello-world/container/config.json"
DEPLOY_SCRIPT_PATH="/root/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
MAKEFILE_PATH="/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
DOCKER_COMPOSE_PATH="/root/infernet-container-starter/deploy/docker-compose.yaml"
#foundryup="/root/.foundry/bin/foundryup"
#FORGE_PATH="/root/.foundry/bin/forge"
export PATH=$PATH:/root/.foundry/bin

# Function for confirmation prompt
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n]: " choice
    if [[ -z "$choice" || "$choice" == "y" ]]; then
        return 0  # Proceed with action
    else
        return 1  # Skip action
    fi
}

# Function to install dependencies
install_dependencies() {
    echo "Updating packages and installing dependencies..."
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y make build-essential unzip lz4 gcc git jq ncdu tmux \
    cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc curl screen
    echo "Installing Docker and Docker Compose..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
    echo "Downloading required image"
    docker pull ritualnetwork/hello-world-infernet:latest
}

# Function to clone repository
clone_repository() {
    local repo_url="https://github.com/ritual-net/infernet-container-starter"
    local destination="infernet-container-starter"
    
    # Prompt user for cloning
    read -p "Download infernet-container-starter repository? [y/n]: " confirm
    confirm=${confirm:-y}

    if [[ "$confirm" == "y" ]]; then
        # Check if the directory exists and is not empty
        if [[ -d "$destination" && ! -z "$(ls -A $destination)" ]]; then
            echo "WARNING: Directory '$destination' already exists and is not empty. Cloning will not proceed."
            read -p "Do you want to delete the existing directory and clone again? [y/n]: " delete_confirm

            if [[ "$delete_confirm" == "y" ]]; then
                echo "Deleting existing directory and cloning..."
                rm -rf "$destination"
                git clone "$repo_url" "$destination"
            else
                echo "Cloning skipped."
            fi
        else
            echo "Cloning infernet-container-starter repository..."
            git clone "$repo_url" "$destination"
        fi
    else
        echo "Cloning skipped."
    fi
    cd infernet-container-starter || exit
}

# Function to change settings
change_settings() {
    # Get user input
    read -p "Enter sleep value [3]: " SLEEP
    SLEEP=${SLEEP:-3}
    read -p "Enter trail_head_blocks value [1]: " TRAIL_HEAD_BLOCKS
    TRAIL_HEAD_BLOCKS=${TRAIL_HEAD_BLOCKS:-1}
    read -p "Enter batch_size value [1800]: " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-1800}
    read -p "Enter starting_sub_id value [205000]: " STARTING_SUB_ID
    STARTING_SUB_ID=${STARTING_SUB_ID:-205000}

    # Apply changes
    sed -i "s|\"sleep\":.*|\"sleep\": $SLEEP,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"batch_size\":.*|\"batch_size\": $BATCH_SIZE,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"starting_sub_id\":.*|\"starting_sub_id\": $STARTING_SUB_ID,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"trail_head_blocks\":.*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS,|" "$HELLO_CONFIG_PATH"
}

# Function to configure configuration files
configure_files() {
    echo "Configuring configuration files..."

    # Backup files
    cp "$HELLO_CONFIG_PATH" "${HELLO_CONFIG_PATH}.bak"
    cp "$DEPLOY_SCRIPT_PATH" "${DEPLOY_SCRIPT_PATH}.bak"
    cp "$MAKEFILE_PATH" "${MAKEFILE_PATH}.bak"
    cp "$DOCKER_COMPOSE_PATH" "${DOCKER_COMPOSE_PATH}.bak"

    # User input parameters
    read -p "Enter your private_key (with 0x): " PRIVATE_KEY
    read -p "Enter RPC address [https://mainnet.base.org]: " RPC_URL
    RPC_URL=${RPC_URL:-https://mainnet.base.org}
    change_settings

    # Changes in configuration file
    sed -i 's|4000,|5000,|' "$HELLO_CONFIG_PATH"
    if confirm "Is port 3000 available?"; then
        echo "Great, continuing installation"
    else
        echo "Port 3000 is busy, changing to 4998. Please note this during checks."
        sed -i 's|"3000"|"4998"|' "$HELLO_CONFIG_PATH"
    fi
    sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"private_key\":.*|\"private_key\": \"$PRIVATE_KEY\",|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"$RPC_URL\",|" "$HELLO_CONFIG_PATH"

    # Changes in deploy script and Makefile
    sed -i "s|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$DEPLOY_SCRIPT_PATH"
    sed -i "s|sender :=.*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
    sed -i "s|RPC_URL :=.*|RPC_URL := $RPC_URL|" "$MAKEFILE_PATH"

    # Change port in docker-compose.yaml
    sed -i 's|4000:|5000:|' "$DOCKER_COMPOSE_PATH"
    sed -i 's|8545:|4999:|' "$DOCKER_COMPOSE_PATH"
    sed -i "s|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|" "$DOCKER_COMPOSE_PATH"    

    echo "Configuration files setup complete."
}

# Function to start a screen session
start_screen_session() {
    # Check if a session named 'ritual' already exists
    if screen -list | grep -q "ritual"; then
        echo "Found existing 'ritual' session. Deleting..."
        screen -S ritual -X quit
    fi

    echo "Starting 'ritual' screen session..."
    screen -S ritual -d -m bash -c "project=hello-world make deploy-container; bash"
    echo "New screen window opened."
}

# Restart project
restart_node() {
    if confirm "Restart Docker containers?"; then
        echo "Restarting containers..."
        docker compose -f $DOCKER_COMPOSE_PATH down
        docker compose -f $DOCKER_COMPOSE_PATH up -d 
    else
        echo "Container restart canceled."
    fi
}

# Function to check and run foundryup
run_foundryup() {
    # Check if Foundry path is added to .bashrc
    if grep -q 'foundry' ~/.bashrc; then
        source ~/.bashrc
        echo "Running foundryup..."
        foundryup
    else
        echo "Foundryup path not found in .bashrc."
        echo "Please manually run 'source ~/.bashrc' or restart the terminal."
    fi
}

# Function to install Foundry
install_foundry() {
    echo "Installing Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    #run_foundryup
    foundryup
}

# Function to install project dependencies
install_project_dependencies() {
    echo "Installing dependencies for hello-world project..."
    cd /root/infernet-container-starter/projects/hello-world/contracts || exit
    forge install --no-commit foundry-rs/forge-std || { echo "Error installing forge-std dependency. Fixing..."; rm -rf lib/forge-std && forge install --no-commit foundry-rs/forge-std; }
    forge install --no-commit ritual-net/infernet-sdk || { echo "Error installing infernet-sdk dependency. Fixing..."; rm -rf lib/infernet-sdk && forge install --no-commit ritual-net/infernet-sdk; }
}

# Function to deploy contract
deploy_contract() {
    if confirm "Deploy contract?"; then
        echo "Deploying contract..."
        cd /root/infernet-container-starter || exit
        project=hello-world make deploy-contracts
    else
        echo "Skipping contract deployment."
    fi
}

# Function to replace contract address
call_contract() {
    read -p "Enter Contract Address: " CONTRACT_ADDRESS
    echo "Replacing old address in CallsContract.s.sol..."
    sed -i "s|SaysGM(.*)|SaysGM($CONTRACT_ADDRESS)|" ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol
    echo "Running command project=hello-world make call-contract..."
    project=hello-world make call-contract
}

# Function to replace RPC URL
replace_rpc_url() {
    if confirm "Replace RPC URL?"; then
        read -p "Enter new RPC URL [https://mainnet.base.org]: " NEW_RPC_URL
        NEW_RPC_URL=${NEW_RPC_URL:-https://mainnet.base.org}

        CONFIG_PATHS=(
            "/root/infernet-container-starter/projects/hello-world/container/config.json"
            "/root/infernet-container-starter/deploy/config.json"
            "/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
        )

        # Variable to track found files
        files_found=false

        for config_path in "${CONFIG_PATHS[@]}"; do
            if [[ -f "$config_path" ]]; then
                sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$NEW_RPC_URL\"|g" "$config_path"
                echo "RPC URL replaced in $config_path"
                files_found=true  # Set flag if file is found
            else
                echo "File $config_path not found, skipping."
            fi
        done

        # If no files were found, display a message
        if ! $files_found; then
            echo "No configuration files found for RPC URL replacement."
            return  # Exit the function
        fi
        restart_node
        echo "Containers restarted after RPC URL replacement."
    else
        echo "RPC URL replacement canceled."
    fi
}

# Function to delete node
delete_node() {
    if confirm "Delete node and clean up files?"; then
        cd ~
        echo "Stopping and removing containers"
        docker compose -f $DOCKER_COMPOSE_PATH down

        # Terminate screen session
        if screen -list | grep -q "ritual"; then
            echo "Terminating 'ritual' screen session..."
            screen -S ritual -X quit
        fi

        echo "Deleting project directory"
        rm -rf ~/infernet-container-starter
        
        echo "Removing project images, storage..."
        docker system prune -a
        echo "Node deleted and files cleaned up."
    else
        echo "Node deletion canceled."
    fi
}

# Function to display project information
show_project_info() {
    echo "Project information:"
    echo ""
    echo "Recommended system specifications:"
    echo "- CPU: 4 cores"
    echo "- RAM: 16 GB"
    echo "- Storage: 500 GB SSD"
    echo "- New EVM wallet with ETH tokens on Base mainnet (15-20$ balance)"
    echo ""
    echo "Required ports (4998 - backup for 3000):"
    required_ports=("3000" "5000" "2020" "24224" "6379" "4999", "4998")
    
    for port in "${required_ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo "Port $port: BUSY"
        else
            echo "Port $port: FREE"
        fi
    done
}

# Function to display menu
show_menu() {
    echo ""
    echo "Choose an action:"
    echo "1. Node installation"
    echo "2. Change basic settings"
    echo "3. Replace RPC"
    echo "4. Node logs"
    echo "5. Container status"
    echo "6. Deploy contract"
    echo "7. Project information"
    echo "8. Restart containers"
    echo "9. Delete node"
    echo "0. Exit"
}

# Function to handle user choice
handle_choice() {
    case "$1" in
        1)
            echo "Starting node installation..."
            install_dependencies
            clone_repository
            configure_files
            start_screen_session
            install_foundry
            install_project_dependencies
            deploy_contract
            call_contract
            ;;
        2)
            change_settings
            cp "$HELLO_CONFIG_PATH" "$CONFIG_PATH"
            restart_node
            ;;
        3)
            echo "Replacing RPC URL..."
            replace_rpc_url
            ;;
        4)
            echo "Displaying node logs..."
            docker logs -f --tail 20 infernet-node
            ;;
        5)
            docker ps -a |grep infernet
            ;;
        6)
            deploy_contract
            call_contract
            ;;
        7)
            show_project_info
            ;;
        8)  
            restart_node
            ;;
        9)
            echo "Deleting node..."
            delete_node
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
}

while true; do
    show_logotip
    show_menu
    read -p "Your choice: " action
    handle_choice "$action"
    echo ""
done