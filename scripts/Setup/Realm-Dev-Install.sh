#!/bin/bash

### AzerothCore INSTALL SCRIPT
### TESTED WITH UBUNTU ONLY

. /AzerothCore-Auto-Installer/configs/root-config
. /AzerothCore-Auto-Installer/configs/auth-config
. /AzerothCore-Auto-Installer/configs/realm-dev-config

if [ $USER != "$SETUP_REALM_USER" ]; then

echo "You must run this script under the $SETUP_REALM_USER user!"

else

## LETS START
echo ""
echo "##########################################################"
echo "## DEV REALM INSTALL SCRIPT STARTING...."
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
echo "- [startrealm debug] : Start Realm screen under GDB"
echo "- [startrealm release] : Start Realm screen under release"
echo "- [stoprealm] : Stops all screen sessions on the user"
echo ""
((NUM++)); echo "- [$NUM] : Close Worldserver"
((NUM++)); echo "- [$NUM] : Setup MySQL Database & Users"
((NUM++)); echo "- [$NUM] : Pull and Setup Source"
((NUM++)); echo "- [$NUM] : Setup Worldserver Config"
((NUM++)); echo "- [$NUM] : Import Database"
((NUM++)); echo "- [$NUM] : Download 3.3.5a Client Data"
((NUM++)); echo "- [$NUM] : Setup World Restarter Scripts"
((NUM++)); echo "- [$NUM] : Setup Misc Scripts"
((NUM++)); echo "- [$NUM] : Setup Crontab"
((NUM++)); echo "- [$NUM] : Setup Script Alias"
((NUM++)); echo "- [$NUM] : Setup Realmlist"
((NUM++)); echo "- [$NUM] : Start Worldserver"
echo ""

else


