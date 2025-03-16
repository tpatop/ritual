#!/bin/bash

# Логотип
show_logotip() {
    # Установка figlet, если его нет
    if ! command -v figlet &> /dev/null; then
        sudo apt install figlet -y  # Install figlet if not present
    fi

    # ASCII art text
    text=$(figlet -f slant "RITUAL NODE")

    # Огненный градиент (red -> orange -> yellow)
    echo -e "\e[91m${text//█/\e[93m█\e[91m}\e[0m"
    
    bash <(curl -s https://raw.githubusercontent.com/tpatop/logo/refs/heads/main/logotype.sh)
}

# Переменные для путей
CONFIG_PATH="/root/infernet-container-starter/deploy/config.json"
HELLO_CONFIG_PATH="/root/infernet-container-starter/projects/hello-world/container/config.json"
DEPLOY_SCRIPT_PATH="/root/infernet-container-starter/projects/hello-world/contracts/script/Deploy.s.sol"
MAKEFILE_PATH="/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
DOCKER_COMPOSE_PATH="/root/infernet-container-starter/deploy/docker-compose.yaml"
#foundryup="/root/.foundry/bin/foundryup"
#FORGE_PATH="/root/.foundry/bin/forge"
export PATH=$PATH:/root/.foundry/bin

# Функция для запроса подтверждения
confirm() {
    local prompt="$1"
    read -p "$prompt [y/n]: " choice
    if [[ -z "$choice" || "$choice" == "y" ]]; then
        return 0  # Выполнить действие
    else
        return 1  # Пропустить действие
    fi
}

# Функция для установки зависимостей
install_dependencies() {
    echo "Обновление пакетов и установка зависимостей..."
    sudo apt update -y && sudo apt upgrade -y
    sudo apt install -y make build-essential unzip lz4 gcc git jq ncdu tmux \
    cmake clang pkg-config libssl-dev python3-pip protobuf-compiler bc curl screen
    echo "Установка Docker и Docker Compose..."
    bash <(curl -s https://raw.githubusercontent.com/tpatop/nodateka/refs/heads/main/basic/admin/docker.sh)
    echo "Скачивание необходимого образа"
    docker pull ritualnetwork/hello-world-infernet:latest
}

# Функция для клонирования репозитория
clone_repository() {
    local repo_url="https://github.com/ritual-net/infernet-container-starter"
    local destination="infernet-container-starter"
    
    # Запрос у пользователя на клонирование
    read -p "Скачать репозиторий infernet-container-starter? [y/n]: " confirm
    confirm=${confirm:-y}

    if [[ "$confirm" == "y" ]]; then
        # Проверяем, существует ли папка и не является ли она пустой
        if [[ -d "$destination" && ! -z "$(ls -A $destination)" ]]; then
            echo "ВНИМАНИЕ: Каталог '$destination' уже существует и не пуст. Клонирование не будет выполнено."
            read -p "Хотите удалить существующий каталог и клонировать заново? [y/n]: " delete_confirm

            if [[ "$delete_confirm" == "y" ]]; then
                echo "Удаление существующего каталога и клонирование..."
                rm -rf "$destination"
                git clone "$repo_url" "$destination"
            else
                echo "Клонирование пропущено."
            fi
        else
            echo "Клонирование репозитория infernet-container-starter..."
            git clone "$repo_url" "$destination"
        fi
    else
        echo "Клонирование пропущено."
    fi
    cd infernet-container-starter || exit
}

# Функция для изменений настроек
change_settings() {
    # Получение данных
    read -p "Введите значение sleep [3]: " SLEEP
    SLEEP=${SLEEP:-3}
    read -p "Введите значение trail_head_blocks [1]: " TRAIL_HEAD_BLOCKS
    TRAIL_HEAD_BLOCKS=${TRAIL_HEAD_BLOCKS:-1}
    read -p "Введите значение batch_size [1800]: " BATCH_SIZE
    BATCH_SIZE=${BATCH_SIZE:-1800}
    read -p "Введите значение starting_sub_id [205000]: " STARTING_SUB_ID
    STARTING_SUB_ID=${STARTING_SUB_ID:-205000}

    # Внесение изменений
    sed -i "s|\"sleep\":.*|\"sleep\": $SLEEP,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"batch_size\":.*|\"batch_size\": $BATCH_SIZE,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"starting_sub_id\":.*|\"starting_sub_id\": $STARTING_SUB_ID,|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"trail_head_blocks\":.*|\"trail_head_blocks\": $TRAIL_HEAD_BLOCKS,|" "$HELLO_CONFIG_PATH"

}


# Функция для настройки конфигурационных файлов
configure_files() {
    echo "Настройка файлов конфигурации..."

    # Резервное копирование файлов
    cp "$HELLO_CONFIG_PATH" "${HELLO_CONFIG_PATH}.bak"
    cp "$DEPLOY_SCRIPT_PATH" "${DEPLOY_SCRIPT_PATH}.bak"
    cp "$MAKEFILE_PATH" "${MAKEFILE_PATH}.bak"
    cp "$DOCKER_COMPOSE_PATH" "${DOCKER_COMPOSE_PATH}.bak"

    # Параметры с пользовательским вводом
    read -p "Введите ваш private_key (c 0x): " PRIVATE_KEY
    read -p "Введите адрес RPC [https://mainnet.base.org]: " RPC_URL
    RPC_URL=${RPC_URL:-https://mainnet.base.org}
    change_settings

    # Изменения в файле конфигурации
    sed -i 's|4000,|5000,|' "$HELLO_CONFIG_PATH"
    if confirm "Порт 3000 свободен?"; then
        echo "Отлично, продолжаю установку"
    else
        echo "Занятый порт 3000 будет изменен на 4998. Учтите это при проверках."
        sed -i 's|"3000"|"4998"|' "$HELLO_CONFIG_PATH"
    fi
    sed -i "s|\"registry_address\":.*|\"registry_address\": \"0x3B1554f346DFe5c482Bb4BA31b880c1C18412170\",|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"private_key\":.*|\"private_key\": \"$PRIVATE_KEY\",|" "$HELLO_CONFIG_PATH"
    sed -i "s|\"rpc_url\":.*|\"rpc_url\": \"$RPC_URL\",|" "$HELLO_CONFIG_PATH"

    # Изменения в deploy-скрипте и Makefile
    sed -i "s|address registry =.*|address registry = 0x3B1554f346DFe5c482Bb4BA31b880c1C18412170;|" "$DEPLOY_SCRIPT_PATH"
    sed -i "s|sender :=.*|sender := $PRIVATE_KEY|" "$MAKEFILE_PATH"
    sed -i "s|RPC_URL :=.*|RPC_URL := $RPC_URL|" "$MAKEFILE_PATH"

    # Изменение порта в docker-compose.yaml
    sed -i 's|4000:|5000:|' "$DOCKER_COMPOSE_PATH"
    sed -i 's|8545:|4999:|' "$DOCKER_COMPOSE_PATH"
    sed -i "s|ritualnetwork/infernet-node:1.3.1|ritualnetwork/infernet-node:1.4.0|" "$DOCKER_COMPOSE_PATH"    

    echo "Настройка файлов завершена."
}

# Функция для запуска screen сессии
start_screen_session() {
    # Проверяем наличие сессии с именем 'ritual'
    if screen -list | grep -q "ritual"; then
        echo "Найдена предыдущая сессия 'ritual'. Удаляем..."
        screen -S ritual -X quit
    fi

    echo "Запуск screen сессии 'ritual'..."
    screen -S ritual -d -m bash -c "project=hello-world make deploy-container; bash"
    echo "Открыто новое окно screen."
}

# Перезапуск проекта
restart_node() {
    if confirm "Перезапустить Docker контейнеры?"; then
        echo "Перезапуск контейнеров..."
        docker compose -f $DOCKER_COMPOSE_PATH down
        docker compose -f $DOCKER_COMPOSE_PATH up -d 
    else
        echo "Перезапуск контейнеров отменен."
    fi
}

# Функция для проверки и выполнения foundryup
run_foundryup() {
    # Проверяем, добавлен ли путь до Foundry в .bashrc
    if grep -q 'foundry' ~/.bashrc; then
        source ~/.bashrc
        echo "Запускаем foundryup..."
        foundryup
    else
        echo "Путь до foundryup не найден в .bashrc."
        echo "Пожалуйста, выполните 'source ~/.bashrc' вручную или перезапустите терминал."
    fi
}

# Функция для установки Foundry
install_foundry() {
    echo "Установка Foundry..."
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
}

# Функция для установки зависимостей проекта
install_project_dependencies() {
    echo "Установка зависимостей для hello-world проекта..."
    cd /root/infernet-container-starter/projects/hello-world/contracts || exit
    forge install --no-commit foundry-rs/forge-std || { echo "Ошибка при установке зависимости forge-std. Устраняем..."; rm -rf lib/forge-std && forge install --no-commit foundry-rs/forge-std; }
    forge install --no-commit ritual-net/infernet-sdk || { echo "Ошибка при установке зависимости infernet-sdk. Устраняем..."; rm -rf lib/infernet-sdk && forge install --no-commit ritual-net/infernet-sdk; }
}

# Функция для развертывания контракта
deploy_contract() {
    if confirm "Развернуть контракт?"; then
        echo "Развертывание контракта..."
        cd /root/infernet-container-starter || exit
        project=hello-world make deploy-contracts
    else
        echo "Пропущено развертывание контракта."
    fi
}
# Функция для замены адреса контракта
call_contract() {
    read -p "Введите Contract Address: " CONTRACT_ADDRESS
    echo "Заменяем старый номер в CallsContract.s.sol..."
    sed -i "s|SaysGM(.*)|SaysGM($CONTRACT_ADDRESS)|" ~/infernet-container-starter/projects/hello-world/contracts/script/CallContract.s.sol
    echo "Выполняем команду project=hello-world make call-contract..."
    project=hello-world make call-contract
}

# Функция для замены RPC URL
replace_rpc_url() {
    if confirm "Заменить RPC URL?"; then
        read -p "Введите новый RPC URL [https://mainnet.base.org]: " NEW_RPC_URL
        NEW_RPC_URL=${NEW_RPC_URL:-https://mainnet.base.org}

        CONFIG_PATHS=(
            "/root/infernet-container-starter/projects/hello-world/container/config.json"
            "/root/infernet-container-starter/deploy/config.json"
            "/root/infernet-container-starter/projects/hello-world/contracts/Makefile"
        )

        # Переменная для отслеживания найденных файлов
        files_found=false

        for config_path in "${CONFIG_PATHS[@]}"; do
            if [[ -f "$config_path" ]]; then
                sed -i "s|\"rpc_url\": \".*\"|\"rpc_url\": \"$NEW_RPC_URL\"|g" "$config_path"
                echo "RPC URL заменен в $config_path"
                files_found=true  # Устанавливаем флаг, если файл найден
            else
                echo "Файл $config_path не найден, пропускаем."
            fi
        done

        # Если не найдено ни одного файла, выводим сообщение
        if ! $files_found; then
            echo "Не удалось найти ни одного конфигурационного файла для замены RPC URL."
            return  # Завершаем выполнение функции
        fi
        restart_node
        echo "Контейнеры перезапущены после замены RPC URL."
    else
        echo "Замена RPC URL отменена."
    fi
}

# Функция для удаления ноды
delete_node() {
    if confirm "Удалить ноду и очистить файлы?"; then
        cd ~
        echo "Остановка и удаление контейнеров"
        docker compose -f $DOCKER_COMPOSE_PATH down

        # Завершение screen сессии
        if screen -list | grep -q "ritual"; then
            echo "Завершаем screen сессию 'ritual'..."
            screen -S ritual -X quit
        fi

        echo "Удаление директории проекта"
        rm -rf ~/infernet-container-starter
        
        echo "Удаление образов проекта, хранилищ..."
        docker system prune -a
        echo "Нода удалена и файлы очищены."
    else
        echo "Удаление ноды отменено."
    fi
}

# Функция для отображения информации о проекте
show_project_info() {
    echo "Информация о проекте:"
    echo ""
    echo "Рекомендуемые системные характеристики:"
    echo "- CPU: 4 ядра"
    echo "- RAM: 16 GB"
    echo "- Хранилище: 500 GB SSD"
    echo "- Новый EVM кошелек с токенами ETH на основной сети Base (15-20$ на счету)"
    echo ""
    echo "Требуемые порты (4998 - резерв для 3000):"
    required_ports=("3000" "5000" "2020" "24224" "6379" "4999", "4998")
    
    for port in "${required_ports[@]}"; do
        if ss -tuln | grep -q ":$port "; then
            echo "Порт $port: ЗАНЯТ"
        else
            echo "Порт $port: СВОБОДЕН"
        fi
    done
}

# Функция для отображения меню
show_menu() {
    echo ""
    echo "Выберите действие:"
    echo "1. Установка ноды"
    echo "2. Смена базовых настроек"
    echo "3. Замена RPC"
    echo "4. Логи ноды"
    echo "5. Статус контейнеров"
    echo "6. Деплой контракта"
    echo "7. Информация о проекте"
    echo "8. Перезагрузка контейнеров"
    echo "9. Удаление ноды"
    echo "0. Выход"
}

# Функция для обработки выбора пользователя
handle_choice() {
    case "$1" in
        1)
            echo "Запущена установка ноды..."
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
            echo "Замена RPC URL..."
            replace_rpc_url
            ;;
        4)
            echo "Отображение логов ноды..."
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
            echo "Удаление ноды..."
            delete_node
            ;;
        0)
            echo "Выход..."
            exit 0
            ;;
        *)
            echo "Неверный выбор, попробуйте снова."
            ;;
    esac
}

while true; do
    show_logotip
    show_menu
    read -p "Ваш выбор: " action
    handle_choice "$action"
    echo ""
done
