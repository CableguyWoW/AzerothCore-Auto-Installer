#!/bin/bash

### AzerothCore INSTALL SCRIPT
### TESTED WITH DEBIAN ONLY

. /AzerothCore-Auto-Installer/configs/root-config
. /AzerothCore-Auto-Installer/configs/auth-config
. /AzerothCore-Auto-Installer/configs/realm-dev-config

### LETS START
echo ""
echo "##########################################################"
echo "## ROOT INSTALL SCRIPT STARTING...."
echo "##########################################################"
echo ""
NUM=0
export DEBIAN_FRONTEND=noninteractive


if [ "$1" = "" ]; then
echo ""
echo "## No option selected, see list below"
echo ""
echo "- [all] : Run Full Script"
echo ""
((NUM++)); echo "- [$NUM] : Install AzerothCore Requirements"
((NUM++)); echo "- [$NUM] : Update File Permissions"
((NUM++)); echo "- [$NUM] : Install and Setup MySQL"
((NUM++)); echo "- [$NUM] : Create Remote MySQL user"
((NUM++)); echo "- [$NUM] : Setup Firewall"
((NUM++)); echo "- [$NUM] : Setup Linux Users"
((NUM++)); echo "- [$NUM] : Install Fail2Ban"
((NUM++)); echo "- [$NUM] : Show Command List"
echo ""
echo ""


else


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Installing AzerothCore requirements"
echo "##########################################################"
echo ""
sudo apt update -y
sudo apt install git cmake make gcc g++ clang libssl-dev libbz2-dev libreadline-dev libncurses-dev libmysqlclient-dev libboost-all-dev lsb-release gnupg wget p7zip-full screen -y
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Update File Permissions"
echo "##########################################################"
echo ""
# Define the shared group
SHARED_GROUP="azerothcore"
# Create the shared group if it doesn't exist
if ! getent group "$SHARED_GROUP" >/dev/null; then
  sudo groupadd "$SHARED_GROUP"