NUM=0
((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Closing Worldserver"
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

# World Database Setup
echo "Checking if the database '${REALM_DB_USER}_world' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE '${REALM_DB_USER}_world';" | grep -q "${REALM_DB_USER}_world"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE ${REALM_DB_USER}_world DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Database '${REALM_DB_USER}_world' created."
    else
        echo "Failed to create database '${REALM_DB_USER}_world'."
        exit 1
    fi
else
    echo "Database '${REALM_DB_USER}_world' already exists."
fi

echo "Checking if the database '${REALM_DB_USER}_character' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SHOW DATABASES LIKE '${REALM_DB_USER}_character';" | grep -q "${REALM_DB_USER}_character"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE DATABASE ${REALM_DB_USER}_character DEFAULT CHARACTER SET UTF8MB4 COLLATE utf8mb4_unicode_ci;"
    if [[ $? -eq 0 ]]; then
        echo "Database '${REALM_DB_USER}_character' created."
    else
        echo "Failed to create database '${REALM_DB_USER}_character'."
        exit 1
    fi
else
    echo "Database '${REALM_DB_USER}_character' already exists."
fi

# Create the realm user if it does not already exist
echo "Checking if the realm user '${REALM_DB_USER}' exists..."
if ! mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "SELECT User FROM mysql.user WHERE User = '${REALM_DB_USER}' AND Host = 'localhost';" | grep -q "${REALM_DB_USER}"; then
    mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "CREATE USER '${REALM_DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '$REALM_DB_PASS';"
    if [[ $? -eq 0 ]]; then
        echo "Realm DB user '${REALM_DB_USER}' created."
    else
        echo "Failed to create realm DB user '${REALM_DB_USER}'."
        exit 1
    fi
else
    echo "Realm DB user '${REALM_DB_USER}' already exists."
    
    # Update password for existing user
    echo "Updating password for realm DB user '${REALM_DB_USER}'..."
    if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "ALTER USER '${REALM_DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '$REALM_DB_PASS';"; then
        echo "Password for realm DB user '${REALM_DB_USER}' updated successfully."
    else
        echo "Failed to update password for realm DB user '${REALM_DB_USER}'."
        exit 1
    fi
fi

# Grant privileges
echo "Granting privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON ${REALM_DB_USER}_world.* TO '${REALM_DB_USER}'@'localhost';"; then
    echo "Granted all privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'."
else
    echo "Failed to grant privileges on '${REALM_DB_USER}_world' to '${REALM_DB_USER}'."
    exit 1
fi

echo "Granting privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'..."
if mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON ${REALM_DB_USER}_character.* TO '${REALM_DB_USER}'@'localhost';"; then
    echo "Granted all privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'."
else
    echo "Failed to grant privileges on '${REALM_DB_USER}_character' to '${REALM_DB_USER}'."
    exit 1
fi

# Flush privileges
mysql -u "$ROOT_USER" -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
echo "Flushed privileges."
echo "Setup World DB Account completed."

fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Pulling AzerothCore Source"
echo "##########################################################"
echo ""
cd /home/$SETUP_REALM_USER/
mkdir /home/$SETUP_REALM_USER/server/
mkdir /home/$SETUP_REALM_USER/server/logs/
mkdir /home/$SETUP_REALM_USER/server/logs/crashes/
mkdir /home/$SETUP_REALM_USER/server/data/
## Source install
if [ -d "cd /home/$SETUP_REALM_USER/azerothcore" ]; then
    while true; do
        read -p "$FOLDERNAME already exists. Redownload? (y/n): " file_choice
        if [[ "$file_choice" =~ ^[Yy]$ ]]; then
            rm -rf /home/$SETUP_REALM_USER/azerothcore
            git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" azerothcore
            break
        elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping download." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    git clone --single-branch --branch $CORE_BRANCH "$CORE_REPO_URL" azerothcore
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "modules" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM. Adding Custom AzerothCore Modules"
echo "##########################################################"
echo ""

# Directory for modules
MODULE_DIR="/home/$SETUP_REALM_USER/azerothcore/modules"

# Config directory path
CONFIG_DIR="/home/$SETUP_REALM_USER/server/etc"

# Ensure module directory exists
mkdir -p "$MODULE_DIR"

# Iterate through module config options (1 to 100)
for i in $(seq 1 100); do
    MODULE_VAR="REALM_MODULE_$i"
    MODULE_URL="${!MODULE_VAR}"

    # Skip empty or undefined module entries
    if [ -z "$MODULE_URL" ]; then
        continue
    fi

    MODULE_NAME=$(basename "$MODULE_URL" .git)

    echo "Processing module: $MODULE_NAME"

    # Remove the existing module directory if it exists
    if [ -d "$MODULE_DIR/$MODULE_NAME" ]; then
        echo "Module $MODULE_NAME already exists. Removing it for reinstallation."
        rm -rf "$MODULE_DIR/$MODULE_NAME"
    fi

    # Clone the module from the specified URL
    echo "Cloning module $MODULE_NAME from $MODULE_URL"
    git clone "$MODULE_URL" "$MODULE_DIR/$MODULE_NAME"
done
fi



((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Building Source"
echo "##########################################################"
echo ""
cd /home/$SETUP_REALM_USER/azerothcore/
mkdir /home/$SETUP_REALM_USER/azerothcore/build
cd /home/$SETUP_REALM_USER/azerothcore/build
# Build flags for CMAKE
if [ "$SETUP_TYPE" = "Normal" ]; then
    cmake /home/$SETUP_REALM_USER/azerothcore/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_REALM_USER/server -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DWITH_WARNINGS=0 -DWITH_COREDEBUG=0 -DTOOLS_BUILD=db-only -DSCRIPTS=$SETUP_SCRIPTS -DMODULES=$SETUP_MODULES -DAPPS_BUILD=world-only
elif [ "$SETUP_TYPE" = "GDB" ]; then
    cmake /home/$SETUP_REALM_USER/azerothcore/ -DCMAKE_INSTALL_PREFIX=/home/$SETUP_REALM_USER/server -DCMAKE_C_COMPILER=/usr/bin/clang -DCMAKE_CXX_COMPILER=/usr/bin/clang++ -DWITH_WARNINGS=0 -DWITH_COREDEBUG=1 -DTOOLS_BUILD=db-only -DSCRIPTS=$SETUP_SCRIPTS -DMODULES=$SETUP_MODULES -DAPPS_BUILD=world-only
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
CONFIG_DIR="/home/$SETUP_REALM_USER/server/etc"
# Rename all .dist config files in the global config directory
#if [ -d "$CONFIG_DIR" ]; then
#    echo "Renaming .dist files in $CONFIG_DIR"
#    find "$CONFIG_DIR" -type f -name "*.dist" -exec bash -c 'mv "$0" "${0%.dist}"' {} \;
#else
#    echo "Config directory $CONFIG_DIR does not exist. Skipping .dist file renaming."
#fi
cd /home/$SETUP_REALM_USER/server/etc/
if [ -f "/home/$SETUP_REALM_USER/server/etc/worldserver.conf.dist" ]; then
    # Backup old conf
    mv "worldserver.conf.dist" "worldserver.conf"
    ## Changing Config values
    echo "Changing Config values"
    ## Misc Edits
    sed -i 's/RealmID = 1/RealmID = '${REALM_ID}'/g' worldserver.conf
    sed -i 's/WorldServerPort = 8085/WorldServerPort = '${SETUP_REALM_PORT}'/g' worldserver.conf
    sed -i 's/RealmZone = 1/RealmZone = '${REALM_ZONE}'/g' worldserver.conf
    sed -i 's/mmap.enablePathFinding = 0/mmap.enablePathFinding = 1/g' worldserver.conf
    ## Folders
    sed -i 's^LogsDir = ""^LogsDir = "/home/'${SETUP_REALM_USER}'/server/logs"^g' worldserver.conf
    sed -i 's^DataDir = "."^DataDir = "/home/'${SETUP_REALM_USER}'/server/data"^g' worldserver.conf
    sed -i 's^BuildDirectory  = ""^BuildDirectory  = "/home/'${SETUP_REALM_USER}'/azerothcore/build"^g' worldserver.conf
    sed -i 's^SourceDirectory  = ""^SourceDirectory  = "/home/'${SETUP_REALM_USER}'/azerothcore/"^g' worldserver.conf
    ## LoginDatabaseInfo
    sed -i "s/127.0.0.1;3306;acore;acore;acore_auth/${AUTH_DB_HOST};3306;${AUTH_DB_USER};${AUTH_DB_PASS};${AUTH_DB_USER};/g" worldserver.conf
    ## WorldDatabaseInfo
    sed -i "s/127.0.0.1;3306;acore;acore;acore_world/${REALM_DB_HOST};3306;${REALM_DB_USER};${REALM_DB_PASS};${REALM_DB_USER}_world/g" worldserver.conf
    ## CharacterDatabaseInfo
    sed -i "s/127.0.0.1;3306;acore;acore;acore_characters/${REALM_DB_HOST};3306;${REALM_DB_USER};${REALM_DB_PASS};${REALM_DB_USER}_character/g" worldserver.conf
else
    echo "Missing config file, exiting..."
    exit 1
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "update" ] || [ "$1" = "$NUM" ]; then
  echo ""
  echo "##########################################################"
  echo "## $NUM. Importing Database (World and Characters Only)" 
  echo "##########################################################"
  echo ""

  # Define paths for the base and update SQL files
  BASE_SQL_PATH="~/azerothcore/sql/base"
  UPDATES_SQL_PATH="~/azerothcore/sql/updates"
  CUSTOM_SQL_PATH="~/azerothcore/sql/custom"


  # Function to execute a SQL file if it has not been executed before
  execute_sql_if_not_applied() {
    local sql_file="$1"
    local db_name="$2"
    
    # Check if this SQL file has already been applied
    result=$(mysql -u "$REALM_DB_USER" -p"$REALM_DB_PASS" -h "$REALM_DB_HOST" -s -N -e "
      SELECT COUNT(*) FROM ${REALM_DB_USER}_updates WHERE sql_file = '$sql_file';
    ")

    if [ "$result" -gt 0 ]; then
      echo "$sql_file has already been applied."
    else
      # Execute the SQL file
      echo "Processing $sql_file..."
      mysql -u "$REALM_DB_USER" -p"$REALM_DB_PASS" -h "$REALM_DB_HOST" "$db_name" < "$sql_file"
      if [ $? -ne 0 ]; then
        echo "Error importing $sql_file. Aborting."
        exit 1
      fi
      # Log the update as applied
      mysql -u "$REALM_DB_USER" -p"$REALM_DB_PASS" -h "$REALM_DB_HOST" -e "
        INSERT INTO ${REALM_DB_USER}_updates (sql_file) VALUES ('$sql_file');
      "
      echo "$sql_file applied successfully."
    fi
  }

  # Run base updates (updates.sql and updates_include.sql)
  echo "Running base updates (updates.sql and updates_include.sql)..."

  for db_dir in db_characters db_world; do
    for base_sql_file in "$BASE_SQL_PATH/$db_dir"/*updates*.sql; do
      execute_sql_if_not_applied "$base_sql_file" "${REALM_DB_USER}_${db_dir}"
    done
  done

  # Import update SQL files for characters and world in chronological order
  echo "Importing update SQL files for characters and world in chronological order..."
  for db_dir in db_characters db_world; do
    find "$UPDATES_SQL_PATH/$db_dir" -type f -name "*.sql" | sort | while read -r sql_file; do
      execute_sql_if_not_applied "$sql_file" "${REALM_DB_USER}_${db_dir}"
    done
  done

  # Import custom SQL files for characters and world
  echo "Importing custom SQL files for characters and world..."
  for db_dir in db_characters db_world; do
    for sql_file in "$CUSTOM_SQL_PATH/$db_dir"/*.sql; do
      execute_sql_if_not_applied "$sql_file" "${REALM_DB_USER}_${db_dir}"
    done
  done

  echo "Database import completed successfully."
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Download 3.3.5a Data"
echo "##########################################################"
echo ""
cd /home/$SETUP_REALM_USER/
if [ -f "/home/$SETUP_REALM_USER/server/data/data.zip" ]; then
    while true; do
        read -p "data.zip already exists. Redownload? (y/n): " file_choice
        if [[ "$file_choice" =~ ^[Yy]$ ]]; then
            sudo rm /home/$SETUP_REALM_USER/server/data/data.zip
            mkdir -p /home/$SETUP_REALM_USER//server/data
            cd /home/$SETUP_REALM_USER//server/data
            curl -L -o data.zip $DATA_REPO_URL
            7z x -y data.zip
        elif [[ "$file_choice" =~ ^[Nn]$ ]]; then
            echo "Skipping download." && break
        else
            echo "Please answer y (yes) or n (no)."
        fi
    done
else
    mkdir -p /home/$SETUP_REALM_USER/server/data 
    cd /home/$SETUP_REALM_USER/server/data
    curl -L -o data.zip $DATA_REPO_URL
    7z x -y data.zip
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Linux Restarter Scripts"
echo "##########################################################"
echo ""
mkdir /home/$SETUP_REALM_USER/server/scripts/
mkdir /home/$SETUP_REALM_USER/server/scripts/Restarter/
mkdir /home/$SETUP_REALM_USER/server/scripts/Restarter/World/
sudo cp -r -u /AzerothCore-Auto-Installer/scripts/Restarter/World/* /home/$SETUP_REALM_USER/server/scripts/Restarter/World/
## FIX SCRIPTS PERMISSIONS
sudo chmod -R +x /home/$SETUP_REALM_USER/server/scripts/Restarter/World
sudo chown -R $SETUP_REALM_USER:$SETUP_REALM_USER /home/$SETUP_REALM_USER/server/scripts/Restarter/World
sudo sed -i "s/realmname/$SETUP_REALM_USER/g" /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh
sudo sed -i "s/realmname/$SETUP_REALM_USER/g" /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Misc Scripts"
echo "##########################################################"
echo ""
cp -r -u /AzerothCore-Auto-Installer/scripts/Setup/Clean-Logs.sh /home/$SETUP_REALM_USER/server/scripts/
chmod +x  /home/$SETUP_REALM_USER/server/scripts/Clean-Logs.sh
cd /home/$SETUP_REALM_USER/server/scripts/
sudo sed -i "s^USER^${SETUP_REALM_USER}^g" Clean-Logs.sh
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Setup Crontab"
echo "##########################################################"
echo ""
crontab -r
if [ $SETUP_TYPE == "GDB" ]; then
	echo "Setup Restarter in GDB mode...."
	crontab -l | { cat; echo "############## START WORLD ##############"; } | crontab -
	crontab -l | { cat; echo "#### GDB WORLD"; } | crontab -
	crontab -l | { cat; echo "@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh"; } | crontab -
	crontab -l | { cat; echo "#### NORMAL WORLD"; } | crontab -
	crontab -l | { cat; echo "#@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh"; } | crontab -
fi
if [ $SETUP_TYPE == "Normal" ]; then
	echo "Setup Restarter in Normal mode...."
	crontab -l | { cat; echo "############## START WORLD ##############"; } | crontab -
	crontab -l | { cat; echo "#### GDB WORLD"; } | crontab -
	crontab -l | { cat; echo "#@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh"; } | crontab -
	crontab -l | { cat; echo "#### NORMAL WORLD"; } | crontab -
	crontab -l | { cat; echo "@reboot /home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh"; } | crontab -
fi
## SETUP CRONTAB BACKUPS
crontab -l | { cat; echo "############## MISC SCRIPTS ##############"; } | crontab -
crontab -l | { cat; echo "* */1* * * * /home/$SETUP_REALM_USER/server/scripts/Clean-Logs.sh"; } | crontab -
echo "$SETUP_REALM_USER Realm Crontab setup"
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
echo "alias commands='cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Realm-Dev-Install.sh && cd -'" >> ~/.bashrc

echo -e "\n## UPDATE" >> ~/.bashrc
echo "alias update='cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Realm-Dev-Install.sh update && cd -'" >> ~/.bashrc

echo -e "\n## REALMLIST" >> ~/.bashrc
echo "alias updaterealmlist='cd /AzerothCore-Auto-Installer/scripts/Setup/ && ./Realm-Dev-Install.sh realmlist && cd -'" >> ~/.bashrc

echo "Added script alias to bashrc"

if ! grep -Fxq "$FOOTER" ~/.bashrc; then
    echo -e "\n$FOOTER\n" >> ~/.bashrc
    echo "footer added"
fi

# Source .bashrc to apply changes
. ~/.bashrc
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "realmlist" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Update Realmlist"
echo "##########################################################"
echo ""
if [ $SETUP_REALMLIST == "true" ]; then
# Get the external IP address
EXTERNAL_IP=$(curl -s http://ifconfig.me)
mysql --host=$REALM_DB_HOST -h $AUTH_DB_HOST -u $AUTH_DB_USER -p$AUTH_DB_PASS << EOF
use auth
DELETE from realmlist where id = $REALM_ID;
REPLACE INTO realmlist VALUES ('$REALM_ID', '$REALM_NAME', '$EXTERNAL_IP', '$EXTERNAL_IP', '255.255.255.0', '$SETUP_REALM_PORT', '0', '0', '$REALM_ZONE', '$REALM_SECURITY', '0', '12340');
quit
EOF
fi
fi


((NUM++))
if [ "$1" = "all" ] || [ "$1" = "$NUM" ]; then
echo ""
echo "##########################################################"
echo "## $NUM.Start Server"
echo "##########################################################"
echo ""
if [ $SETUP_TYPE == "GDB" ]; then
	echo "REALM STARTED IN GDB MODE!"
	/home/$SETUP_REALM_USER/server/scripts/Restarter/World/GDB/start_gdb.sh
fi
if [ $SETUP_TYPE == "Normal" ]; then
	echo "REALM STARTED IN NORMAL MODE!"
	/home/$SETUP_REALM_USER/server/scripts/Restarter/World/Normal/start.sh
fi
fi

echo ""
echo "##########################################################"
echo "## DEV REALM INSTALLED AND FINISHED!"
echo "##########################################################"
echo ""
echo -e "\e[32m↓↓↓ To access the worldserver - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_REALM_USER -c 'screen -r $SETUP_REALM_USER'"
echo "TIP - To exit the screen press ALT + A + D"
echo ""
echo -e "\e[32m↓↓↓ To access the authserver - Run the following ↓↓↓\e[0m"
echo ""
echo "su - $SETUP_AUTH_USER -c 'screen -r $SETUP_AUTH_USER'"
echo "TIP - To exit the screen press ALT + A + D"
echo ""
echo -e "\e[31m↓↓↓ NOTICE - ONCE YOU HAVE SETUP YOUR WORLDSERVER FULLY, RUN THE FOLLOWING TO ACCESS REMOTELY ↓↓↓\e[0m"
echo "su - $SETUP_AUTH_USER -c 'updaterealmlist'"
echo ""

fi
fi
fi
fi
