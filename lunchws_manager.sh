#!/bin/bash

# Constants
# Constants
TUNNEL_SERVICE="lunch-tunnel"
UDPGW_SERVICE="badvpn-udpgw"
PYTHON_SCRIPT_PATH="/etc/lunchkit/lunch_websocket/lunch_websocket.py"
INSTALL_DIR="/etc/lunchkit/lunch_websocket"
UDPGW_SERVICE_FILE="/etc/systemd/system/badvpn-udpgw.service"
UDPGW_BIN="/usr/local/bin/badvpn-udpgw"

# Function to display banner
display_banner() {
   cat << "EOF"
*************************************************
*                                               *
*               Made by Lunch                   *
*         Visit me on X: @LaunchMask            *
*                                               *
*************************************************
EOF
}

# Function to show menu
show_menu() {
    clear
    display_banner
    echo "Tunnel Management Menu"
    echo "----------------------------------------"
    echo "1. Check service status"
    echo "2. Manage SSH users"
    echo "3. Change the listening port"
    echo "4. Restart the service"
    echo "5. Install/Reinstall udpgw"
    echo "6. Uninstall udpgw"
    echo "7. Uninstall Tunnel"
    echo "8. Server information"
    echo "9. Quit"
    echo "----------------------------------------"
}

# Function to check server status
check_server_status() {
    echo "Service status:"
    echo "--------------------"
    echo -n "Tunnel service ($TUNNEL_SERVICE): "
    systemctl is-active $TUNNEL_SERVICE
    
    if [ -f "$UDPGW_SERVICE_FILE" ]; then
        echo -n "udpgw service ($UDPGW_SERVICE): "
        systemctl is-active $UDPGW_SERVICE
    else
        echo "udpgw service: Not installed"
    fi
    echo "--------------------"
}

# Function to add SSH user
add_ssh_user() {
    read -p "Enter username to add: " username
    read -p "Enter password for $username: " -s password
    echo

    if [ -z "$username" ] || [ -z "$password" ]; then
        echo "Error: Username or password cannot be empty."
        return 1
    fi

    if id "$username" &>/dev/null; then
        echo "Error: User $username already exists."
        return 1
    fi

    useradd -m -s /bin/bash -G ssh "$username"
    echo "$username:$password" | chpasswd

    echo "User $username added with SSH access."
}

# Function to remove SSH user
remove_ssh_user() {
   read -p "Enter username to remove: " username

   if ! id "$username" &>/dev/null; then
       echo "Error: User $username does not exist."
       return 1
   fi

   userdel -r "$username"
   echo "User $username removed."
}

# Function to list SSH users
list_ssh_users() {
   echo "SSH Users:"
   awk -F: '$7 ~ /(\/bin\/bash|\/bin\/sh)/ && $1 != "root" { print $1 }' /etc/passwd
}

# Function to manage SSH users
manage_ssh_users() {
   while true; do
       clear
       echo -e "SSH User Management\n"
       echo "1. Add SSH User"
       echo "2. Remove SSH User"
       echo "3. List SSH Users"
       echo "4. Back to Main Menu"

       read -p "Enter your choice: " choice

       case $choice in
           1) add_ssh_user ;;
           2) remove_ssh_user ;;
           3) list_ssh_users ;;
           4) break ;;
           *) echo "Invalid choice. Please enter a valid option." ;;
       esac

       read -n 1 -s -r -p "Press any key to continue..."
       echo
   done
}

# Function to install/reinstall udpgw
install_or_reinstall_udpgw() {
    echo "This will compile and install the latest version of udpgw."
    read -p "continue? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "The operation has been cancelled."
        return
    fi
    
    local udpgw_port=7300
    read -p "Please enter udpgw port (1-65535) [Default: 7300]: " custom_port
    if [[ "$custom_port" =~ ^[0-9]+$ && "$custom_port" -ge 1 && "$custom_port" -le 65535 ]]; then
        udpgw_port=$custom_port
    else
        echo "Use default port 7300."
    fi
    
    echo "Installing udpgw..."
    systemctl stop $UDPGW_SERVICE &>/dev/null
    if [ -d "/root/badvpn" ]; then
        rm -rf /root/badvpn
    fi
    
    apt-get update && apt-get install -y git cmake build-essential
    git clone https://github.com/ambrop72/badvpn.git /root/badvpn
    mkdir -p /root/badvpn/badvpn-build
    cd /root/badvpn/badvpn-build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 &
    wait
    make &
    wait
    cp udpgw/badvpn-udpgw "$UDPGW_BIN"
    
    echo "Creating/updating the udpgw systemd service file..."
    cat > "$UDPGW_SERVICE_FILE" << ENDOFFILE
[Unit]
Description=UDP forwarding for badvpn-tun2socks
After=nss-lookup.target

[Service]
Restart=always
Type=simple
ExecStart=$UDPGW_BIN --loglevel warning --listen-addr 127.0.0.1:$udpgw_port

[Install]
WantedBy=multi-user.target
ENDOFFILE
    
    systemctl daemon-reload
    systemctl enable $UDPGW_SERVICE
    systemctl restart $UDPGW_SERVICE
    echo "udpgw installation/reinstallation is completed, listening to the port: $udpgw_port"
    cd /
}