fi
# Add users to the shared group
sudo usermod -aG "$SHARED_GROUP" "$USER"           # Add current user
sudo usermod -aG "$SHARED_GROUP" "$SETUP_REALM_USER" # Add $SETUP_REALM_USER
sudo usermod -aG "$SHARED_GROUP" "$SETUP_AUTH_USER" # Add $SETUP_AUTH_USER
# Set group ownership and permissions
sudo chown -R :"$SHARED_GROUP" /AzerothCore-Auto-Installer/ # Set ownership to shared group
sudo find /AzerothCore-Auto-Installer/ -type d -exec chmod 2770 {} \; # Directories: Setgid + User/Group read, write, execute
sudo find /AzerothCore-Auto-Installer/ -type f -exec chmod 660 {} \;  # Files: User/Group read, write
sudo chmod +x /AzerothCore-Auto-Installer/scripts/Setup/*.sh          # Make scripts executable
# Ensure new files inherit the shared group
sudo find /AzerothCore-Auto-Installer/ -type d -exec chmod g+s {} \; # Setgid bit for directories
cd /AzerothCore-Auto-Installer/scripts/Setup/
fi



((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Install MySQL Server"
echo "##########################################################"
echo ""

MY_CNF="/etc/mysql/mysql.conf.d/mysqld.cnf"

# Function to check if MySQL is running
check_mysql_running() 
{
    systemctl is-active --quiet mysql
}

# Function to stop MySQL forcefully if needed
force_stop_mysql() 
{
    echo "Attempting to stop MySQL forcefully..."
    # Get MySQL process IDs and terminate them
    pids=$(pgrep -u mysql)
    if [ -n "$pids" ]; then
        echo "MySQL processes found: $pids"
        sudo kill -TERM $pids
        sleep 5  # Wait a moment for termination
        pids=$(pgrep -u mysql)
        if [ -n "$pids" ]; then
            echo "MySQL processes still running. Sending SIGKILL..."
            sudo kill -KILL $pids
        fi
    else
        echo "No MySQL processes found to kill."
    fi
}

# Function to stop MySQL forcefully if needed
stop_mysql() 
{
# Stop MySQL service gracefully
echo "Stopping MySQL service..."
sudo service mysql stop

# Wait for MySQL to stop gracefully
echo "Waiting for MySQL to stop gracefully... Please wait."
attempts=0
max_attempts=5
while check_mysql_running; do
    if [ $attempts -ge $max_attempts ]; then
        echo "MySQL did not stop gracefully. Proceeding with forceful termination..."
        force_stop_mysql
        break
    fi
    echo "Waiting for MySQL to stop... Attempt $((attempts+1)) of $max_attempts"
    sleep 3
    attempts=$((attempts + 1))
done

# Final check to ensure MySQL has stopped
if check_mysql_running; then
    echo "ERROR: MySQL is still running despite attempts to stop it. Please check the logs."
    exit 1
else
    echo "MySQL stopped successfully."
fi
}

# Function to start MySQL
start_mysql() 
{
# Restart MySQL normally
echo "Restarting MySQL normally... Please wait."
sudo service mysql start

echo "Waiting for MySQL to start normally... Please wait."
attempts=0
while ! check_mysql_running; do
    if [ $attempts -ge $max_attempts ]; then
        echo "MySQL failed to start. Please check the logs."
        exit 1
    fi
    echo "Waiting for MySQL to start... Attempt $((attempts+1)) of $max_attempts"
    sleep 3
    attempts=$((attempts + 1))
done
echo "MySQL started successfully."
}

# Function to restart MySQL
restart_mysql()
{
  stop_mysql;
  start_mysql;
}


# Set root password for MySQL installation
echo "mysql-server mysql-server/root_password password $ROOT_PASS" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $ROOT_PASS" | sudo debconf-set-selections

# Install MySQL server
apt-get -y install mysql-server

# Configure MySQL settings
# Add skip-networking if not present
if ! grep -q "^skip-networking" "$MY_CNF"; then
    echo "skip-networking" | sudo tee -a "$MY_CNF" > /dev/null
fi

# Add max_allowed_packet if not present
if ! grep -q "^max_allowed_packet" "$MY_CNF"; then
    echo "max_allowed_packet = 128M" | sudo tee -a "$MY_CNF" > /dev/null
fi

# Add sql_mode if not present
if ! grep -q "^sql_mode" "$MY_CNF"; then
    echo 'sql_mode=""' | sudo tee -a "$MY_CNF" > /dev/null
fi

stop_mysql;

# Start MySQL in safe mode (skip-grant-tables) to allow user changes without a password
echo "Starting MySQL in safe mode to modify user settings... Please wait."
sudo mysqld_safe --skip-grant-tables --skip-networking &
sleep 5  # Wait for MySQL to start in safe mode

# Update MySQL root user settings
echo "Manually updating MySQL root user settings... Please wait."
mysql -u root <<EOF
USE mysql;

UPDATE user 
SET authentication_string = '$ROOT_PASS', plugin = 'mysql_native_password'
WHERE user = 'root' AND host = 'localhost';

UPDATE user 
SET Grant_priv = 'Y', Super_priv = 'Y'
WHERE user = 'root' AND host = 'localhost';

FLUSH PRIVILEGES;
EOF

restart_mysql;

# Configure bind-address after restart if needed
if [ "$REMOTE_DB_SETUP" = "true" ]; then
    if ! grep -q "^bind-address" "$MY_CNF"; then
        echo "bind-address = 0.0.0.0" | sudo tee -a "$MY_CNF" > /dev/null
    fi
fi

restart_mysql;

# Remove skip-networking if not required
sudo sed -i '/^skip-networking/d' "$MY_CNF"

restart_mysql;

fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Setting up MySQL Users"
echo "##########################################################"
echo ""

# Remote DB User Setup
if [ "$REMOTE_DB_SETUP" == "true" ]; then
    echo "Checking if remote DB user '$REMOTE_DB_USER' exists at host '$REMOTE_DB_HOST'..."
    
    # Check if the remote user exists
    if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SELECT User FROM mysql.user WHERE User = '$REMOTE_DB_USER' AND Host = '$REMOTE_DB_HOST';" | grep -q "$REMOTE_DB_USER"; then
        mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '$REMOTE_DB_USER'@'$REMOTE_DB_HOST' IDENTIFIED WITH mysql_native_password BY '$REMOTE_DB_PASS';"
        if [[ $? -eq 0 ]]; then
            echo "Remote DB user '$REMOTE_DB_USER' created."
        else
            echo "Failed to create remote DB user '$REMOTE_DB_USER'."
            exit 1
        fi
    else
        echo "Remote DB user '$REMOTE_DB_USER' already exists."
    fi

    # Grant necessary permissions
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO '$REMOTE_DB_USER'@'$REMOTE_DB_HOST' WITH GRANT OPTION;"
    if [[ $? -eq 0 ]]; then
        echo "Granted all privileges to '$REMOTE_DB_USER'@'$REMOTE_DB_HOST'."
    else
        echo "Failed to grant privileges to '$REMOTE_DB_USER'@'$REMOTE_DB_HOST'."
        exit 1
    fi
    
    # Flush privileges
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
    echo "Flushed privileges."
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setting up Firewall"
echo "##########################################################"
echo ""
sudo apt-get install ufw --assume-yes
# SSH port
sudo sed -i "s/^#Port 22\+$/Port $SSH_PORT/" /etc/ssh/sshd_config
if [ "$REMOTE_DB_SETUP" = "true" ]; then
sudo ufw allow 3306
fi
if [ $SETUP_DEV_WORLD == "true" ]; then
    sudo ufw allow $SETUP_REALM_PORT
fi
if [ $SETUP_AUTH == "true" ]; then
    sudo ufw allow 3724
fi
sudo systemctl restart sshd
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Linux Users"
echo "##########################################################"
echo ""
if [ $SETUP_DEV_WORLD == "true" ]; then
	sudo useradd -m -p $SETUP_REALM_PASS -s /bin/bash $SETUP_REALM_USER
    if ! sudo grep -q "$SETUP_REALM_USER ALL=(ALL) NOPASSWD: ALL" "/etc/sudoers.d/$SETUP_AUTH_USER"; then
        echo "$SETUP_REALM_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$SETUP_REALM_USER
        echo "Added $SETUP_REALM_USER to sudoers with NOPASSWD."
    fi
    echo "Added $SETUP_REALM_USER User account"
fi
if [ $SETUP_AUTH == "true" ]; then
	sudo useradd -m -p $SETUP_AUTH_PASS -s /bin/bash $SETUP_AUTH_USER
    if ! sudo grep -q "$SETUP_AUTH_USER ALL=(ALL) NOPASSWD: ALL" "/etc/sudoers.d/$SETUP_AUTH_USER"; then
        echo "$SETUP_AUTH_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$SETUP_AUTH_USER
        echo "Added $SETUP_AUTH_USER to sudoers with NOPASSWD."
    fi
    echo "Added $SETUP_AUTH_USER User account"
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Install Fail2Ban"
echo "##########################################################"
echo ""
sudo apt install -y fail2ban

# Enable Fail2Ban to start on boot
echo "Enabling Fail2Ban to start on boot..."
sudo systemctl enable fail2ban

# Start Fail2Ban service
echo "Starting Fail2Ban service..."
sudo systemctl start fail2ban

# Basic configuration (optional)
echo "Creating a local configuration file..."
if [ ! -f /etc/fail2ban/jail.local ]; then
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    echo "[DEFAULT]" | sudo tee -a /etc/fail2ban/jail.local
    echo "bantime  = 1h" | sudo tee -a /etc/fail2ban/jail.local
    echo "findtime  = 10m" | sudo tee -a /etc/fail2ban/jail.local
    echo "maxretry = 3" | sudo tee -a /etc/fail2ban/jail.local
    echo "" | sudo tee -a /etc/fail2ban/jail.local
    echo "[sshd]" | sudo tee -a /etc/fail2ban/jail.local
    echo "enabled = true" | sudo tee -a /etc/fail2ban/jail.local
fi

# Restart Fail2Ban to apply changes
echo "Restarting Fail2Ban service..."
sudo systemctl restart fail2ban

# Status of Fail2Ban
echo "Checking the status of Fail2Ban..."
sudo systemctl status fail2ban

echo "Fail2Ban installation completed!"
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "7" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Root install script finished"
echo "##########################################################"
echo ""
echo -e "\e[31mNOTICE - YOUR NEW SSH PORT WILL BE $SSH_PORT FROM NOW ON\e[0m"
echo ""
echo ""
echo -e "\e[32m↓↓↓ For authserver - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_AUTH_USER -c 'cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Auth-Install.sh all'"
echo ""
echo -e "\e[32m↓↓↓ For Dev Realm - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_REALM_USER -c 'cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Realm-Dev-Install.sh all'"
echo ""
fi
fi
