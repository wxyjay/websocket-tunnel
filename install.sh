#!/bin/bash

# Constants
PYTHON_SCRIPT_URL="https://github.com/wxyjay/websocket-tunnel/raw/main/lunch_websocket.py"
LUNCH_MANAGER_SCRIPT_URL="https://github.com/wxyjay/websocket-tunnel/raw/main/lunchws_manager.sh"
INSTALL_DIR="/etc/lunchkit/lunch_websocket"
TUNNEL_SERVICE_FILE="/etc/systemd/system/lunch-tunnel.service"
UDPGW_SERVICE_FILE="/etc/systemd/system/badvpn-udpgw.service"
PYTHON_BIN=$(command -v python3)
LUNCH_MANAGER_SCRIPT="lunchws_manager.sh"
LUNCH_MANAGER_PATH="$INSTALL_DIR/$LUNCH_MANAGER_SCRIPT"
LUNCH_MANAGER_LINK="/usr/local/bin/lunchws"
UDPGW_BIN="/usr/local/bin/badvpn-udpgw"

# Function to install required packages
install_required_packages() {
    echo "Installing required packages..."
    apt-get update
    # Use apt to install python3-websocket instead of pip install
    apt-get install -y python3-pip python3-websocket dos2unix wget git cmake build-essential
}

# Function to download Python proxy script using wget
download_lunch_tunnel() {
    echo "Downloading Python Tunnel script from $PYTHON_SCRIPT_URL..."
    wget -O "$INSTALL_DIR/lunch_websocket.py" "$PYTHON_SCRIPT_URL"
}

# Function to download lunchws_manager.sh script using wget
download_lunchws_manager() {
    echo "Downloading $LUNCH_MANAGER_SCRIPT from $LUNCH_MANAGER_SCRIPT_URL..."
    wget -O "$LUNCH_MANAGER_PATH" "$LUNCH_MANAGER_SCRIPT_URL"
    chmod +x "$LUNCH_MANAGER_PATH"
    ln -sf "$LUNCH_MANAGER_PATH" "$LUNCH_MANAGER_LINK"
    convert_to_unix_line_endings "$LUNCH_MANAGER_PATH"
}

# Function to convert script to Unix line endings
convert_to_unix_line_endings() {
    local file="$1"
    echo "Converting $file to Unix line endings..."
    dos2unix "$file" &>/dev/null
}

# Function to start systemd service
start_systemd_service() {
    echo "Starting lunch-tunnel service..."
    systemctl start lunch-tunnel
    if systemctl is-active --quiet badvpn-udpgw; then
        echo "Starting badvpn-udpgw service..."
        systemctl start badvpn-udpgw
    fi
}

# Function to install systemd service for the main tunnel
install_tunnel_service() {
    echo "Creating Tunnel systemd service file..."
    cat > "$TUNNEL_SERVICE_FILE" <<EOF
[Unit]
Description=Python Tunnel Service
After=network.target

[Service]
ExecStart=$PYTHON_BIN $INSTALL_DIR/lunch_websocket.py
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
}

# Function to install udpgw
install_udpgw() {
    local udpgw_port=$1
    echo "Installing udpgw..."
    if [ -d "/root/badvpn" ]; then
        rm -rf /root/badvpn
    fi
    apt-get install -y git cmake build-essential
    git clone https://github.com/ambrop72/badvpn.git /root/badvpn
    mkdir -p /root/badvpn/badvpn-build
    cd /root/badvpn/badvpn-build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 &
    wait
    make &
    wait
    cp udpgw/badvpn-udpgw "$UDPGW_BIN"
    
    echo "Creating udpgw systemd service file..."
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
    
    systemctl enable badvpn-udpgw
    systemctl start badvpn-udpgw
    echo "udpgw installation complete, listening on port: $udpgw_port"
    cd /
}

# Function to handle udpgw installation logic
handle_udpgw_installation() {
    read -p "Do you want to install udpgw? (y/N): " choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        read -p "Do you want to set a custom udpgw port? (Default: 7300) (y/N): " port_choice
        local udpgw_port=7300
        if [[ "$port_choice" == "y" || "$port_choice" == "Y" ]]; then
            read -p "Please enter the udpgw port (1-65535): " custom_port
            if [[ "$custom_port" =~ ^[0-9]+$ && "$custom_port" -ge 1 && "$custom_port" -le 65535 ]]; then
                udpgw_port=$custom_port
                echo "udpgw port will be set to $udpgw_port."
            else
                echo "Invalid port. Using default port 7300."
            fi
        fi
        install_udpgw "$udpgw_port"
    fi
}

# Function to display banner
display_banner() {
   cat << "EOF"
*************************************************
* *
* Made by Lunch                 *
* Visit me on X: @LaunchMask            *
* *
*************************************************
EOF
    echo
}

# Function to display installation summary
display_installation_summary() {
    echo "Installation completed successfully!"
    echo
    echo "Tunnel script installed in: $INSTALL_DIR"
    echo "$LUNCH_MANAGER_SCRIPT installed in: $LUNCH_MANAGER_PATH"
    echo "You can now manage the service using the 'lunchws menu' command."
}

# Main function
main() {
    display_banner

    install_required_packages

    if [ -z "$PYTHON_BIN" ]; then
        echo "Error: Python 3 not found. Please install Python 3 first."
        exit 1
    fi

    echo "Creating installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    download_lunch_tunnel
    download_lunchws_manager
    install_tunnel_service
    
    echo "Reloading systemd..."
    systemctl daemon-reload
    echo "Enabling lunch-tunnel service..."
    systemctl enable lunch-tunnel

    handle_udpgw_installation
    
    systemctl daemon-reload

    start_systemd_service

    display_installation_summary
}

# Run main function
main
