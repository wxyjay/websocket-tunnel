<p align="center">
  <img src="https://img.shields.io/badge/Linux-Supported-green?logo=linux" alt="Linux Supported" />
  <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="MIT License" />
</p>

# 🥪 Lunch SSH over Websocket Tunnel Installation Guide

**Lunch Tunnel** is a lightweight, easy-to-use tool that tunnels TCP traffic over WebSocket, with optional support for `badvpn-udpgw` to forward UDP traffic. This makes it ideal for use cases like online gaming, VoIP calls, or any application requiring both TCP and UDP tunneling.

---

## 🚀 Key Features

- ✅ TCP tunneling over WebSocket with minimal setup
- ⚙️ Optional `badvpn-udpgw` for high-performance UDP forwarding
- 🧩 Interactive management menu via `lunchws menu`
- 🛠️ Automatic installation and `systemd` integration for background operation

---

## 📦 Installation Steps

Follow the steps below to install **Lunch Tunnel** on your Linux system:

### 1. Download the Installation Script

```bash
wget https://raw.githubusercontent.com/wxyjay/websocket-tunnel/main/install.sh
```

### 2. Grant Execution Permissions

```bash
chmod +x install.sh
```

### 3. Run the Installation Script (with sudo)

```bash
sudo ./install.sh
```

> ℹ️ During installation, the script will prompt you:
>
> - Whether to install `badvpn-udpgw` (UDP forwarding)
> - Whether to set a custom port (default is `7300`)
>
> You can press **Enter** to skip optional steps.

---

## 🧩 Managing the Service

After installation, you can launch the interactive management menu:

```bash
lunchws menu
```

### From this menu, you can:

- 🔍 View the status of the Tunnel and UDPGW services
- 🔄 Change listening ports (Tunnel & UDPGW)
- 👤 Add or manage SSH users
- ♻️ Install, reinstall, or uninstall UDPGW
- 🔁 Restart all related services
- 🧹 Completely uninstall the Lunch Tunnel environment

---

## 📚 Notes

- Requires a modern Linux distribution with `bash`, `wget`, `systemd`, and `python3`
- `badvpn-udpgw` is only required if your use case involves UDP traffic (e.g., games or VoIP)

---

## 💡 Example Use Cases

- 🌐 Bypass restrictive firewalls using WebSocket transport
- 🎮 Enhance online gaming experience with UDPGW
- 📞 Support stable VoIP over UDP

---

## 🛠️ Troubleshooting

If you encounter issues:

- Check logs via `journalctl -u lunchws-tunnel.service` or `-u udpgw.service`
- Ensure your ports are open in any firewall
- Re-run the menu with `lunchws menu` for reconfiguration

---

## 📤 Uninstallation

To completely remove Lunch Tunnel and all its services:

```bash
lunchws menu
```

> Choose **"Uninstall all"** from the menu.

---

## 📬 Support

For issues or feature requests, please visit the [GitHub repository](https://github.com/wxyjay/websocket-tunnel) and open an issue.

---
