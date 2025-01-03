#!/bin/bash

### AzerothCore AUTH INSTALL SCRIPT
### TESTED WITH UBUNTU ONLY

. /AzerothCore-Auto-Installer/configs/root-config
. /AzerothCore-Auto-Installer/configs/realm-dev-config
. /AzerothCore-Auto-Installer/configs/auth-config


if [ $USER != "$SETUP_AUTH_USER" ]; then

echo "You must run this script under the $SETUP_AUTH_USER user!"

else

## LETS START
echo ""
echo "##########################################################"
echo "## AUTH SERVER INSTALL SCRIPT STARTING...."
echo "##########################################################"
echo ""
NUM=0
export DEBIAN_FRONTEND=noninteractive


if [ "$1" = "" ]; then
## Option List
echo "## No option selected, see list below"
echo ""
echo "- [all] : Run Full Script"
echo "- [update] : Update Source and DB"
echo ""
((NUM++)); echo "- [$NUM] : Close Authserver"
((NUM++)); echo "- [$NUM] : Setup MySQL Database & Users"
((NUM++)); echo "- [$NUM] : Pull and Setup Source"
((NUM++)); echo "- [$NUM] : Setup Authserver Config"
((NUM++)); echo "- [$NUM] : Setup Restarter"
((NUM++)); echo "- [$NUM] : Setup Crontab"
((NUM++)); echo "- [$NUM] : Setup Alias"
((NUM++)); echo "- [$NUM] : Start Authserver"
echo ""

else


