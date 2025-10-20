#!/bin/bash

#================================================================================
# Script Name: VPanel Installer
# Description: A professional script to manage VPanel related installations.
# Version: 0.1
#================================================================================

set -e

RESET='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_separator() {
    echo -e "${BLUE}======================================================================${RESET}"
}

show_header() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
          ___                 _
  /\   /\/ _ \__ _ _ __   ___| |
  \ \ / / /_)/ _` | '_ \ / _ \ |
   \ V / ___/ (_| | | | |  __/ |
    \_/\/    \__,_|_| |_|\___|_|

EOF
    echo -e "${RESET}"
    print_separator
    echo -e "${YELLOW}           Welcome to the VPanel Tools Installer & Manager${RESET}"
    print_separator
}

generate_password() {
    openssl rand -base64 16 | tr -dc 'a-zA-Z0-9' | fold -w 12 | head -n 1
}

install_auto_bot() {
    echo -e "\n${CYAN}Starting the fully automatic installation for the bot script...${RESET}"

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This installation requires root privileges.${RESET}"
        echo -e "${YELLOW}Please run the script with 'sudo'.${RESET}"
        return 1
    fi

    local install_path="/var/www/html/bot"
    local auto_db_setup=true

    echo -e "\n${YELLOW}This process will ensure all required packages are installed and will automatically configure the database.${RESET}"

    print_separator
    echo -e "${CYAN}Step 1: Installing prerequisite packages...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y > /dev/null 2>&1
    apt-get install -y software-properties-common > /dev/null 2>&1
    add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1
    apt-get update -y > /dev/null 2>&1
    apt-get install -y nginx mysql-server php8.2-fpm php8.2-mysql php8.2-curl php8.2-xml wget unzip openssl > /dev/null 2>&1
    echo -e "${GREEN}Prerequisites installed/updated successfully.${RESET}"

    print_separator
    echo -e "${CYAN}Step 2: Starting and enabling services...${RESET}"
    systemctl start nginx > /dev/null 2>&1
    systemctl enable nginx > /dev/null 2>&1
    systemctl start mysql > /dev/null 2>&1
    systemctl enable mysql > /dev/null 2>&1
    systemctl start php8.2-fpm > /dev/null 2>&1
    systemctl enable php8.2-fpm > /dev/null 2>&1
    echo -e "${GREEN}Services (Nginx, MySQL, PHP) are up and running.${RESET}"

    print_separator
    echo -e "${CYAN}Step 3: Configuring PHP for larger uploads...${RESET}"
    local php_ini_path="/etc/php/8.2/fpm/php.ini"
    sed -i "s/upload_max_filesize = .*/upload_max_filesize = 256M/" "$php_ini_path"
    sed -i "s/post_max_size = .*/post_max_size = 260M/" "$php_ini_path"
    sed -i "s/memory_limit = .*/memory_limit = 300M/" "$php_ini_path"
    sed -i "s/max_execution_time = .*/max_execution_time = 300/" "$php_ini_path"
    sed -i "s/max_input_time = .*/max_input_time = 300/" "$php_ini_path"
    systemctl restart php8.2-fpm
    echo -e "${GREEN}PHP settings updated for large files and service restarted.${RESET}"

    print_separator
    echo -e "${CYAN}Step 4: Setting up the database automatically...${RESET}"
    db_host="localhost"
    db_name="vpanel_bot_$(openssl rand -hex 4)"
    db_user="vpanel_user_$(openssl rand -hex 4)"
    db_pass=$(generate_password)

    mysql -e "CREATE DATABASE $db_name;"
    mysql -e "CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
    mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    echo -e "${GREEN}Database and user created successfully.${RESET}"

    print_separator
    echo -e "${CYAN}Step 5: Downloading and setting up bot files...${RESET}"
    local repo_url="https://5.75.203.177/vpanel-bot-main.zip"
    local temp_zip_file="/tmp/vpanel-bot-main.zip"
    mkdir -p "$install_path"
    wget -q -O "$temp_zip_file" "$repo_url"
    unzip -q "$temp_zip_file" -d "$install_path"
    shopt -s dotglob
    mv "$install_path/vpanel-bot-main/"* "$install_path/"
    shopt -u dotglob
    rm -f "$temp_zip_file"
    rm -rf "$install_path/vpanel-bot-main/"
    chown -R www-data:www-data "$install_path"
    echo -e "${GREEN}Bot files are in place at ${YELLOW}$install_path${RESET}"

    print_separator
    echo -e "${YELLOW}Please provide the bot and panel information:${RESET}"

    read -p "Telegram Bot Token: " bot_token
    read -p "Telegram Bot Username (without @): " bot_username
    read -p "Telegram Bot Display Name: " bot_name
    echo ""
    read -p "Sanaei Panel Protocol (http/https): " panel_protocol
    read -p "Sanaei Panel URL (domain only): " panel_url
    read -p "Sanaei Panel IP (optional): " panel_ip
    read -p "Sanaei Panel Port: " panel_port
    read -p "Sanaei Panel Path (optional, e.g., /path): " panel_path
    read -p "Sanaei Panel Username: " panel_username
    read -s -p "Sanaei Panel Password: " panel_password
    echo ""
    read -p "Bot Admin Username: " admin_username
    read -s -p "Bot Admin Password (min 6 chars): " admin_password
    echo ""
    read -p "Bot Admin Panel Path (e.g., my-admin): " admin_path

    print_separator
    echo -e "${CYAN}Configuring the bot...${RESET}"
    mysql -h"$db_host" -u"$db_user" -p"$db_pass" "$db_name" < "$install_path/database.sql"
    echo -e "${GREEN}Database structure imported.${RESET}"

    local env_file="$install_path/local/.env"
    sed -i "s/^DB_HOST=.*/DB_HOST=$db_host/" "$env_file"
    sed -i "s/^DB_PORT=.*/DB_PORT=3306/" "$env_file"
    sed -i "s/^DB_DATABASE=.*/DB_DATABASE=$db_name/" "$env_file"
    sed -i "s/^DB_USERNAME=.*/DB_USERNAME=$db_user/" "$env_file"
    sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=\"$db_pass\"/" "$env_file"
    echo -e "${GREEN}.env file configured.${RESET}"

    local hashed_password=$(php -r "echo password_hash('$admin_password', PASSWORD_DEFAULT);")
    local sql_commands="
    UPDATE settings SET value='$bot_token' WHERE name='bot_token';
    UPDATE settings SET value='$bot_username' WHERE name='bot_username';
    UPDATE settings SET value='$bot_name' WHERE name='bot_name';
    UPDATE settings SET value='$admin_path' WHERE name='path';
    INSERT INTO hosts (protocol, url, ip, port, path, username, password) VALUES ('$panel_protocol', '$panel_url', '$panel_ip', '$panel_port', '$panel_path', '$panel_username', '$panel_password');
    UPDATE users SET username='$admin_username', password='$hashed_password' WHERE id=1;
    UPDATE settings SET value='yes' WHERE name='installed';
    "
    mysql -h"$db_host" -u"$db_user" -p"$db_pass" "$db_name" -e "$sql_commands"
    echo -e "${GREEN}All settings saved to the database.${RESET}"

    print_separator
    echo -e "${CYAN}Configuring Nginx web server...${RESET}"
    rm -f /etc/nginx/sites-enabled/default
    local nginx_conf="/etc/nginx/sites-available/vpanel-bot"
    cat > "$nginx_conf" <<EOF
server {
    listen 80;
    server_name _;
    client_max_body_size 260M;
    root $install_path;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    ln -s -f "$nginx_conf" /etc/nginx/sites-enabled/
    nginx -t > /dev/null 2>&1
    systemctl restart nginx
    echo -e "${GREEN}Nginx configured to serve the bot.${RESET}"

    print_separator
    echo -e "${CYAN}Finalizing installation...${RESET}"
    rm -f "$install_path/install.php"
    rm -f "$install_path/database.sql"
    echo -e "${GREEN}Removed temporary installation files.${RESET}"

    print_separator
    echo -e "${GREEN}✅✅✅ Automatic installation complete! ✅✅✅${RESET}"
    echo -e "${YELLOW}The bot is now installed.${RESET}"
    echo -e "${RED}IMPORTANT: Please return to the main menu and use the 'Set Bot Cron Job' option to fully activate the bot.${RESET}"
    echo -e "You can access the admin panel at: ${CYAN}http://<your_server_ip>/$admin_path${RESET}"

    if [ "$auto_db_setup" = true ]; then
        print_separator
        echo -e "${RED}IMPORTANT: Please save these auto-generated database credentials:${RESET}"
        echo -e "Database Name: ${GREEN}$db_name${RESET}"
        echo -e "Database User: ${GREEN}$db_user${RESET}"
        echo -e "Database Password: ${GREEN}$db_pass${RESET}"
    fi
    print_separator
}


install_manual_bot() {
    echo -e "\n${CYAN}Starting the manual installation process for the bot script...${RESET}"

    if ! command_exists wget || ! command_exists unzip; then
        echo -e "${RED}Error: 'wget' and 'unzip' are required. Please install them.${RESET}"
        echo -e "${YELLOW}On Debian/Ubuntu, use: sudo apt update && sudo apt install wget unzip -y${RESET}"
        return 1
    fi

    local repo_url="https://5.75.203.177/vpanel-bot-main.zip"
    local temp_zip_file="vpanel-bot-main.zip"

    read -p "$(echo -e ${YELLOW}"\nPlease enter the full installation path (e.g., /var/www/html/bot): "${RESET})" install_path

    if [ -z "$install_path" ]; then
        echo -e "\n${RED}Error: The installation path cannot be empty. Operation cancelled.${RESET}"
        return 1
    fi

    mkdir -p "$install_path"

    echo -e "\n${CYAN}Downloading the script from the repository...${RESET}"
    if wget -q -O "$temp_zip_file" "$repo_url"; then
        echo -e "${GREEN}Download completed successfully.${RESET}"
    else
        echo -e "${RED}Error downloading the file. Please check your internet connection and the URL.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Extracting files to: $install_path${RESET}"
    if unzip -q "$temp_zip_file" -d "$install_path"; then
        mv "$install_path/vpanel-bot-main/"* "$install_path/"
        rmdir "$install_path/vpanel-bot-main/"
        echo -e "${GREEN}Files extracted successfully.${RESET}"
    else
        echo -e "${RED}Error extracting the zip file.${RESET}"
        rm -f "$temp_zip_file"
        return 1
    fi

    rm -f "$temp_zip_file"

    print_separator
    echo -e "${GREEN}✅ Initial installation complete!${RESET}"
    echo -e "${YELLOW}Please open install.php in your browser to continue the setup.${RESET}"
    print_separator
}

setup_bot_ssl_auto() {
    echo -e "\n${CYAN}Starting Automatic SSL Setup for Bot via Let's Encrypt...${RESET}"
    local nginx_conf="/etc/nginx/sites-available/vpanel-bot"

    if [ ! -f "$nginx_conf" ]; then
        echo -e "${RED}Error: Bot Nginx config not found at '$nginx_conf'.${RESET}"
        echo -e "${YELLOW}Please install the bot first using the automatic installer.${RESET}"
        return 1
    fi

    if ! command_exists certbot; then
        echo -e "${YELLOW}Certbot not found. Installing...${RESET}"
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1
        echo -e "${GREEN}Certbot installed successfully.${RESET}"
    fi

    print_separator
    read -p "$(echo -e ${YELLOW}"Enter your domain name (e.g., bot.example.com): "${RESET})" domain
    read -p "$(echo -e ${YELLOW}"Enter your email for Let's Encrypt renewal notices: "${RESET})" email

    if [ -z "$domain" ] || [ -z "$email" ]; then
        echo -e "${RED}Error: Domain and email cannot be empty. Aborting.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Updating Nginx configuration for domain: $domain...${RESET}"
    if sudo sed -i "s/server_name _;/server_name $domain;/" "$nginx_conf"; then
        echo -e "${GREEN}Nginx config updated.${RESET}"
    else
        echo -e "${RED}Error: Failed to update Nginx configuration file.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Testing Nginx configuration...${RESET}"
    if ! sudo nginx -t; then
        echo -e "${RED}Error: Nginx configuration test failed.${RESET}"
        echo -e "${YELLOW}Reverting changes...${RESET}"
        sudo sed -i "s/server_name $domain;/server_name _;/" "$nginx_conf"
        return 1
    fi

    echo -e "\n${CYAN}Reloading Nginx to apply changes...${RESET}"
    sudo systemctl reload nginx

    echo -e "\n${CYAN}Requesting SSL certificate for $domain...${RESET}"

    if sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email "$email" -d "$domain"; then
        echo -e "\n${GREEN}✅✅✅ SSL certificate has been successfully configured for $domain! ✅✅✅${RESET}"
    else
        echo -e "\n${RED}Error: SSL certificate generation failed. Please check Certbot's output.${RESET}"
        echo -e "${YELLOW}Reverting Nginx configuration changes...${RESET}"
        sudo sed -i "s/server_name $domain;/server_name _;/" "$nginx_conf"
        sudo systemctl reload nginx
    fi
}

setup_bot_ssl_manual() {
    echo -e "\n${CYAN}Starting Manual SSL Setup for Bot...${RESET}"
    local nginx_conf="/etc/nginx/sites-available/vpanel-bot"

    if [ ! -f "$nginx_conf" ]; then
        echo -e "${RED}Error: Bot Nginx config not found. Please install the bot first.${RESET}"
        return 1
    fi

    print_separator
    read -p "$(echo -e ${YELLOW}"Enter the full path to your certificate file (e.g., /path/to/fullchain.pem): "${RESET})" cert_path
    read -p "$(echo -e ${YELLOW}"Enter the full path to your private key file (e.g., /path/to/privkey.pem): "${RESET})" key_path

    if [ ! -f "$cert_path" ] || [ ! -f "$key_path" ]; then
        echo -e "${RED}Error: One or both certificate file paths are invalid. Aborting.${RESET}"
        return 1
    fi

    local install_path=$(grep -oP 'root\s+\K[^;]+' "$nginx_conf")
    read -p "$(echo -e ${YELLOW}"Please confirm the domain name for this certificate (e.g., bot.example.com): "${RESET})" domain

    if [ -z "$domain" ]; then
        echo -e "${RED}Error: Domain name cannot be empty. Aborting.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Backing up existing Nginx config to ${nginx_conf}.bak...${RESET}"
    sudo cp "$nginx_conf" "${nginx_conf}.bak"

    echo -e "${CYAN}Writing new Nginx configuration with SSL...${RESET}"
    sudo bash -c "cat > '$nginx_conf'" <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

# Main HTTPS server block
server {
    listen 443 ssl http2;
    server_name $domain;

    # SSL Configuration
    ssl_certificate $cert_path;
    ssl_certificate_key $key_path;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    root $install_path;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    echo -e "\n${CYAN}Testing Nginx configuration...${RESET}"
    if sudo nginx -t; then
        echo -e "${GREEN}Nginx configuration is valid.${RESET}"
        echo -e "${CYAN}Restarting Nginx to apply changes...${RESET}"
        sudo systemctl restart nginx
        echo -e "\n${GREEN}✅✅✅ Manual SSL setup complete! ✅✅✅${RESET}"
    else
        echo -e "\n${RED}Error: Nginx configuration test failed.${RESET}"
        echo -e "${YELLOW}Restoring from backup. Please check your settings and try again.${RESET}"
        sudo mv "${nginx_conf}.bak" "$nginx_conf"
    fi
}

ssl_menu() {
    while true; do
        show_header
        echo -e "${YELLOW}Bot SSL Configuration Menu${RESET}"
        print_separator
        echo -e "${GREEN}1)${RESET} Automatic Setup (Let's Encrypt)"
        echo -e "${GREEN}2)${RESET} Manual Setup (Provide own certs)"
        echo -e "------------------------------------"
        echo -e "${RED}0)${RESET} Back to Main Menu"
        print_separator

        read -p "$(echo -e ${YELLOW}"Please choose an option [0-2]: "${RESET})" choice

        case $choice in
            1)
                setup_bot_ssl_auto
                echo -e "\n${YELLOW}Press Enter to return...${RESET}"; read -r
                ;;
            2)
                setup_bot_ssl_manual
                echo -e "\n${YELLOW}Press Enter to return...${RESET}"; read -r
                ;;
            0)
                return
                ;;
            *)
                echo -e "\n${RED}Error: Invalid option.${RESET}"
                echo -e "\n${YELLOW}Press Enter to return...${RESET}"; read -r
                ;;
        esac
    done
}

setup_bot_cronjob() {
    echo -e "\n${CYAN}Preparing to set up bot cron job...${RESET}"

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This operation requires root access.${RESET}"
        echo -e "${YELLOW}Please run the script with 'sudo'.${RESET}"
        return 1
    fi

    local install_path="/var/www/html/bot"

    if [ ! -f "${install_path}/scheduler.php" ]; then
        echo -e "${RED}Error: scheduler file not found in '${install_path}/scheduler.php'.${RESET}"
        echo -e "${YELLOW}Please ensure the bot is installed correctly via the auto-install option first.${RESET}"
        return 1
    fi

    print_separator
    echo -e "${CYAN}Setting up cron job to run every minute...${RESET}"
    local cron_command="/usr/bin/php ${install_path}/scheduler.php"
    local cron_job="* * * * * ${cron_command} >/dev/null 2>&1"

    local current_crontab=$(crontab -l 2>/dev/null)

    (echo "$current_crontab"; echo "$cron_job") | crontab -
    echo -e "${GREEN}✅ Cron job has been set successfully for the root user.${RESET}"
    
    print_separator
}

install_auto_api() {
    echo -e "\n${CYAN}Starting integrated automatic installation of Sanaei API...${RESET}"

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This installation requires root privileges. Please run with sudo.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Step 1: Installing prerequisite packages (git, curl, php)...${RESET}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y > /dev/null 2>&1
    apt-get install -y git curl software-properties-common unzip > /dev/null 2>&1
    echo -e "${GREEN}Prerequisites installed successfully.${RESET}"

    print_separator
    echo -e "${CYAN}Step 2: Downloading Sanaei API from repository...${RESET}"
    local install_dir="/var/www/sanaei-api"
    if [ -d "$install_dir" ]; then
        read -p "$(echo -e ${YELLOW}"Directory $install_dir already exists. Overwrite? [y/N]: "${RESET})" confirm_overwrite
        if [[ "$confirm_overwrite" =~ ^[yY](es)?$ ]]; then
            rm -rf "$install_dir"
            echo -e "${CYAN}Existing directory removed.${RESET}"
        else
            echo -e "${BLUE}Installation cancelled by user.${RESET}"
            return 1
        fi
    fi
    mkdir -p /var/www
    local repo_url="https://github.com/vpaneladmin/sanaei-api.git"
    if git clone "$repo_url" "$install_dir" >/dev/null 2>&1; then
        echo -e "${GREEN}Project downloaded successfully to $install_dir.${RESET}"
    else
        echo -e "${RED}Error: Failed to clone the repository.${RESET}"
        return 1
    fi

    print_separator
    echo -e "${CYAN}Step 3: Setting up Timezone, PHP 8.2 and Composer...${RESET}"
    timedatectl set-timezone Asia/Tehran
    add-apt-repository ppa:ondrej/php -y > /dev/null 2>&1
    apt-get update -y > /dev/null 2>&1
    apt-get install -y php8.2 php8.2-fpm php8.2-xml php8.2-curl php8.2-sqlite3 php8.2-dom > /dev/null 2>&1

    if ! command_exists composer; then
        wget https://getcomposer.org/installer -q -O composer-installer.php
        php composer-installer.php --filename=composer --install-dir=/usr/local/bin > /dev/null 2>&1
        rm composer-installer.php
    fi
    echo -e "${GREEN}PHP and Composer are ready.${RESET}"

    echo -e "${CYAN}Step 4: Installing application dependencies...${RESET}"
    cd "$install_dir/api"
    echo -e "${YELLOW}Running 'composer install'. This may take a few moments...${RESET}"
    if php /usr/local/bin/composer install --no-dev --optimize-autoloader; then
        echo -e "${GREEN}Composer dependencies installed successfully.${RESET}"
    else
        echo -e "${RED}Error: 'composer install' failed. Please check the output above for details.${RESET}"
        return 1
    fi

    echo -e "${CYAN}Configuring application environment...${RESET}"
    php artisan key:generate
    echo -e "${GREEN}Application configured.${RESET}"

    print_separator
    echo -e "${CYAN}Step 5: Configuring the system service...${RESET}"
    read -p "$(echo -e ${YELLOW}"Please enter your server's public IP address: "${RESET})" server_ip
    if [ -z "$server_ip" ]; then
        echo -e "${RED}Error: IP address cannot be empty. Aborting.${RESET}"
        return 1
    fi

    local service_script_path="/usr/local/bin/vpanel.sh"
    cat > "$service_script_path" <<EOF
#!/bin/bash
cd $install_dir/api
php artisan serve --host=$server_ip --port=8009
EOF
    chmod +x "$service_script_path"
    echo -e "${GREEN}Service script created at $service_script_path.${RESET}"

    local systemd_file_path="/etc/systemd/system/vpanel.service"
    cat > "$systemd_file_path" <<EOF
[Unit]
Description=Sanaei VPanel API Service
After=network.target

[Service]
User=root
Group=root
ExecStart=/bin/bash $service_script_path
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    echo -e "${GREEN}Systemd service file created.${RESET}"

    print_separator
    echo -e "${CYAN}Step 6: Opening firewall and starting service...${RESET}"
    ufw allow 8009/tcp > /dev/null 2>&1
    echo -e "${GREEN}Firewall port 8009 opened.${RESET}"

    systemctl daemon-reload
    systemctl start vpanel.service
    systemctl enable vpanel.service
    echo -e "${GREEN}Sanaei API service is now running and enabled on boot.${RESET}"

    print_separator
    echo -e "${GREEN}✅✅✅ Sanaei API installation complete! ✅✅✅${RESET}"
    echo -e "${YELLOW}The API should be accessible at: ${CYAN}http://$server_ip:8009${RESET}"
    print_separator
}

install_manual_api() {
    echo -e "\n${CYAN}Starting Guided Manual Installation for Sanaei API...${RESET}"
    print_separator
    echo -e "${YELLOW}This process will clone the repository for you and then provide instructions.${RESET}"

    if ! command_exists git; then
        echo -e "\n${RED}'git' is not installed, which is required to clone the repository.${RESET}"
        read -p "$(echo -e ${YELLOW}"Do you want to install git now? [y/N]: "${RESET})" install_git
        if [[ "$install_git" =~ ^[yY](es)?$ ]]; then
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y git > /dev/null 2>&1
            echo -e "${GREEN}Git has been installed successfully.${RESET}"
        else
            echo -e "${RED}Cannot proceed without git. Aborting.${RESET}"
            return 1
        fi
    fi

    local repo_url="https://github.com/vpaneladmin/sanaei-api.git"
    local clone_dir="sanaei-api"

    if [ -d "$clone_dir" ]; then
        echo -e "\n${YELLOW}Directory '$clone_dir' already exists.${RESET}"
        read -p "$(echo -e ${YELLOW}"Do you want to remove it and clone again? [y/N]: "${RESET})" remove_dir
        if [[ "$remove_dir" =~ ^[yY](es)?$ ]]; then
            rm -rf "$clone_dir"
            echo -e "${CYAN}Removed existing directory.${RESET}"
        else
            echo -e "${RED}Aborting to prevent data loss.${RESET}"
            return 1
        fi
    fi

    echo -e "\n${CYAN}Cloning the Sanaei API repository into './$clone_dir'...${RESET}"
    if git clone "$repo_url" "$clone_dir"; then
        echo -e "${GREEN}Repository cloned successfully.${RESET}"
    else
        echo -e "${RED}Error: Failed to clone the repository. Please check your connection.${RESET}"
        return 1
    fi

    print_separator
    echo -e "${GREEN}✅ First step is complete! Now, follow these manual steps:${RESET}"
    print_separator
    echo -e "${CYAN}1. Navigate into the new directory:${RESET}"
    echo -e "   ${YELLOW}cd $clone_dir${RESET}"
    echo ""
    echo -e "${CYAN}2. Run the installer script with sudo privileges:${RESET}"
    echo -e "   ${YELLOW}sudo bash install.sh${RESET}"
    echo ""
    echo -e "${CYAN}3. During the installation, the script will ask you for:${RESET}"
    echo -e "   - ${YELLOW}Your Server's IP Address${RESET} (Enter it and press Enter)"
    echo -e "   - ${YELLOW}Confirmation to run Composer${RESET} (You should probably enter 'yes')"
    echo ""
    echo -e "${CYAN}4. After the script finishes, verify the installation:${RESET}"
    echo -e "   Open your web browser and go to ${YELLOW}http://<YOUR_IP>:8009${RESET}"
    echo -e "   You should see a message confirming it's working."
    print_separator
}

uninstall_sanaei_api() {
    echo -e "\n${CYAN}Starting the uninstallation process for Sanaei API...${RESET}"
    local default_api_path="/var/www/sanaei-api"
    read -p "$(echo -e ${YELLOW}"Enter the path of the 'sanaei-api' directory to remove [Default: ${default_api_path}]: "${RESET})" api_path

    api_path=${api_path:-$default_api_path}

    if [ ! -d "$api_path" ]; then
        echo -e "\n${RED}Error: The directory '$api_path' was not found.${RESET}"
        return 1
    fi

    echo -e "\n${RED}WARNING: You are about to permanently delete the following directory and its service:${RESET}"
    echo -e "${YELLOW}$api_path${RESET}"
    read -p "$(echo -e ${RED}"Are you sure you want to continue? [y/N]: "${RESET})" confirm

    if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
        echo -e "\n${CYAN}Stopping and disabling the systemd service...${RESET}"
        if systemctl is-active --quiet vpanel.service; then
            systemctl stop vpanel.service
            echo -e "${GREEN}Service stopped.${RESET}"
        fi
        if systemctl is-enabled --quiet vpanel.service; then
            systemctl disable vpanel.service
            rm -f /etc/systemd/system/vpanel.service
            rm -f /usr/local/bin/vpanel.sh
            systemctl daemon-reload
            echo -e "${GREEN}Service disabled and files removed.${RESET}"
        fi

        echo -e "\n${CYAN}Removing directory...${RESET}"
        if rm -rf "$api_path"; then
            echo -e "${GREEN}✅ Sanaei API directory has been successfully removed.${RESET}"
        else
            echo -e "${RED}Error: Failed to remove the directory. Check permissions.${RESET}"
        fi
    else
        echo -e "\n${BLUE}Uninstallation cancelled by user.${RESET}"
    fi
}

change_sanaei_api_ip() {
    echo -e "\n${CYAN}Starting the process to change Sanaei API IP address...${RESET}"

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This action requires root privileges.${RESET}"
        echo -e "${YELLOW}Please run the script with 'sudo'.${RESET}"
        return 1
    fi

    local service_script_path="/usr/local/bin/vpanel.sh"

    if [ ! -f "$service_script_path" ]; then
        echo -e "${RED}Error: The service script was not found at '${service_script_path}'.${RESET}"
        echo -e "${YELLOW}Please ensure the Sanaei API was installed correctly using the automatic installer.${RESET}"
        return 1
    fi

    read -p "$(echo -e ${YELLOW}"Please enter the new IP address for the API server: "${RESET})" new_ip

    if [ -z "$new_ip" ]; then
        echo -e "\n${RED}Error: The IP address cannot be empty. Operation cancelled.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Updating the service configuration file...${RESET}"
    if sed -i -E "s/--host=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|--host=[a-zA-Z0-9.-]+/--host=$new_ip/" "$service_script_path"; then
        echo -e "${GREEN}Service file updated successfully.${RESET}"
    else
        echo -e "${RED}Error: Failed to update the service file.${RESET}"
        return 1
    fi

    echo -e "\n${CYAN}Restarting the Sanaei API service to apply changes...${RESET}"
    if systemctl restart vpanel.service; then
        echo -e "${GREEN}✅ Sanaei API service restarted successfully.${RESET}"
        echo -e "${YELLOW}The API is now running on the new IP: ${new_ip}${RESET}"
    else
        echo -e "${RED}Error: Failed to restart the 'vpanel.service'.${RESET}"
        echo -e "${YELLOW}Please check the service status with 'systemctl status vpanel.service'.${RESET}"
    fi
}


show_telegram() {
    local telegram_channel="https://t.me/Vpanell"
    print_separator
    echo -e "${CYAN}Join our official channel for news, updates, and support:${RESET}"
    echo -e "${BLUE}${telegram_channel}${RESET}"
    print_separator
}

main_menu() {
    while true; do
        show_header
        echo -e "${GREEN}1)${RESET} Install Bot Script (Fully Automatic)"
        echo -e "${GREEN}2)${RESET} Install Bot Script (Manual)"
        echo -e "${CYAN}3)${RESET} Configure SSL for Bot"
        echo -e "${CYAN}4)${RESET} Set Bot Cron Job"
        echo -e "------------------------------------"
        echo -e "${GREEN}5)${RESET} Install Sanaei API (Fully Automatic & Integrated)"
        echo -e "${GREEN}6)${RESET} Install Sanaei API (Guided Manual)"
        echo -e "${CYAN}7)${RESET} Change Sanaei API IP"
        echo -e "${RED}8)${RESET} Uninstall Sanaei API"
        echo -e "------------------------------------"
        echo -e "${CYAN}9)${RESET} Official Telegram Channel"
        echo -e "${RED}0)${RESET} Exit"
        print_separator

        read -p "$(echo -e ${YELLOW}"Please choose an option [0-9]: "${RESET})" choice

        case $choice in
            1) install_auto_bot ;;
            2) install_manual_bot ;;
            3) ssl_menu ;;
            4) setup_bot_cronjob ;;
            5) install_auto_api ;;
            6) install_manual_api ;;
            7) change_sanaei_api_ip ;;
            8) uninstall_sanaei_api ;;
            9) show_telegram ;;
            0) echo -e "\n${BLUE}Goodbye!${RESET}"; exit 0 ;;
            *) echo -e "\n${RED}Error: Invalid option.${RESET}" ;;
        esac

        echo -e "\n${YELLOW}Press Enter to return to the main menu...${RESET}"
        read -r
    done
}

main_menu
