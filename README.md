# Lunch Websocket Tunnel Installation Guide

This guide will walk you through the installation of Lunch Websocket Tunnel on your Linux system.


## Installation Steps


Follow these steps to execute the commands in your terminal:

1.  **Download the Installation Script**:
    Open your Linux terminal and use `wget` to download the latest installation script:
    ```bash
    wget [https://raw.githubusercontent.com/wxyjay/websocket-tunnel/main/install.sh](https://raw.githubusercontent.com/wxyjay/websocket-tunnel/main/install.sh)
    ```

2.  **Grant Execution Permissions**:
    Make the downloaded installation script executable:
    ```bash
    chmod +x install.sh
    ```

3.  **Run the Installation Script**:
    Execute the script with `sudo` privileges. The installation process will handle dependency installation, file downloads, service configuration, and starting the service.
    ```bash
    sudo ./install.sh
    ```
    Pay attention to any messages printed in the terminal during the installation.


## Using the Lunch Proxy Menu

After the installation is complete, you can open the Lunch Websocket Tunnel menu by entering the following command in your terminal:

```bash
lunchws menu