NUM=0
((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Closing Authserver"
echo "##########################################################"
echo ""
killall screen
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup MySQL Database & Users"
echo "##########################################################"
echo ""

# Auth Database Setup
echo "Checking if the 'auth' database exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE 'auth';" | grep -q "auth"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE auth DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Auth database created."
    else
        echo "Failed to create Auth database."
        exit 1
    fi
else
    echo "Auth database already exists."
fi

# Create the auth user if it does not already exist
echo "Checking if the auth user '$AUTH_DB_USER' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SELECT User FROM mysql.user WHERE User = '$AUTH_DB_USER' AND Host = 'localhost';" | grep -q "$AUTH_DB_USER"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '$AUTH_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$AUTH_DB_PASS';"
    if [[ $? -eq 0 ]]; then
        echo "Auth DB user '$AUTH_DB_USER' created."
    else
        echo "Failed to create Auth DB user '$AUTH_DB_USER'."
        exit 1
    fi
else
    echo "Auth DB user '$AUTH_DB_USER' already exists."
    
    # Update password for existing user
    echo "Updating password for auth DB user '$AUTH_DB_USER'..."
    if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "ALTER USER '$AUTH_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$AUTH_DB_PASS';"; then
        echo "Password for auth DB user '$AUTH_DB_USER' updated successfully."
    else
        echo "Failed to update password for auth DB user '$AUTH_DB_USER'."
        exit 1
    fi
fi

# Grant privileges to the auth user
echo "Granting privileges to '$AUTH_DB_USER' on the 'auth' database..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON auth.* TO '$AUTH_DB_USER'@'localhost';"; then
    echo "Granted all privileges on 'auth' database to '$AUTH_DB_USER'."
else
    echo "Failed to grant privileges to '$AUTH_DB_USER'."
    exit 1
fi

# Flush privileges
mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
echo "Flushed privileges."
echo "Setup Auth DB Account completed."
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Compling AzerothCore Source"
echo "##########################################################"
echo ""
cd /home/$SETUP_AUTH_USER/
mkdir /home/$SETUP_AUTH_USER/
mkdir /home/$SETUP_AUTH_USER/server/
mkdir /home/$SETUP_AUTH_USER/logs/
## Source install
git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" azerothcore
## Build source
echo "Building Source"
cd /home/$SETUP_AUTH_USER/azerothcore/
mkdir /home/$SETUP_AUTH_USER/azerothcore/build
cd /home/$SETUP_AUTH_USER/azerothcore/build
# Build flags for CMAKE
if [ "$SETUP_TYPE" = "Normal" ]; then
    cmake /home/$SETUP_AUTH_USER/azerothcore/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_AUTH_USER/server -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DWITH_WARNINGS=0 -DWITH_COREDEBUG=0 -DTOOLS_BUILD=none -DSCRIPTS=static -DAPPS_BUILD=auth-only
elif [ "$SETUP_TYPE" = "GDB" ]; then
    cmake /home/$SETUP_AUTH_USER/azerothcore/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_AUTH_USER/server -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DWITH_WARNINGS=0 -DWITH_COREDEBUG=1 -DTOOLS_BUILD=none -DSCRIPTS=static -DAPPS_BUILD=auth-only
fi
# Stop issues with overusing CPU on some hosts
cpus=$(nproc)
if [ "$cpus" -gt 1 ]; then
  cpus=$((cpus - 1))
fi
make -j "$cpus" install
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Config"
echo "##########################################################"
echo ""
cd /home/$SETUP_AUTH_USER/server/etc/
if [ -f "/home/$SETUP_AUTH_USER/server/etc/authserver.conf.dist" ]; then
    # Backup old conf
    mv "authserver.conf" "authserver_$(date +%Y%m%d_%H%M%S).conf"
    mv "authserver.conf.dist" "authserver.conf"
    echo "Moved authserver.conf.dist to authserver.conf."
    ## Changing Config values
    echo "Changing Config values"
    sed -i 's^LogsDir = ""^LogsDir = "/home/'${SETUP_AUTH_USER}'/server/logs"^g' authserver.conf
    sed -i "s/Updates.EnableDatabases = 0/Updates.EnableDatabases = 1/g" authserver.conf
    sed -i "s/Updates.AutoSetup = 0/Updates.AutoSetup = 1/g" authserver.conf
    sed -i "s/127.0.0.1;3306;acore;acore;acore_auth/${AUTH_DB_HOST};3306;${AUTH_DB_USER};${AUTH_DB_PASS};${AUTH_DB_USER};/g" authserver.conf
else
    echo "Missing config file, exiting..."
    exit 1
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "5" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Restarter"
echo "##########################################################"
echo ""
mkdir /home/$SETUP_AUTH_USER/server/scripts/
mkdir /home/$SETUP_AUTH_USER/server/scripts/Restarter/
mkdir /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
sudo cp -r -u /AzerothCore-Auto-Installer/scripts/Restarter/Auth/* /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
## FIX SCRIPTS PERMISSIONS
sudo chmod -R +x /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
sudo chown -R $SETUP_AUTH_USER:$SETUP_AUTH_USER /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/
sed -i "s/realmname/$SETUP_AUTH_USER/g" /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Crontab"
echo "##########################################################"
echo ""
crontab -r
crontab -l | { cat; echo "############## START AUTHSERVER ##############"; } | crontab -
crontab -l | { cat; echo "@reboot /home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh"; } | crontab -
echo "Auth Crontab setup"
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Setup Script Alias"
echo "##########################################################"
echo ""

HEADER="#### CUSTOM ALIAS"
FOOTER="#### END CUSTOM ALIAS"

# Remove content between the header and footer, including the markers
sed -i "/$HEADER/,/$FOOTER/d" ~/.bashrc

# Add header and footer if they are not present
if ! grep -Fxq "$HEADER" ~/.bashrc; then
    echo -e "\n$HEADER\n" >> ~/.bashrc
    echo "header added"
else
    echo "header present"
fi

# Add new commands between the header and footer
echo -e "\n## COMMANDS" >> ~/.bashrc
echo "alias commands='cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Auth-Install.sh && cd -'" >> ~/.bashrc

echo -e "\n## UPDATE" >> ~/.bashrc
echo "alias update='cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Auth-Install.sh update && cd -'" >> ~/.bashrc

if ! grep -Fxq "$FOOTER" ~/.bashrc; then
    echo -e "\n$FOOTER\n" >> ~/.bashrc
    echo "footer added"
fi

echo "Added script alias to bashrc"

# Source .bashrc to apply changes
. ~/.bashrc
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Starting Authserver"
echo "##########################################################"
echo ""
/home/$SETUP_AUTH_USER/server/scripts/Restarter/Auth/start.sh
echo "Authserver started"
fi

echo ""
echo "##########################################################"
echo "## AUTH INSTALLED AND FINISHED!"
echo "##########################################################"
echo ""
echo -e "\e[32m↓↓↓ To access the authserver - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_AUTH_USER -c 'screen -r auth'"
echo "TIP - To exit the screen press ALT + A + D"
echo ""
echo -e "\e[32m↓↓↓ To Install the Dev Realm - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_REALM_USER -c 'cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Realm-Dev-Install.sh all'"
echo ""


fi
fi