# Function to uninstall udpgw
uninstall_udpgw() {
    if [ ! -f "$UDPGW_SERVICE_FILE" ]; then
        echo "udpgw not installed."
        return
    fi
    
    read -p "Are you sure you want to uninstall udpgw? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        echo "Stop and disable the udpgw service..."
        systemctl stop $UDPGW_SERVICE
        systemctl disable $UDPGW_SERVICE
        
        echo "Deleting the udpgw file..."
        rm -f "$UDPGW_BIN"
        rm -f "$UDPGW_SERVICE_FILE"
        
        systemctl daemon-reload
        echo "udpgw uninstall complete."
    else
        echo "The operation has been cancelled."
    fi
}

# Function to change listening port
change_listening_port() {
    # Change Tunnel port
    read -p "Enter a new Websocket Tunnel listening port:" new_tunnel_port
    if ! [[ "$new_tunnel_port" =~ ^[0-9]+$ ]]; then
        echo "Error: Please enter a valid integer port number."
    elif [ -f "$PYTHON_SCRIPT_PATH" ]; then
        # Modify the ExecStart line in the systemd service file directly
        sed -i "s|ExecStart=.*|ExecStart=$(command -v python3) $PYTHON_SCRIPT_PATH $new_tunnel_port|" "/etc/systemd/system/$TUNNEL_SERVICE.service"
        echo "The Websocket Tunnel listening port has been changed to $new_tunnel_port。"
    else
        echo "Error: Script file $PYTHON_SCRIPT_PATH not found."
    fi

    # Change udpgw port if installed
    if [ -f "$UDPGW_SERVICE_FILE" ]; then
        read -p "Do you need to change the listening port of udpgw? (y/N):" change_udpgw
        if [[ "$change_udpgw" == "y" || "$change_udpgw" == "Y" ]]; then
            read -p "Enter a new udpgw listening port:" new_udpgw_port
            if ! [[ "$new_udpgw_port" =~ ^[0-9]+$ ]]; then
                echo "Error: Please enter a valid integer port number."
            else
                sed -i "s|--listen-addr 127.0.0.1:[0-9]*|--listen-addr 127.0.0.1:$new_udpgw_port|" "$UDPGW_SERVICE_FILE"
                echo "The udpgw listening port has been changed to $new_udpgw_port。"
            fi
        fi
    fi

    echo "Restarting the service to apply changes..."
    restart_services
}

# Function to restart services
restart_services() {
    echo "Restarting $TUNNEL_SERVICE service..."
    systemctl daemon-reload
    systemctl restart $TUNNEL_SERVICE
    systemctl status $TUNNEL_SERVICE --no-pager
    
    if systemctl list-units --full -all | grep -Fq "$UDPGW_SERVICE.service"; then
        echo "Restarting $UDPGW_SERVICE service..."
        systemctl restart $UDPGW_SERVICE
        systemctl status $UDPGW_SERVICE --no-pager
    fi
}

# Function to uninstall the entire tunnel script
uninstall_tunnel_script() {
    read -p "Are you sure you want to uninstall all Tunnel-related services and files? (y/N): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "The operation has been cancelled."
        return
    fi

    echo "Stoping $TUNNEL_SERVICE service..."
    systemctl stop $TUNNEL_SERVICE
    systemctl disable $TUNNEL_SERVICE

    echo "Deleting a Tunnel file..."
    rm -rf "$INSTALL_DIR"
    rm -f "/usr/local/bin/lunchws"
    rm -f "/etc/systemd/system/$TUNNEL_SERVICE.service"

    # Uninstall udpgw if it exists
    if [ -f "$UDPGW_SERVICE_FILE" ]; then
        uninstall_udpgw <<< "y" # Pass 'y' to the confirmation prompt
    fi
    
    systemctl daemon-reload
    echo "The Tunnel script is completely uninstalled."
}

# Function to display server information
server_information() {
    echo "Server information:"
    echo "--------------------"
    
    # Tunnel Service Status
    if systemctl is-active --quiet $TUNNEL_SERVICE; then
        echo "Tunnel Service Status: Active"
    else
        echo "Tunnel Service Status: Inactive"
    fi
    
    # Tunnel Port
    current_port=$(grep -oP 'ExecStart=.* \K[0-9]+' "/etc/systemd/system/$TUNNEL_SERVICE.service")
    echo "Current Tunnel listening port: $current_port"

    # udpgw Status and Port
    if [ -f "$UDPGW_SERVICE_FILE" ]; then
        if systemctl is-active --quiet $UDPGW_SERVICE; then
            echo "Udpgw service status: Active"
        else
            echo "Udpgw service status: Inactive"
        fi
        udpgw_port=$(grep -oP '127\.0\.0\.1:\K[0-9]+' "$UDPGW_SERVICE_FILE")
        echo "Current udpgw listening port: $udpgw_port"
    else
        echo "Udpgw service status: Not installed"
    fi
    echo "--------------------"
}

# Main function
main() {
    if [ "$1" = "menu" ]; then
        while true; do
            show_menu
            read -p "Enter your selection: " choice

            case $choice in
                1) check_server_status ;;
                2) manage_ssh_users ;;
                3) change_listening_port ;;
                4) restart_services ;;
                5) install_or_reinstall_udpgw ;;
                6) uninstall_udpgw ;;
                7) uninstall_tunnel_script; break ;;
                8) server_information ;;
                9) echo "Quitting..."; break ;;
                *) echo "Invalid selection, please enter a valid option." ;;
            esac
            read -n 1 -s -r -p "Press any key to continue..."
            echo
        done
    else
        echo "Usage: $0 menu"
    fi
}

# Run main function with arguments
main "$@"
